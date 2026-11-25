#include "abi_query.hpp"

#include <cstring>

#include "ty_interface.hpp"

namespace rscabi {

namespace {

bool contains(const char *text, const char *needle)
{
    return text != NULL && needle != NULL && std::strstr(text, needle) != NULL;
}

} // namespace

CallingConv callconv_for_canon(const CanonAbi &abi, const char *target_triple)
{
    switch (abi.kind)
    {
        case CanonAbiKind::C:
            if (contains(target_triple, "windows"))
            {
                return contains(target_triple, "i686") ? CallingConv::X86Stdcall
                                                        : CallingConv::X86Win64;
            }
            if (contains(target_triple, "aarch64") || contains(target_triple, "arm"))
            {
                return CallingConv::ArmAapcs;
            }
            return CallingConv::C;
        case CanonAbiKind::Rust:
            return CallingConv::Rust;
        case CanonAbiKind::RustCold:
            return CallingConv::RustCold;
        case CanonAbiKind::RustPreserveNone:
        case CanonAbiKind::RustTail:
            return CallingConv::RustCall;
        case CanonAbiKind::Custom:
            return CallingConv::Custom;
        case CanonAbiKind::Swift:
            return CallingConv::Swift;
        case CanonAbiKind::GpuKernel:
            return CallingConv::GpuKernel;
        case CanonAbiKind::Interrupt:
            return CallingConv::Interrupt;
        case CanonAbiKind::Arm:
            return CallingConv::ArmAapcs;
        case CanonAbiKind::X86:
            switch (abi.x86)
            {
                case X86Call::Fastcall: return CallingConv::X86Fastcall;
                case X86Call::Stdcall: return CallingConv::X86Stdcall;
                case X86Call::Thiscall: return CallingConv::X86Thiscall;
                case X86Call::Vectorcall: return CallingConv::X86Vectorcall;
                case X86Call::Win64: return CallingConv::X86Win64;
                case X86Call::SysV64:
                default: return CallingConv::X86SysV64;
            }
    }
    return CallingConv::C;
}

CallingConv callconv_for_extern(ExternAbi abi, const char *target_triple)
{
    CanonAbi canon = canonize(abi, target_triple);
    return callconv_for_canon(canon, target_triple);
}

const char *callconv_name(CallingConv callconv)
{
    switch (callconv)
    {
        case CallingConv::C: return "C";
        case CallingConv::Rust: return "Rust";
        case CallingConv::RustCold: return "rust-cold";
        case CallingConv::RustCall: return "rust-call";
        case CallingConv::System: return "system";
        case CallingConv::ArmAapcs: return "aapcs";
        case CallingConv::X86Stdcall: return "stdcall";
        case CallingConv::X86Fastcall: return "fastcall";
        case CallingConv::X86Thiscall: return "thiscall";
        case CallingConv::X86Vectorcall: return "vectorcall";
        case CallingConv::X86SysV64: return "sysv64";
        case CallingConv::X86Win64: return "win64";
        case CallingConv::Swift: return "Swift";
        case CallingConv::GpuKernel: return "gpu-kernel";
        case CallingConv::Interrupt: return "interrupt";
        case CallingConv::Custom: return "custom";
    }
    return "C";
}

bool parse_callconv(const std::string &text, CallingConv *out)
{
    if (out == NULL)
    {
        return false;
    }
    if (text == "C" || text == "c")
    {
        *out = CallingConv::C;
    }
    else if (text == "Rust" || text == "rust")
    {
        *out = CallingConv::Rust;
    }
    else if (text == "rust-cold")
    {
        *out = CallingConv::RustCold;
    }
    else if (text == "rust-call")
    {
        *out = CallingConv::RustCall;
    }
    else if (text == "system")
    {
        *out = CallingConv::System;
    }
    else if (text == "aapcs")
    {
        *out = CallingConv::ArmAapcs;
    }
    else if (text == "stdcall")
    {
        *out = CallingConv::X86Stdcall;
    }
    else if (text == "fastcall")
    {
        *out = CallingConv::X86Fastcall;
    }
    else if (text == "thiscall")
    {
        *out = CallingConv::X86Thiscall;
    }
    else if (text == "vectorcall")
    {
        *out = CallingConv::X86Vectorcall;
    }
    else if (text == "sysv64")
    {
        *out = CallingConv::X86SysV64;
    }
    else if (text == "win64")
    {
        *out = CallingConv::X86Win64;
    }
    else if (text == "Swift" || text == "swift")
    {
        *out = CallingConv::Swift;
    }
    else if (text == "gpu-kernel")
    {
        *out = CallingConv::GpuKernel;
    }
    else if (text == "interrupt")
    {
        *out = CallingConv::Interrupt;
    }
    else if (text == "custom")
    {
        *out = CallingConv::Custom;
    }
    else
    {
        return false;
    }
    return true;
}

bool homogeneous_aggregate(const TypeContext &cx,
                           const LayoutData &layout,
                           ExternAbi abi,
                           const char *target_triple,
                           HomogeneousAggregate *out)
{
    (void)abi;
    (void)target_triple;
    if (out == NULL)
    {
        return false;
    }
    TyAbiInterface ty(cx);
    Reg reg;
    bool has_data = false;
    if (!ty.homogeneous_aggregate(layout, &reg, &has_data))
    {
        return false;
    }
    *out = has_data ? HomogeneousAggregate::homogeneous(reg)
                    : HomogeneousAggregate::no_data();
    return true;
}

} // namespace rscabi
