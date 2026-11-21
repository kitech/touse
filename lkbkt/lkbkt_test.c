/*
 * lkbkt_test.c - behaviour tests for the nginx-derived leaky bucket.
 *
 * Expected values are derived by hand from nginx's formula:
 *
 *     excess = excess - rate * ms / 1000 + 1000   (clamped at 0)
 *     reject when excess > burst
 *     delay  when excess > delay
 */

#include "leakybucket.h"

#include <stdio.h>
#include <string.h>

static int failures;

#define CHECK(cond)                                                           \
    do {                                                                      \
        if (!(cond)) {                                                        \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);   \
            failures++;                                                       \
        }                                                                     \
    } while (0)

#define KEY "k"

static lkbkt_result
hit(lkbkt_t *b, const char *key, uint64_t now_ms, uint32_t *delay_ms)
{
    return lkbkt_check(b, key, strlen(key), now_ms, delay_ms);
}

/*
 * nodelay: first request for a key is free (nginx excess starts at 0), then
 * `burst` more requests pass, everything above `burst` is rejected.
 */
static void
test_nodelay_burst(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, LKBKT_NODELAY, 128);
    int i, passed = 0, rejected = 0;

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    for (i = 0; i < 8; i++) {
        lkbkt_result r = hit(b, KEY, 1000, NULL);
        if (r == LKBKT_PASS) {
            passed++;
        } else if (r == LKBKT_REJECT) {
            rejected++;
        }
    }

    CHECK(passed == 6);   /* 1 free + burst (5) */
    CHECK(rejected == 2);

    /* after one full second the water has drained completely */
    CHECK(hit(b, KEY, 2000, NULL) == LKBKT_PASS);

    lkbkt_free(b);
}

/* default nginx behaviour: every excess request is delayed. */
static void
test_default_delay(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, 0, 128);
    uint32_t w = 0;
    int i;

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, KEY, 1000, &w) == LKBKT_PASS); /* first request is free */
    CHECK(w == 0);

    CHECK(hit(b, KEY, 1000, &w) == LKBKT_DELAY);
    CHECK(w == 100); /* excess 1000 / rate 10000 per s == 100 ms */

    CHECK(hit(b, KEY, 1000, &w) == LKBKT_DELAY);
    CHECK(w == 200);

    for (i = 0; i < 3; i++) {
        CHECK(hit(b, KEY, 1000, &w) == LKBKT_DELAY);
    }
    CHECK(w == 500); /* excess reached burst */

    CHECK(hit(b, KEY, 1000, &w) == LKBKT_REJECT);

    lkbkt_free(b);
}

/* delay=N: requests up to N excess units pass without being delayed. */
static void
test_delay_threshold(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, 2, 128);
    uint32_t w = 0;

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, KEY, 0, &w) == LKBKT_PASS); /* free */
    CHECK(hit(b, KEY, 0, &w) == LKBKT_PASS); /* excess 1000 <= 2000 */
    CHECK(hit(b, KEY, 0, &w) == LKBKT_PASS); /* excess 2000 <= 2000 */

    CHECK(hit(b, KEY, 0, &w) == LKBKT_DELAY);
    CHECK(w == 100); /* (3000 - 2000) / 10000 per s == 100 ms */

    lkbkt_free(b);
}

/* 1 r/s, no burst: exactly one request per second gets through. */
static void
test_one_per_second(void)
{
    lkbkt_t *b = lkbkt_new(1, 0, LKBKT_NODELAY, 128);

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, KEY, 0, NULL) == LKBKT_PASS);    /* free */
    CHECK(hit(b, KEY, 0, NULL) == LKBKT_REJECT);
    CHECK(hit(b, KEY, 1000, NULL) == LKBKT_PASS);
    CHECK(hit(b, KEY, 1000, NULL) == LKBKT_REJECT);
    CHECK(hit(b, KEY, 2000, NULL) == LKBKT_PASS);

    lkbkt_free(b);
}

/* A backwards clock must not create extra burst capacity. */
static void
test_clock_backwards(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, LKBKT_NODELAY, 128);

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, KEY, 100000, NULL) == LKBKT_PASS);
    CHECK(hit(b, KEY, 100000, NULL) == LKBKT_PASS);

    /* step back 60 s: elapsed is clamped to 0, water keeps accumulating */
    CHECK(hit(b, KEY, 40000, NULL) == LKBKT_PASS); /* 2000 */
    CHECK(hit(b, KEY, 40000, NULL) == LKBKT_PASS); /* 3000 */
    CHECK(hit(b, KEY, 40000, NULL) == LKBKT_PASS); /* 4000 */
    CHECK(hit(b, KEY, 40000, NULL) == LKBKT_PASS); /* 5000 */
    CHECK(hit(b, KEY, 40000, NULL) == LKBKT_REJECT);

    lkbkt_free(b);
}

/* Least-recently-used keys are evicted when max_keys is reached. */
static void
test_eviction(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, LKBKT_NODELAY, 2);

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, "a", 1000, NULL) == LKBKT_PASS);
    CHECK(hit(b, "b", 1000, NULL) == LKBKT_PASS);
    CHECK(lkbkt_size(b) == 2);

    CHECK(hit(b, "c", 1000, NULL) == LKBKT_PASS); /* evicts oldest: "a" */
    CHECK(lkbkt_size(b) == 2);

    /* "a" was evicted, so it starts over: first request is free */
    CHECK(hit(b, "a", 1000, NULL) == LKBKT_PASS);
    CHECK(lkbkt_size(b) == 2);

    lkbkt_free(b);
}

/* Different keys have independent buckets. */
static void
test_key_isolation(void)
{
    lkbkt_t *b = lkbkt_new(1, 0, LKBKT_NODELAY, 128);

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, "x", 0, NULL) == LKBKT_PASS);
    CHECK(hit(b, "x", 0, NULL) == LKBKT_REJECT);
    CHECK(hit(b, "y", 0, NULL) == LKBKT_PASS);

    lkbkt_free(b);
}

/* Idle + drained keys are removed after 60 s. */
static void
test_expire(void)
{
    lkbkt_t *b = lkbkt_new(10, 5, LKBKT_NODELAY, 128);

    CHECK(b != NULL);
    if (b == NULL) {
        return;
    }

    CHECK(hit(b, "idle", 1000, NULL) == LKBKT_PASS);
    CHECK(lkbkt_size(b) == 1);

    CHECK(lkbkt_expire(b, 1000 + 59999) == 0); /* not idle long enough */
    CHECK(lkbkt_size(b) == 1);

    CHECK(lkbkt_expire(b, 1000 + 60000) == 1);
    CHECK(lkbkt_size(b) == 0);

    lkbkt_free(b);
}

static void
test_bad_args(void)
{
    CHECK(lkbkt_new(0, 5, 0, 10) == NULL);
    CHECK(lkbkt_new(10, 5, 0, 0) == NULL);
    CHECK(lkbkt_check(NULL, "k", 1, 0, NULL) == LKBKT_ERROR);
}

int
main(void)
{
    test_nodelay_burst();
    test_default_delay();
    test_delay_threshold();
    test_one_per_second();
    test_clock_backwards();
    test_eviction();
    test_key_isolation();
    test_expire();
    test_bad_args();

    if (failures == 0) {
        printf("all tests passed\n");
        return 0;
    }

    fprintf(stderr, "%d check(s) failed\n", failures);
    return 1;
}
