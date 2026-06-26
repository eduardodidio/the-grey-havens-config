#!/usr/bin/env bash
#
# Injection security tests for bin/didio-config-lib.sh (F02-T04).
#
# Verifies that config functions do not execute or interpolate adversarial
# input (quotes, newlines, command substitution, etc.) when reading/writing
# config keys/values.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DIDIO_HOME="$ROOT_DIR"

# shellcheck disable=SC1090
source "$ROOT_DIR/bin/didio-config-lib.sh"

FAILURES=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc (expected to contain: $needle)"
    echo "  actual: $haystack"
    FAILURES=$((FAILURES + 1))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/project"
CONFIG="$TMP/project/didio.config.json"

echo '{}' > "$CONFIG"
export PROJECT_ROOT="$TMP/project"

# === Happy path: normal read/write ===

didio_write_config "test_key" "test_value"
VALUE="$(didio_read_config "test_key")"
assert_eq "happy path: write and read normal string" "test_value" "$VALUE"

didio_write_config "bool_true" "true"
BOOL="$(didio_read_config "bool_true")"
assert_eq "happy path: write and read bool true" "true" "$BOOL"

didio_write_config "bool_false" "false"
BOOL="$(didio_read_config "bool_false")"
assert_eq "happy path: write and read bool false" "false" "$BOOL"

didio_write_config "number" "42"
NUM="$(didio_read_config "number")"
assert_eq "happy path: write and read int" "42" "$NUM"

# === Edge case: single quote injection ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

didio_write_config "quote_key" "val'ue"
VALUE="$(didio_read_config "quote_key")"
assert_eq "edge case: single quote in value stored literally" "val'ue" "$VALUE"

# Read raw JSON to verify the quote is escaped properly
JSON_VALUE="$(python3 - "$CONFIG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
    print(c.get('quote_key', ''))
PY
)"
assert_eq "edge case: single quote read from JSON valid" "val'ue" "$JSON_VALUE"

# === Edge case: double quote injection ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

didio_write_config "dquote_key" 'val"ue'
VALUE="$(didio_read_config "dquote_key")"
assert_eq "edge case: double quote in value stored literally" 'val"ue' "$VALUE"

# === Edge case: newline in value ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

# Use printf to embed a literal newline
VALUE_WITH_NEWLINE="line1
line2"
didio_write_config "newline_key" "$VALUE_WITH_NEWLINE"
VALUE="$(didio_read_config "newline_key")"
assert_eq "edge case: newline in value stored literally" "$VALUE_WITH_NEWLINE" "$VALUE"

# === Edge case: command substitution attempt ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

didio_write_config "cmd_key" '$(whoami)'
VALUE="$(didio_read_config "cmd_key")"
assert_eq "edge case: \$(whoami) not executed" '$(whoami)' "$VALUE"

# === Edge case: backtick attempt ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

didio_write_config "backtick_key" '`date`'
VALUE="$(didio_read_config "backtick_key")"
assert_eq "edge case: backtick not executed" '`date`' "$VALUE"

# === Edge case: Python code attempt in value ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

PAYLOAD='"); import os; os.system("id"); print("'
didio_write_config "py_inject" "$PAYLOAD"
VALUE="$(didio_read_config "py_inject")"
assert_eq "edge case: python code not executed" "$PAYLOAD" "$VALUE"

# === Edge case: quote + newline + code (worst case) ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

EVIL="val'ue
with\"quotes
and code'); import sys; sys.exit(1); print('"
didio_write_config "evil_key" "$EVIL"
VALUE="$(didio_read_config "evil_key")"
assert_eq "edge case: evil payload stored literally" "$EVIL" "$VALUE"

# === Edge case: key with special chars ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

didio_write_config "key'with\"quote" "value"
VALUE="$(didio_read_config "key'with\"quote")"
assert_eq "edge case: key with quotes" "value" "$VALUE"

# === Edge case: very long value ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

LONG_VALUE="$(python3 -c "print('x' * 10000)")"
didio_write_config "long_key" "$LONG_VALUE"
VALUE="$(didio_read_config "long_key")"
assert_eq "edge case: very long value preserved" "$LONG_VALUE" "$VALUE"

# === Edge case: unicode ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

UNICODE="こんにちは世界 🌍 привет"
didio_write_config "unicode_key" "$UNICODE"
VALUE="$(didio_read_config "unicode_key")"
assert_eq "edge case: unicode preserved" "$UNICODE" "$VALUE"

# === Edge case: value "true"/"false" typed correctly ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

# String "true" (not bool)
didio_write_config "str_true" "true"
# Read raw JSON to verify it's stored as bool, not string
JSON_TYPE="$(python3 - "$CONFIG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
    v = c.get('str_true')
    print('bool' if isinstance(v, bool) else type(v).__name__)
PY
)"
assert_eq "edge case: literal 'true' typed as bool" "bool" "$JSON_TYPE"

