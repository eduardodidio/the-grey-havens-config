#!/usr/bin/env bash
#
# codex-driver.sh — Codex CLI execution driver.
#
# Runs `codex exec` headless, consuming the driver contract env vars defined
# in drivers/DRIVER_CONTRACT.md (F01-T02): DIDIO_PROMPT, DIDIO_MODEL,
# DIDIO_FALLBACK, DIDIO_EFFORT, DIDIO_LOG_FILE, DIDIO_ROLE, DIDIO_FEATURE,
# DIDIO_TASK_ID.
#
# Equivalence map (see _brief/01-execution-provider-abstraction.md):
#   --json  ~ Claude --output-format stream-json --verbose
#   --yolo  ~ Claude --dangerously-skip-permissions (bypass approvals+sandbox)
#   --model ~ Claude --model
#
# Known gaps:
#   - DIDIO_FALLBACK is accepted for contract compatibility but unused:
#     Codex has no --fallback-model equivalent (single-model, no automatic
#     fallback).
#   - DIDIO_EFFORT is accepted for contract compatibility but unused: effort
#     is model/config-dependent in Codex, not a CLI flag.
#
# Event schema note: Codex's --json NDJSON event shapes differ from Claude's
# stream-json events; the normalizer (F01-T11) is responsible for mapping
# both into a common schema.
#
# The prompt is passed via stdin (not as a positional arg) because prompts
# may be large/multiline.
#
# Dry-run mode: when DIDIO_DRIVER_DRYRUN is set (non-empty), the driver
# prints the resolved command as NDJSON and exits 0 without invoking codex.
# Default (unset): normal behavior (no observable change to real invocation).

set -uo pipefail

# Build the command line for introspection and dry-run logging
CMD_PARTS=(
  codex exec
  --json
  --yolo
)
[[ -n "${DIDIO_MODEL:-}" ]] && CMD_PARTS+=(--model "$DIDIO_MODEL")

if [[ -n "${DIDIO_DRIVER_DRYRUN:-}" ]]; then
  # Dry-run: print the command and exit without invoking codex
  # (note: prompt passed via stdin not represented in command string)
  CMD_STR="${CMD_PARTS[*]}"
  printf '{"type":"system","subtype":"driver-dryrun","provider":"codex","command":"%s","prompt_size":%d}\n' \
    "${CMD_STR//\"/\\\"}" "${#DIDIO_PROMPT}" >> "$DIDIO_LOG_FILE"
  exit 0
fi

# Normal mode: invoke the command and capture exit code
set +e
codex exec \
  --json \
  --yolo \
  ${DIDIO_MODEL:+--model "$DIDIO_MODEL"} \
  - <<<"$DIDIO_PROMPT" \
  > "$DIDIO_LOG_FILE" 2>&1
EXIT_CODE=$?
set -e

exit $EXIT_CODE
