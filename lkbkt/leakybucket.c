/*
 * leakybucket.c - standalone leaky-bucket rate limiter.
 *
 * Derived from the arithmetic of nginx's ngx_http_limit_req_module
 * (Copyright (C) Igor Sysoev, Nginx, Inc.; BSD-2-Clause).  The data
 * structures are new: nginx uses an rbtree + queue in shared memory, this
 * implementation uses a chained hash table + an LRU list in ordinary heap
 * memory, so it can be dropped into any C program.
 */

#include "leakybucket.h"

#include <stdlib.h>
#include <string.h>

#ifdef LKBKT_THREAD_SAFE
#include <pthread.h>
#endif

/* nginx refuses to expire a key that has been touched within 60 seconds. */
#define LKBKT_IDLE_MS 60000

typedef struct lkbkt_entry {
    struct lkbkt_entry *hnext; /* hash chain */
    struct lkbkt_entry *prev;  /* LRU: nearer head == more recently used */
    struct lkbkt_entry *next;
    uint64_t hash;
    uint64_t last_ms;
    uint64_t excess; /* milli-requests */
    uint32_t keylen;
    char key[]; /* flexible array member, `keylen` bytes */
} lkbkt_entry;

struct lkbkt {
    uint64_t rate;  /* milli-requests per second */
    uint64_t burst; /* milli-requests */
    uint64_t delay; /* milli-requests, UINT64_MAX == never delay */
    size_t max_keys;
    size_t nkeys;
    size_t nbuckets; /* power of two */
    uint64_t seed;
    lkbkt_entry **buckets;
    lkbkt_entry *lru_head;
    lkbkt_entry *lru_tail;
#ifdef LKBKT_THREAD_SAFE
    pthread_mutex_t lock;
#endif
};

#ifdef LKBKT_THREAD_SAFE
#define LKBKT_LOCK(b) pthread_mutex_lock(&(b)->lock)
#define LKBKT_UNLOCK(b) pthread_mutex_unlock(&(b)->lock)
#else
#define LKBKT_LOCK(b) ((void)0)
#define LKBKT_UNLOCK(b) ((void)0)
#endif

static uint64_t
lkbkt_hash(uint64_t seed, const char *key, size_t len)
{
    uint64_t h = 1469598103934665603ULL ^ seed; /* FNV-1a 64 offset basis */
    size_t i;

    for (i = 0; i < len; i++) {
        h ^= (uint64_t)(unsigned char)key[i];
        h *= 1099511628211ULL; /* FNV prime */
    }

    return h;
}

/*
 * Water drained after `elapsed` ms, in milli-requests.  `ceiling` bounds the
 * useful result (we only ever compare it against a bucket level of similar
 * size), which lets us cap `elapsed` and avoid 64-bit overflow on long idles.
 */
static uint64_t
lkbkt_leak(const lkbkt_t *b, uint64_t elapsed, uint64_t ceiling)
{
    uint64_t ms = elapsed;

    if (b->rate == 0) {
        return 0;
    }

    if (ceiling > UINT64_MAX / 1000u) {
        ceiling = UINT64_MAX / 1000u;
    }

    /* ms required to drain `ceiling`; +2 absorbs integer rounding. */
    {
        uint64_t cap = ceiling * 1000u / b->rate + 2u;
        if (ms > cap) {
            ms = cap;
        }
    }

    return b->rate * ms / 1000u;
}

static lkbkt_entry *
lkbkt_find(lkbkt_t *b, uint64_t hash, const char *key, size_t keylen)
{
    lkbkt_entry *e = b->buckets[hash & (b->nbuckets - 1u)];

    while (e != NULL) {
        if (e->hash == hash && e->keylen == (uint32_t)keylen
            && memcmp(e->key, key, keylen) == 0)
        {
            return e;
        }
        e = e->hnext;
    }

    return NULL;
}

