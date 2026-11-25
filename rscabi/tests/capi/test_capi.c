#include "../../include/rscabi.h"

#include <stdio.h>

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
    rscabi_target_t *target = NULL;
    rscabi_context_t *ctx = NULL;
    rscabi_type_t *u8 = NULL;
    rscabi_type_t *u16 = NULL;
    rscabi_type_t *ref = NULL;
    rscabi_type_t *slice_ref = NULL;
    rscabi_type_t *boxed = NULL;
    rscabi_type_t *nonnulled = NULL;
    rscabi_type_t *option = NULL;
    rscabi_type_t *tuple = NULL;
    rscabi_type_t *union_type = NULL;
    rscabi_type_t *simd = NULL;
    rscabi_type_t *coroutine = NULL;
    rscabi_layout_t *layout = NULL;
    rscabi_layout_t *union_layout = NULL;
    rscabi_layout_t *simd_layout = NULL;
    rscabi_layout_t *coroutine_layout = NULL;
    rscabi_layout_t *slice_ref_layout = NULL;
    rscabi_layout_t *box_layout = NULL;
    rscabi_layout_t *nonnull_layout = NULL;
    rscabi_layout_info_t info;
    rscabi_variant_info_t variant;
    rscabi_u128_t zero;
    rscabi_u128_t one;
    const rscabi_type_t *some_fields[1];
    uint64_t offsets[8];
    uint32_t order[8];
    uint32_t code = 0;
    size_t state0 = 0;
    size_t state1 = 0;
    size_t count = 0;
    rscabi_byte_range_t ranges[8];
    size_t variant_count = 0;
    size_t range_count = 0;
    int dependent_padding = 0;

    zero.lo = 0;
    zero.hi = 0;
    one.lo = 1;
    one.hi = 0;

    CHECK(rscabi_abi_version() == 1);
    CHECK(rscabi_target_new(64, 64, 64, 1, &target) == RSCABI_OK);
    CHECK(rscabi_context_new(target, &ctx) == RSCABI_OK);
    CHECK(rscabi_type_int(ctx, 8, 0, &u8) == RSCABI_OK);
    CHECK(rscabi_type_reference(ctx, u8, 0, &ref) == RSCABI_OK);
    CHECK(rscabi_type_enum_begin(ctx, NULL, &option) == RSCABI_OK);
    CHECK(rscabi_type_enum_add_variant(ctx, option, NULL, 0, zero, 0) == RSCABI_OK);
    some_fields[0] = ref;
    CHECK(rscabi_type_enum_add_variant(ctx, option, some_fields, 1, one, 0) == RSCABI_OK);
    CHECK(rscabi_type_finish(ctx, option) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, option, &layout) == RSCABI_OK);

    CHECK(rscabi_layout_info(layout, &info) == RSCABI_OK);
    CHECK(info.size == 8);
    CHECK(info.align == 8);
    CHECK(info.tag_encoding == RSCABI_TAG_NICHE);
    CHECK(info.variant_count == 2);
    CHECK(info.backend_repr == RSCABI_BACKEND_SCALAR);

    CHECK(rscabi_layout_variant_count(layout, &variant_count) == RSCABI_OK);
    CHECK(variant_count == 2);
    CHECK(rscabi_layout_variant_info(layout, 0, &variant) == RSCABI_OK);
    CHECK(variant.has_tag_range == 1);
    CHECK(variant.tag_start.lo == 0);
    CHECK(variant.tag_end.lo == 0);

    /* Niche encoding: the whole pointer-sized niche doubles as the payload
       slot, so `Option<&u8>` has no variant-dependent padding. */
    CHECK(rscabi_layout_has_variant_dependent_padding(layout, &dependent_padding) == RSCABI_OK);
    CHECK(dependent_padding == 0);

    CHECK(rscabi_layout_variant_dependent_padding_ranges(layout, 0, ranges, 8, &range_count)
          == RSCABI_OK);
    CHECK(range_count == 0);
    CHECK(rscabi_layout_variant_dependent_padding_ranges(layout, 1, ranges, 8, &range_count)
          == RSCABI_OK);
    CHECK(range_count == 0);

    CHECK(rscabi_type_box(ctx, u8, &boxed) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, boxed, &box_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(box_layout, &info) == RSCABI_OK);
    CHECK(info.size == 8);
    CHECK(info.has_largest_niche == 1);

    CHECK(rscabi_type_nonnull(ctx, u8, &nonnulled) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, nonnulled, &nonnull_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(nonnull_layout, &info) == RSCABI_OK);
    CHECK(info.size == 8);
    CHECK(info.has_largest_niche == 1);

    CHECK(rscabi_type_slice_ref(ctx, u8, 0, &slice_ref) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, slice_ref, &slice_ref_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(slice_ref_layout, &info) == RSCABI_OK);
    CHECK(info.size == 16);
    CHECK(info.align == 8);
    CHECK(info.backend_repr == RSCABI_BACKEND_SCALAR_PAIR);

    CHECK(rscabi_type_tuple_begin(ctx, &tuple) == RSCABI_OK);
    CHECK(rscabi_type_int(ctx, 16, 0, &u16) == RSCABI_OK);
    CHECK(rscabi_type_add_field(ctx, tuple, u16) == RSCABI_OK);
    CHECK(rscabi_type_finish(ctx, tuple) == RSCABI_OK);
    CHECK(rscabi_type_add_field(ctx, tuple, u16) == RSCABI_ERR_INVALID_ARG);

    CHECK(rscabi_type_union_begin(ctx, NULL, &union_type) == RSCABI_OK);
    CHECK(rscabi_type_add_field(ctx, union_type, u8) == RSCABI_OK);
    CHECK(rscabi_type_add_field(ctx, union_type, u16) == RSCABI_OK);
    CHECK(rscabi_type_finish(ctx, union_type) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, union_type, &union_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(union_layout, &info) == RSCABI_OK);
    CHECK(info.size == 2);
    CHECK(info.align == 2);
    CHECK(rscabi_layout_fields_kind(union_layout, &code) == RSCABI_OK);
    CHECK(code == RSCABI_FIELDS_UNION);
    CHECK(rscabi_layout_field_offsets(union_layout, offsets, 8, &count) == RSCABI_OK);
    CHECK(count == 2);
    CHECK(offsets[0] == 0);
    CHECK(offsets[1] == 0);
    CHECK(rscabi_layout_memory_order(union_layout, order, 8, &count) == RSCABI_OK);
    CHECK(count == 2);
    CHECK(order[0] == 0);
    CHECK(order[1] == 1);

    CHECK(rscabi_type_simd(ctx, u8, 16, 0, &simd) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, simd, &simd_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(simd_layout, &info) == RSCABI_OK);
    CHECK(info.size == 16);
    CHECK(info.align == 16);
    CHECK(info.backend_repr == RSCABI_BACKEND_SIMD_VECTOR);

    CHECK(rscabi_type_coroutine_begin(ctx, &coroutine) == RSCABI_OK);
    CHECK(rscabi_type_coroutine_add_state(ctx, coroutine, zero, &state0) == RSCABI_OK);
    CHECK(state0 == 0);
    CHECK(rscabi_type_coroutine_add_state(ctx, coroutine, one, &state1) == RSCABI_OK);
    CHECK(state1 == 1);
    CHECK(rscabi_type_coroutine_add_state_field(ctx, coroutine, state0, u8) == RSCABI_OK);
    CHECK(rscabi_type_coroutine_add_state_field(ctx, coroutine, state1, u16) == RSCABI_OK);
    CHECK(rscabi_type_coroutine_set_discriminant(ctx, coroutine, state1, one) == RSCABI_OK);
    CHECK(rscabi_type_finish(ctx, coroutine) == RSCABI_OK);
    CHECK(rscabi_layout_of(ctx, coroutine, &coroutine_layout) == RSCABI_OK);
    CHECK(rscabi_layout_info(coroutine_layout, &info) == RSCABI_OK);
    CHECK(info.variant_count == 2);
    CHECK(info.tag_encoding == RSCABI_TAG_DIRECT);
    CHECK(rscabi_layout_tag_encoding(coroutine_layout, &code) == RSCABI_OK);
    CHECK(code == RSCABI_TAG_DIRECT);
    CHECK(rscabi_layout_variant_field_offsets(coroutine_layout, 0, offsets, 8, &count)
          == RSCABI_OK);
    CHECK(count == 1);
    CHECK(rscabi_layout_variant_memory_order(coroutine_layout, 0, order, 8, &count)
          == RSCABI_OK);
    CHECK(count == 1);
    CHECK(rscabi_layout_variant_tag_range(coroutine_layout, 0, &zero, &one) == RSCABI_OK);
    CHECK(zero.lo == 0);
    CHECK(one.lo == 0);

    rscabi_layout_free(coroutine_layout);
    rscabi_layout_free(simd_layout);
    rscabi_layout_free(union_layout);
    rscabi_layout_free(nonnull_layout);
    rscabi_layout_free(slice_ref_layout);
    rscabi_layout_free(box_layout);
    rscabi_layout_free(layout);
    rscabi_type_free(slice_ref);
    rscabi_type_free(tuple);
    rscabi_type_free(coroutine);
    rscabi_type_free(simd);
    rscabi_type_free(union_type);
    rscabi_type_free(u16);
    rscabi_type_free(nonnulled);
    rscabi_type_free(boxed);
    rscabi_type_free(option);
    rscabi_type_free(ref);
    rscabi_type_free(u8);
    rscabi_context_free(ctx);
    rscabi_target_free(target);

    if (failures != 0)
    {
        printf("%d check(s) failed\n", failures);
        return 1;
    }
    printf("rscabi C API tests: ok\n");
    return 0;
}
