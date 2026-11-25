# rustc layout probe

Two-tier probe used by `tests/oracle/oracle.sh` when `ORACLE_INTERNAL=1`.

## Tier 1: `probe.sh`

Works with the locally installed stable toolchain when `RUSTC_BOOTSTRAP=1` is
set. It uses `rustc -Zprint-type-sizes` to expose:

- field memory order (the order rustc actually lays fields out in memory),
- variant field order,
- total size and alignment.

This is the tier used by the default internal oracle run.

```bash
RUSTC_BOOTSTRAP=1 ./probe.sh 'pub struct F1 { a: u8, b: u64, c: u8 }' F1
```

## Tier 2: `private_probe.rs`

A rustc-private driver that uses `rustc_abi` directly to dump the full internal
layout decision: `memory_index`, `tag_encoding`, `niche_variants`, `niche_start`
and the largest niche. It requires a nightly toolchain with the `rustc-dev`
component and a matching compiler build; it is not required for the stable
oracle.

Build example (nightly + rustc-dev only):

```bash
rustc +nightly --edition 2021 private_probe.rs -o private_probe \
    $(rustc +nightly --print sysroot)/lib
./private_probe <crate.rlib> > internals.txt
```

The internal oracle labels every comparison line with the exact
`rustc --version` output. Cross-version differences in internal decisions are
reported separately and never change the stable size/align oracle verdict.
