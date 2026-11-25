#include <cstdio>
#include <cstdlib>

#include "../../src/model/abi_type.hpp"

namespace {

int failures = 0;

#define CHECK(cond)                                                              \
    do                                                                           \
    {                                                                            \
        if (!(cond))                                                             \
        {                                                                        \
            printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);               \
            failures++;                                                          \
        }                                                                        \
    } while (0)

rscabi::AbiType *int_type(rscabi::TypeContext *ctx,
                          uint32_t bits,
                          bool is_signed = false)
{
    rscabi::AbiType *type = ctx->create(rscabi::TypeKind::Int);
    type->scalar.primitive = rscabi::PrimitiveKind::Int;
    type->scalar.bits = bits;
    type->scalar.is_signed = is_signed;
    type->scalar.valid = rscabi::WrappingRange::full(bits);
    return type;
}

rscabi::AbiType *option_of(rscabi::TypeContext *ctx, rscabi::AbiType *inner)
{
    rscabi::AbiType *type = ctx->create(rscabi::TypeKind::Enum);
    rscabi::EnumVariant none;
    none.discriminant = rscabi::U128::from_u64(0);
    type->variants.push_back(none);
    rscabi::EnumVariant some;
    some.fields.push_back(inner);
    some.discriminant = rscabi::U128::from_u64(1);
    type->variants.push_back(some);
    return type;
}

rscabi::LayoutData layout_of(rscabi::TypeContext *ctx, rscabi::AbiType *type)
{
    rscabi::LayoutData result;
    if (!ctx->layout_of(type, &result))
    {
        printf("FAIL layout_of returned false\n");
        failures++;
    }
    return result;
}

void test_primitives()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);

    rscabi::LayoutData unit = layout_of(&ctx, ctx.create(rscabi::TypeKind::Unit));
    CHECK(unit.size == 0);
    CHECK(unit.align == 1);

    rscabi::LayoutData u8 = layout_of(&ctx, int_type(&ctx, 8));
    CHECK(u8.size == 1);
    CHECK(u8.align == 1);
    CHECK(u8.backend == rscabi::BackendReprKind::Scalar);

    rscabi::LayoutData u32 = layout_of(&ctx, int_type(&ctx, 32));
    CHECK(u32.size == 4);
    CHECK(u32.align == 4);

    rscabi::LayoutData u64 = layout_of(&ctx, int_type(&ctx, 64));
    CHECK(u64.size == 8);
    CHECK(u64.align == 8);

    rscabi::LayoutData boolean = layout_of(&ctx, ctx.create(rscabi::TypeKind::Bool));
    CHECK(boolean.size == 1);
    CHECK(boolean.has_niche);

    rscabi::LayoutData pointer = layout_of(&ctx, ctx.create(rscabi::TypeKind::Pointer));
    CHECK(pointer.size == 8);
    CHECK(pointer.align == 8);

    rscabi::LayoutData reference = layout_of(&ctx, ctx.create(rscabi::TypeKind::Reference));
    CHECK(reference.size == 8);
    CHECK(reference.has_niche);
    CHECK(reference.largest_niche.offset == 0);
    CHECK(reference.largest_niche.value.start.lo == 0);
    CHECK(reference.largest_niche.value.end.lo == 0);
}

void test_aggregates()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);

    rscabi::AbiType *structure = ctx.create(rscabi::TypeKind::Struct);
    structure->fields.push_back(int_type(&ctx, 8));
    structure->fields.push_back(int_type(&ctx, 32));
    rscabi::LayoutData struct_layout = layout_of(&ctx, structure);
    CHECK(struct_layout.size == 8);
    CHECK(struct_layout.align == 4);
    CHECK(struct_layout.field_offsets[0] == 4);
    CHECK(struct_layout.field_offsets[1] == 0);
    CHECK(struct_layout.in_memory_order[0] == 1);
    CHECK(struct_layout.in_memory_order[1] == 0);

    rscabi::AbiType *packed = ctx.create(rscabi::TypeKind::Struct);
    packed->repr.is_packed = true;
    packed->repr.pack_bits = 8;
    packed->fields.push_back(int_type(&ctx, 8));
    packed->fields.push_back(int_type(&ctx, 32));
    rscabi::LayoutData packed_layout = layout_of(&ctx, packed);
    CHECK(packed_layout.size == 5);
    CHECK(packed_layout.align == 1);
    CHECK(packed_layout.field_offsets[0] == 0);
    CHECK(packed_layout.field_offsets[1] == 1);

    rscabi::AbiType *array = ctx.create(rscabi::TypeKind::Array);
    array->inner = int_type(&ctx, 16);
    array->array_count = 3;
    rscabi::LayoutData array_layout = layout_of(&ctx, array);
    CHECK(array_layout.size == 6);
    CHECK(array_layout.align == 2);

    rscabi::AbiType *nonzero = ctx.create(rscabi::TypeKind::NonZero);
    nonzero->inner = int_type(&ctx, 32);
    rscabi::LayoutData nonzero_layout = layout_of(&ctx, nonzero);
    CHECK(nonzero_layout.size == 4);
    CHECK(nonzero_layout.has_niche);
    CHECK(nonzero_layout.largest_niche.value.start.is_zero());
    CHECK(nonzero_layout.largest_niche.value.end.is_zero());
}

