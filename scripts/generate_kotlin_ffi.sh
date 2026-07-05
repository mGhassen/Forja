#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FFI="$ROOT/crates/ffi"
OUT="$ROOT/packages/kotlin/generated"

mkdir -p "$OUT"

cd "$FFI"
cargo build -p ffi --features cli --bin uniffi-bindgen --release

"$FFI/../target/release/uniffi-bindgen" generate \
  --language kotlin \
  --out-dir "$OUT" \
  "$FFI/src/forja.udl"

echo "Kotlin bindings -> $OUT"
