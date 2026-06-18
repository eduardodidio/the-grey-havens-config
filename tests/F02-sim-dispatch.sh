#!/usr/bin/env bash
# tests/F02-sim-dispatch.sh — Axis C: per-role resolution + economy + meta lifecycle
#
# Uses echo-driver (zero model spend). EXTENDS F01-spawn-dispatch — does NOT
# repeat: basic echo dispatch, NDJSON in log, unknown provider exit 2, non-zero
# exit->failed. New coverage: resolution per role (model/fallback/effort from
# echo NDJSON AND meta), economy-tier switch, meta field completeness.
#
# TAP-ish output; exits non-zero on any failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tests/lib/sim-harness.sh
source "$SCRIPT_DIR/lib/sim-harness.sh"

FAILURES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$SCRIPT_DIR/fixtures/F02-task.md"

# ---------------------------------------------------------------------------
# Scaffold a temp project with two roles (developer + architect).
# Override the default config to set precise model/fallback/effort per role
# and add a models_economy section for the economy test.
# ---------------------------------------------------------------------------
P1="$TMP/proj"
sim_make_project "$P1" developer architect

cat > "$P1/didio.config.json" <<'JSON'
{
  "providers": { "echo": { "bin": "true" } },
  "economy": false,
  "models": {
    "developer": { "model": "sonnet", "fallback": "haiku", "effort": "medium", "provider": "echo" },
    "architect": { "model": "opus",   "fallback": "sonnet",                    "provider": "echo" }
  },
  "models_economy": {
    "developer": { "model": "haiku",  "fallback": "sonnet", "effort": "low",   "provider": "echo" },
    "architect": { "model": "haiku",  "fallback": "haiku",                     "provider": "echo" }
  }
}
JSON

# ---------------------------------------------------------------------------
# 1. Resolution — developer (model + fallback + effort asserted in NDJSON + meta)
# ---------------------------------------------------------------------------
echo "# 1. Resolution: developer"

_out="$(sim_spawn "$P1" developer F02 "$FIXTURE" 0)"
LOG_DEV="$(printf '%s' "$_out" | head -n1)"
META_DEV="$(printf '%s' "$_out" | tail -n1)"
NDJSON_DEV="$(cat "$LOG_DEV" 2>/dev/null)"

assert_contains "developer NDJSON model=sonnet"   "$NDJSON_DEV" '"model":"sonnet"'
assert_contains "developer NDJSON fallback=haiku" "$NDJSON_DEV" '"fallback":"haiku"'
assert_contains "developer NDJSON effort=medium"  "$NDJSON_DEV" '"effort":"medium"'
assert_eq       "developer meta model"            "sonnet" "$(sim_meta_field "$META_DEV" model)"
assert_eq       "developer meta fallback_model"   "haiku"  "$(sim_meta_field "$META_DEV" fallback_model)"
assert_eq       "developer meta provider"         "echo"   "$(sim_meta_field "$META_DEV" provider)"

# ---------------------------------------------------------------------------
# 2. Resolution — architect (boundary: no effort configured → empty in NDJSON)
# ---------------------------------------------------------------------------
echo "# 2. Resolution: architect (no effort)"

_out2="$(sim_spawn "$P1" architect F02 "$FIXTURE" 0)"
LOG_ARC="$(printf '%s' "$_out2" | head -n1)"
META_ARC="$(printf '%s' "$_out2" | tail -n1)"
NDJSON_ARC="$(cat "$LOG_ARC" 2>/dev/null)"

assert_contains "architect NDJSON model=opus"     "$NDJSON_ARC" '"model":"opus"'
assert_contains "architect NDJSON fallback=sonnet" "$NDJSON_ARC" '"fallback":"sonnet"'
assert_contains "architect NDJSON effort empty"   "$NDJSON_ARC" '"effort":""'
assert_eq       "architect meta model"            "opus"   "$(sim_meta_field "$META_ARC" model)"
assert_eq       "architect meta fallback_model"   "sonnet" "$(sim_meta_field "$META_ARC" fallback_model)"

# ---------------------------------------------------------------------------
# 3. Economy mode — developer resolves to economy tier (haiku)
# ---------------------------------------------------------------------------
echo "# 3. Economy: developer → haiku tier"

python3 - "$P1/didio.config.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
c['economy'] = True
with open(sys.argv[1], 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
PY

_out3="$(sim_spawn "$P1" developer F02 "$FIXTURE" 0)"
LOG_ECO="$(printf '%s' "$_out3" | head -n1)"
META_ECO="$(printf '%s' "$_out3" | tail -n1)"
NDJSON_ECO="$(cat "$LOG_ECO" 2>/dev/null)"

assert_contains "economy NDJSON model=haiku" "$NDJSON_ECO" '"model":"haiku"'
assert_eq       "economy meta model=haiku"   "haiku" "$(sim_meta_field "$META_ECO" model)"

# Reset economy flag for subsequent tests.
python3 - "$P1/didio.config.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    c = json.load(f)
c['economy'] = False
with open(sys.argv[1], 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
PY

# ---------------------------------------------------------------------------
# 4. Meta lifecycle — field completeness on the completed developer run
# ---------------------------------------------------------------------------
echo "# 4. Meta lifecycle: field completeness"

for _field in feature role task log exit_code finished_at; do
  _val="$(sim_meta_field "$META_DEV" "$_field")"
  if [[ -n "$_val" ]]; then
    echo "ok - meta field '$_field' present"
  else
    echo "FAIL - meta field '$_field' missing or empty"
    FAILURES=$((FAILURES + 1))
  fi
done
assert_eq "meta status=completed" "completed" "$(sim_meta_field "$META_DEV" status)"

if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$META_DEV" 2>/dev/null; then
  echo "ok - meta is valid JSON"
else
  echo "FAIL - meta is not valid JSON"
  FAILURES=$((FAILURES + 1))
fi

# ---------------------------------------------------------------------------
# 5. Failure path — ECHO_DRIVER_EXIT=1 → meta failed + propagated exit code
# ---------------------------------------------------------------------------
echo "# 5. Failure path: exit 1 → meta failed"

_out5="$(sim_spawn "$P1" developer F02 "$FIXTURE" 1)"
_rc5=$?
META_FAIL="$(printf '%s' "$_out5" | tail -n1)"

assert_eq       "failure: spawn exits non-zero"   "1"      "$_rc5"
assert_file_exists "failure: meta file created"   "$META_FAIL"
assert_eq       "failure: meta status=failed"     "failed" "$(sim_meta_field "$META_FAIL" status)"
assert_eq       "failure: meta exit_code=1"       "1"      "$(sim_meta_field "$META_FAIL" exit_code)"

# ---------------------------------------------------------------------------
echo ""
echo "---"
if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: all F02-sim-dispatch checks passed"
  exit 0
else
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi
