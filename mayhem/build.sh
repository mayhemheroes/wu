#!/usr/bin/env bash
#
# wu/mayhem/build.sh — build the Wu compiler pipeline as a libFuzzer fuzz target and a clean
# test-oracle binary.
#
#   /mayhem/translate — libFuzzer + ASan target (mayhem/fuzz). Feeds an in-memory source string
#                       through the full lexer/parser/visitor/codegen pipeline. cargo-fuzz gives
#                       guaranteed SanitizerCoverage instrumentation (the old file-input `wu @@`
#                       binary had ASan but NO sancov, so Mayhem got 0 edges and dynamic analysis
#                       failed).
#   /mayhem/wu-test   — clean (uninstrumented) `wu` CLI used by test.sh as the golden oracle.
#
# ASan/sancov come from RUSTFLAGS / cargo-fuzz, NOT clang $SANITIZER_FLAGS (rustc ignores those).
#
# AIR-GAPPED CONTRACT (SPEC §6.5): PATCH re-runs this script offline; the cargo registry under
# $CARGO_HOME is populated by this first online build.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

# DWARF < 4 (§6.2 item 10). $SANITIZER_FLAGS from the base is for clang/C++; Rust uses RUST_DEBUG_FLAGS.
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C strip=none -C force-frame-pointers=yes -C llvm-args=--dwarf-version=2}"

cd "$SRC"

# Strip ASan runtime debug info so project DWARF < 4 appears first in .debug_info.
ASAN_RT="$(find "$RUSTUP_HOME/toolchains" -name "librustc-nightly_rt.asan.a" 2>/dev/null | head -1)"
if [ -n "$ASAN_RT" ] && [ -f "$ASAN_RT" ]; then
    echo "Stripping debug info from Rust ASan runtime: $ASAN_RT"
    objcopy --strip-debug "$ASAN_RT"
fi

mkdir -p "$WU_HOME"

echo "=== clean build (test oracle) ==="
RUSTFLAGS="" cargo build --release --jobs "$MAYHEM_JOBS"
cp -f target/release/wu /mayhem/wu-test
echo "built /mayhem/wu-test"

echo "=== cargo fuzz build: translate (libFuzzer + ASan + sancov) ==="
FUZZ_DIR="mayhem/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"
export RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS}"
echo "RUSTFLAGS=$RUSTFLAGS"
cargo fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions translate
bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/translate"
[ -x "$bin" ] || { echo "ERROR: missing $bin" >&2; exit 1; }
cp -f "$bin" /mayhem/translate
echo "built /mayhem/translate"

echo "build.sh complete:"
ls -la /mayhem/translate /mayhem/wu-test
