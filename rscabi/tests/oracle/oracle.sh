#!/usr/bin/env bash

set -euo pipefail

# `-Zprint-type-sizes` and `#[repr(simd)]` are used only for oracle probing.
# They do not affect rscabi itself, which stays a plain C++11 library.
export RUSTC_BOOTSTRAP=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DUMP="${RSCABI_DUMP:-$ROOT/rscabi_dump}"
RUSTC_BIN="${RUSTC:-rustc}"

if [[ ! -x "$DUMP" ]]; then
    echo "rscabi_dump not found: $DUMP" >&2
    echo "run 'make' in $ROOT first" >&2
    exit 2
fi

if ! command -v "$RUSTC_BIN" >/dev/null 2>&1; then
    echo "rustc not found: $RUSTC_BIN" >&2
    exit 2
fi

rustc_version="$($RUSTC_BIN --version)"
echo "oracle rustc: $rustc_version"
if [[ "$rustc_version" != *"1.100.0"* ]]; then
    echo "warning: oracle expects rustc 1.100.0, got: $rustc_version" >&2
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rust_type() {
    case "$1" in
        u8|u16|u32|u64|u128|usize|i8|i16|i32|i64|i128|isize|bool|char|f32|f64) echo "$1" ;;
        ptr\(u8\)) echo "*const u8" ;;
        ref\(u8\)) echo "&u8" ;;
        refmut\(u8\)) echo "&mut u8" ;;
        fnptr) echo "fn()" ;;
        nonzero\(u32\)) echo "std::num::NonZeroU32" ;;
        nonzero\(u64\)) echo "std::num::NonZeroU64" ;;
        nonzero\(usize\)) echo "std::num::NonZeroUsize" ;;
        box\(u8\)) echo "Box<u8>" ;;
        nonnull\(u8\)) echo "std::ptr::NonNull<u8>" ;;
        transparent\(nonzero\(u32\)\)) echo "WN" ;;
        struct\(repr=C,u8,u32\)) echo "C1" ;;
        struct\(repr=C,u64,u8\)) echo "C2" ;;
        struct\(repr=align=128,u8,u64\)) echo "A16" ;;
        struct\(repr=pack=8,u8,u64\)) echo "P1" ;;
        enum\(repr=C,u8\|u32\)) echo "CE" ;;
        enum\(repr=C,unit\|u64\)) echo "CE64" ;;
        enum\(repr=int=16,u8\|u32\)) echo "E16" ;;
        enum\(repr=int=8,u8\|u32\)) echo "E8" ;;
        refslice\(u8\)) echo "&[u8]" ;;
        fatptr\(u8\)) echo "*const [u8]" ;;
        option\(refslice\(u8\)\)) echo "Option<&[u8]>" ;;
        option\(ref\(u8\)\)) echo "Option<&u8>" ;;
        option\(refmut\(u8\)\)) echo "Option<&mut u8>" ;;
        option\(nonzero\(u32\)\)) echo "Option<std::num::NonZeroU32>" ;;
        option\(box\(u8\)\)) echo "Option<Box<u8>>" ;;
        option\(nonnull\(u8\)\)) echo "Option<std::ptr::NonNull<u8>>" ;;
        option\(transparent\(nonzero\(u32\)\)\)) echo "Option<WN>" ;;
        option\(fnptr\)) echo "Option<fn()>" ;;
        option\(bool\)) echo "Option<bool>" ;;
        option\(char\)) echo "Option<char>" ;;
        option\(u8\)) echo "Option<u8>" ;;
        option\(u32\)) echo "Option<u32>" ;;
        enum\(unit\|u8\)) echo "R1" ;;
        enum\(u8\|u16\)) echo "R2" ;;
        enum\(u8\|u32\|u64\)) echo "R3" ;;
        enum\(unit\|u128\)) echo "R4" ;;
        enum\(\(u8,u8\)\|\(u16,u16\)\)) echo "R5" ;;
        option\(tuple\(u8,u8\)\)) echo "Option<(u8, u8)>" ;;
        option\(array\(u8,3\)\)) echo "Option<[u8; 3]>" ;;
        option\(option\(u8\)\)) echo "Option<Option<u8>>" ;;
        struct\(u8,u64,u8\)) echo "F1" ;;
        struct\(u64,u8,u8\)) echo "F2" ;;
        tuple\(u8,u32,u8\)) echo "(u8, u32, u8)" ;;
        struct\(u8,u16,u8,u32\)) echo "F3" ;;
        option\(struct\(u8,u64\)\)) echo "Option<F4>" ;;
        union\(u8,u64\)) echo "U1" ;;
        union\(u8,u16,u32\)) echo "U2" ;;
        union\(repr=C,u8,u64\)) echo "CU1" ;;
        option\(union\(u8,u64\)\)) echo "Option<U1>" ;;
        array\(u16,3\)) echo "[u16; 3]" ;;
        simd\(u8,16\)) echo "S16" ;;
        simd\(u32,4\)) echo "S4" ;;
        *) return 1 ;;
    esac
}

