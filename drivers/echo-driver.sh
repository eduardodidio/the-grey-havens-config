#!/usr/bin/env bash
#
# echo-driver.sh — trivial test-fixture driver (F01-T02).
#
# Validates the driver contract (drivers/DRIVER_CONTRACT.md) without spending
# real model tokens: writes a canned NDJSON line carrying the contract env
# vars to $DIDIO_LOG_FILE, then exits with $ECHO_DRIVER_EXIT (default 0).

set -uo pipefail

printf '{"type":"system","subtype":"echo-driver","role":"%s","feature":"%s","task":"%s","model":"%s","fallback":"%s","effort":"%s"}\n' \
  "${DIDIO_ROLE:-}" "${DIDIO_FEATURE:-}" "${DIDIO_TASK_ID:-}" "${DIDIO_MODEL:-}" "${DIDIO_FALLBACK:-}" "${DIDIO_EFFORT:-}" \
  >> "${DIDIO_LOG_FILE:?DIDIO_LOG_FILE required}"

exit "${ECHO_DRIVER_EXIT:-0}"
