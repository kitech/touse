#ifndef RSCABI_CANON_ABI_HPP
#define RSCABI_CANON_ABI_HPP

#include "extern_abi.hpp"

namespace rscabi {

enum class ArmCall
{
    Aapcs,
    CCmseNonSecureCall,
    CCmseNonSecureEntry,
};

enum class X86Call
{
    Fastcall,
    Stdcall,
    SysV64,
    Thiscall,
    Vectorcall,
    Win64,
};

enum class InterruptKind
{
    Avr,
    AvrNonBlocking,
    Msp430,
    RiscvMachine,
    RiscvSupervisor,
    X86,
};

enum class CanonAbiKind
{
    C,
    Rust,
    RustCold,
    RustPreserveNone,
    RustTail,
    Custom,
    Swift,
    Arm,
    GpuKernel,
    Interrupt,
    X86,
};

struct CanonAbi
{
    CanonAbiKind kind;
    ArmCall arm;
    X86Call x86;
    InterruptKind interrupt;

    CanonAbi()
        : kind(CanonAbiKind::Rust),
          arm(ArmCall::Aapcs),
          x86(X86Call::SysV64),
          interrupt(InterruptKind::X86) {}

    bool is_rustic_abi() const;
    const char *as_str() const;
};

CanonAbi canonize(ExternAbi abi, const char *target_triple);

} // namespace rscabi

#endif
