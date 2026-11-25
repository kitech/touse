# Provenance

`rscabi` is derived from `rustc_abi` in rust-lang/rust 1.100.0.
It is a standalone C++11 port and is not the official rustc crate.

## Upstream

```text
Project: rust-lang/rust
Tag: 1.100.0
Annotated tag object: 6b503e798d0cc01ca1052eeefaccee43893b0ff6
Commit: 0ef1bc386059596dada8fb65b50425aab2ea637a
Source path: compiler/rustc_abi/
Extracted: 2026-11-25
```

## Files used as reference

```text
compiler/rustc_abi/src/lib.rs
compiler/rustc_abi/src/wrapping_range.rs
compiler/rustc_abi/src/layout.rs
compiler/rustc_abi/src/layout/coroutine.rs
compiler/rustc_abi/src/layout/simple.rs
compiler/rustc_abi/src/layout/ty.rs
compiler/rustc_abi/src/callconv.rs
compiler/rustc_abi/src/callconv/reg.rs
compiler/rustc_abi/src/canon_abi.rs
compiler/rustc_abi/src/extern_abi.rs
compiler/rustc_abi/src/extern_abi/tests.rs
compiler/rustc_abi/src/tests.rs
```

The high-level `compiler/rustc_abi/src/layout/ty.rs` interface is not ported directly because it depends on rustc-internal `Ty`/`TyCtxt`. This project uses its own `AbiType` and `TypeContext` instead.

The remaining `rustc_abi` modules are in scope for this port: `callconv.rs` /
`callconv/`, `canon_abi.rs`, `extern_abi.rs` / `extern_abi/`, `layout/ty.rs`,
and `tests.rs`. `layout/ty.rs` is realized by a C++ `TyAbiInterface` over
`AbiType` / `TypeContext` rather than rustc `Ty`/`TyCtxt`.

## Capability provenance

```text
Size/Align/U128/WrappingRange/Scalar and valid-range complement:
  compiler/rustc_abi/src/lib.rs
  compiler/rustc_abi/src/wrapping_range.rs
  compiler/rustc_abi/src/layout.rs

Rust-style field reordering (NicheBias, StructKind, alignment_group_key,
niche_size_key, inner_niche_offset_key and the two-layout univariant() choice):
  compiler/rustc_abi/src/layout.rs

Niche optimization and compression (Niche::available/reserve/from_scalar,
largest variant + largest niche, niche_variants range, variant placement,
backend reuse and best-layout comparison):
  compiler/rustc_abi/src/layout.rs

SIMD vector layout and packed fallback:
  compiler/rustc_abi/src/lib.rs
  compiler/rustc_abi/src/layout.rs

Coroutine layout (overlap-eligible/ineligible locals, prefix promotion,
per-variant field layout and direct discriminant):
  compiler/rustc_abi/src/layout/coroutine.rs

Register/HVA model and register alignment:
  compiler/rustc_abi/src/callconv.rs
  compiler/rustc_abi/src/callconv/reg.rs

Canonical ABI resolution and target-specific extern ABI defaults:
  compiler/rustc_abi/src/canon_abi.rs
  compiler/rustc_abi/src/extern_abi.rs

Ty-driven ABI interface (C++ AbiType/TypeContext equivalent):
  compiler/rustc_abi/src/layout/ty.rs
```

The internal layout getters exposed through `rscabi.h` and `rscabi_dump
--dump-internals` are additions of this port. They expose `memory_index`,
field offsets/sizes, tag ranges and the chosen niche for cross-checking
against rustc; they are not part of the upstream `rustc_abi` public API.

## Adaptations

- Rust `u128` is represented as a C++ struct with `uint64_t lo` and `uint64_t hi`.
- C++11 has no `std::optional`, `std::variant` or `std::make_unique`; the port uses explicit structs, status codes and owning containers.
- All `extern "C"` entry points catch exceptions and return `rscabi_status_t`.
- The stable promise boundary follows rustc/std documentation, not undocumented `repr(Rust)` field layout.
- The oracle keeps rustc 1.100.0 / commit `0ef1bc386059596dada8fb65b50425aab2ea637a` as its baseline and warns when local rustc differs; internal cross-check lines are labelled with the actual `rustc --version`.
