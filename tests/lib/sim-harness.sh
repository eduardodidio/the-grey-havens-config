#!/usr/bin/env bash
# tests/lib/sim-harness.sh — sourceable simulation harness for F02 Axis C tests.
#
# SOURCE this file; do NOT execute it directly (unless running the self-smoke).
# Does NOT set -e or modify the caller's shell flags.
#
# Public API:
#   assert_eq          <desc> <expected> <actual>
#   assert_contains    <desc> <haystack> <needle>
#   assert_file_exists <desc> <path>
#   sim_make_project   <tmpdir> [role ...]   — scaffold isolated temp project
#   sim_spawn          <tmpdir> <role> <feature> <task-file> [exit_code]
#   sim_meta_field     <meta.json> <key>
#
# Counters:  FAILURES (incremented by assert_* failures)
#
# Self-smoke: bash tests/lib/sim-harness.sh

# Locate project root relative to THIS file (works when sourced or executed).
_SIM_HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Test counters — callers may pre-initialise FAILURES; harness won't reset it.
# ---------------------------------------------------------------------------
FAILURES="${FAILURES:-0}"

# ---------------------------------------------------------------------------
# Assertion helpers (TAP-ish output, matching F01 style)
# ---------------------------------------------------------------------------

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

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc"
    echo "  file not found: $path"
    FAILURES=$((FAILURES + 1))
  fi
}

# ---------------------------------------------------------------------------
# sim_meta_field <meta.json> <key>
# Read one field from a .meta.json file. Uses sys.argv — no f-string injection.
# ---------------------------------------------------------------------------
sim_meta_field() {
  local meta_file="$1" key="$2"
  python3 - "$meta_file" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        m = json.load(f)
    print(m.get(key, ''))
except Exception:
    pass
PY
}