static void
lkbkt_lru_push(lkbkt_t *b, lkbkt_entry *e)
{
    e->prev = NULL;
    e->next = b->lru_head;

    if (b->lru_head != NULL) {
        b->lru_head->prev = e;
    }
    b->lru_head = e;

    if (b->lru_tail == NULL) {
        b->lru_tail = e;
    }
}

static void
lkbkt_lru_remove(lkbkt_t *b, lkbkt_entry *e)
{
    if (e->prev != NULL) {
        e->prev->next = e->next;
    } else {
        b->lru_head = e->next;
    }

    if (e->next != NULL) {
        e->next->prev = e->prev;
    } else {
        b->lru_tail = e->prev;
    }

    e->prev = NULL;
    e->next = NULL;
}

static void
lkbkt_lru_touch(lkbkt_t *b, lkbkt_entry *e)
{
    if (b->lru_head == e) {
        return;
    }
    lkbkt_lru_remove(b, e);
    lkbkt_lru_push(b, e);
}

static void
lkbkt_hash_remove(lkbkt_t *b, lkbkt_entry *e)
{
    lkbkt_entry **pp = &b->buckets[e->hash & (b->nbuckets - 1u)];

    while (*pp != NULL) {
        if (*pp == e) {
            *pp = e->hnext;
            return;
        }
        pp = &(*pp)->hnext;
    }
}

static void
lkbkt_insert(lkbkt_t *b, lkbkt_entry *e)
{
    size_t idx = e->hash & (b->nbuckets - 1u);

    e->hnext = b->buckets[idx];
    b->buckets[idx] = e;
    lkbkt_lru_push(b, e);
    b->nkeys++;
}

static void
lkbkt_drop(lkbkt_t *b, lkbkt_entry *e)
{
    lkbkt_hash_remove(b, e);
    lkbkt_lru_remove(b, e);
    free(e);
    b->nkeys--;
}

static void
lkbkt_evict_tail(lkbkt_t *b)
{
    if (b->lru_tail != NULL) {
        lkbkt_drop(b, b->lru_tail);
    }
}

lkbkt_t *
lkbkt_new(unsigned rate_per_sec, unsigned burst, unsigned delay,
          size_t max_keys)
{
    lkbkt_t *b;
    size_t nb = 16;

    if (rate_per_sec == 0 || max_keys == 0) {
        return NULL;
    }

    while (nb < max_keys) {
        if (nb > ((size_t)-1) / 2) {
            return NULL;
        }
        nb <<= 1;
    }

    b = (lkbkt_t *)calloc(1, sizeof(*b));
    if (b == NULL) {
        return NULL;
    }

    b->buckets = (lkbkt_entry **)calloc(nb, sizeof(*b->buckets));
    if (b->buckets == NULL) {
        free(b);
        return NULL;
    }

    b->rate = (uint64_t)rate_per_sec * 1000u;
    b->burst = (uint64_t)burst * 1000u;
    b->delay = (delay == LKBKT_NODELAY)
                   ? UINT64_MAX
                   : (uint64_t)delay * 1000u;
    b->max_keys = max_keys;
    b->nkeys = 0;
    b->nbuckets = nb;
    b->lru_head = NULL;
    b->lru_tail = NULL;
    b->seed = (uint64_t)(uintptr_t)b ^ 0x9e3779b97f4a7c15ULL;

#ifdef LKBKT_THREAD_SAFE
    if (pthread_mutex_init(&b->lock, NULL) != 0) {
        free(b->buckets);
        free(b);
        return NULL;
    }
#endif

    return b;
}

void
lkbkt_free(lkbkt_t *b)
{
    lkbkt_entry *e;

    if (b == NULL) {
        return;
    }

    e = b->lru_head;
    while (e != NULL) {
        lkbkt_entry *next = e->next;
        free(e);
        e = next;
    }

    free(b->buckets);

#ifdef LKBKT_THREAD_SAFE
    pthread_mutex_destroy(&b->lock);
#endif

    free(b);
}

