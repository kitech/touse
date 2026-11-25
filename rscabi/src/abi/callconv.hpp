#ifndef RSCABI_CALLCONV_HPP
#define RSCABI_CALLCONV_HPP

#include "../core/core.hpp"

namespace rscabi {

enum class RegKindKind
{
    Integer,
    Float,
    Vector,
};

struct Reg
{
    RegKindKind kind;
    Size size;
    PrimitiveSpec hint_vector_elem;

    Reg() : kind(RegKindKind::Integer), size(), hint_vector_elem() {}

    bool operator==(const Reg &other) const
    {
        return kind == other.kind && size.bytes == other.size.bytes;
    }
    bool operator!=(const Reg &other) const { return !(*this == other); }

    static Reg integer(uint64_t bytes);
    static Reg floating(uint64_t bytes);
    static Reg vector(uint64_t bytes);
    static Reg opaque_vector(uint64_t bytes);
    static Reg from_layout(const LayoutData &layout);

    Align align(const TargetDataLayout &target) const;
};

enum class HomogeneousAggregateKind
{
    Homogeneous,
    NoData,
};

struct HomogeneousAggregate
{
    HomogeneousAggregateKind kind;
    Reg reg;

    HomogeneousAggregate() : kind(HomogeneousAggregateKind::NoData), reg() {}

    static HomogeneousAggregate homogeneous(const Reg &r);
    static HomogeneousAggregate no_data();
    bool unit(Reg *out) const;
};

struct Heterogeneous {};

enum class CallingConv
{
    C,
    Rust,
    RustCold,
    RustCall,
    System,
    ArmAapcs,
    X86Stdcall,
    X86Fastcall,
    X86Thiscall,
    X86Vectorcall,
    X86SysV64,
    X86Win64,
    Swift,
    GpuKernel,
    Interrupt,
    Custom,
};

} // namespace rscabi

#endif
