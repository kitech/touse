#ifndef RSCABI_EXTERN_ABI_HPP
#define RSCABI_EXTERN_ABI_HPP

#include <string>

namespace rscabi {

// Mirrors rustc_abi::ExternAbi at commit
// 0ef1bc386059596dada8fb65b50425aab2ea637a. `unwind` is folded into the
// C-like variants instead of being a bool payload at the C++ boundary.
enum class ExternAbi
{
    C,
    CUnwind,
    System,
    SystemUnwind,
    Rust,
    RustCall,
    RustCold,
    RustInvalid,
    RustPreserveNone,
    RustTail,
    LlvmIntrinsic,
    Custom,
    EfiApi,
    Swift,
    Aapcs,
    AapcsUnwind,
    CmseNonSecureCall,
    CmseNonSecureEntry,
    GpuKernel,
    PtxKernel,
    AvrInterrupt,
    AvrNonBlockingInterrupt,
    Msp430Interrupt,
    RiscvInterruptM,
    RiscvInterruptS,
    X86Interrupt,
    Cdecl,
    CdeclUnwind,
    Stdcall,
    StdcallUnwind,
    Fastcall,
    FastcallUnwind,
    Thiscall,
    ThiscallUnwind,
    Vectorcall,
    VectorcallUnwind,
    SysV64,
    SysV64Unwind,
    Win64,
    Win64Unwind,
};

const char *extern_abi_as_str(ExternAbi abi);
bool extern_abi_from_str(const std::string &text, ExternAbi *out);
bool extern_abi_is_rustic(ExternAbi abi);
bool extern_abi_supports_c_variadic(ExternAbi abi);

ExternAbi extern_abi_default_for_target(const std::string &triple);
ExternAbi extern_abi_resolve_system(ExternAbi abi, const std::string &triple);

} // namespace rscabi

#endif
