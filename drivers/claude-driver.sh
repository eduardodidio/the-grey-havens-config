#!/usr/bin/env bash
#
# claude-driver.sh — Claude Code execution driver.
#
# Reproduces today's `claude -p` invocation verbatim (see
# tasks/features/F01-multi-model-providers/_brief/01-execution-provider-abstraction.md,
# "Current invocation"). Consumes the driver contract env vars defined in
# drivers/DRIVER_CONTRACT.md (F01-T02): DIDIO_PROMPT, DIDIO_MODEL,
# DIDIO_FALLBACK, DIDIO_EFFORT, DIDIO_LOG_FILE, DIDIO_ROLE, DIDIO_FEATURE,
# DIDIO_TASK_ID.
#
# AC3 fidelity: this reproduces the CURRENT didio-spawn-agent.sh invocation
# byte-for-byte, which DOES pass --effort (when DIDIO_EFFORT is set) and
# --allowedTools. (The F01 plan was written against an older snapshot that
# lacked these flags; preserving today's real behavior is what AC3 requires.)
#
# Dry-run mode: when DIDIO_DRIVER_DRYRUN is set (non-empty), the driver
# prints the resolved command as NDJSON and exits 0 without invoking claude.
# Default (unset): normal behavior (no observable change to real invocation).

set -uo pipefail

# Build the command line for introspection and dry-run logging
CMD_PARTS=(
  claude
  -p "$DIDIO_PROMPT"
  --output-format stream-json
  --verbose
)
[[ -n "${DIDIO_MODEL:-}" ]] && CMD_PARTS+=(--model "$DIDIO_MODEL")
[[ -n "${DIDIO_FALLBACK:-}" ]] && CMD_PARTS+=(--fallback-model "$DIDIO_FALLBACK")
[[ -n "${DIDIO_EFFORT:-}" ]] && CMD_PARTS+=(--effort "$DIDIO_EFFORT")
CMD_PARTS+=(
  --dangerously-skip-permissions
  --allowedTools "Edit Write MultiEdit Read Bash Glob Grep"
)

if [[ -n "${DIDIO_DRIVER_DRYRUN:-}" ]]; then
  # Dry-run: print the command and exit without invoking claude
  CMD_STR="${CMD_PARTS[*]}"
  printf '{"type":"system","subtype":"driver-dryrun","provider":"claude","command":"%s"}\n' \
    "${CMD_STR//\"/\\\"}" >> "$DIDIO_LOG_FILE"
  exit 0
fi

# Normal mode: invoke the command and capture exit code
set +e
"${CMD_PARTS[@]}" > "$DIDIO_LOG_FILE" 2>&1
EXIT_CODE=$?
set -e

exit $EXIT_CODE
