#!/usr/bin/env bash

set -euo pipefail

RUSTC_BIN="${RUSTC:-rustc}"
export RUSTC_BOOTSTRAP=1

if [[ $# -ne 2 ]]; then
    echo "usage: $0 '<rust source defining TYPE>' TYPE" >&2
    exit 2
fi

source_text="$1"
type_name="$2"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/probe.rs" <<EOF
#![allow(internal_features)]
#![feature(repr_simd)]

$source_text

fn main() {
    println!("{} {}", std::mem::size_of::<$type_name>(), std::mem::align_of::<$type_name>());
}
EOF

"$RUSTC_BIN" --version
"$RUSTC_BIN" -Zprint-type-sizes -o "$tmpdir/probe" "$tmpdir/probe.rs" 2>/dev/null \
    | awk -v needle="type: \`$type_name\`" '
        index($0, needle) { active = 1; print; next }
        active && /print-type-size type:/ { active = 0 }
        active { print }
    '