lkbkt_result
lkbkt_check(lkbkt_t *b, const char *key, size_t keylen, uint64_t now_ms,
            uint32_t *delay_ms)
{
    lkbkt_entry *e;
    uint64_t hash;
    uint64_t excess;
    uint64_t leak;
    int64_t ms;
    int64_t ex;

    if (delay_ms != NULL) {
        *delay_ms = 0;
    }

    if (b == NULL || (key == NULL && keylen != 0)
        || keylen > (size_t)UINT32_MAX)
    {
        return LKBKT_ERROR;
    }

    LKBKT_LOCK(b);

    hash = lkbkt_hash(b->seed, key, keylen);
    e = lkbkt_find(b, hash, key, keylen);

    if (e == NULL) {
        /*
         * nginx creates a new node with excess = 0 and last = now, so the
         * very first request observed for a key is always admitted.
         */
        if (b->nkeys >= b->max_keys) {
            lkbkt_evict_tail(b);
        }

        e = (lkbkt_entry *)malloc(sizeof(*e) + keylen);
        if (e == NULL) {
            LKBKT_UNLOCK(b);
            return LKBKT_ERROR;
        }

        e->hash = hash;
        e->last_ms = now_ms;
        e->excess = 0;
        e->keylen = (uint32_t)keylen;
        e->hnext = NULL;
        e->prev = NULL;
        e->next = NULL;
        if (keylen != 0) {
            memcpy(e->key, key, keylen);
        }

        lkbkt_insert(b, e);
        LKBKT_UNLOCK(b);
        return LKBKT_PASS;
    }

    lkbkt_lru_touch(b, e);

    ms = (int64_t)(now_ms - e->last_ms);
    if (ms < -60000) {
        ms = 1; /* clock jumped far backwards: assume a 1 ms step */
    } else if (ms < 0) {
        ms = 0;
    }

    leak = lkbkt_leak(b, (uint64_t)ms, e->excess + 1000u);

    /* exact nginx expression, including the clamp after +1000: */
    ex = (int64_t)e->excess - (int64_t)leak + 1000;
    if (ex < 0) {
        ex = 0;
    }
    excess = (uint64_t)ex;

    if (excess > b->burst) {
        /* Over the limit: nginx returns BUSY without touching the state. */
        LKBKT_UNLOCK(b);
        return LKBKT_REJECT;
    }

    if (ms != 0) {
        e->last_ms = now_ms;
    }
    e->excess = excess;

    if (excess <= b->delay) {
        LKBKT_UNLOCK(b);
        return LKBKT_PASS;
    }

    {
        uint64_t wait = (excess - b->delay) * 1000u / b->rate;
        if (wait > (uint64_t)UINT32_MAX) {
            wait = (uint64_t)UINT32_MAX;
        }
        if (delay_ms != NULL) {
            *delay_ms = (uint32_t)wait;
        }
    }

    LKBKT_UNLOCK(b);
    return LKBKT_DELAY;
}

size_t
lkbkt_expire(lkbkt_t *b, uint64_t now_ms)
{
    size_t removed = 0;

    if (b == NULL) {
        return 0;
    }

    LKBKT_LOCK(b);

    while (b->lru_tail != NULL) {
        lkbkt_entry *e = b->lru_tail;
        int64_t ms = (int64_t)(now_ms - e->last_ms);
        uint64_t leak;

        if (ms < 0) {
            ms = -ms;
        }
        if (ms < LKBKT_IDLE_MS) {
            break;
        }

        leak = lkbkt_leak(b, (uint64_t)ms, e->excess + 1u);
        if (e->excess > leak) {
            break; /* still has water, keep it */
        }

        lkbkt_drop(b, e);
        removed++;
    }

    LKBKT_UNLOCK(b);
    return removed;
}

size_t
lkbkt_size(const lkbkt_t *b)
{
    return (b != NULL) ? b->nkeys : 0;
}