cases=(
    "u8"
    "u16"
    "u32"
    "u64"
    "u128"
    "usize"
    "bool"
    "char"
    "f32"
    "f64"
    "fnptr"
    "ptr(u8)"
    "ref(u8)"
    "refmut(u8)"
    "nonzero(u32)"
    "nonzero(u64)"
    "nonzero(usize)"
    "box(u8)"
    "nonnull(u8)"
    "transparent(nonzero(u32))"
    "struct(repr=C,u8,u32)"
    "struct(repr=C,u64,u8)"
    "struct(repr=align=128,u8,u64)"
    "struct(repr=pack=8,u8,u64)"
    "enum(repr=C,u8|u32)"
    "enum(repr=C,unit|u64)"
    "enum(repr=int=16,u8|u32)"
    "enum(repr=int=8,u8|u32)"
    "refslice(u8)"
    "fatptr(u8)"
    "option(refslice(u8))"
    "option(ref(u8))"
    "option(refmut(u8))"
    "option(nonzero(u32))"
    "option(box(u8))"
    "option(nonnull(u8))"
    "option(transparent(nonzero(u32)))"
    "option(fnptr)"
    "option(bool)"
    "option(char)"
    "option(u8)"
    "option(u32)"
    "enum(unit|u8)"
    "enum(u8|u16)"
    "enum(u8|u32|u64)"
    "enum(unit|u128)"
    "enum((u8,u8)|(u16,u16))"
    "option(tuple(u8,u8))"
    "option(array(u8,3))"
    "option(option(u8))"
    "struct(u8,u64,u8)"
    "struct(u64,u8,u8)"
    "tuple(u8,u32,u8)"
    "struct(u8,u16,u8,u32)"
    "option(struct(u8,u64))"
    "union(u8,u64)"
    "union(u8,u16,u32)"
    "union(repr=C,u8,u64)"
    "option(union(u8,u64))"
    "array(u16,3)"
    "simd(u8,16)"
    "simd(u32,4)"
)

write_probe() {
    local rust_expr="$1"
    cat > "$tmpdir/probe.rs" <<EOF
#![allow(internal_features)]
#![feature(repr_simd)]

#[repr(transparent)]
pub struct WN(pub std::num::NonZeroU32);

#[repr(C)]
pub struct C1 { pub a: u8, pub b: u32 }

#[repr(C)]
pub struct C2 { pub a: u64, pub b: u8 }

#[repr(align(16))]
pub struct A16 { pub a: u8, pub b: u64 }

#[repr(packed)]
pub struct P1 { pub a: u8, pub b: u64 }

#[repr(C)]
pub enum CE { A(u8), B(u32) }

#[repr(C)]
pub enum CE64 { A, B(u64) }

#[repr(u16)]
pub enum E16 { A(u8), B(u32) }

#[repr(u8)]
pub enum E8 { A(u8), B(u32) }

pub enum R1 { A, B(u8) }

pub enum R2 { A(u8), B(u16) }

pub enum R3 { A(u8), B(u32), C(u64) }

pub enum R4 { A, B(u128) }

pub enum R5 { A(u8, u8), B(u16, u16) }

pub struct F1 { pub a: u8, pub b: u64, pub c: u8 }

pub struct F2 { pub a: u64, pub b: u8, pub c: u8 }

pub struct F3 { pub a: u8, pub b: u16, pub c: u8, pub d: u32 }

pub struct F4 { pub a: u8, pub b: u64 }

// Tuple structs follow the same rustc field-reordering algorithm as tuples.
pub struct T3(pub u8, pub u32, pub u8);

pub union U1 { pub a: u8, pub b: u64 }

pub union U2 { pub a: u8, pub b: u16, pub c: u32 }

#[repr(C)]
pub union CU1 { pub a: u8, pub b: u64 }

#[repr(simd)]
pub struct S16([u8; 16]);

#[repr(simd)]
pub struct S4([u32; 4]);

fn main() {
    println!("{} {}", std::mem::size_of::<$rust_expr>(), std::mem::align_of::<$rust_expr>());
}
EOF
}

failures=0

