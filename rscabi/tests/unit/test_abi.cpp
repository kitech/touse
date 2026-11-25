#include <cstdio>
#include <cstring>
#include <string>

#include "../../src/abi/abi_query.hpp"
#include "../../src/abi/callconv.hpp"
#include "../../src/abi/canon_abi.hpp"
#include "../../src/abi/extern_abi.hpp"
#include "../../src/abi/ty_interface.hpp"
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

void test_extern_abi()
{
    rscabi::ExternAbi abi;
    CHECK(rscabi::extern_abi_from_str("Rust", &abi));
    CHECK(abi == rscabi::ExternAbi::Rust);
    CHECK(std::strcmp(rscabi::extern_abi_as_str(abi), "Rust") == 0);

    CHECK(rscabi::extern_abi_from_str("C-unwind", &abi));
    CHECK(abi == rscabi::ExternAbi::CUnwind);
    CHECK(rscabi::extern_abi_supports_c_variadic(abi));

    CHECK(rscabi::extern_abi_from_str("rust-call", &abi));
    CHECK(rscabi::extern_abi_is_rustic(abi));

    CHECK(!rscabi::extern_abi_from_str("not-an-abi", &abi));
}

void test_canon_abi()
{
    rscabi::CanonAbi rust = rscabi::canonize(rscabi::ExternAbi::Rust,
                                             "x86_64-unknown-linux-gnu");
    CHECK(rust.kind == rscabi::CanonAbiKind::Rust);
    CHECK(rust.is_rustic_abi());
    CHECK(std::strcmp(rust.as_str(), "Rust") == 0);

    rscabi::CanonAbi win64 = rscabi::canonize(rscabi::ExternAbi::Win64,
                                              "x86_64-pc-windows-msvc");
    CHECK(win64.kind == rscabi::CanonAbiKind::X86);
    CHECK(win64.x86 == rscabi::X86Call::Win64);
    CHECK(std::strcmp(win64.as_str(), "win64") == 0);

    rscabi::CanonAbi aapcs = rscabi::canonize(rscabi::ExternAbi::Aapcs,
                                              "aarch64-unknown-linux-gnu");
    CHECK(aapcs.kind == rscabi::CanonAbiKind::Arm);
    CHECK(std::strcmp(aapcs.as_str(), "aapcs") == 0);

    rscabi::CanonAbi system = rscabi::canonize(rscabi::ExternAbi::System,
                                              "x86_64-pc-windows-msvc");
    CHECK(system.kind == rscabi::CanonAbiKind::X86);
    CHECK(std::strcmp(system.as_str(), "win64") == 0);
}

void test_callconv()
{
    CHECK(rscabi::callconv_for_extern(rscabi::ExternAbi::Rust,
                                      "x86_64-unknown-linux-gnu") ==
          rscabi::CallingConv::Rust);
    CHECK(rscabi::callconv_for_extern(rscabi::ExternAbi::Aapcs,
                                      "aarch64-unknown-linux-gnu") ==
          rscabi::CallingConv::ArmAapcs);
    CHECK(rscabi::callconv_for_extern(rscabi::ExternAbi::System,
                                      "x86_64-pc-windows-msvc") ==
          rscabi::CallingConv::X86Win64);
    CHECK(std::strcmp(rscabi::callconv_name(rscabi::CallingConv::X86SysV64),
                      "sysv64") == 0);

    rscabi::CallingConv cc;
    CHECK(rscabi::parse_callconv("vectorcall", &cc));
    CHECK(cc == rscabi::CallingConv::X86Vectorcall);
    CHECK(!rscabi::parse_callconv("bogus", &cc));
}

void test_numeric_and_reg()
{
    CHECK(rscabi::Numeric::from_integer(rscabi::IntegerClass::I32, true).bits() == 32);
    CHECK(rscabi::Numeric::from_float(rscabi::FloatClass::F128).bits() == 128);

    rscabi::Reg integer = rscabi::Reg::integer(8);
    rscabi::Reg float32 = rscabi::Reg::floating(4);
    CHECK(integer.kind == rscabi::RegKindKind::Integer);
    CHECK(float32.kind == rscabi::RegKindKind::Float);
    CHECK(integer != float32);

    rscabi::TargetDataLayout target;
    CHECK(integer.align(target).bytes() >= 1);
}

void test_homogeneous_aggregate()
{
    rscabi::TargetDataLayout target;
    rscabi::TypeContext ctx(target);
    rscabi::AbiType *u32 = ctx.create(rscabi::TypeKind::Int);
    u32->scalar.primitive = rscabi::PrimitiveKind::Int;
    u32->scalar.bits = 32;
    u32->scalar.valid = rscabi::WrappingRange::full(32);

    rscabi::LayoutData layout;
    CHECK(ctx.layout_of(u32, &layout));

    rscabi::TyAbiInterface ty(ctx);
    rscabi::Reg reg;
    bool has_data = false;
    CHECK(ty.homogeneous_aggregate(layout, &reg, &has_data));
    CHECK(has_data);
    CHECK(reg.kind == rscabi::RegKindKind::Integer);
    CHECK(reg.size.bytes == 4);

    rscabi::HomogeneousAggregate aggregate;
    CHECK(rscabi::homogeneous_aggregate(ctx,
                                        layout,
                                        rscabi::ExternAbi::Rust,
                                        "x86_64-unknown-linux-gnu",
                                        &aggregate));
    CHECK(aggregate.kind == rscabi::HomogeneousAggregateKind::Homogeneous);
}

} // namespace

int main()
{
    test_extern_abi();
    test_canon_abi();
    test_callconv();
    test_numeric_and_reg();
    test_homogeneous_aggregate();

    if (failures != 0)
    {
        printf("%d ABI test failure(s)\n", failures);
        return 1;
    }
    printf("abi tests: ok\n");
    return 0;
}
