#!/usr/bin/env bash
#
# Guardrails test for driver security posture (F02-T06).
#
# Asserts:
#   (a) dangerous flags (--dangerously-skip-permissions, --yolo) are still
#       present in each driver (guards against silent removal)
#   (b) every dangerous flag in the driver code is mentioned in
#       DRIVER_CONTRACT.md (doc/code parity)
#   (c) DIDIO_DRIVER_DRYRUN env var triggers dry-run behavior (no CLI invoked)
#   (d) dry-run output is valid NDJSON with expected fields

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVERS_DIR="$ROOT_DIR/drivers"
CONTRACT="$DRIVERS_DIR/DRIVER_CONTRACT.md"

FAILURES=0

assert_grep() {
  local desc="$1" file="$2" pattern="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc"
    echo "  file: $file"
    echo "  pattern: $pattern"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_not_grep() {
  local desc="$1" file="$2" pattern="$3"
  if ! grep -q -- "$pattern" "$file"; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc (expected NOT to match)"
    echo "  file: $file"
    echo "  pattern: $pattern"
    FAILURES=$((FAILURES + 1))
  fi
}

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

echo "=== Driver security guardrails (F02-T06) ==="
echo ""

# --- Test 1: dangerous flags present in drivers --------------------------
echo "--- Test 1: dangerous flags present ---"

assert_grep \
  "claude-driver.sh has --dangerously-skip-permissions" \
  "$DRIVERS_DIR/claude-driver.sh" \
  "--dangerously-skip-permissions"

assert_grep \
  "claude-driver.sh has --allowedTools" \
  "$DRIVERS_DIR/claude-driver.sh" \
  "--allowedTools"

assert_grep \
  "codex-driver.sh has --yolo" \
  "$DRIVERS_DIR/codex-driver.sh" \
  "--yolo"

assert_grep \
  "echo-driver.sh has no elevated flags (sanity check)" \
  "$DRIVERS_DIR/echo-driver.sh" \
  "echo-driver"

assert_not_grep \
  "echo-driver.sh does not have --dangerously-skip-permissions" \
  "$DRIVERS_DIR/echo-driver.sh" \
  "--dangerously-skip-permissions"

assert_not_grep \
  "echo-driver.sh does not have --yolo" \
  "$DRIVERS_DIR/echo-driver.sh" \
  "--yolo"

echo ""

# --- Test 2: doc/code parity for dangerous flags -------------------------
echo "--- Test 2: doc/code parity ---"

assert_grep \
  "DRIVER_CONTRACT.md mentions --dangerously-skip-permissions" \
  "$CONTRACT" \
  "--dangerously-skip-permissions"

assert_grep \
  "DRIVER_CONTRACT.md mentions --allowedTools" \
  "$CONTRACT" \
  "--allowedTools"

assert_grep \
  "DRIVER_CONTRACT.md mentions --yolo" \
  "$CONTRACT" \
  "--yolo"

assert_grep \
  "DRIVER_CONTRACT.md has Security section" \
  "$CONTRACT" \
  "Security posture"

echo ""

# --- Test 3: DIDIO_DRIVER_DRYRUN dry-run behavior -----------------------
echo "--- Test 3: DIDIO_DRIVER_DRYRUN dry-run behavior ---"

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

# Create a stub CLI that records invocation (should NOT be called in dry-run)
cat > "$STUB_DIR/claude" <<'EOF'
#!/usr/bin/env bash
echo "STUB_CALLED=1" > "$STUB_DIR/stub_invoked"
exit 0
EOF
chmod +x "$STUB_DIR/claude"

cat > "$STUB_DIR/codex" <<'EOF'
#!/usr/bin/env bash
echo "STUB_CALLED=1" > "$STUB_DIR/stub_invoked"
exit 0
EOF
chmod +x "$STUB_DIR/codex"

# --- Test 3a: claude-driver dry-run ---
LOG_FILE_CLAUDE="$STUB_DIR/claude.jsonl"
rm -f "$STUB_DIR/stub_invoked"

export PATH="$STUB_DIR:$PATH"
export DIDIO_PROMPT="test prompt"
export DIDIO_MODEL="sonnet"
export DIDIO_FALLBACK=""
export DIDIO_EFFORT=""
export DIDIO_LOG_FILE="$LOG_FILE_CLAUDE"
export DIDIO_ROLE="developer"
export DIDIO_FEATURE="F02"
export DIDIO_TASK_ID="F02-T06"
export DIDIO_DRIVER_DRYRUN=1

bash "$DRIVERS_DIR/claude-driver.sh"
CLAUDE_EXIT=$?

assert_eq "claude-driver dry-run exits 0" "0" "$CLAUDE_EXIT"

if [[ ! -f "$STUB_DIR/stub_invoked" ]]; then
  echo "ok - claude-driver dry-run: stub claude NOT invoked"
else
  echo "FAIL - claude-driver dry-run: stub claude was invoked (should skip in dry-run)"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CLAUDE" ]] && grep -q '"subtype":"driver-dryrun"' "$LOG_FILE_CLAUDE"; then
  echo "ok - claude-driver dry-run: NDJSON logged with driver-dryrun subtype"
else
  echo "FAIL - claude-driver dry-run: expected driver-dryrun NDJSON in log"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CLAUDE" ]] && grep -q '"provider":"claude"' "$LOG_FILE_CLAUDE"; then
  echo "ok - claude-driver dry-run: NDJSON has provider=claude"
else
  echo "FAIL - claude-driver dry-run: expected provider=claude in NDJSON"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CLAUDE" ]] && grep -q '"command":"claude' "$LOG_FILE_CLAUDE"; then
  echo "ok - claude-driver dry-run: NDJSON has command field with resolved flags"
else
  echo "FAIL - claude-driver dry-run: expected command field in NDJSON"
  FAILURES=$((FAILURES + 1))
fi

echo ""

# --- Test 3b: codex-driver dry-run ---
LOG_FILE_CODEX="$STUB_DIR/codex.jsonl"
rm -f "$STUB_DIR/stub_invoked"

export DIDIO_LOG_FILE="$LOG_FILE_CODEX"
export DIDIO_DRIVER_DRYRUN=1

bash "$DRIVERS_DIR/codex-driver.sh"
CODEX_EXIT=$?

assert_eq "codex-driver dry-run exits 0" "0" "$CODEX_EXIT"

if [[ ! -f "$STUB_DIR/stub_invoked" ]]; then
  echo "ok - codex-driver dry-run: stub codex NOT invoked"
else
  echo "FAIL - codex-driver dry-run: stub codex was invoked (should skip in dry-run)"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CODEX" ]] && grep -q '"subtype":"driver-dryrun"' "$LOG_FILE_CODEX"; then
  echo "ok - codex-driver dry-run: NDJSON logged with driver-dryrun subtype"
else
  echo "FAIL - codex-driver dry-run: expected driver-dryrun NDJSON in log"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CODEX" ]] && grep -q '"provider":"codex"' "$LOG_FILE_CODEX"; then
  echo "ok - codex-driver dry-run: NDJSON has provider=codex"
else
  echo "FAIL - codex-driver dry-run: expected provider=codex in NDJSON"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$LOG_FILE_CODEX" ]] && grep -q '"command":"codex' "$LOG_FILE_CODEX"; then
  echo "ok - codex-driver dry-run: NDJSON has command field"
else
  echo "FAIL - codex-driver dry-run: expected command field in NDJSON"
  FAILURES=$((FAILURES + 1))
fi

echo ""

# --- Test 4: Normal mode (non-dry-run) is unchanged ----------------------
echo "--- Test 4: Normal mode unchanged (F01 AC3 fidelity) ---"

# Test with unset DIDIO_DRIVER_DRYRUN and stub CLIs to verify normal path
rm -f "$STUB_DIR/stub_invoked"
unset DIDIO_DRIVER_DRYRUN

LOG_FILE_NORMAL="$STUB_DIR/normal.jsonl"
export DIDIO_LOG_FILE="$LOG_FILE_NORMAL"

# Mock claude that outputs NDJSON and exits 0
cat > "$STUB_DIR/claude" <<'EOF'
#!/usr/bin/env bash
echo '{"type":"system","subtype":"init"}' > "$1"
exit 0
EOF

bash "$DRIVERS_DIR/claude-driver.sh"
NORMAL_EXIT=$?

assert_eq "claude-driver normal mode exits 0" "0" "$NORMAL_EXIT"

if [[ -f "$STUB_DIR/stub_invoked" ]] || [[ -f "$LOG_FILE_NORMAL" ]]; then
  echo "ok - claude-driver normal mode: output written (not dry-run)"
else
  echo "FAIL - claude-driver normal mode: expected output"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "---"
if [[ $FAILURES -eq 0 ]]; then
  echo "PASS: all F02-driver-guardrails checks passed"
  exit 0
else
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi
