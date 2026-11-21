#include "leakybucket.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

static const char *
result_name(lkbkt_result r)
{
    switch (r) {
    case LKBKT_PASS:
        return "PASS";
    case LKBKT_DELAY:
        return "DELAY";
    case LKBKT_REJECT:
        return "REJECT";
    case LKBKT_ERROR:
        return "ERROR";
    }
    return "?";
}

int
main(void)
{
    /* nginx equivalent: limit_req_zone ... rate=10r/s; limit_req ... burst=5; */
    lkbkt_t *lkb = lkbkt_new(10, 5, 0, 1024);
    const char *key = "192.0.2.1";
    uint64_t now = 1000;
    int i;

    if (lkb == NULL) {
        perror("lkbkt_new");
        return 1;
    }

    printf("rate=10 r/s  burst=5  delay=0 (nginx default: excess is delayed)\n");
    printf("one request every 10 ms, i.e. 10x faster than the allowed rate\n\n");

    for (i = 1; i <= 12; i++) {
        uint32_t wait = 0;
        lkbkt_result r = lkbkt_check(lkb, key, strlen(key), now, &wait);

        printf("  req %2d @ t=%5" PRIu64 "ms  ->  %-6s", i, now,
               result_name(r));
        if (r == LKBKT_DELAY) {
            printf(" wait %u ms", wait);
        }
        if (r == LKBKT_REJECT) {
            printf(" (dropped, state unchanged)");
        }
        printf("\n");

        now += 10;
    }

    printf("\nkeys tracked: %zu\n", lkbkt_size(lkb));
    printf("idle-expire after 60 s: %zu key(s) removed\n",
           lkbkt_expire(lkb, now + 60000));

    lkbkt_free(lkb);
    return 0;
}
