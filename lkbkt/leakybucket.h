/*
 * leakybucket.h - standalone leaky-bucket rate limiter in C.
 *
 * The accumulation/leak arithmetic is a re-implementation of the algorithm
 * used by nginx's ngx_http_limit_req_module (BSD-2-Clause):
 *
 *     excess = excess - rate * elapsed_ms / 1000 + 1000
 *
 * Units, identical to nginx:
 *   - rate  : milli-requests per second   (1000  ==  1 r/s)
 *   - excess: milli-requests, i.e. water level (1000 == 1 request)
 *   - burst : milli-requests              (burst * 1000)
 *   - delay : milli-requests              (delay * 1000)
 */

#ifndef LKBKT_LEAKYBUCKET_H
#define LKBKT_LEAKYBUCKET_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lkbkt lkbkt_t;

typedef enum lkbkt_result {
    LKBKT_PASS   = 0, /* serve immediately */
    LKBKT_DELAY  = 1, /* serve after *delay_ms milliseconds */
    LKBKT_REJECT = 2, /* over the limit, reject */
    LKBKT_ERROR  = 3  /* invalid argument or out of memory */
} lkbkt_result;

/*
 * Pass this as `delay` to reproduce nginx's `nodelay`: excess requests below
 * `burst` are served immediately, requests above `burst` are rejected. There
 * is no delaying at all.
 */
#define LKBKT_NODELAY 0xFFFFFFFFu

/*
 * Create a limiter.
 *
 *   rate_per_sec  requests per second, must be > 0
 *   burst         additional requests tolerated above the steady rate
 *   delay         requests below this level pass immediately; between `delay`
 *                 and `burst` they are delayed. 0 == nginx default (delay
 *                 every excess request). LKBKT_NODELAY == never delay.
 *   max_keys      maximum number of distinct keys kept in memory (> 0);
 *                 least-recently-used keys are evicted when full.
 *
 * Returns NULL on invalid parameters or allocation failure.
 */
lkbkt_t *lkbkt_new(unsigned rate_per_sec, unsigned burst, unsigned delay,
                   size_t max_keys);

void lkbkt_free(lkbkt_t *lkb);

/*
 * Account one request for `key`.
 *
 * `now_ms` is a caller-supplied monotonic clock in milliseconds. Supplying it
 * instead of calling clock_gettime() keeps the core deterministic and testable.
 *
 * On LKBKT_DELAY, *delay_ms (when non-NULL) receives the number of milliseconds
 * the caller should wait before serving the request.
 *
 * The bucket state is left untouched on LKBKT_REJECT, matching nginx.
 */
lkbkt_result lkbkt_check(lkbkt_t *lkb, const char *key, size_t keylen,
                         uint64_t now_ms, uint32_t *delay_ms);

/*
 * Drop keys that have been idle for at least 60 seconds and whose water level
 * has fully drained. Returns the number of keys removed. Mirrors nginx's
 * ngx_http_limit_req_expire().
 */
size_t lkbkt_expire(lkbkt_t *lkb, uint64_t now_ms);

/* Number of keys currently tracked. */
size_t lkbkt_size(const lkbkt_t *lkb);

#ifdef __cplusplus
}
#endif

#endif /* LKBKT_LEAKYBUCKET_H */