for case_expr in "${cases[@]}"; do
    rust_expr="$(rust_type "$case_expr")" || continue

    write_probe "$rust_expr"

    "$RUSTC_BIN" -O -o "$tmpdir/probe" "$tmpdir/probe.rs" 2>"$tmpdir/probe.err" || {
        echo "RUSTC COMPILE FAILED $case_expr" >&2
        cat "$tmpdir/probe.err" >&2
        failures=$((failures + 1))
        continue
    }
    read -r rust_size rust_align < <("$tmpdir/probe")

    dump_output="$("$DUMP" --type "$case_expr")"
    rscabi_size="$(printf '%s\n' "$dump_output" | sed -n 's/^size: //p')"
    rscabi_align="$(printf '%s\n' "$dump_output" | sed -n 's/^align: //p')"

    if [[ "$rust_size" != "$rscabi_size" || "$rust_align" != "$rscabi_align" ]]; then
        echo "MISMATCH $case_expr"
        echo "  rustc:  size=$rust_size align=$rust_align"
        echo "  rscabi: size=$rscabi_size align=$rscabi_align"
        failures=$((failures + 1))
    else
        echo "OK $case_expr size=$rust_size align=$rust_align"
    fi
done

# Internal layout cross-check: memory order, field offsets, memory_index and
# tag/niche encoding. Results are labelled with the exact rustc version;
# cross-version differences are reported but never downgrade the stable ABI
# oracle result above.
if [[ "${ORACLE_INTERNAL:-0}" == "1" ]]; then
    echo "internal layout oracle (rustc=$rustc_version)" >&2

    # Field order / memory_index cross-check uses `-Zprint-type-sizes`, which
    # prints fields in rustc's chosen memory order for structs and tuples.
    order_cases=(
        "struct(u8,u64,u8)@F1"
        "struct(u64,u8,u8)@F2"
        "tuple(u8,u32,u8)@T3"
        "struct(repr=C,u8,u32)@C1"
        "struct(repr=align=128,u8,u64)@A16"
        "struct(repr=pack=8,u8,u64)@P1"
        "union(u8,u64)@U1"
    )

    for entry in "${order_cases[@]}"; do
        case_expr="${entry%%@*}"
        rust_expr="${entry##*@}"

        write_probe "$rust_expr"
        cp "$tmpdir/probe.rs" "$tmpdir/internal.rs"
        "$RUSTC_BIN" -Zprint-type-sizes -o "$tmpdir/internal-bin" \
            "$tmpdir/internal.rs" 2>/dev/null > "$tmpdir/internal.txt"

        rust_order="$(awk -v needle="type: \`$rust_expr\`" '
            index($0, needle) { active = 1; next }
            active && /print-type-size type:/ { active = 0 }
            active && /field / {
                line = $0
                sub(/^.*field /, "", line)
                gsub(/`/, "", line)
                sub(/:.*/, "", line)
                sub(/^\./, "", line)
                printf "%s ", line
            }
        ' "$tmpdir/internal.txt" | sed 's/ *$//')"

        dump_output="$("$DUMP" --type "$case_expr" --dump-internals)"
        rscabi_order="$(printf '%s\n' "$dump_output" | sed -n 's/^memory_order://p' \
            | sed 's/^ *//' | tr ' ' '\n' | paste -sd' ' -)"

        # rustc prints fields in memory order; map names to declaration indexes.
        expected_order=""
        for field in $rust_order; do
            case "$field" in
                a) idx=0 ;;
                b) idx=1 ;;
                c) idx=2 ;;
                d) idx=3 ;;
                pointer) idx=0 ;;
                *) idx="$field" ;;
            esac
            expected_order="$expected_order $idx"
        done
        expected_order="$(echo "$expected_order" | sed 's/^ *//')"

        status="OK"
        if [[ "$expected_order" != "$rscabi_order" ]]; then
            echo "INTERNAL MISMATCH [$rustc_version] $case_expr memory_order"
            echo "  rustc:  $expected_order"
            echo "  rscabi: $rscabi_order"
            failures=$((failures + 1))
            status="MISMATCH"
        fi
        echo "INTERNAL [$rustc_version] $case_expr status=$status memory_order=$rscabi_order"
    done

    # Tag and niche selection checks. rustc-private internals are not exposed
    # by -Zprint-type-sizes, so these assert the expected rustc decisions.
    encoding_cases=(
        "enum(u8|u32|u64)@direct@3@0"
        "enum(repr=C,u8|u32)@direct@2@0"
        "enum(repr=int=8,u8|u32)@direct@2@0"
        "option(ref(u8))@niche@2@1"
        "option(nonzero(u32))@niche@2@1"
        "option(box(u8))@niche@2@1"
        "option(bool)@niche@2@1"
        "option(char)@niche@2@1"
    )

    for entry in "${encoding_cases[@]}"; do
        IFS='@' read -r case_expr expected_tag expected_count expected_untagged <<<"$entry"
        dump_output="$("$DUMP" --type "$case_expr" --dump-internals)"
        tag="$(printf '%s\n' "$dump_output" | sed -n 's/^tag_encoding: //p')"
        variant_count="$(printf '%s\n' "$dump_output" | sed -n 's/^variants: //p')"
        untagged="$(printf '%s\n' "$dump_output" | sed -n 's/^untagged_variant: //p')"
        status="OK"
        if [[ "$tag" != "$expected_tag" || "$variant_count" != "$expected_count" ||
              "$untagged" != "$expected_untagged" ]]; then
            echo "INTERNAL MISMATCH [$rustc_version] $case_expr tag/niche selection"
            echo "  expected: tag=$expected_tag variants=$expected_count untagged=$expected_untagged"
            echo "  rscabi:   tag=$tag variants=$variant_count untagged=$untagged"
            failures=$((failures + 1))
            status="MISMATCH"
        fi
        echo "INTERNAL [$rustc_version] $case_expr status=$status tag=$tag variants=$variant_count untagged=$untagged"
    done

    # Coroutine internals: rustc generators remain unstable, so verify the
    # structural invariants emitted by rscabi itself and label them too.
    for case_expr in \
        "coroutine(async,state(u8)|state(u64))" \
        "coroutine(gen,state(u8,u32)|state(u64))"
    do
        dump_output="$("$DUMP" --type "$case_expr" --dump-internals)"
        variant_count="$(printf '%s\n' "$dump_output" | sed -n 's/^variants: //p')"
        tag="$(printf '%s\n' "$dump_output" | sed -n 's/^tag_encoding: //p')"
        if [[ "$variant_count" != "2" || "$tag" != "direct" ]]; then
            echo "INTERNAL MISMATCH [$rustc_version] $case_expr coroutine invariants" >&2
            failures=$((failures + 1))
        else
            echo "INTERNAL [$rustc_version] $case_expr status=OK tag=$tag variants=$variant_count"
        fi
    done