rm "$CONFIG"
echo '{}' > "$CONFIG"

# String "123" (should be int)
didio_write_config "str_num" "123"
JSON_TYPE="$(python3 - "$CONFIG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
    v = c.get('str_num')
    print('int' if isinstance(v, int) else type(v).__name__)
PY
)"
assert_eq "edge case: literal '123' typed as int" "int" "$JSON_TYPE"

# === Role getter functions with special input ===

rm "$CONFIG"
cat > "$CONFIG" <<'JSON'
{
  "economy": false,
  "models": {
    "architect": { "model": "opus", "fallback": "sonnet", "effort": "high" },
    "developer": { "model": "sonnet", "fallback": "haiku", "provider": "claude" }
  }
}
JSON

MODEL="$(didio_model_for_role "architect")"
assert_eq "role getter: model returns expected value" "opus" "$MODEL"

FALLBACK="$(didio_fallback_for_role "architect")"
assert_eq "role getter: fallback returns expected value" "sonnet" "$FALLBACK"

EFFORT="$(didio_effort_for_role "architect")"
assert_eq "role getter: effort returns expected value" "high" "$EFFORT"

PROVIDER="$(didio_provider_for_role "developer")"
assert_eq "role getter: provider returns configured value" "claude" "$PROVIDER"

# Role with no provider defaults to 'claude'
PROVIDER="$(didio_provider_for_role "architect")"
assert_eq "role getter: provider defaults to claude when unset" "claude" "$PROVIDER"

# === Role getter with special chars in role name ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

# Edge case: role name with quote (unusual but test defense)
# This should return empty since role doesn't exist, not execute anything
RESULT="$(didio_model_for_role "role'with\"quote" || true)"
assert_eq "role getter: special chars in role name don't inject" "" "$RESULT"

# === Error scenario: malformed JSON returns empty ===

rm "$CONFIG"
echo 'invalid json {' > "$CONFIG"

VALUE="$(didio_read_config "any_key" 2>/dev/null || true)"
assert_eq "error scenario: malformed JSON returns empty" "" "$VALUE"

# === Error scenario: missing config returns empty ===

rm "$CONFIG"
VALUE="$(didio_read_config "any_key")"
assert_eq "error scenario: missing config returns empty" "" "$VALUE"

# === didio_recommend_parallel returns tier-specific strings ===

OPUS_PARALLEL="$(didio_recommend_parallel "opus")"
assert_contains "tier coverage: opus recommends weight" "$OPUS_PARALLEL" "3-4"

SONNET_PARALLEL="$(didio_recommend_parallel "sonnet")"
assert_contains "tier coverage: sonnet recommends weight" "$SONNET_PARALLEL" "5-8"

HAIKU_PARALLEL="$(didio_recommend_parallel "haiku")"
assert_contains "tier coverage: haiku recommends weight" "$HAIKU_PARALLEL" "8-12"

# === Boundary: economy mode ===

rm "$CONFIG"
cat > "$CONFIG" <<'JSON'
{
  "economy": true,
  "models": {
    "architect": { "model": "opus", "fallback": "sonnet" }
  },
  "models_economy": {
    "architect": { "model": "sonnet", "fallback": "haiku" }
  }
}
JSON

MODEL="$(didio_model_for_role "architect")"
assert_eq "boundary: economy mode respects models_economy" "sonnet" "$MODEL"

# === Boundary: max_parallel with turbo ===

rm "$CONFIG"
cat > "$CONFIG" <<'JSON'
{
  "turbo": true,
  "max_parallel": 4
}
JSON

MAX="$(didio_max_parallel)"
assert_eq "boundary: turbo overrides max_parallel to 0" "0" "$MAX"

# === Boundary: provider_bin fallback ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

BIN="$(didio_provider_bin "unknown_provider")"
assert_eq "boundary: unknown provider bin defaults to provider name" "unknown_provider" "$BIN"

# === Boundary: second_brain defaults ===

rm "$CONFIG"
echo '{}' > "$CONFIG"

ENABLED="$(didio_second_brain_enabled)"
assert_eq "boundary: second_brain_enabled defaults to false" "false" "$ENABLED"

FALLBACK="$(didio_second_brain_fallback)"
assert_eq "boundary: second_brain_fallback defaults to true" "true" "$FALLBACK"

# === JSON output for dict/list values ===

rm "$CONFIG"
cat > "$CONFIG" <<'JSON'
{
  "models": {
    "architect": { "model": "opus" }
  },
  "arr": [1, 2, 3]
}
JSON

DICT_OUTPUT="$(didio_read_config "models")"
assert_contains "json output: dict returns valid JSON" "$DICT_OUTPUT" '"architect"'

ARRAY_OUTPUT="$(didio_read_config "arr")"
assert_contains "json output: array returns valid JSON" "$ARRAY_OUTPUT" "[1, 2, 3]"

echo "---"
if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: all F02-config-injection checks passed"
  exit 0
else
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi
