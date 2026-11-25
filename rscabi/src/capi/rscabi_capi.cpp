#include "../../include/rscabi.h"

#include <new>
#include <vector>

#include "../abi/abi_query.hpp"
#include "../abi/callconv.hpp"
#include "../abi/canon_abi.hpp"
#include "../abi/extern_abi.hpp"
#include "../model/abi_type.hpp"

struct rscabi_target
{
    rscabi::TargetDataLayout data;
};

struct rscabi_context
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext *types;

    rscabi_context() : target(), types(NULL) {}
};

struct rscabi_type
{
    rscabi::AbiType *value;

    rscabi_type() : value(NULL) {}
};

struct rscabi_layout
{
    rscabi::LayoutData data;
    std::vector<rscabi_byte_range_t> independent_padding;
    std::vector<rscabi_byte_range_t> dependent_padding;
    std::vector<std::vector<rscabi_byte_range_t> > variant_padding;

    rscabi_layout() : data() {}
};

namespace {

rscabi::ReprOptions to_repr(const rscabi_repr_t *repr)
{
    rscabi::ReprOptions result;
    if (repr == NULL)
    {
        return result;
    }
    result.is_c = (repr->flags & RSCABI_REPR_C) != 0;
    result.is_transparent = (repr->flags & RSCABI_REPR_TRANSPARENT) != 0;
    result.is_packed = (repr->flags & RSCABI_REPR_PACKED) != 0;
    result.is_simd = (repr->flags & RSCABI_REPR_SIMD) != 0;
    result.is_scalable = (repr->flags & RSCABI_REPR_SCALABLE) != 0;
    result.align_bits = repr->align_bits;
    result.pack_bits = repr->pack_bits;
    result.int_bits = repr->int_bits;
    return result;
}

uint32_t backend_code(rscabi::BackendReprKind kind)
{
    switch (kind)
    {
        case rscabi::BackendReprKind::Scalar:
            return RSCABI_BACKEND_SCALAR;
        case rscabi::BackendReprKind::ScalarPair:
            return RSCABI_BACKEND_SCALAR_PAIR;
        case rscabi::BackendReprKind::SimdVector:
            return RSCABI_BACKEND_SIMD_VECTOR;
        case rscabi::BackendReprKind::Memory:
        default:
            return RSCABI_BACKEND_MEMORY;
    }
}

uint32_t variants_code(rscabi::VariantsKind kind)
{
    switch (kind)
    {
        case rscabi::VariantsKind::Empty:
            return RSCABI_VARIANTS_NONE;
        case rscabi::VariantsKind::Multiple:
            return RSCABI_VARIANTS_MULTIPLE;
        case rscabi::VariantsKind::Single:
        default:
            return RSCABI_VARIANTS_SINGLE;
    }
}

uint32_t tag_code(rscabi::TagEncodingKind kind)
{
    switch (kind)
    {
        case rscabi::TagEncodingKind::Direct:
            return RSCABI_TAG_DIRECT;
        case rscabi::TagEncodingKind::Niche:
            return RSCABI_TAG_NICHE;
        case rscabi::TagEncodingKind::None:
        default:
            return RSCABI_TAG_NONE;
    }
}

uint32_t fields_code(rscabi::FieldsShapeKind kind)
{
    switch (kind)
    {
        case rscabi::FieldsShapeKind::Primitive:
            return RSCABI_FIELDS_PRIMITIVE;
        case rscabi::FieldsShapeKind::Array:
            return RSCABI_FIELDS_ARRAY;
        case rscabi::FieldsShapeKind::Union:
            return RSCABI_FIELDS_UNION;
        case rscabi::FieldsShapeKind::Arbitrary:
        default:
            return RSCABI_FIELDS_ARBITRARY;
    }
}

rscabi_status_t write_u64s(const std::vector<uint64_t> &values,
                           uint64_t *out,
                           size_t capacity,
                           size_t *out_count)
{
    if (out_count == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out_count = values.size();
    if (capacity < values.size() || (out == NULL && !values.empty()))
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    for (size_t i = 0; i < values.size(); i++)
    {
        out[i] = values[i];
    }
    return RSCABI_OK;
}

rscabi_status_t write_u32s(const std::vector<uint32_t> &values,
                           uint32_t *out,
                           size_t capacity,
                           size_t *out_count)
{
    if (out_count == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out_count = values.size();
    if (capacity < values.size() || (out == NULL && !values.empty()))
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    for (size_t i = 0; i < values.size(); i++)
    {
        out[i] = values[i];
    }
    return RSCABI_OK;
}

rscabi_u128_t to_u128(const rscabi::U128 &value)
{
    rscabi_u128_t out;
    out.lo = value.lo;
    out.hi = value.hi;
    return out;
}

void mark_range(std::vector<char> *occupied,
                uint64_t offset,
                uint64_t size,
                uint64_t total)
{
    if (occupied == NULL || size == 0 || offset >= total)
    {
        return;
    }
    uint64_t end = offset + size;
    if (end > total)
    {
        end = total;
    }
    for (uint64_t i = offset; i < end; i++)
    {
        (*occupied)[static_cast<size_t>(i)] = 1;
    }
}

void mark_layout(std::vector<char> *occupied,
                 const rscabi::LayoutData &layout,
                 uint64_t total)
{
    for (size_t i = 0; i < layout.field_offsets.size() && i < layout.field_sizes.size(); i++)
    {
        mark_range(occupied, layout.field_offsets[i], layout.field_sizes[i], total);
    }
}

void mark_variant(std::vector<char> *occupied,
                  const rscabi::VariantLayout &variant,
                  uint64_t total)
{
    for (size_t i = 0; i < variant.field_offsets.size() && i < variant.field_sizes.size(); i++)
    {
        mark_range(occupied, variant.field_offsets[i], variant.field_sizes[i], total);
    }
}

void append_ranges(const std::vector<char> &occupied,
                   std::vector<rscabi_byte_range_t> *out)
{
    uint64_t i = 0;
    while (i < occupied.size())
    {
        if (occupied[static_cast<size_t>(i)] == 0)
        {
            i++;
            continue;
        }
        uint64_t start = i;
        while (i < occupied.size() && occupied[static_cast<size_t>(i)] != 0)
        {
            i++;
        }
        rscabi_byte_range_t range;
        range.offset = start;
        range.size = i - start;
        out->push_back(range);
    }
}

void compute_padding(const rscabi::LayoutData &layout, rscabi_layout *out)
{
    uint64_t total = layout.size;
    out->independent_padding.clear();
    out->dependent_padding.clear();
    out->variant_padding.clear();
    if (total == 0)
    {
        return;
    }

    if (layout.variants_kind == rscabi::VariantsKind::Multiple && !layout.variants.empty())
    {
        std::vector<std::vector<char> > occupied_by_variant;
        std::vector<char> any_occupied(static_cast<size_t>(total), 0);
        for (size_t v = 0; v < layout.variants.size(); v++)
        {
            std::vector<char> current(static_cast<size_t>(total), 0);
            mark_layout(&current, layout, total);
            mark_variant(&current, layout.variants[v], total);
            for (size_t i = 0; i < current.size(); i++)
            {
                if (current[i] != 0)
                {
                    any_occupied[i] = 1;
                }
            }
            occupied_by_variant.push_back(current);
        }

        std::vector<char> independent(static_cast<size_t>(total), 0);
        for (size_t i = 0; i < any_occupied.size(); i++)
        {
            if (any_occupied[i] == 0)
            {
                independent[i] = 1;
            }
        }
        append_ranges(independent, &out->independent_padding);

        for (size_t v = 0; v < occupied_by_variant.size(); v++)
        {
            std::vector<char> dependent(static_cast<size_t>(total), 0);
            for (size_t i = 0; i < dependent.size(); i++)
            {
                if (occupied_by_variant[v][i] == 0 && any_occupied[i] != 0)
                {
                    dependent[i] = 1;
                }
            }
            std::vector<rscabi_byte_range_t> ranges;
            append_ranges(dependent, &ranges);
            for (size_t i = 0; i < ranges.size(); i++)
            {
                out->dependent_padding.push_back(ranges[i]);
            }
            out->variant_padding.push_back(ranges);
        }
        return;
    }

    std::vector<char> occupied(static_cast<size_t>(total), 0);
    mark_layout(&occupied, layout, total);
    for (size_t v = 0; v < layout.variants.size(); v++)
    {
        mark_variant(&occupied, layout.variants[v], total);
    }
    std::vector<char> padding(static_cast<size_t>(total), 0);
    for (size_t i = 0; i < padding.size(); i++)
    {
        if (occupied[i] == 0)
        {
            padding[i] = 1;
        }
    }
    append_ranges(padding, &out->independent_padding);
    for (size_t v = 0; v < layout.variants.size(); v++)
    {
        out->variant_padding.push_back(out->independent_padding);
    }
}

rscabi_status_t write_ranges(const std::vector<rscabi_byte_range_t> &ranges,
                             rscabi_byte_range_t *out_ranges,
                             size_t capacity,
                             size_t *out_count)
{
    if (out_count == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out_count = ranges.size();
    if (out_ranges == NULL && capacity != 0)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    if (capacity < ranges.size())
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    for (size_t i = 0; i < ranges.size(); i++)
    {
        out_ranges[i] = ranges[i];
    }
    return RSCABI_OK;
}

rscabi::AbiType *checked_type(rscabi_context_t *ctx, rscabi_type_t *type)
{
    if (ctx == NULL || ctx->types == NULL || type == NULL || type->value == NULL)
    {
        return NULL;
    }
    return type->value;
}

bool to_extern_abi(uint32_t code, rscabi::ExternAbi *out)
{
    const uint32_t last = static_cast<uint32_t>(rscabi::ExternAbi::Win64Unwind);
    if (out == NULL || code > last)
    {
        return false;
    }
    *out = static_cast<rscabi::ExternAbi>(code);
    return true;
}

rscabi_type_t *make_type(rscabi_context_t *ctx, rscabi::TypeKind kind)
{
    if (ctx == NULL || ctx->types == NULL)
    {
        return NULL;
    }
    rscabi_type_t *wrapper = new rscabi_type_t();
    wrapper->value = ctx->types->create(kind);
    return wrapper;
}

} // namespace

extern "C" const char *rscabi_rustc_version(void)
{
    return "1.100.0";
}

extern "C" const char *rscabi_source_commit(void)
{
    return "0ef1bc386059596dada8fb65b50425aab2ea637a";
}

extern "C" uint32_t rscabi_abi_version(void)
{
    return 1;
}

extern "C" rscabi_status_t rscabi_target_new(uint32_t pointer_bits,
                                              uint32_t pointer_align_bits,
                                              uint32_t usize_bits,
                                              uint8_t little_endian,
                                              rscabi_target_t **out)
{
    try
    {
        if (out == NULL || pointer_bits == 0 || pointer_bits > 128 ||
            (pointer_bits % 8) != 0 || pointer_align_bits == 0 ||
            pointer_align_bits > 128 || (pointer_align_bits % 8) != 0 ||
            usize_bits == 0 || usize_bits > 128 || (usize_bits % 8) != 0)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_target_t *target = new rscabi_target_t();
        target->data.little_endian = little_endian != 0;
        target->data.pointer_bits = pointer_bits;
        target->data.pointer_align_bits = pointer_align_bits;
        target->data.usize_bits = usize_bits;
        *out = target;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_target_from_llvm_datalayout(const char *data_layout,
                                                              rscabi_target_t **out)
{
    try
    {
        if (data_layout == NULL || out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_target_t *target = new rscabi_target_t();
        if (!rscabi::parse_llvm_data_layout(data_layout, &target->data))
        {
            delete target;
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = target;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" void rscabi_target_free(rscabi_target_t *target)
{
    delete target;
}

extern "C" rscabi_status_t rscabi_context_new(rscabi_target_t *target,
                                               rscabi_context_t **out)
{
    try
    {
        if (target == NULL || out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_context_t *ctx = new rscabi_context_t();
        ctx->target = target->data;
        ctx->types = new rscabi::TypeContext(ctx->target);
        *out = ctx;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" void rscabi_context_free(rscabi_context_t *ctx)
{
    if (ctx == NULL)
    {
        return;
    }
    delete ctx->types;
    ctx->types = NULL;
    delete ctx;
}

extern "C" rscabi_status_t rscabi_type_never(rscabi_context_t *ctx, rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Never);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_unit(rscabi_context_t *ctx, rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Unit);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_bool(rscabi_context_t *ctx, rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Bool);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_char(rscabi_context_t *ctx, rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Char);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_int(rscabi_context_t *ctx,
                                           uint32_t bits,
                                           int is_signed,
                                           rscabi_type_t **out)
{
    try
    {
        if (out == NULL || bits == 0 || bits > 128 || (bits % 8) != 0)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Int);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->scalar.primitive = rscabi::PrimitiveKind::Int;
        wrapper->value->scalar.bits = bits;
        wrapper->value->scalar.is_signed = is_signed != 0;
        wrapper->value->scalar.valid = rscabi::WrappingRange::full(bits);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_float(rscabi_context_t *ctx,
                                             uint32_t bits,
                                             rscabi_type_t **out)
{
    try
    {
        if (out == NULL || (bits != 16 && bits != 32 && bits != 64 && bits != 128))
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Float);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->scalar.primitive = rscabi::PrimitiveKind::Float;
        wrapper->value->scalar.bits = bits;
        wrapper->value->scalar.valid = rscabi::WrappingRange::full(bits);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_fn_pointer(rscabi_context_t *ctx,
                                                  rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::FnPointer);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange::full(ctx->target.pointer_bits);
        }
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_pointer(rscabi_context_t *ctx,
                                               rscabi_type_t *pointee,
                                               int fat,
                                               rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Pointer);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange::full(ctx->target.pointer_bits);
        }
        if (pointee != NULL)
        {
            wrapper->value->inner = pointee->value;
        }
        wrapper->value->is_fat_pointer = fat != 0;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_reference(rscabi_context_t *ctx,
                                                 rscabi_type_t *pointee,
                                                 int is_mutable,
                                                 rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Reference);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange(
                rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(ctx->target.pointer_bits));
        }
        if (pointee != NULL)
        {
            wrapper->value->inner = pointee->value;
        }
        wrapper->value->is_mutable = is_mutable != 0;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_slice_ref(rscabi_context_t *ctx,
                                                 rscabi_type_t *element,
                                                 int is_mutable,
                                                 rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Reference);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange(
                rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(ctx->target.pointer_bits));
        }
        if (element != NULL)
        {
            wrapper->value->inner = element->value;
        }
        wrapper->value->is_fat_pointer = true;
        wrapper->value->is_mutable = is_mutable != 0;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_box(rscabi_context_t *ctx,
                                           rscabi_type_t *inner,
                                           rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Box);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange(
                rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(ctx->target.pointer_bits));
        }
        if (inner != NULL)
        {
            wrapper->value->inner = inner->value;
        }
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_nonnull(rscabi_context_t *ctx,
                                               rscabi_type_t *inner,
                                               rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::NonNull);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (ctx != NULL && ctx->types != NULL)
        {
            wrapper->value->scalar.bits = ctx->target.pointer_bits;
            wrapper->value->scalar.valid = rscabi::WrappingRange(
                rscabi::U128::from_u64(1), rscabi::u128_unsigned_max(ctx->target.pointer_bits));
        }
        if (inner != NULL)
        {
            wrapper->value->inner = inner->value;
        }
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_nonzero(rscabi_context_t *ctx,
                                               rscabi_type_t *inner,
                                               rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::NonZero);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (inner != NULL)
        {
            wrapper->value->inner = inner->value;
        }
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_transparent_newtype(rscabi_context_t *ctx,
                                                           rscabi_type_t *inner,
                                                           rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Transparent);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (inner != NULL)
        {
            wrapper->value->inner = inner->value;
        }
        wrapper->value->repr.is_transparent = true;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_array(rscabi_context_t *ctx,
                                             rscabi_type_t *element,
                                             uint64_t count,
                                             rscabi_type_t **out)
{
    try
    {
        if (out == NULL || element == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Array);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->inner = element->value;
        wrapper->value->array_count = count;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_slice(rscabi_context_t *ctx,
                                             rscabi_type_t *element,
                                             rscabi_type_t **out)
{
    try
    {
        if (out == NULL || element == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Slice);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->inner = element->value;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_tuple_begin(rscabi_context_t *ctx,
                                                   rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Tuple);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_struct_begin(rscabi_context_t *ctx,
                                                    const rscabi_repr_t *repr,
                                                    rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Struct);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->repr = to_repr(repr);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_union_begin(rscabi_context_t *ctx,
                                                   const rscabi_repr_t *repr,
                                                   rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Union);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->repr = to_repr(repr);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_enum_begin(rscabi_context_t *ctx,
                                                  const rscabi_repr_t *repr,
                                                  rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Enum);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->repr = to_repr(repr);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_simd(rscabi_context_t *ctx,
                                            rscabi_type_t *element,
                                            uint64_t lanes,
                                            int packed,
                                            rscabi_type_t **out)
{
    try
    {
        if (out == NULL || element == NULL || element->value == NULL ||
            lanes == 0 || lanes > 65535)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi_type_t *wrapper = make_type(ctx, rscabi::TypeKind::Simd);
        if (wrapper == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        wrapper->value->inner = element->value;
        wrapper->value->array_count = lanes;
        wrapper->value->repr.is_simd = true;
        wrapper->value->repr.is_packed = packed != 0;
        wrapper->value->finished = true;
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_coroutine_begin(rscabi_context_t *ctx,
                                                       rscabi_type_t **out)
{
    try
    {
        if (out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = make_type(ctx, rscabi::TypeKind::Coroutine);
        return *out == NULL ? RSCABI_ERR_INVALID_ARG : RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_coroutine_add_state(rscabi_context_t *ctx,
                                                           rscabi_type_t *coroutine,
                                                           rscabi_u128_t discriminant,
                                                           size_t *out_index)
{
    try
    {
        rscabi::AbiType *type = checked_type(ctx, coroutine);
        if (type == NULL || type->kind != rscabi::TypeKind::Coroutine || out_index == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->finished)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi::CoroutineState state;
        state.discriminant = rscabi::U128(discriminant.lo, discriminant.hi);
        type->coroutine_states.push_back(state);
        *out_index = type->coroutine_states.size() - 1;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_coroutine_add_state_field(rscabi_context_t *ctx,
                                                                 rscabi_type_t *coroutine,
                                                                 size_t state_index,
                                                                 rscabi_type_t *field)
{
    try
    {
        rscabi::AbiType *type = checked_type(ctx, coroutine);
        if (type == NULL || type->kind != rscabi::TypeKind::Coroutine || field == NULL ||
            field->value == NULL || state_index >= type->coroutine_states.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->finished)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        type->coroutine_states[state_index].fields.push_back(field->value);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_coroutine_set_discriminant(rscabi_context_t *ctx,
                                                                  rscabi_type_t *coroutine,
                                                                  size_t state_index,
                                                                  rscabi_u128_t discriminant)
{
    try
    {
        rscabi::AbiType *type = checked_type(ctx, coroutine);
        if (type == NULL || type->kind != rscabi::TypeKind::Coroutine ||
            state_index >= type->coroutine_states.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->finished)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        type->coroutine_states[state_index].discriminant =
            rscabi::U128(discriminant.lo, discriminant.hi);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_add_field(rscabi_context_t *ctx,
                                                 rscabi_type_t *aggregate,
                                                 rscabi_type_t *field)
{
    try
    {
        rscabi::AbiType *type = checked_type(ctx, aggregate);
        if (type == NULL || field == NULL || field->value == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->kind != rscabi::TypeKind::Tuple && type->kind != rscabi::TypeKind::Struct &&
            type->kind != rscabi::TypeKind::Union &&
            type->kind != rscabi::TypeKind::Coroutine)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->finished)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        type->fields.push_back(field->value);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_enum_add_variant(rscabi_context_t *ctx,
                                                        rscabi_type_t *aggregate,
                                                        const rscabi_type_t *const *fields,
                                                        size_t field_count,
                                                        rscabi_u128_t discriminant,
                                                        uint32_t flags)
{
    try
    {
        rscabi::AbiType *type = checked_type(ctx, aggregate);
        if (type == NULL || type->kind != rscabi::TypeKind::Enum)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (type->finished)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        if (field_count != 0 && fields == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi::EnumVariant variant;
        for (size_t i = 0; i < field_count; i++)
        {
            if (fields[i] == NULL || fields[i]->value == NULL)
            {
                return RSCABI_ERR_INVALID_ARG;
            }
            variant.fields.push_back(fields[i]->value);
        }
        variant.discriminant = rscabi::U128(discriminant.lo, discriminant.hi);
        variant.flags = flags;
        type->variants.push_back(variant);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_type_finish(rscabi_context_t *ctx,
                                              rscabi_type_t *type)
{
    try
    {
        rscabi::AbiType *value = checked_type(ctx, type);
        if (value == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        value->finished = true;
        if (ctx != NULL && ctx->types != NULL)
        {
            ctx->types->invalidate_cache();
        }
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" void rscabi_type_free(rscabi_type_t *type)
{
    delete type;
}

extern "C" rscabi_status_t rscabi_layout_of(rscabi_context_t *ctx,
                                            rscabi_type_t *type,
                                            rscabi_layout_t **out)
{
    try
    {
        if (ctx == NULL || ctx->types == NULL || out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi::AbiType *value = checked_type(ctx, type);
        if (value == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi::LayoutData layout;
        if (!ctx->types->layout_of(value, &layout))
        {
            return RSCABI_ERR_LAYOUT;
        }
        rscabi_layout_t *wrapper = new rscabi_layout_t();
        wrapper->data = layout;
        compute_padding(layout, wrapper);
        *out = wrapper;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_info(const rscabi_layout_t *layout,
                                              rscabi_layout_info_t *out)
{
    try
    {
        if (layout == NULL || out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        const rscabi::LayoutData &data = layout->data;
        out->size = data.size;
        out->align = data.align;
        out->unadjusted_abi_align = data.unadjusted_abi_align;
        out->uninhabited = data.uninhabited ? 1 : 0;
        out->has_largest_niche = data.has_niche ? 1 : 0;
        out->niche_offset = data.largest_niche.offset;
        out->niche_start = to_u128(data.largest_niche.value.start);
        out->niche_end = to_u128(data.largest_niche.value.end);
        out->tag_encoding = tag_code(data.tag_encoding);
        out->untagged_variant = static_cast<uint32_t>(data.untagged_variant);
        out->variant_count = static_cast<uint32_t>(data.variants.size());
        out->field_count = static_cast<uint32_t>(data.field_offsets.size());
        out->backend_repr = backend_code(data.backend);
        out->variants_kind = variants_code(data.variants_kind);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_field_offset(const rscabi_layout_t *layout,
                                                      size_t field_index,
                                                      uint64_t *out_offset)
{
    try
    {
        if (layout == NULL || out_offset == NULL ||
            field_index >= layout->data.field_offsets.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_offset = layout->data.field_offsets[field_index];
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_count(const rscabi_layout_t *layout,
                                                       size_t *out_count)
{
    try
    {
        if (layout == NULL || out_count == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_count = layout->data.variants.size();
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_info(const rscabi_layout_t *layout,
                                                      size_t variant_index,
                                                      rscabi_variant_info_t *out)
{
    try
    {
        if (layout == NULL || out == NULL ||
            variant_index >= layout->data.variants.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        const rscabi::VariantLayout &variant = layout->data.variants[variant_index];
        out->size = variant.size;
        out->align = variant.align;
        out->has_tag_range = variant.has_tag_range ? 1 : 0;
        out->tag_start = to_u128(variant.tag_range.start);
        out->tag_end = to_u128(variant.tag_range.end);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_has_variant_dependent_padding(
    const rscabi_layout_t *layout, int *out)
{
    try
    {
        if (layout == NULL || out == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out = layout->dependent_padding.empty() ? 0 : 1;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_independent_padding_ranges(
    const rscabi_layout_t *layout,
    rscabi_byte_range_t *out_ranges,
    size_t capacity,
    size_t *out_count)
{
    try
    {
        if (layout == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_ranges(layout->independent_padding, out_ranges, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_dependent_padding_ranges(
    const rscabi_layout_t *layout,
    size_t variant_index,
    rscabi_byte_range_t *out_ranges,
    size_t capacity,
    size_t *out_count)
{
    try
    {
        if (layout == NULL || variant_index >= layout->variant_padding.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_ranges(layout->variant_padding[variant_index], out_ranges, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_field_offsets(const rscabi_layout_t *layout,
                                                       uint64_t *out_offsets,
                                                       size_t capacity,
                                                       size_t *out_count)
{
    try
    {
        if (layout == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_u64s(layout->data.field_offsets, out_offsets, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_field_sizes(const rscabi_layout_t *layout,
                                                     uint64_t *out_sizes,
                                                     size_t capacity,
                                                     size_t *out_count)
{
    try
    {
        if (layout == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_u64s(layout->data.field_sizes, out_sizes, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_memory_order(const rscabi_layout_t *layout,
                                                      uint32_t *out_order,
                                                      size_t capacity,
                                                      size_t *out_count)
{
    try
    {
        if (layout == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_u32s(layout->data.in_memory_order, out_order, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_fields_kind(const rscabi_layout_t *layout,
                                                     uint32_t *out_kind)
{
    try
    {
        if (layout == NULL || out_kind == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_kind = fields_code(layout->data.fields_kind);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_field_offsets(const rscabi_layout_t *layout,
                                                               size_t variant_index,
                                                               uint64_t *out_offsets,
                                                               size_t capacity,
                                                               size_t *out_count)
{
    try
    {
        if (layout == NULL || variant_index >= layout->data.variants.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_u64s(layout->data.variants[variant_index].field_offsets,
                          out_offsets, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_memory_order(const rscabi_layout_t *layout,
                                                              size_t variant_index,
                                                              uint32_t *out_order,
                                                              size_t capacity,
                                                              size_t *out_count)
{
    try
    {
        if (layout == NULL || variant_index >= layout->data.variants.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        return write_u32s(layout->data.variants[variant_index].in_memory_order,
                          out_order, capacity, out_count);
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_variant_tag_range(const rscabi_layout_t *layout,
                                                           size_t variant_index,
                                                           rscabi_u128_t *out_start,
                                                           rscabi_u128_t *out_end)
{
    try
    {
        if (layout == NULL || out_start == NULL || out_end == NULL ||
            variant_index >= layout->data.variants.size())
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        const rscabi::VariantLayout &variant = layout->data.variants[variant_index];
        if (!variant.has_tag_range)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_start = to_u128(variant.tag_range.start);
        *out_end = to_u128(variant.tag_range.end);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_tag_encoding(const rscabi_layout_t *layout,
                                                      uint32_t *out_encoding)
{
    try
    {
        if (layout == NULL || out_encoding == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_encoding = tag_code(layout->data.tag_encoding);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_untagged_variant(const rscabi_layout_t *layout,
                                                          uint32_t *out_variant)
{
    try
    {
        if (layout == NULL || out_variant == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_variant = static_cast<uint32_t>(layout->data.untagged_variant);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_layout_niche_variants(const rscabi_layout_t *layout,
                                                        uint32_t *out_start,
                                                        uint32_t *out_end)
{
    try
    {
        if (layout == NULL || out_start == NULL || out_end == NULL)
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        *out_start = static_cast<uint32_t>(layout->data.niche_variants_start);
        *out_end = static_cast<uint32_t>(layout->data.niche_variants_end);
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" rscabi_status_t rscabi_extern_abi_from_str(const char *text,
                                                      uint32_t *out)
{
    if (text == NULL || out == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    rscabi::ExternAbi abi;
    if (!rscabi::extern_abi_from_str(text, &abi))
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out = static_cast<uint32_t>(abi);
    return RSCABI_OK;
}

extern "C" const char *rscabi_extern_abi_as_str(uint32_t abi_code)
{
    rscabi::ExternAbi abi;
    if (!to_extern_abi(abi_code, &abi))
    {
        return "C";
    }
    return rscabi::extern_abi_as_str(abi);
}

extern "C" int rscabi_extern_abi_is_rustic(uint32_t abi_code)
{
    rscabi::ExternAbi abi;
    return to_extern_abi(abi_code, &abi) && rscabi::extern_abi_is_rustic(abi) ? 1 : 0;
}

extern "C" int rscabi_extern_abi_supports_c_variadic(uint32_t abi_code)
{
    rscabi::ExternAbi abi;
    return to_extern_abi(abi_code, &abi) &&
                   rscabi::extern_abi_supports_c_variadic(abi)
               ? 1
               : 0;
}

extern "C" rscabi_status_t rscabi_extern_abi_default_for_target(
    const char *target_triple, uint32_t *out)
{
    if (target_triple == NULL || out == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out = static_cast<uint32_t>(
        rscabi::extern_abi_default_for_target(target_triple));
    return RSCABI_OK;
}

extern "C" rscabi_status_t rscabi_extern_abi_resolve_system(uint32_t abi_code,
                                                            const char *target_triple,
                                                            uint32_t *out)
{
    rscabi::ExternAbi abi;
    if (!to_extern_abi(abi_code, &abi) || target_triple == NULL || out == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out = static_cast<uint32_t>(
        rscabi::extern_abi_resolve_system(abi, target_triple));
    return RSCABI_OK;
}

extern "C" rscabi_status_t rscabi_canonize(uint32_t abi_code,
                                           const char *target_triple,
                                           rscabi_canon_abi_t *out)
{
    rscabi::ExternAbi abi;
    if (!to_extern_abi(abi_code, &abi) || target_triple == NULL || out == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    rscabi::CanonAbi canon = rscabi::canonize(abi, target_triple);
    out->kind = static_cast<uint32_t>(canon.kind);
    out->arm = static_cast<uint32_t>(canon.arm);
    out->x86 = static_cast<uint32_t>(canon.x86);
    out->interrupt = static_cast<uint32_t>(canon.interrupt);
    return RSCABI_OK;
}

extern "C" const char *rscabi_canon_abi_as_str(const rscabi_canon_abi_t *abi)
{
    if (abi == NULL)
    {
        return "Rust";
    }
    rscabi::CanonAbi value;
    value.kind = static_cast<rscabi::CanonAbiKind>(abi->kind);
    value.arm = static_cast<rscabi::ArmCall>(abi->arm);
    value.x86 = static_cast<rscabi::X86Call>(abi->x86);
    value.interrupt = static_cast<rscabi::InterruptKind>(abi->interrupt);
    return value.as_str();
}

extern "C" int rscabi_canon_abi_is_rustic(const rscabi_canon_abi_t *abi)
{
    if (abi == NULL)
    {
        return 0;
    }
    rscabi::CanonAbi value;
    value.kind = static_cast<rscabi::CanonAbiKind>(abi->kind);
    return value.is_rustic_abi() ? 1 : 0;
}

extern "C" rscabi_status_t rscabi_callconv_for_extern(uint32_t abi_code,
                                                      const char *target_triple,
                                                      uint32_t *out)
{
    rscabi::ExternAbi abi;
    if (!to_extern_abi(abi_code, &abi) || target_triple == NULL || out == NULL)
    {
        return RSCABI_ERR_INVALID_ARG;
    }
    *out = static_cast<uint32_t>(
        rscabi::callconv_for_extern(abi, target_triple));
    return RSCABI_OK;
}

extern "C" const char *rscabi_callconv_name(uint32_t callconv)
{
    return rscabi::callconv_name(static_cast<rscabi::CallingConv>(callconv));
}

extern "C" rscabi_status_t rscabi_layout_homogeneous_aggregate(
    rscabi_context_t *ctx,
    const rscabi_layout_t *layout,
    uint32_t abi_code,
    const char *target_triple,
    rscabi_homogeneous_aggregate_t *out)
{
    try
    {
        rscabi::ExternAbi abi;
        if (ctx == NULL || ctx->types == NULL || layout == NULL || out == NULL ||
            target_triple == NULL || !to_extern_abi(abi_code, &abi))
        {
            return RSCABI_ERR_INVALID_ARG;
        }
        rscabi::HomogeneousAggregate aggregate;
        if (!rscabi::homogeneous_aggregate(
                *ctx->types, layout->data, abi, target_triple, &aggregate))
        {
            return RSCABI_ERR_UNSUPPORTED;
        }
        if (aggregate.kind == rscabi::HomogeneousAggregateKind::NoData)
        {
            out->kind = RSCABI_AGG_NO_DATA;
            out->reg.kind = RSCABI_REG_KIND_INTEGER;
            out->reg.size = 0;
            return RSCABI_OK;
        }
        out->kind = RSCABI_AGG_HOMOGENEOUS;
        out->reg.kind = static_cast<uint32_t>(aggregate.reg.kind);
        out->reg.size = aggregate.reg.size.bytes;
        return RSCABI_OK;
    }
    catch (...)
    {
        return RSCABI_ERR_PANIC;
    }
}

extern "C" void rscabi_layout_free(rscabi_layout_t *layout)
{
    delete layout;
}
