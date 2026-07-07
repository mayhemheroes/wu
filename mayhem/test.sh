#!/usr/bin/env bash
#
# wu/mayhem/test.sh — compile each testsuite .wu file and diff the emitted .lua against golden output.
# Behavioral oracle: a no-op PATCH that exits(0) without compiling cannot pass (sabotage-checked).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

cd "$SRC"
mkdir -p "$WU_HOME"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

ORACLE=/mayhem/wu-test
TS="$SRC/mayhem/testsuite"
if [ ! -x "$ORACLE" ]; then
  echo "ERROR: missing $ORACLE (build.sh should have produced it)" >&2
  emit_ctrf "wu-golden" 0 1 0; exit 1
fi

PASSED=0; FAILED=0; SKIPPED=0
shopt -s nullglob
for wufile in "$TS"/*.wu; do
  base="$(basename "$wufile" .wu)"
  golden="$TS/${base}.lua"
  if [ ! -f "$golden" ]; then
    echo "SKIP $base: no golden ${base}.lua" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  work="$(mktemp -d)"
  cp "$wufile" "$work/${base}.wu"
  (cd "$work" && "$ORACLE" "${base}.wu" >/dev/null 2>&1) || {
    echo "FAIL $base: wu exited non-zero" >&2
    FAILED=$((FAILED + 1))
    rm -rf "$work"
    continue
  }
  if [ ! -f "$work/${base}.lua" ]; then
    echo "FAIL $base: no ${base}.lua emitted" >&2
    FAILED=$((FAILED + 1))
    rm -rf "$work"
    continue
  fi
  if diff -q "$golden" "$work/${base}.lua" >/dev/null 2>&1; then
    echo "PASS $base"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL $base: output differs from golden" >&2
    diff -u "$golden" "$work/${base}.lua" | head -20 >&2 || true
    FAILED=$((FAILED + 1))
  fi
  rm -rf "$work"
done

[ $((PASSED + FAILED)) -gt 0 ] || { echo "ERROR: no tests ran" >&2; emit_ctrf "wu-golden" 0 1 0; exit 1; }
emit_ctrf "wu-golden" "$PASSED" "$FAILED" "$SKIPPED"
