#!/usr/bin/env bash
# tests/F02-sim-parallel.sh — Axis C simulation: parallelism, no-clobber, and
# context isolation (F02-T09, AC6).
#
# Test suite:
#   1. No-clobber: 3 sequential spawns with distinct (role, task) combos →
#      3 distinct log + meta files; each contains its own role.
#   2. Parallel safety: same 3 combos spawned concurrently (& + wait) →
#      all 3 log + meta files produced; all valid JSON; all status=completed.
#   3. max_parallel / recommend_parallel: config value respected; turbo → 0;
#      sonnet tier string correct.
#   4. Context isolation: LEAK_CANARY exported in parent is absent from the
#      probe driver's observed env when spawn-agent is invoked via env -i;
#      DIDIO_* contract vars and PATH are present.
#
# No model tokens spent — echo-driver (scenarios 1-2) and
# tests/fixtures/F02-probe-driver.sh (scenario 4).

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=tests/lib/sim-harness.sh
source "$ROOT_DIR/tests/lib/sim-harness.sh"

FAILURES=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$ROOT_DIR/tests/fixtures/F02-task.md"

# Three task files with distinct basenames so TASK_ID differs regardless of
# same-second timestamp when spawning concurrently.
TASK_A="$TMP/F02-task-architect.md"
TASK_B="$TMP/F02-task-developer.md"
TASK_C="$TMP/F02-task-techlead.md"
cp "$FIXTURE" "$TASK_A"
cp "$FIXTURE" "$TASK_B"
cp "$FIXTURE" "$TASK_C"

# ---------------------------------------------------------------------------
# Scenario 1: No-clobber — 3 sequential spawns, distinct (role, task) combos
# ---------------------------------------------------------------------------
echo "=== Scenario 1: no-clobber (sequential) ==="

P_SEQ="$TMP/noclobber"
sim_make_project "$P_SEQ" architect developer techlead

_outA="$(sim_spawn "$P_SEQ" architect F02 "$TASK_A" 0)"
_outB="$(sim_spawn "$P_SEQ" developer F02 "$TASK_B" 0)"
_outC="$(sim_spawn "$P_SEQ" techlead  F02 "$TASK_C" 0)"

LOG_A="$(printf '%s' "$_outA" | head -n1)"
LOG_B="$(printf '%s' "$_outB" | head -n1)"
LOG_C="$(printf '%s' "$_outC" | head -n1)"
META_A="$(printf '%s' "$_outA" | tail -n1)"
META_B="$(printf '%s' "$_outB" | tail -n1)"
META_C="$(printf '%s' "$_outC" | tail -n1)"

assert_file_exists "no-clobber: architect log" "$LOG_A"
assert_file_exists "no-clobber: developer log" "$LOG_B"
assert_file_exists "no-clobber: techlead log"  "$LOG_C"
assert_file_exists "no-clobber: architect meta" "$META_A"
assert_file_exists "no-clobber: developer meta" "$META_B"
assert_file_exists "no-clobber: techlead meta"  "$META_C"

# All 3 log paths must be distinct (no file was clobbered/overwritten).
if [[ "$LOG_A" != "$LOG_B" && "$LOG_B" != "$LOG_C" && "$LOG_A" != "$LOG_C" ]]; then
  echo "ok - no-clobber: all 3 log paths are distinct"
else
  echo "FAIL - no-clobber: log path collision detected"
  FAILURES=$((FAILURES + 1))
fi

# Count == 3 (collision detection: if two spawns wrote to the same file, count
# would be < 3 — the spawns appear to succeed but the data is overwritten).
_seq_log_count=0
while IFS= read -r _; do
  _seq_log_count=$((_seq_log_count + 1))
done < <(find "$P_SEQ/logs/agents" -name "*.jsonl" 2>/dev/null)
assert_eq "no-clobber: exactly 3 log files on disk" "3" "$_seq_log_count"

_seq_meta_count=0
while IFS= read -r _; do
  _seq_meta_count=$((_seq_meta_count + 1))
done < <(find "$P_SEQ/logs/agents" -name "*.meta.json" 2>/dev/null)
assert_eq "no-clobber: exactly 3 meta files on disk" "3" "$_seq_meta_count"

# Each log must carry its own role marker (echoed by echo-driver).
assert_contains "no-clobber: architect log has role" \
  "$(cat "$LOG_A" 2>/dev/null)" '"role":"architect"'
assert_contains "no-clobber: developer log has role" \
  "$(cat "$LOG_B" 2>/dev/null)" '"role":"developer"'
assert_contains "no-clobber: techlead log has role" \
  "$(cat "$LOG_C" 2>/dev/null)" '"role":"techlead"'

# ---------------------------------------------------------------------------
# Scenario 2: Parallel safety — 3 concurrent spawns (& + wait)
# ---------------------------------------------------------------------------
echo "=== Scenario 2: parallel safety (concurrent) ==="

P_PAR="$TMP/parallel"
sim_make_project "$P_PAR" architect developer techlead

(
  cd "$P_PAR"
  ECHO_DRIVER_EXIT=0 DIDIO_HOME="$P_PAR" \
    bash "$P_PAR/bin/didio-spawn-agent.sh" architect F02 "$TASK_A" "" \
    >/dev/null 2>&1
) &
(
  cd "$P_PAR"
  ECHO_DRIVER_EXIT=0 DIDIO_HOME="$P_PAR" \
    bash "$P_PAR/bin/didio-spawn-agent.sh" developer F02 "$TASK_B" "" \
    >/dev/null 2>&1
) &
(
  cd "$P_PAR"
  ECHO_DRIVER_EXIT=0 DIDIO_HOME="$P_PAR" \
    bash "$P_PAR/bin/didio-spawn-agent.sh" techlead  F02 "$TASK_C" "" \
    >/dev/null 2>&1
) &
wait

_par_log_count=0
while IFS= read -r _; do
  _par_log_count=$((_par_log_count + 1))
done < <(find "$P_PAR/logs/agents" -name "*.jsonl" 2>/dev/null)
assert_eq "parallel: exactly 3 log files produced" "3" "$_par_log_count"

_par_meta_count=0
while IFS= read -r _; do
  _par_meta_count=$((_par_meta_count + 1))
done < <(find "$P_PAR/logs/agents" -name "*.meta.json" 2>/dev/null)
assert_eq "parallel: exactly 3 meta files produced" "3" "$_par_meta_count"

# All meta files must be valid JSON with status=completed.
_par_invalid=0
while IFS= read -r _m; do
  python3 -m json.tool "$_m" >/dev/null 2>&1 || _par_invalid=$((_par_invalid + 1))
done < <(find "$P_PAR/logs/agents" -name "*.meta.json" 2>/dev/null)
assert_eq "parallel: all meta files are valid JSON" "0" "$_par_invalid"

_par_bad_status=0
while IFS= read -r _m; do
  _st="$(sim_meta_field "$_m" status)"
  [[ "$_st" == "completed" ]] || _par_bad_status=$((_par_bad_status + 1))
done < <(find "$P_PAR/logs/agents" -name "*.meta.json" 2>/dev/null)
assert_eq "parallel: all meta files status=completed" "0" "$_par_bad_status"

# ---------------------------------------------------------------------------
# Scenario 3: max_parallel / recommend_parallel
# ---------------------------------------------------------------------------
echo "=== Scenario 3: max_parallel / recommend_parallel ==="

# Use a subshell to avoid mutating PROJECT_ROOT in the calling shell.
# Source config-lib inside the subshell so its functions see the local PROJECT_ROOT.

# 3a: max_parallel returns the configured value when turbo=false.
P_MP="$TMP/max-parallel"
mkdir -p "$P_MP"
printf '{"max_parallel": 4, "turbo": false}\n' > "$P_MP/didio.config.json"
_mp_result="$(
  export PROJECT_ROOT="$P_MP"
  # shellcheck source=bin/didio-config-lib.sh
  source "$ROOT_DIR/bin/didio-config-lib.sh"
  didio_max_parallel
)"
assert_eq "max_parallel: returns configured value (4)" "4" "$_mp_result"

# 3b: turbo=true overrides max_parallel to 0 (unlimited).
P_TURBO="$TMP/turbo"
mkdir -p "$P_TURBO"
printf '{"max_parallel": 4, "turbo": true}\n' > "$P_TURBO/didio.config.json"
_turbo_result="$(
  export PROJECT_ROOT="$P_TURBO"
  # shellcheck source=bin/didio-config-lib.sh
  source "$ROOT_DIR/bin/didio-config-lib.sh"
  didio_max_parallel
)"
assert_eq "max_parallel: turbo=true returns 0 (unlimited)" "0" "$_turbo_result"

# 3c/3d: recommend_parallel — sourced config-lib already in scope.
# shellcheck source=bin/didio-config-lib.sh
source "$ROOT_DIR/bin/didio-config-lib.sh"
assert_eq "recommend_parallel: sonnet tier" \
  "5-8 (equilibrio custo/qualidade)" \
  "$(didio_recommend_parallel sonnet)"
