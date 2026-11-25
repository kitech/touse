#include "extern_abi.hpp"

namespace rscabi {

namespace {

struct Entry
{
    ExternAbi abi;
    const char *text;
};

const Entry kEntries[] = {
    {ExternAbi::C, "C"},
    {ExternAbi::CUnwind, "C-unwind"},
    {ExternAbi::System, "system"},
    {ExternAbi::SystemUnwind, "system-unwind"},
    {ExternAbi::Rust, "Rust"},
    {ExternAbi::RustCall, "rust-call"},
    {ExternAbi::RustCold, "rust-cold"},
    {ExternAbi::RustInvalid, "rust-invalid"},
    {ExternAbi::RustPreserveNone, "rust-preserve-none"},
    {ExternAbi::RustTail, "tail"},
    {ExternAbi::LlvmIntrinsic, "llvm-intrinsic"},
    {ExternAbi::Custom, "custom"},
    {ExternAbi::EfiApi, "efiapi"},
    {ExternAbi::Swift, "Swift"},
    {ExternAbi::Aapcs, "aapcs"},
    {ExternAbi::AapcsUnwind, "aapcs-unwind"},
    {ExternAbi::CmseNonSecureCall, "cmse-nonsecure-call"},
    {ExternAbi::CmseNonSecureEntry, "cmse-nonsecure-entry"},
    {ExternAbi::GpuKernel, "gpu-kernel"},
    {ExternAbi::PtxKernel, "ptx-kernel"},
    {ExternAbi::AvrInterrupt, "avr-interrupt"},
    {ExternAbi::AvrNonBlockingInterrupt, "avr-non-blocking-interrupt"},
    {ExternAbi::Msp430Interrupt, "msp430-interrupt"},
    {ExternAbi::RiscvInterruptM, "riscv-interrupt-m"},
    {ExternAbi::RiscvInterruptS, "riscv-interrupt-s"},
    {ExternAbi::X86Interrupt, "x86-interrupt"},
    {ExternAbi::Cdecl, "cdecl"},
    {ExternAbi::CdeclUnwind, "cdecl-unwind"},
    {ExternAbi::Stdcall, "stdcall"},
    {ExternAbi::StdcallUnwind, "stdcall-unwind"},
    {ExternAbi::Fastcall, "fastcall"},
    {ExternAbi::FastcallUnwind, "fastcall-unwind"},
    {ExternAbi::Thiscall, "thiscall"},
    {ExternAbi::ThiscallUnwind, "thiscall-unwind"},
    {ExternAbi::Vectorcall, "vectorcall"},
    {ExternAbi::VectorcallUnwind, "vectorcall-unwind"},
    {ExternAbi::SysV64, "sysv64"},
    {ExternAbi::SysV64Unwind, "sysv64-unwind"},
    {ExternAbi::Win64, "win64"},
    {ExternAbi::Win64Unwind, "win64-unwind"},
};

} // namespace

const char *extern_abi_as_str(ExternAbi abi)
{
    for (size_t i = 0; i < sizeof(kEntries) / sizeof(kEntries[0]); i++)
    {
        if (kEntries[i].abi == abi)
        {
            return kEntries[i].text;
        }
    }
    return "C";
}

bool extern_abi_from_str(const std::string &text, ExternAbi *out)
{
    if (out == NULL)
    {
        return false;
    }
    for (size_t i = 0; i < sizeof(kEntries) / sizeof(kEntries[0]); i++)
    {
        if (text == kEntries[i].text)
        {
            *out = kEntries[i].abi;
            return true;
        }
    }
    return false;
}

bool extern_abi_is_rustic(ExternAbi abi)
{
    switch (abi)
    {
        case ExternAbi::Rust:
        case ExternAbi::RustCall:
        case ExternAbi::RustCold:
        case ExternAbi::RustPreserveNone:
        case ExternAbi::RustTail:
            return true;
        default:
            return false;
    }
}

bool extern_abi_supports_c_variadic(ExternAbi abi)
{
    switch (abi)
    {
        case ExternAbi::C:
        case ExternAbi::CUnwind:
        case ExternAbi::Cdecl:
        case ExternAbi::CdeclUnwind:
        case ExternAbi::Aapcs:
        case ExternAbi::AapcsUnwind:
        case ExternAbi::SysV64:
        case ExternAbi::SysV64Unwind:
        case ExternAbi::Win64:
        case ExternAbi::Win64Unwind:
        case ExternAbi::EfiApi:
        case ExternAbi::System:
        case ExternAbi::SystemUnwind:
            return true;
        default:
            return false;
    }
}

ExternAbi extern_abi_default_for_target(const std::string &triple)
{
    if (triple.find("windows") != std::string::npos)
    {
        return triple.find("i686") != std::string::npos ? ExternAbi::Stdcall
                                                        : ExternAbi::Win64;
    }
    if (triple.find("aarch64") != std::string::npos ||
        triple.find("arm") != std::string::npos)
    {
        return ExternAbi::Aapcs;
    }
    return ExternAbi::C;
}

ExternAbi extern_abi_resolve_system(ExternAbi abi, const std::string &triple)
{
    if (abi != ExternAbi::System && abi != ExternAbi::SystemUnwind)
    {
        return abi;
    }
    ExternAbi resolved = extern_abi_default_for_target(triple);
    if (abi == ExternAbi::SystemUnwind)
    {
        switch (resolved)
        {
            case ExternAbi::Aapcs: return ExternAbi::AapcsUnwind;
            case ExternAbi::Stdcall: return ExternAbi::StdcallUnwind;
            case ExternAbi::Win64: return ExternAbi::Win64Unwind;
            default: return ExternAbi::CUnwind;
        }
    }
    return resolved;
}

} // namespace rscabi