void test_enums()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);

    rscabi::LayoutData option_ref = layout_of(&ctx, option_of(&ctx, ctx.create(rscabi::TypeKind::Reference)));
    CHECK(option_ref.size == 8);
    CHECK(option_ref.align == 8);
    CHECK(option_ref.tag_encoding == rscabi::TagEncodingKind::Niche);
    CHECK(option_ref.variants.size() == 2);
    CHECK(option_ref.variants[0].has_tag_range);
    CHECK(option_ref.variants[0].tag_range.start.lo == 0);
    CHECK(option_ref.variants[0].tag_range.end.lo == 0);

    rscabi::LayoutData option_u8 = layout_of(&ctx, option_of(&ctx, int_type(&ctx, 8)));
    CHECK(option_u8.size == 2);
    CHECK(option_u8.align == 1);
    CHECK(option_u8.tag_encoding == rscabi::TagEncodingKind::Direct);
    CHECK(option_u8.variants.size() == 2);

    rscabi::LayoutData option_u32 = layout_of(&ctx, option_of(&ctx, int_type(&ctx, 32)));
    CHECK(option_u32.size == 8);
    CHECK(option_u32.align == 4);
    CHECK(option_u32.tag_encoding == rscabi::TagEncodingKind::Direct);

    rscabi::LayoutData option_box = layout_of(&ctx, option_of(&ctx, ctx.create(rscabi::TypeKind::Box)));
    CHECK(option_box.size == 8);
    CHECK(option_box.align == 8);
    CHECK(option_box.tag_encoding == rscabi::TagEncodingKind::Niche);

    rscabi::LayoutData option_nonnull =
        layout_of(&ctx, option_of(&ctx, ctx.create(rscabi::TypeKind::NonNull)));
    CHECK(option_nonnull.size == 8);
    CHECK(option_nonnull.align == 8);
    CHECK(option_nonnull.tag_encoding == rscabi::TagEncodingKind::Niche);

    rscabi::AbiType *nonzero_u32 = ctx.create(rscabi::TypeKind::NonZero);
    nonzero_u32->inner = int_type(&ctx, 32);
    rscabi::AbiType *wrapper = ctx.create(rscabi::TypeKind::Transparent);
    wrapper->inner = nonzero_u32;
    rscabi::LayoutData option_wrapper = layout_of(&ctx, option_of(&ctx, wrapper));
    CHECK(option_wrapper.size == 4);
    CHECK(option_wrapper.align == 4);
    CHECK(option_wrapper.tag_encoding == rscabi::TagEncodingKind::Niche);
}

void test_target_32()
{
    rscabi::TargetDataLayout target;
    bool parsed = rscabi::parse_llvm_data_layout(
        "e-m:e-p:32:32-i16:16:16-i32:32:32-i64:32:64-a:0:32:32", &target);
    CHECK(parsed);
    CHECK(target.pointer_bits == 32);
    CHECK(target.pointer_align_bits == 32);
    CHECK(target.aggregate_align_bits == 0);

    rscabi::TypeContext ctx(target);
    rscabi::LayoutData pointer = layout_of(&ctx, ctx.create(rscabi::TypeKind::Pointer));
    CHECK(pointer.size == 4);
    CHECK(pointer.align == 4);

    rscabi::LayoutData usize = layout_of(&ctx, int_type(&ctx, 32));
    CHECK(usize.size == 4);
    CHECK(usize.align == 4);

    rscabi::AbiType *structure = ctx.create(rscabi::TypeKind::Struct);
    structure->fields.push_back(int_type(&ctx, 8));
    structure->fields.push_back(int_type(&ctx, 32));
    rscabi::LayoutData struct_layout = layout_of(&ctx, structure);
    CHECK(struct_layout.size == 8);
    CHECK(struct_layout.align == 4);

    rscabi::LayoutData option_ref = layout_of(&ctx, option_of(&ctx, ctx.create(rscabi::TypeKind::Reference)));
    CHECK(option_ref.size == 4);
    CHECK(option_ref.align == 4);

    rscabi::AbiType *slice_ref = ctx.create(rscabi::TypeKind::Reference);
    slice_ref->is_fat_pointer = true;
    slice_ref->scalar.bits = 32;
    slice_ref->scalar.valid = rscabi::WrappingRange(
        rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(32));
    rscabi::LayoutData fat = layout_of(&ctx, slice_ref);
    CHECK(fat.size == 8);
    CHECK(fat.align == 4);
    CHECK(fat.backend == rscabi::BackendReprKind::ScalarPair);

    rscabi::LayoutData option_fat = layout_of(&ctx, option_of(&ctx, slice_ref));
    CHECK(option_fat.size == 8);
    CHECK(option_fat.align == 4);
    CHECK(option_fat.tag_encoding == rscabi::TagEncodingKind::Niche);
}