assert_eq "recommend_parallel: opus tier" \
  "3-4 (modelo pesado, alto custo)" \
  "$(didio_recommend_parallel opus)"

# ---------------------------------------------------------------------------
# Scenario 4: Context isolation
# ---------------------------------------------------------------------------
echo "=== Scenario 4: context isolation ==="

# Build a project that routes "developer" through the probe driver.
P_ISO="$TMP/isolation"
mkdir -p "$P_ISO/bin" "$P_ISO/drivers" "$P_ISO/agents/prompts" "$P_ISO/logs/agents"
cp "$ROOT_DIR/bin/didio-spawn-agent.sh" "$P_ISO/bin/didio-spawn-agent.sh"
chmod +x "$P_ISO/bin/didio-spawn-agent.sh"
cp "$ROOT_DIR/bin/didio-config-lib.sh" "$P_ISO/bin/didio-config-lib.sh"
cp "$ROOT_DIR/tests/fixtures/F02-probe-driver.sh" "$P_ISO/drivers/probe-driver.sh"
chmod +x "$P_ISO/drivers/probe-driver.sh"
printf '# developer role prompt (isolation sim)\n' \
  > "$P_ISO/agents/prompts/developer.md"
cat > "$P_ISO/didio.config.json" <<'JSON'
{
  "providers": { "probe": { "bin": "true" } },
  "models": {
    "developer": {
      "model": "probe-model",
      "fallback": "probe-fallback",
      "effort": "low",
      "provider": "probe"
    }
  }
}
JSON

TASK_ISO="$TMP/F02-task-isolation.md"
cp "$FIXTURE" "$TASK_ISO"

# Export canary so it exists in the parent environment — the test below must
# prove it doesn't reach the driver when spawn-agent is invoked cleanly.
export LEAK_CANARY=should_not_appear

ISO_SENTINEL="$(mktemp "$P_ISO/logs/agents/.sentinel.XXXXXX")"

# env -i simulates how the Wave runner invokes spawn-agent in isolation: only
# PATH and DIDIO_HOME (plus HOME for python3 stdlib access) are forwarded.
# LEAK_CANARY is stripped here; spawn-agent then exports only DIDIO_* to the
# probe driver, which observes and logs its full environment.
(
  cd "$P_ISO"
  env -i PATH="$PATH" HOME="${HOME:-}" DIDIO_HOME="$P_ISO" \
    bash "$P_ISO/bin/didio-spawn-agent.sh" developer F02 "$TASK_ISO" "" \
    >/dev/null 2>&1
) || true

ISO_LOG="$(find "$P_ISO/logs/agents" -name "*.jsonl" \
  -newer "$ISO_SENTINEL" 2>/dev/null | head -n1 || true)"
rm -f "$ISO_SENTINEL"

assert_file_exists "isolation: probe driver produced a log" "${ISO_LOG:-}"

if [[ -n "$ISO_LOG" ]]; then
  # LEAK_CANARY must be absent.
  python3 - "$ISO_LOG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("subtype") == "probe-driver":
            sys.exit(1 if "LEAK_CANARY" in entry.get("env_keys", []) else 0)
sys.exit(0)
PY
  if [[ $? -eq 0 ]]; then
    echo "ok - isolation: LEAK_CANARY absent from driver env"
  else
    echo "FAIL - isolation: LEAK_CANARY leaked into driver env"
    FAILURES=$((FAILURES + 1))
  fi

  # PATH must be present (inherited per contract).
  python3 - "$ISO_LOG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("subtype") == "probe-driver":
            sys.exit(0 if "PATH" in entry.get("env_keys", []) else 1)
sys.exit(1)
PY
  if [[ $? -eq 0 ]]; then
    echo "ok - isolation: PATH present in driver env (inherited per contract)"
  else
    echo "FAIL - isolation: PATH missing from driver env"
    FAILURES=$((FAILURES + 1))
  fi

  # At least one DIDIO_* var must be present.
  python3 - "$ISO_LOG" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("subtype") == "probe-driver":
            keys = entry.get("env_keys", [])
            sys.exit(0 if any(k.startswith("DIDIO_") for k in keys) else 1)
sys.exit(1)
PY
  if [[ $? -eq 0 ]]; then
    echo "ok - isolation: DIDIO_* contract vars present in driver env"
  else
    echo "FAIL - isolation: no DIDIO_* vars found in driver env"
    FAILURES=$((FAILURES + 1))
  fi
fi

unset LEAK_CANARY

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "---"
if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: all F02-sim-parallel checks passed"
  exit 0
else
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi
