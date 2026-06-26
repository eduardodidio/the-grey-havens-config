# Axis C — Agent-management simulation tests

## Current test surface (grounded)

- `tests/F01-spawn-dispatch.sh` — already covers, via `echo-driver`: dispatch
  to the resolved driver, NDJSON lands in log, `.meta.json` records provider
  + propagated exit code, unknown provider exits 2, non-zero driver exit →
  `status: failed`. **Do not duplicate these.**
- `tests/F01-{claude,codex}-driver.sh`, `tests/F01-docs-check.sh`.
- `bin/test_didio_events.py` — the only Python test (event normalization).
- `tests/fixtures/{claude-stream,codex-json}.jsonl`.

## Gap → new suite (must EXTEND, not repeat F01)

A suite that simulates agent **management** end-to-end with the deterministic
`echo-driver.sh` as stand-in, covering what F01 does not:

- **Resolution per role:** for each role, `model`/`fallback`/`effort`/
  `provider` resolved from config flow into the driver env (assert the
  echo-driver's canned NDLine reflects the configured values, including the
  `economy` switch).
- **Meta lifecycle:** `.meta.json` starts `running` then transitions to
  `completed`; fields (`feature`, `role`, `task`, `model`, `provider`,
  `exit_code`, `finished_at`) populated.
- **Failure path:** `ECHO_DRIVER_EXIT=1` → meta `status: failed`,
  `exit_code: 1`, spawn-agent exits non-zero.
- **Parallelism / no-clobber:** spawning several roles "as a Wave"
  concurrently produces distinct log + meta filenames (timestamp + task id),
  none overwritten.
- **Context isolation:** the driver receives ONLY the documented contract env
  vars (`DIDIO_*`); arbitrary parent-shell vars do not leak into the agent.

## Foundations dependency

This suite depends on the shared simulation harness + fixtures from Wave 0
(`tests/lib/sim-harness.sh`) and runs under the project test runner
(`tests/run.sh`) defined in Wave 0.

## Acceptance criteria (for the remediation tasks)

- New `tests/F02-sim-*.sh` pass under `bash tests/run.sh`, use only
  `echo-driver` (zero model spend), and are deterministic/repeatable.
- Each test prints TAP-ish `ok -`/`FAIL -` lines and exits non-zero on any
  failure (match F01 test style: `assert_eq`, `assert_contains`).