fi

# Extern ABI / canonical ABI / calling-convention table checks. These mirror
# the rustc_abi 1.100.0 canonize/callconv mapping and are run through the CLI
# so the public output format is covered too.
abi_cases=(
    "Rust@x86_64-unknown-linux-gnu@Rust@Rust"
    "rust-cold@x86_64-unknown-linux-gnu@rust-cold@rust-cold"
    "C@x86_64-unknown-linux-gnu@C@C"
    "C@aarch64-unknown-linux-gnu@C@aapcs"
    "system@x86_64-pc-windows-msvc@win64@win64"
    "stdcall@i686-pc-windows-msvc@stdcall@stdcall"
    "aapcs@aarch64-unknown-linux-gnu@aapcs@aapcs"
    "x86-interrupt@x86_64-unknown-none@x86-interrupt@interrupt"
)

for entry in "${abi_cases[@]}"; do
    IFS='@' read -r abi triple expected_canon expected_callconv <<<"$entry"
    dump_output="$("$DUMP" --type u8 --target-triple "$triple" --extern-abi "$abi")"
    canon="$(printf '%s\n' "$dump_output" | sed -n 's/^canon_abi: //p')"
    callconv="$(printf '%s\n' "$dump_output" | sed -n 's/^callconv: //p')"

    status="OK"
    if [[ "$canon" != "$expected_canon" || "$callconv" != "$expected_callconv" ]]; then
        echo "ABI MISMATCH [$rustc_version] abi=$abi triple=$triple"
        echo "  expected: canon=$expected_canon callconv=$expected_callconv"
        echo "  rscabi:   canon=$canon callconv=$callconv"
        failures=$((failures + 1))
        status="MISMATCH"
    fi
    echo "ABI [$rustc_version] $abi@$triple status=$status canon=$canon callconv=$callconv"
done

# Explicit --callconv override must be visible in CLI output.
override_output="$("$DUMP" --type u8 --target-triple 'x86_64-unknown-linux-gnu' \
    --extern-abi C --callconv vectorcall)"
override="$(printf '%s\n' "$override_output" | sed -n 's/^callconv_requested: //p')"
if [[ "$override" != "vectorcall" ]]; then
    echo "ABI MISMATCH [$rustc_version] explicit callconv override"
    echo "  expected: vectorcall"
    echo "  rscabi:   $override"
    failures=$((failures + 1))
else
    echo "ABI [$rustc_version] explicit callconv status=OK callconv=$override"
fi

if [[ "$failures" -ne 0 ]]; then
    echo "$failures oracle mismatch(es)" >&2
    exit 1
fi

echo "rscabi oracle: ok"
