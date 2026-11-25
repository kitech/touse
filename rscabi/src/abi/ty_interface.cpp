#include "ty_interface.hpp"

#include "callconv.hpp"

namespace rscabi {

bool TyAbiInterface::field_layout(const LayoutData &parent,
                                  FieldIdx index,
                                  LayoutData *out) const
{
    if (out == NULL || index.index >= parent.field_sizes.size())
    {
        return false;
    }
    *out = LayoutData();
    out->size = parent.field_sizes[index.index];
    out->align = parent.align;
    out->backend = BackendReprKind::Memory;
    return true;
}

bool TyAbiInterface::variant_layout(const LayoutData &parent,
                                    VariantIdx index,
                                    LayoutData *out) const
{
    if (out == NULL || index.index >= parent.variants.size())
    {
        return false;
    }
    const VariantLayout &variant = parent.variants[index.index];
    *out = LayoutData();
    out->size = variant.size;
    out->align = variant.align;
    out->unadjusted_abi_align = variant.unadjusted_abi_align;
    out->backend = variant.backend;
    out->field_offsets = variant.field_offsets;
    out->field_sizes = variant.field_sizes;
    out->in_memory_order = variant.in_memory_order;
    out->has_niche = variant.has_niche;
    out->largest_niche = variant.largest_niche;
    return true;
}

bool TyAbiInterface::merge(const Reg &a,
                           bool a_data,
                           const Reg &b,
                           bool b_data,
                           Reg *out,
                           bool *has_data) const
{
    if (out == NULL || has_data == NULL)
    {
        return false;
    }
    if (!a_data && !b_data)
    {
        *out = Reg();
        *has_data = false;
        return true;
    }
    if (!a_data)
    {
        *out = b;
        *has_data = true;
        return true;
    }
    if (!b_data)
    {
        *out = a;
        *has_data = true;
        return true;
    }
    if (a != b)
    {
        return false;
    }
    *out = a;
    *has_data = true;
    return true;
}

bool TyAbiInterface::homogeneous_aggregate(const LayoutData &layout,
                                           Reg *out,
                                           bool *has_data) const
{
    if (out == NULL || has_data == NULL)
    {
        return false;
    }
    *out = Reg();
    *has_data = false;
    (void)cx_;

    if (layout.backend == BackendReprKind::SimdScalableVector)
    {
        return false;
    }
    if (layout.backend == BackendReprKind::Scalar)
    {
        *out = Reg::from_layout(layout);
        *has_data = true;
        return true;
    }
    if (layout.backend == BackendReprKind::SimdVector)
    {
        *out = Reg::opaque_vector(layout.size);
        *has_data = true;
        return true;
    }
    if (layout.backend != BackendReprKind::ScalarPair &&
        layout.backend != BackendReprKind::Memory)
    {
        return false;
    }

    uint64_t cursor = 0;
    Reg result;
    bool result_data = false;
    for (size_t i = 0; i < layout.field_sizes.size(); i++)
    {
        uint64_t field_size = layout.field_sizes[i];
        if (field_size == 0)
        {
            continue;
        }
        if (i < layout.field_offsets.size() && layout.field_offsets[i] != cursor)
        {
            return false;
        }
        Reg field_reg = Reg::integer(field_size);
        if (!merge(result, result_data, field_reg, true, &result, &result_data))
        {
            return false;
        }
        cursor += field_size;
    }

    for (size_t v = 0; v < layout.variants.size(); v++)
    {
        LayoutData variant;
        if (!variant_layout(layout, VariantIdx(static_cast<uint32_t>(v)), &variant))
        {
            return false;
        }
        Reg variant_reg;
        bool variant_data = false;
        if (!homogeneous_aggregate(variant, &variant_reg, &variant_data))
        {
            return false;
        }
        if (!merge(result, result_data, variant_reg, variant_data, &result, &result_data))
        {
            return false;
        }
    }

    if (cursor != layout.size)
    {
        if (!result_data || cursor != 0 || result.size.bytes != layout.size)
        {
            return false;
        }
    }
    if (layout.size != 0 && !result_data)
    {
        return false;
    }
    *out = result;
    *has_data = result_data;
    return true;
}

} // namespace rscabi
