# F02 — Wave 2 summary

**Status:** completed
**Tasks:** F02-T08, F02-T09
**Generated:** 2026-06-17T00:00:00Z

## Files touched
- `tests/F02-sim-dispatch.sh` (T08: per-role resolution model/fallback/effort in NDJSON+meta, economy-tier switch, meta lifecycle completeness, failure path exit→failed)
- `tests/F02-sim-parallel.sh` (T09: no-clobber 3-spawn sequential, parallel-safety 3-spawn concurrent, max_parallel/turbo logic, context isolation via env -i + probe driver)
- `tests/fixtures/F02-probe-driver.sh` (T09: instrumented stand-in that writes observed env var names as NDJSON — zero model spend)

## Decisions
- T09 used `env -i PATH HOME DIDIO_HOME` to simulate Wave-runner isolation without modifying spawn-agent itself; canary absence proven by probe-driver log inspection.
- T09's parallel scenario calls `didio-spawn-agent.sh` directly in subshells (not via `sim_spawn`) to avoid `sim_spawn`'s stdout-capture design conflicting with background jobs (`&`).
- T08's economy test mutates the temp config via `sys.argv`/heredoc python3 — consistent with the Wave 0/1 canonical safe-invocation pattern; no f-string interpolation of shell vars.

## Notes for next Wave
- T12 (F02-architecture.mmd) should depict the echo-driver/probe-driver branching in the simulation layer alongside the hardened config-lib → spawn-agent → driver pipeline from Wave 1.
- T13 (F02-journey.mmd) should include the economy-mode fork in the agent dispatch flow and the running→completed/failed meta lifecycle transitions proven in T08.
- Both sim test files are auto-discovered by `tests/run.sh` — Wave 3 (T12, T13) requires no runner edits.
- All Wave 2 scripts follow `set -uo pipefail` + shellcheck `--severity=error` policy established in Wave 0.
- The `assert_file_exists` call in T08's failure-path section uses `"${META_FAIL:-}"` — Wave 3 diagrams can treat meta creation as unconditional (both success and failure paths write a meta file).
