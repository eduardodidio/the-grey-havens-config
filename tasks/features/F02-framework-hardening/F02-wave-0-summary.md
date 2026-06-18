# F02 — Wave 0 summary

**Status:** completed
**Tasks:** F02-T01, F02-T02, F02-T03
**Generated:** 2026-06-16T00:00:00Z

## Files touched
- `tests/run.sh` (T01: new glob-based runner; bash + python3 only; nullglob guard; per-file PASS/FAIL + summary)
- `CLAUDE.md` (T01: Build/Test/Run lines replaced with real commands)
- `tests/F02-shellcheck.sh` (T02: shellcheck baseline, --severity=error gate, skip if absent, detection probe)
- `tests/lib/sim-harness.sh` (T03: sourceable sim harness; assert_eq/contains/file_exists; sim_make_project/sim_spawn/sim_meta_field; self-smoke with 4 scenarios)
- `tests/fixtures/F02-task.md` (T03: minimal fixture task for simulation smoke tests)

## Decisions
- T02 placed `set -euo pipefail` policy in the shellcheck script header (not DRIVER_CONTRACT.md) to avoid collision with T06 (same-Wave single-writer rule).
- `sim_meta_field` in sim-harness uses `sys.argv` + heredoc, not f-string interpolation — sets the secure example for Wave 1 injection fixes (T04/T05).
- `sim_spawn` issues `cd "$tmpdir"` inside a subshell so PROJECT_ROOT resolves correctly, matching the F01 test idiom.

## Notes for next Wave
- Wave 1 tasks (T04–T11) touch entirely distinct files — no cross-task collision risk; all can run in parallel.
- T04/T05 (injection fixes) can reference `sim_meta_field`'s `sys.argv` pattern in sim-harness as the canonical safe example.
- `tests/run.sh` auto-discovers `tests/F0*-*.sh` — every new test file Wave 1 drops is picked up with zero runner edits.
- `shellcheck` gate uses `--severity=error`; warning-level findings are informational only — Wave 1 scripts should follow the same policy.
- Missing-prompt edge case (spawn-agent exits 2, no log written) is now proven by T03 self-smoke — Wave 2 simulation tests can rely on this contract.