void test_u128()
{
    using rscabi::U128;
    CHECK(rscabi::u128_unsigned_max(64).lo == 0xffffffffffffffffULL);
    CHECK(rscabi::u128_unsigned_max(64).hi == 0);
    CHECK(rscabi::u128_unsigned_max(128).hi == 0xffffffffffffffffULL);
    CHECK(rscabi::u128_bit_length(U128::from_u64(1)) == 1);
    CHECK(rscabi::u128_bit_length(rscabi::u128_unsigned_max(128)) == 128);
    CHECK(rscabi::u128_add(U128(0xffffffffffffffffULL, 0), U128::from_u64(1)).hi == 1);
    CHECK(rscabi::u128_truncate(U128(0, 1), 64).is_zero());
}

void test_niche_reserve()
{
    using namespace rscabi;

    Niche bool_niche;
    Scalar boolean;
    boolean.primitive = PrimitiveKind::Bool;
    boolean.bits = 8;
    boolean.valid = WrappingRange(U128::from_u64(0), U128::from_u64(1));
    CHECK(Niche::from_scalar(0, boolean, &bool_niche));
    CHECK(bool_niche.available().lo == 0xfe);

    U128 niche_start;
    WrappingRange new_valid;
    CHECK(bool_niche.reserve(U128::from_u64(1), &niche_start, &new_valid));
    CHECK(niche_start.lo == 2);
    CHECK(new_valid.start.lo == 0);
    CHECK(new_valid.end.lo == 2);

    Scalar reference;
    reference.primitive = PrimitiveKind::Pointer;
    reference.bits = 64;
    reference.valid = WrappingRange(U128::from_u64(1), u128_unsigned_max(64));
    Niche ref_niche;
    CHECK(Niche::from_scalar(0, reference, &ref_niche));
    CHECK(ref_niche.available().lo == 1);
    CHECK(ref_niche.reserve(U128::from_u64(1), &niche_start, &new_valid));
    CHECK(niche_start.is_zero());
    CHECK(new_valid.is_full(64));

    CHECK(Align::max_aligned_factor(24).bytes() == 8);
    CHECK(Align::max_aligned_factor(16).bytes() == 16);
}

void test_simd()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);

    rscabi::AbiType *simd = ctx.create(rscabi::TypeKind::Simd);
    simd->inner = int_type(&ctx, 8);
    simd->array_count = 16;
    simd->repr.is_simd = true;
    rscabi::LayoutData layout = layout_of(&ctx, simd);
    CHECK(layout.size == 16);
    CHECK(layout.align == 16);
    CHECK(layout.backend == rscabi::BackendReprKind::SimdVector);

    rscabi::AbiType *packed = ctx.create(rscabi::TypeKind::Simd);
    packed->inner = int_type(&ctx, 8);
    packed->array_count = 3;
    packed->repr.is_simd = true;
    packed->repr.is_packed = true;
    rscabi::LayoutData packed_layout = layout_of(&ctx, packed);
    CHECK(packed_layout.size == 3);
    CHECK(packed_layout.align == 1);
    CHECK(packed_layout.backend == rscabi::BackendReprKind::Memory);
}

void test_coroutine()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);

    rscabi::AbiType *coroutine = ctx.create(rscabi::TypeKind::Coroutine);
    rscabi::CoroutineState first;
    first.fields.push_back(int_type(&ctx, 8));
    first.discriminant = rscabi::U128::from_u64(0);
    rscabi::CoroutineState second;
    second.fields.push_back(int_type(&ctx, 64));
    second.discriminant = rscabi::U128::from_u64(1);
    coroutine->coroutine_states.push_back(first);
    coroutine->coroutine_states.push_back(second);

    rscabi::LayoutData layout = layout_of(&ctx, coroutine);
    CHECK(layout.size == 16);
    CHECK(layout.align == 8);
    CHECK(layout.variants_kind == rscabi::VariantsKind::Multiple);
    CHECK(layout.variants.size() == 2);
    CHECK(layout.tag_encoding == rscabi::TagEncodingKind::Direct);
    CHECK(layout.variants[0].field_offsets.size() == 1);
    CHECK(layout.variants[1].field_offsets.size() == 1);
}

} // namespace

int main()
{
    test_primitives();
    test_aggregates();
    test_enums();
    test_target_32();
    test_u128();
    test_niche_reserve();
    test_simd();
    test_coroutine();
    if (failures != 0)
    {
        printf("%d check(s) failed\n", failures);
        return 1;
    }
    printf("rscabi unit tests: ok\n");
    return 0;
}
