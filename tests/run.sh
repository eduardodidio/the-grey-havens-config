#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
FAILED_FILES=()

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

run_shell_test() {
  local file="$1"
  local label
  label="$(basename "$file")"
  if bash "$file" > "$TMP_OUT" 2>&1; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label"
    sed 's/^/      /' "$TMP_OUT"
    FAIL=$((FAIL + 1))
    FAILED_FILES+=("$label")
  fi
}

run_py_test() {
  local file="$1"
  local label
  label="$(basename "$file")"
  if python3 "$file" > "$TMP_OUT" 2>&1; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label"
    sed 's/^/      /' "$TMP_OUT"
    FAIL=$((FAIL + 1))
    FAILED_FILES+=("$label")
  fi
}

echo "=== didio test runner ==="
echo ""

# Shell tests: tests/F0*-*.sh  (nullglob avoids literal-string expansion on empty match)
shopt -s nullglob
for f in "$ROOT"/tests/F0*-*.sh; do
  run_shell_test "$f"
done

# Python tests: bin/test_*.py
for f in "$ROOT"/bin/test_*.py; do
  run_py_test "$f"
done

# Python tests: tests/test_*.py
for f in "$ROOT"/tests/test_*.py; do
  run_py_test "$f"
done
shopt -u nullglob

echo ""
echo "--- $PASS passed, $FAIL failed ---"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed files:"
  for f in "${FAILED_FILES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
