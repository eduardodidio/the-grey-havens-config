# Wave 0 — Foundations (shared setup, front-loaded)

These must exist before Axes A–D tasks so later Waves run unattended.

## Test runner (blocks Axis C, and the project's Build/Test/Run)

CLAUDE.md currently has placeholder `echo 'configure ... command'` for
Build/Test/Run. Define a real runner:

- `tests/run.sh` — discovers and runs every `tests/F0*-*.sh` and every
  Python test (`bin/test_*.py`, `tests/test_*.py`), prints a per-file pass/
  fail summary, exits non-zero if any fail. Dependency-free (bash + python3).
- New test files just need to match the glob — the runner is **not** edited
  by later test tasks (avoids single-writer conflicts).
- Wire CLAUDE.md: **Test:** `bash tests/run.sh`; **Build:** no-op/lint note;
  **Run:** `didio` CLI entry note.

## Shellcheck baseline (Axis D6)

- `tests/F02-shellcheck.sh` — runs `shellcheck` over `bin/*.sh`,
  `drivers/*.sh`, `tests/*.sh`. If `shellcheck` is absent, **skip with a
  clear note and exit 0** (optional dep — no new hard dependency). Record any
  accepted suppressions inline with justification.

## Simulation harness + fixtures (blocks Axis C)

- `tests/lib/sim-harness.sh` — sourceable helpers reused by `F02-sim-*.sh`:
  build an isolated temp `PROJECT_ROOT` (copy/symlink `bin/`, `drivers/`,
  `agents/prompts/`, a crafted `didio.config.json` whose roles use
  `provider: echo`), run `bin/didio-spawn-agent.sh`, and read back the
  produced `.jsonl` + `.meta.json`. Include `assert_eq`/`assert_contains`
  matching the F01 test style.
- `tests/fixtures/F02-*` — any minimal task files / configs the sim needs.

## Why Wave 0

Front-loading the runner + harness lets Axis A/B/C/D tasks run **in
parallel** in Waves 1–2 without re-deriving setup or prompting the user.
