# rscabi

`rscabi` 是一个独立的 C++11 库，移植并抽取 `rustc_abi` 在 rust-lang/rust **1.100.0** 中的类型布局、标量有效范围与 niche 计算逻辑，并对外提供 C API。

它不是 rustc 官方 crate，不依赖 Rust 运行时、LLVM、rustc-dev 或 gccrs。

来源说明：

```text
rscabi is derived from rustc_abi in rust-lang/rust 1.100.0.
It is a standalone C++11 port and is not the official rustc crate.
```

完整来源信息见 [PROVENANCE.md](PROVENANCE.md)。

## 目录

```text
rscabi/
  include/rscabi.h       C-compatible API
  src/core/              Size/Align/U128/WrappingRange/Scalar/LayoutCalculator
  src/model/             AbiType/TypeContext/layout_of
  src/capi/              extern "C" 边界与异常隔离
  cli/rscabi_dump        DSL -> layout 调试工具
  tests/                 单元测试、C API 测试、rustc oracle 脚本
  tools/rustc_layout_probe/  rustc 内部布局探针（稳定版 -Zprint-type-sizes / 可选 rustc-private 驱动）
```

## 构建

使用 Makefile：

```bash
cd rscabi
make
make check
```

使用 CMake：

```bash
cd rscabi
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

产物：

```text
librscabi.a
rscabi_dump
```

只要求 C++11 编译器和 C11 编译器，例如：

```bash
g++ -std=c++11 ...
clang++ -std=c++11 ...
```

## C API 使用

最小示例：

```c
#include "rscabi.h"

