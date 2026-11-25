#include "../../include/rscabi.h"

#include <stdio.h>
#include <string.h>

#define CHECK(cond)                                                              \
    do                                                                           \
    {                                                                            \
        if (!(cond))                                                             \
        {                                                                        \
            printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);               \
            failures++;                                                          \
        }                                                                        \
    } while (0)

int main(void)
{
    int failures = 0;
    uint32_t abi = 0;
    uint32_t resolved = 0;
    uint32_t callconv = 0;
    rscabi_canon_abi_t canon;
    rscabi_target_t *target = NULL;
    rscabi_context_t *ctx = NULL;
    rscabi_type_t *u32 = NULL;
    rscabi_layout_t *layout = NULL;
    rscabi_homogeneous_aggregate_t aggregate;

    CHECK(rscabi_extern_abi_from_str("Rust", &abi) == RSCABI_OK);
    CHECK(abi == RSCABI_EXTERN_ABI_RUST);
    CHECK(strcmp(rscabi_extern_abi_as_str(abi), "Rust") == 0);
    CHECK(rscabi_extern_abi_is_rustic(abi));

    CHECK(rscabi_extern_abi_from_str("aapcs", &abi) == RSCABI_OK);
    CHECK(abi == RSCABI_EXTERN_ABI_AAPCS);
    CHECK(rscabi_extern_abi_from_str("bogus", &abi) == RSCABI_ERR_INVALID_ARG);

    CHECK(rscabi_extern_abi_default_for_target("x86_64-pc-windows-msvc", &abi) ==
          RSCABI_OK);
    CHECK(abi == RSCABI_EXTERN_ABI_WIN64);

    CHECK(rscabi_extern_abi_from_str("system", &abi) == RSCABI_OK);
    CHECK(rscabi_extern_abi_resolve_system(
              abi, "x86_64-pc-windows-msvc", &resolved) == RSCABI_OK);
    CHECK(resolved == RSCABI_EXTERN_ABI_WIN64);

    CHECK(rscabi_canonize(RSCABI_EXTERN_ABI_RUST,
                          "x86_64-unknown-linux-gnu",
                          &canon) == RSCABI_OK);
    CHECK(canon.kind == RSCABI_CANON_RUST);
    CHECK(strcmp(rscabi_canon_abi_as_str(&canon), "Rust") == 0);
    CHECK(rscabi_canon_abi_is_rustic(&canon));

    CHECK(rscabi_canonize(RSCABI_EXTERN_ABI_WIN64,
                          "x86_64-pc-windows-msvc",
                          &canon) == RSCABI_OK);
    CHECK(canon.kind == RSCABI_CANON_X86);
    CHECK(canon.x86 == RSCABI_X86_CALL_WIN64);

    CHECK(rscabi_callconv_for_extern(RSCABI_EXTERN_ABI_RUST,
                                     "x86_64-unknown-linux-gnu",
                                     &callconv) == RSCABI_OK);
    CHECK(callconv == RSCABI_CALLCONV_RUST);
    CHECK(strcmp(rscabi_callconv_name(callconv), "Rust") == 0);

    CHECK(rscabi_target_new(64, 64, 64, 1, &target) == RSCABI_OK);
    CHECK(rscabi_context_new(target, &ctx) == RSCABI_OK);
    CHECK(rscabi_type_int(ctx, 32, 0, &u32) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, u32, &layout) == RSCABI_OK);

    CHECK(rscabi_layout_homogeneous_aggregate(
              ctx,
              layout,
              RSCABI_EXTERN_ABI_RUST,
              "x86_64-unknown-linux-gnu",
              &aggregate) == RSCABI_OK);
    CHECK(aggregate.kind == RSCABI_AGG_HOMOGENEOUS);
    CHECK(aggregate.reg.kind == RSCABI_REG_KIND_INTEGER);
    CHECK(aggregate.reg.size == 4);

    rscabi_layout_free(layout);
    rscabi_type_free(u32);
    rscabi_context_free(ctx);
    rscabi_target_free(target);

    if (failures != 0)
    {
        printf("%d C ABI test failure(s)\n", failures);
        return 1;
    }
    printf("C ABI tests: ok\n");
    return 0;
}
