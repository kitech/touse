#include "canon_abi.hpp"

namespace rscabi {

bool CanonAbi::is_rustic_abi() const
{
    switch (kind)
    {
        case CanonAbiKind::Rust:
        case CanonAbiKind::RustCold:
        case CanonAbiKind::RustPreserveNone:
        case CanonAbiKind::RustTail:
            return true;
        default:
            return false;
    }
}

const char *CanonAbi::as_str() const
{
    switch (kind)
    {
        case CanonAbiKind::C: return "C";
        case CanonAbiKind::Rust: return "Rust";
        case CanonAbiKind::RustCold: return "rust-cold";
        case CanonAbiKind::RustPreserveNone: return "rust-preserve-none";
        case CanonAbiKind::RustTail: return "tail";
        case CanonAbiKind::Custom: return "custom";
        case CanonAbiKind::Swift: return "Swift";
        case CanonAbiKind::GpuKernel: return "gpu-kernel";
        case CanonAbiKind::Arm:
            switch (arm)
            {
                case ArmCall::Aapcs: return "aapcs";
                case ArmCall::CCmseNonSecureCall: return "cmse-nonsecure-call";
                case ArmCall::CCmseNonSecureEntry: return "cmse-nonsecure-entry";
            }
            return "aapcs";
        case CanonAbiKind::Interrupt:
            switch (interrupt)
            {
                case InterruptKind::Avr: return "avr-interrupt";
                case InterruptKind::AvrNonBlocking: return "avr-non-blocking-interrupt";
                case InterruptKind::Msp430: return "msp430-interrupt";
                case InterruptKind::RiscvMachine: return "riscv-interrupt-m";
                case InterruptKind::RiscvSupervisor: return "riscv-interrupt-s";
                case InterruptKind::X86: return "x86-interrupt";
            }
            return "x86-interrupt";
        case CanonAbiKind::X86:
            switch (x86)
            {
                case X86Call::Fastcall: return "fastcall";
                case X86Call::Stdcall: return "stdcall";
                case X86Call::SysV64: return "sysv64";
                case X86Call::Thiscall: return "thiscall";
                case X86Call::Vectorcall: return "vectorcall";
                case X86Call::Win64: return "win64";
            }
            return "sysv64";
    }
    return "Rust";
}

CanonAbi canonize(ExternAbi abi, const char *target_triple)
{
    const std::string triple = target_triple == NULL ? std::string() : std::string(target_triple);
    ExternAbi resolved = extern_abi_resolve_system(abi, triple);
    CanonAbi result;

    switch (resolved)
    {
        case ExternAbi::Rust:
            result.kind = CanonAbiKind::Rust;
            break;
        case ExternAbi::RustCold:
            result.kind = CanonAbiKind::RustCold;
            break;
        case ExternAbi::RustPreserveNone:
            result.kind = CanonAbiKind::RustPreserveNone;
            break;
        case ExternAbi::RustTail:
            result.kind = CanonAbiKind::RustTail;
            break;
        case ExternAbi::Custom:
            result.kind = CanonAbiKind::Custom;
            break;
        case ExternAbi::Swift:
            result.kind = CanonAbiKind::Swift;
            break;
        case ExternAbi::GpuKernel:
        case ExternAbi::PtxKernel:
            result.kind = CanonAbiKind::GpuKernel;
            break;
        case ExternAbi::Aapcs:
        case ExternAbi::CmseNonSecureCall:
        case ExternAbi::CmseNonSecureEntry:
            result.kind = CanonAbiKind::Arm;
            result.arm = resolved == ExternAbi::Aapcs
                             ? ArmCall::Aapcs
                             : (resolved == ExternAbi::CmseNonSecureCall
                                    ? ArmCall::CCmseNonSecureCall
                                    : ArmCall::CCmseNonSecureEntry);
            break;
        case ExternAbi::AvrInterrupt:
        case ExternAbi::AvrNonBlockingInterrupt:
        case ExternAbi::Msp430Interrupt:
        case ExternAbi::RiscvInterruptM:
        case ExternAbi::RiscvInterruptS:
        case ExternAbi::X86Interrupt:
            result.kind = CanonAbiKind::Interrupt;
            switch (resolved)
            {
                case ExternAbi::AvrInterrupt:
                    result.interrupt = InterruptKind::Avr;
                    break;
                case ExternAbi::AvrNonBlockingInterrupt:
                    result.interrupt = InterruptKind::AvrNonBlocking;
                    break;
                case ExternAbi::Msp430Interrupt:
                    result.interrupt = InterruptKind::Msp430;
                    break;
                case ExternAbi::RiscvInterruptM:
                    result.interrupt = InterruptKind::RiscvMachine;
                    break;
                case ExternAbi::RiscvInterruptS:
                    result.interrupt = InterruptKind::RiscvSupervisor;
                    break;
                default:
                    result.interrupt = InterruptKind::X86;
                    break;
            }
            break;
        case ExternAbi::Fastcall:
        case ExternAbi::Stdcall:
        case ExternAbi::Thiscall:
        case ExternAbi::Vectorcall:
        case ExternAbi::SysV64:
        case ExternAbi::Win64:
            result.kind = CanonAbiKind::X86;
            switch (resolved)
            {
                case ExternAbi::Fastcall: result.x86 = X86Call::Fastcall; break;
                case ExternAbi::Stdcall: result.x86 = X86Call::Stdcall; break;
                case ExternAbi::Thiscall: result.x86 = X86Call::Thiscall; break;
                case ExternAbi::Vectorcall: result.x86 = X86Call::Vectorcall; break;
                case ExternAbi::Win64: result.x86 = X86Call::Win64; break;
                default: result.x86 = X86Call::SysV64; break;
            }
            break;
        default:
            result.kind = CanonAbiKind::C;
            break;
    }
    return result;
}

} // namespace rscabi