# ---------------------------------------------------------------------------
# sim_make_project <tmpdir> [role ...]
#
# Scaffold a self-contained temp project that echo-dispatches successfully:
#   $tmpdir/bin/               — didio-spawn-agent.sh + didio-config-lib.sh
#   $tmpdir/drivers/           — echo-driver.sh
#   $tmpdir/agents/prompts/    — one minimal <role>.md per requested role
#   $tmpdir/logs/agents/       — empty; receive .jsonl + .meta.json on spawn
#   $tmpdir/didio.config.json  — all roles set "provider": "echo"
#
# Defaults to roles: architect developer techlead qa
# ---------------------------------------------------------------------------
sim_make_project() {
  local tmpdir="$1"
  shift
  local roles
  if [[ $# -gt 0 ]]; then
    roles=("$@")
  else
    roles=(architect developer techlead qa)
  fi

  mkdir -p \
    "$tmpdir/bin" \
    "$tmpdir/drivers" \
    "$tmpdir/agents/prompts" \
    "$tmpdir/logs/agents"

  cp "$_SIM_HARNESS_ROOT/bin/didio-spawn-agent.sh" "$tmpdir/bin/didio-spawn-agent.sh"
  chmod +x "$tmpdir/bin/didio-spawn-agent.sh"

  cp "$_SIM_HARNESS_ROOT/bin/didio-config-lib.sh" "$tmpdir/bin/didio-config-lib.sh"

  cp "$_SIM_HARNESS_ROOT/drivers/echo-driver.sh" "$tmpdir/drivers/echo-driver.sh"
  chmod +x "$tmpdir/drivers/echo-driver.sh"

  local role
  for role in "${roles[@]}"; do
    printf '# %s role prompt (sim)\n' "$role" > "$tmpdir/agents/prompts/${role}.md"
  done

  # Build models JSON: all listed roles use echo provider.
  local models_json="" sep=""
  for role in "${roles[@]}"; do
    models_json+="${sep}\"${role}\": { \"model\": \"sim-model\", \"fallback\": \"sim-fallback\", \"effort\": \"low\", \"provider\": \"echo\" }"
    sep=", "
  done

  printf '{\n  "providers": { "echo": { "bin": "true" } },\n  "models": { %s }\n}\n' \
    "$models_json" > "$tmpdir/didio.config.json"
}

# ---------------------------------------------------------------------------
# sim_spawn <tmpdir> <role> <feature> <task-file> [exit_code]
#
# Run didio-spawn-agent.sh inside an isolated project (cd to tmpdir so that
# PROJECT_ROOT resolves correctly, matching the F01 test idiom).
# Sets ECHO_DRIVER_EXIT to exit_code (default 0).
#
# Outputs two lines to stdout:
#   line 1 — absolute path to the .jsonl log  (empty if spawn failed early)
#   line 2 — absolute path to the .meta.json  (empty if spawn failed early)
#
# Returns the spawn-agent exit code.
# ---------------------------------------------------------------------------
sim_spawn() {
  local tmpdir="$1" role="$2" feature="$3" task_file="$4"
  local exit_code="${5:-0}"
  local spawn="$tmpdir/bin/didio-spawn-agent.sh"
  local task_id
  task_id="$(basename "$task_file" .md)"

  ( cd "$tmpdir" && \
    ECHO_DRIVER_EXIT="$exit_code" \
    DIDIO_HOME="$tmpdir" \
    bash "$spawn" "$role" "$feature" "$task_file" "" >/dev/null 2>&1 )
  local rc=$?

  local log_file=""
  log_file="$(ls -t "$tmpdir/logs/agents/${feature}-${role}-${task_id}-"*.jsonl 2>/dev/null | head -n1 || true)"
  local meta_file=""
  [[ -n "$log_file" ]] && meta_file="${log_file%.jsonl}.meta.json"

  printf '%s\n' "${log_file:-}" "${meta_file:-}"

  return $rc
}

# ---------------------------------------------------------------------------
# Self-smoke test (runs only when executed directly, not when sourced)
# Tests four scenarios; passes when FAILURES == 0.
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  FAILURES=0
  _SMOKE_TMP="$(mktemp -d)"
  trap 'rm -rf "$_SMOKE_TMP"' EXIT

  P1="$_SMOKE_TMP/main"        # happy path + error scenario + boundary
  P2="$_SMOKE_TMP/noprompt"    # missing role prompt edge case
  mkdir -p "$P1" "$P2"

  FIXTURE="$_SIM_HARNESS_ROOT/tests/fixtures/F02-task.md"
  TASK_B="$_SMOKE_TMP/F02-task-b.md"
  printf '# Minimal task B (boundary test)\n\n## Objective\nno-op\n' > "$TASK_B"

  # Scenario 1: happy path ---------------------------------------------------
  sim_make_project "$P1" developer

  _out="$(sim_spawn "$P1" developer F02 "$FIXTURE" 0)"
  LOG1="$(printf '%s' "$_out" | head -n1)"
  META1="$(printf '%s' "$_out" | tail -n1)"

  assert_file_exists "happy path: log file created" "$LOG1"
  assert_file_exists "happy path: meta file created" "$META1"
  assert_eq "happy path: meta status == completed" "completed" "$(sim_meta_field "$META1" status)"
  assert_contains "happy path: log contains echo-driver subtype" \
    "$(cat "$LOG1" 2>/dev/null)" '"subtype":"echo-driver"'

  # Scenario 2: missing role prompt -> spawn-agent exits 2 -------------------
  sim_make_project "$P2" developer  # no 'architect' prompt

  _out2="$(sim_spawn "$P2" architect F02 "$FIXTURE" 0)"
  _rc2=$?
  _log2="$(printf '%s' "$_out2" | head -n1)"

  assert_eq "missing prompt: spawn-agent exits 2" "2" "$_rc2"
  assert_eq "missing prompt: no log file produced" "" "$_log2"

  # Scenario 3: ECHO_DRIVER_EXIT=1 -> meta status failed ---------------------
  _out3="$(sim_spawn "$P1" developer F02 "$TASK_B" 1)"
  _rc3=$?
  META3="$(printf '%s' "$_out3" | tail -n1)"

  assert_eq "failure: spawn-agent exits non-zero" "1" "$_rc3"
  assert_file_exists "failure: meta file created" "$META3"
  assert_eq "failure: meta status == failed" "failed" "$(sim_meta_field "$META3" status)"
  assert_eq "failure: meta exit_code == 1" "1" "$(sim_meta_field "$META3" exit_code)"

  # Scenario 4: boundary — two spawns produce distinct log filenames ----------
  # Reuse P1; use two different task files so task-id differs (TS may be same second).
  _out4a="$(sim_spawn "$P1" developer F02 "$FIXTURE" 0)"
  _out4b="$(sim_spawn "$P1" developer F02 "$TASK_B" 0)"
  LOG4A="$(printf '%s' "$_out4a" | head -n1)"
  LOG4B="$(printf '%s' "$_out4b" | head -n1)"

  assert_file_exists "boundary: first spawn log exists" "$LOG4A"
  assert_file_exists "boundary: second spawn log exists" "$LOG4B"
  if [[ "$LOG4A" != "$LOG4B" ]]; then
    echo "ok - boundary: two spawns produce distinct log filenames"
  else
    echo "FAIL - boundary: both spawns wrote the same log file"
    FAILURES=$((FAILURES + 1))
  fi

  # Summary ------------------------------------------------------------------
  echo "---"
  if [[ $FAILURES -eq 0 ]]; then
    echo "PASS: all sim-harness smoke checks passed"
    exit 0
  else
    echo "FAIL: $FAILURES check(s) failed"
    exit 1
  fi

fi
