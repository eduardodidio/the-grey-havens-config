#!/usr/bin/env bash
# tests/F02-spawn-meta.sh — verify that the initial .meta.json is produced via
# python3/json.dump and handles hostile inputs (quotes, newlines) safely.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=tests/lib/sim-harness.sh
source "$ROOT_DIR/tests/lib/sim-harness.sh"

FAILURES=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$ROOT_DIR/tests/fixtures/F02-task.md"

# ---------------------------------------------------------------------------
# Scenario 1: Happy path — normal spawn → meta has all expected fields,
# valid JSON at both write points, status transitions running→completed.
# ---------------------------------------------------------------------------
P1="$TMP/happy"
sim_make_project "$P1" developer

_out="$(sim_spawn "$P1" developer F02 "$FIXTURE" 0)"
META1="$(printf '%s' "$_out" | tail -n1)"

assert_file_exists "happy path: meta file created" "$META1"
python3 -m json.tool "$META1" >/dev/null 2>&1 \
  && echo "ok - happy path: meta is valid JSON" \
  || { echo "FAIL - happy path: meta is not valid JSON"; FAILURES=$((FAILURES+1)); }
assert_eq "happy path: status == completed" "completed"    "$(sim_meta_field "$META1" status)"
assert_eq "happy path: feature"             "F02"          "$(sim_meta_field "$META1" feature)"
assert_eq "happy path: role"                "developer"    "$(sim_meta_field "$META1" role)"
assert_eq "happy path: model"               "sim-model"    "$(sim_meta_field "$META1" model)"
assert_eq "happy path: fallback_model"      "sim-fallback" "$(sim_meta_field "$META1" fallback_model)"
assert_eq "happy path: provider"            "echo"         "$(sim_meta_field "$META1" provider)"

# ---------------------------------------------------------------------------
# Scenario 2: Edge case — task file path containing a double-quote (")
# → initial meta JSON must still be parseable; literal value preserved.
# ---------------------------------------------------------------------------
P2="$TMP/hostile-quote"
sim_make_project "$P2" developer

HOSTILE_QUOTE="$P2/F02-task-it\"s-hostile.md"
cp "$FIXTURE" "$HOSTILE_QUOTE"

SENTINEL2="$(mktemp "$P2/logs/agents/.sentinel.XXXXXX")"
( cd "$P2" && DIDIO_HOME="$P2" \
  bash "$P2/bin/didio-spawn-agent.sh" developer F02 "$HOSTILE_QUOTE" "" \
  >/dev/null 2>&1 ) || true
META2="$(find "$P2/logs/agents" -name "*.meta.json" -newer "$SENTINEL2" 2>/dev/null | head -n1)"
rm -f "$SENTINEL2"

if [[ -z "$META2" ]]; then
  echo "FAIL - hostile-quote: meta file not created"
  FAILURES=$((FAILURES+1))
else
  echo "ok - hostile-quote: meta file created"
  python3 -m json.tool "$META2" >/dev/null 2>&1 \
    && echo "ok - hostile-quote: meta is valid JSON despite quote in path" \
    || { echo "FAIL - hostile-quote: meta is not valid JSON (quote in path broke JSON)"; FAILURES=$((FAILURES+1)); }
  python3 - "$META2" <<'PY'
import sys, json
with open(sys.argv[1]) as f:
    m = json.load(f)
exit(0 if '"' in m.get("task_file", "") else 1)
PY
  if [[ $? -eq 0 ]]; then
    echo "ok - hostile-quote: literal quote preserved in task_file field"
  else
    echo "FAIL - hostile-quote: literal quote not preserved in task_file field"
    FAILURES=$((FAILURES+1))
  fi
fi

# ---------------------------------------------------------------------------
# Scenario 3: Edge case — task file path containing a newline
# → initial meta JSON must still be parseable; literal value preserved.
# ---------------------------------------------------------------------------
P3="$TMP/hostile-newline"
sim_make_project "$P3" developer

HOSTILE_NL="$(printf '%s/F02-task-new\nline.md' "$P3")"
cp "$FIXTURE" "$HOSTILE_NL"

SENTINEL3="$(mktemp "$P3/logs/agents/.sentinel.XXXXXX")"
( cd "$P3" && DIDIO_HOME="$P3" \
  bash "$P3/bin/didio-spawn-agent.sh" developer F02 "$HOSTILE_NL" "" \
  >/dev/null 2>&1 ) || true
# Use -print0 / read -d '' to handle embedded newlines in the filename.
META3=""
while IFS= read -r -d '' _f; do
  META3="$_f"
  break
done < <(find "$P3/logs/agents" -name "*.meta.json" -newer "$SENTINEL3" -print0 2>/dev/null)
rm -f "$SENTINEL3"

if [[ -z "$META3" ]]; then
  echo "FAIL - hostile-newline: meta file not created"
  FAILURES=$((FAILURES+1))
else
  echo "ok - hostile-newline: meta file created"
  python3 -m json.tool "$META3" >/dev/null 2>&1 \
    && echo "ok - hostile-newline: meta is valid JSON despite newline in path" \
    || { echo "FAIL - hostile-newline: meta is not valid JSON (newline broke JSON)"; FAILURES=$((FAILURES+1)); }
  python3 - "$META3" <<'PY'
import sys, json
with open(sys.argv[1]) as f:
    m = json.load(f)
exit(0 if '\n' in m.get("task_file", "") else 1)
PY
  if [[ $? -eq 0 ]]; then
    echo "ok - hostile-newline: literal newline preserved in task_file field"
  else
    echo "FAIL - hostile-newline: literal newline not preserved in task_file field"
    FAILURES=$((FAILURES+1))
  fi
fi

# ---------------------------------------------------------------------------
# Scenario 4: Error scenario — driver exits 1 → final meta status:failed,
# exit_code:1; initial header was already valid JSON.
# ---------------------------------------------------------------------------
P4="$TMP/failure"
sim_make_project "$P4" developer

_out4="$(sim_spawn "$P4" developer F02 "$FIXTURE" 1)"
_rc4=$?
META4="$(printf '%s' "$_out4" | tail -n1)"

assert_eq "failure: spawn-agent exits non-zero" "1" "$_rc4"
assert_file_exists "failure: meta file created" "$META4"
python3 -m json.tool "$META4" >/dev/null 2>&1 \
  && echo "ok - failure: final meta is valid JSON" \
  || { echo "FAIL - failure: final meta is not valid JSON"; FAILURES=$((FAILURES+1)); }
assert_eq "failure: meta status == failed"   "failed" "$(sim_meta_field "$META4" status)"
assert_eq "failure: meta exit_code == 1"     "1"      "$(sim_meta_field "$META4" exit_code)"

# ---------------------------------------------------------------------------
# Scenario 5: Boundary — empty model/fallback default to "default"/"none",
# provider string preserved.
# ---------------------------------------------------------------------------
P5="$TMP/boundary-defaults"
mkdir -p "$P5/bin" "$P5/drivers" "$P5/agents/prompts" "$P5/logs/agents"
cp "$ROOT_DIR/bin/didio-spawn-agent.sh" "$P5/bin/didio-spawn-agent.sh"
chmod +x "$P5/bin/didio-spawn-agent.sh"
cp "$ROOT_DIR/bin/didio-config-lib.sh" "$P5/bin/didio-config-lib.sh"
cp "$ROOT_DIR/drivers/echo-driver.sh" "$P5/drivers/echo-driver.sh"
chmod +x "$P5/drivers/echo-driver.sh"
printf '# developer role prompt (boundary)\n' > "$P5/agents/prompts/developer.md"
# No model/fallback keys — must default to "default"/"none"
cat > "$P5/didio.config.json" <<'JSON'
{
  "providers": { "echo": { "bin": "true" } },
  "models": {
    "developer": { "provider": "echo" }
  }
}
JSON

_out5="$(sim_spawn "$P5" developer F02 "$FIXTURE" 0)"
META5="$(printf '%s' "$_out5" | tail -n1)"

assert_file_exists "boundary-defaults: meta file created" "$META5"
python3 -m json.tool "$META5" >/dev/null 2>&1 \
  && echo "ok - boundary-defaults: meta is valid JSON" \
  || { echo "FAIL - boundary-defaults: meta is not valid JSON"; FAILURES=$((FAILURES+1)); }
assert_eq "boundary-defaults: model defaults to 'default'" "default" "$(sim_meta_field "$META5" model)"
assert_eq "boundary-defaults: fallback defaults to 'none'"  "none"    "$(sim_meta_field "$META5" fallback_model)"
assert_eq "boundary-defaults: provider preserved"           "echo"    "$(sim_meta_field "$META5" provider)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "---"
if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: all F02-spawn-meta checks passed"
  exit 0
else
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi
