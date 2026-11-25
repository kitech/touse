#include "callconv.hpp"

namespace rscabi {

Reg Reg::integer(uint64_t bytes)
{
    Reg result;
    result.kind = RegKindKind::Integer;
    result.size = Size(bytes);
    return result;
}

Reg Reg::floating(uint64_t bytes)
{
    Reg result;
    result.kind = RegKindKind::Float;
    result.size = Size(bytes);
    return result;
}

Reg Reg::vector(uint64_t bytes)
{
    Reg result;
    result.kind = RegKindKind::Vector;
    result.size = Size(bytes);
    return result;
}

Reg Reg::opaque_vector(uint64_t bytes)
{
    return vector(bytes);
}

Reg Reg::from_layout(const LayoutData &layout)
{
    if (layout.backend == BackendReprKind::SimdVector ||
        layout.backend == BackendReprKind::SimdScalableVector)
    {
        return opaque_vector(layout.size);
    }
    if (layout.backend == BackendReprKind::Scalar && layout.has_tag_scalar)
    {
        if (layout.tag_scalar.primitive == PrimitiveKind::Float)
        {
            return floating(Size::from_bits(layout.tag_scalar.bits).bytes);
        }
        return integer(Size::from_bits(layout.tag_scalar.bits).bytes);
    }
    return integer(layout.size);
}

Align Reg::align(const TargetDataLayout &target) const
{
    if (kind == RegKindKind::Float)
    {
        switch (size.bits())
        {
            case 16: return target.integer_align(16);
            case 32: return target.integer_align(32);
            case 64: return target.integer_align(64);
            case 128: return target.integer_align(128);
            default: return Align::one();
        }
    }
    if (kind == RegKindKind::Vector)
    {
        Align result;
        if (!Align::from_bytes(target.rust_vector_align_bytes(size.bytes), &result))
        {
            return Align::one();
        }
        return result;
    }
    return target.integer_align(size.bits() == 0 ? 8 : static_cast<uint32_t>(size.bits()));
}

HomogeneousAggregate HomogeneousAggregate::homogeneous(const Reg &r)
{
    HomogeneousAggregate result;
    result.kind = HomogeneousAggregateKind::Homogeneous;
    result.reg = r;
    return result;
}

HomogeneousAggregate HomogeneousAggregate::no_data()
{
    return HomogeneousAggregate();
}

bool HomogeneousAggregate::unit(Reg *out) const
{
    if (kind != HomogeneousAggregateKind::Homogeneous || out == NULL)
    {
        return false;
    }
    *out = reg;
    return true;
}

} // namespace rscabi