int main(void)
{
    rscabi_target_t *target = NULL;
    rscabi_context_t *ctx = NULL;
    rscabi_type_t *u8 = NULL;
    rscabi_layout_t *layout = NULL;
    rscabi_layout_info_t info;

    if (rscabi_target_new(64, 64, 64, 1, &target) != RSCABI_OK)
    {
        return 1;
    }
    if (rscabi_context_new(target, &ctx) != RSCABI_OK)
    {
        return 2;
    }
    if (rscabi_type_int(ctx, 8, 0, &u8) != RSCABI_OK)
    {
        return 3;
    }
    if (rscabi_layout_of(ctx, u8, &layout) != RSCABI_OK)
    {
        return 4;
    }
    if (rscabi_layout_info(layout, &info) != RSCABI_OK)
    {
        return 5;
    }

    rscabi_layout_free(layout);
    rscabi_type_free(u8);
    rscabi_context_free(ctx);
    rscabi_target_free(target);
    return info.size == 1 ? 0 : 6;
}
```

类型通过 `rscabi_context_t` 创建：底层 `AbiType` 由 context 统一持有，C API 返回的 `rscabi_type_t *` wrapper 由调用者负责用 `rscabi_type_free()` 释放。`rscabi_type_free()` 只释放 wrapper，不释放底层类型，因此其他类型继续引用同一个底层类型是安全的。`rscabi_layout_t *` 由调用者用 `rscabi_layout_free()` 释放。

聚合类型Builder调用 `rscabi_type_finish()` 后即冻结：再次调用 `rscabi_type_add_field()` 或 `rscabi_type_enum_add_variant()` 会返回 `RSCABI_ERR_INVALID_ARG`。`rscabi_type_finish()` 会清理 layout 缓存。

所有 `extern "C"` 函数都会捕获 C++ 异常，不会让异常跨过 C 边界。

## rscabi_dump DSL

```bash
./rscabi_dump --type 'u8'
./rscabi_dump --type 'option(ref(u8))'
./rscabi_dump --type 'option(box(u8))'
./rscabi_dump --type 'option(nonnull(u32))'
./rscabi_dump --type 'struct(u8,u32,u64)'
./rscabi_dump --type 'struct(repr=C+packed,u8,u32)'
./rscabi_dump --type 'enum(unit|u8|(u16,u16))'
./rscabi_dump --type 'array(nonzero(u32),4)'
./rscabi_dump --target i686 --type 'usize'
./rscabi_dump --target i686 --type 'option(ref(u8))'
./rscabi_dump --target i686 --type 'refslice(u8)'
./rscabi_dump --target 'e-m:e-p:64:64-i32:32:32-i64:64:64-a:0:64:64' --type 'ptr(u8)'
./rscabi_dump --type 'u32' --target-triple 'aarch64-unknown-linux-gnu' --extern-abi aapcs
./rscabi_dump --type 'u32' --target-triple 'x86_64-pc-windows-msvc' --extern-abi system --callconv win64
./rscabi_dump --type 'simd(u8,16)' --dump-internals
./rscabi_dump --type 'coroutine(async,state(u8)|state(u64))' --dump-internals
```

支持的类型表达式：

```text
never
unit
bool
char
i8..i128 / u8..u128 / isize / usize
f16 / f32 / f64 / f128
fnptr
ptr(T)
fatptr(T)
ref(T) / refmut(T) / refslice(T)
box(T)
nonnull(T)
nonzero(T)
transparent(T)
array(T,N)
slice(T)
tuple(T1,T2,...)
struct(T1,T2,...)
struct(repr=...,T1,T2,...)
union(T1,T2,...)
union(repr=...,T1,T2,...)
enum(V1|V2|...)
enum(repr=...,V1|V2|...)
option(T)
simd(T,N) / simd_packed(T,N)
coroutine(async|gen,state(T1,...)|state(T2,...)|...)
```

`repr=` 支持 `C`、`packed`、`simd`、`align=N`、`pack=N`、`int=N`，用 `+` 连接。

`--dump-internals` 会额外输出 `fields_kind`、`memory_order`（字段内存顺序）、`tag_encoding`、`untagged_variant`、`niche_variants`、`niche_start`、`largest_niche_available`，以及每个 variant 的 `memory_index` 和 `field_offsets`。

## 当前范围

实现覆盖：

- `Size` / `Align` / 溢出检查
- `U128` 与 `WrappingRange`
- 标量布局与 niche 补集；`Niche::available()` / `reserve()` / `from_scalar()` 语义
- rustc 风格字段重排：`NicheBias`、`StructKind`、`alignment_group_key`、`Reverse(alignment_group_key) -> niche_size_key -> inner_niche_offset_key`、`univariant()` 双布局评估
- rustc 风格 niche 优化压缩：largest variant + largest niche、`niche_variants` 连续区间、variant 压缩/前后放置、backend 复用、best layout 比较（size 优先，再比 niche available）
- struct/tuple/union/array/slice 布局
- tagged enum、niche enum、`repr(C)`、`repr(align=N)`、`repr(pack=N)` 与 `repr(int=N)` 的 tag 布局
- ScalarPair/fat pointer：`fatptr(T)`、`refslice(T)`、`rscabi_type_slice_ref()`
- `Option<T>` 在稳定承诺类型上的 niche 布局
- SIMD：`repr(simd)` 向量布局与 packed 非 2 次幂 lane 回退
- coroutine：overlap-eligible / ineligible 局部划分、prefix 提升、per-variant 字段布局、direct discriminant
- 内部布局暴露：`memory_index`、字段 offset/size、tag range、niche 选择结果，C API 与 CLI 都可查询
- C API、CLI、单元测试、C API 测试
- padding range 查询：`variant_independent_padding` 是所有 variant 都未占用的字节；`variant_dependent_padding_ranges(variant_index)` 返回该 variant 独有、其他 variant 占用的字节
- extern ABI：`ExternAbi` 全集、`system` 的 target 解析、C-variadic 能力查询
- canonical ABI：`CanonAbi` 与 ARM / X86 / interrupt / GPU / Rust 变体
- calling convention：`Reg` / `RegKind` / `HomogeneousAggregate` 与 target 特化映射
- `rustc_abi::layout::ty` 对应的 `TyAbiInterface`：由 C++ `AbiType` / `TypeContext` 等价实现

明确不覆盖：

- 完整 `rustc_middle::Ty` / `TyCtxt` 端口
- rustc_abi 支持矩阵之外的 target 特化差异
- 普通用户 enum 的跨版本 ABI 稳定性承诺

`rustc_abi::tests.rs` 的语义对应测试由本项目测试与 oracle 扩展实现，不直接复用 rustc 内部测试代码。

普通 `#[repr(Rust)]` enum 的精确字段顺序和 niche 选择属于 rustc 内部实现细节，不是稳定 ABI。稳定边界以 rustc/std 文档承诺为准，例如 `std::option` 对 `Option<&U>`、`Option<Box<U>>`、`Option<NonNull<U>>`、`Option<NonZero*>`、`Option<fn()>` 等的保证。

## 验证

```bash
make check
bash tests/oracle/oracle.sh
ORACLE_INTERNAL=1 bash tests/oracle/oracle.sh
```

oracle 脚本会把一组类型的 `rscabi_dump` 结果与本机 Rust 的 `size_of` / `align_of` 输出对比；版本不是 1.100.0 时保留 warning。`ORACLE_INTERNAL=1` 还会对字段内存顺序、`memory_index`、`tag_encoding`、niche 选择过程做第二层对拍，并在每行结果上标注实际使用的 rustc 版本。内部细节属于 rustc 实现细节，跨版本差异单独报告，不会改变稳定 ABI oracle 的结论。

`tools/rustc_layout_probe/` 提供两层探针：稳定工具链配合 `RUSTC_BOOTSTRAP=1` 的 `-Zprint-type-sizes`，以及需要 nightly + rustc-dev 的 `private_probe.rs`（可输出完整的 `niche_variants`、`niche_start`、`largest_niche`）。
