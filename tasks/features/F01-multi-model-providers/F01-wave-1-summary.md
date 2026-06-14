# F01 — Wave 1 summary

**Status:** partial
**Tasks:** F01-T04, F01-T05, F01-T06
**Generated:** 2026-06-13T00:00:00Z

## Files touched
- `drivers/claude-driver.sh` (T05: verbatim claude -p driver, executable, golden-flag comments)
- `tests/F01-claude-driver.sh` (T05: smoke test with stubbed claude — PASS, 9/9 checks)

## Decisions
- _none_ — only T05 has artifacts on disk.

## Test results
- `tests/F01-claude-driver.sh`: PASS (all 9 checks, AC3 golden-flag check passes)

## Notes for next Wave
- T04 (config-lib provider helpers: `didio_provider_for_role`, `didio_provider_bin`,
  `didio_provider_model_for_role` in `bin/didio-config-lib.sh`) — **not implemented**,
  `bin/` directory does not exist in this repo.
- T06 (skills/ neutral source migration + `skills/MIGRATION.md`) — **not implemented**,
  `skills/` directory does not exist in this repo (besides an unrelated
  `install-claude-didio-framework` entry).
- Wave 0 artifacts referenced by the wave-0 summary as "completed" are also
  missing from this repo: `drivers/DRIVER_CONTRACT.md`, `drivers/echo-driver.sh`,
  `skills/SPEC.md`, `skills/_example.md`, `tests/F01-config-schema.sh`,
  `tests/F01-driver-contract.sh`, `tests/F01-skill-spec.sh`. T07/T08 (Wave 2,
  depend on T04) and T09 (depends on T06) cannot proceed until T04 and T06 are
  (re-)implemented and Wave 0's missing artifacts are restored.
- `didio.config.json` does have the `providers` registry from T01
  (`{"claude": {"bin":"claude","default":true}, "codex": {"bin":"codex"}}`),
  so T04 can be built against it once started.
