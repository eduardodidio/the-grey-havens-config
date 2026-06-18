# Feature Workflow — The Grey Havens

## Pipeline

```
/create-feature
  ↓
Architect generates tasks
  - Minimal, independent tasks grouped in parallel Waves
  - Wave 0 reserved for setup/permissions
  - Each task includes: objective, impl details, acceptance criteria,
    test scenarios, diagrams
  ↓
didio run-wave <FXX> 0        # setup in parallel [global install command]
  ↓
didio run-wave <FXX> 1..N     # features in parallel [global install command]
  ↓
Developer implements each task in a clean bash (via didio spawn-agent)
  - Stack rules from CLAUDE.md
  - Tests mandatory (happy, edge, error, boundary)
  - Diagrams updated
  ↓
Tech Lead reviews
  - Architecture, code quality, test coverage, diagram accuracy
  - Rejects if gaps found
  ↓
QA validates
  - Runs full test suite
  - Fills missing test gaps
  - Exercises the feature for real (browser / curl / harness)
  - Diagrams reflect reality
```

## Orchestration — Repo vs. Global Install

**Wave execution** (`didio run-wave <FXX> <N> developer`) is provided by the
global `didio` CLI (`~/.claude-didio-config/`), NOT by scripts in this repo.

The repo contains:
- `bin/didio-spawn-agent.sh` — launches a single agent in a clean context
- `agents/prompts/*.md` — role-specific instructions
- `tasks/features/<FXX>-*/` — feature task manifests

The global install provides:
- `didio run-wave` — orchestrates parallel execution of tasks within a Wave
- `didio dashboard` — tracks Wave status
- Checkpoint/resume artifacts (`*.checkpoint.json`, `*.ckpt.at`) for resuming after failures
- Test gate enforcement (see below)

## Testing Gate

**No Wave advances without passing tests.**

Each Wave runs this sequence:
1. Execute all tasks in the Wave in parallel (via `didio run-wave`)
2. For each task, Developer runs the stack's test command (see `CLAUDE.md`)
3. If **any test fails**, the Wave halts and writes a checkpoint file
   (`<FXX>-<N>.checkpoint.json`). No subsequent Wave begins.
4. Human reviews the failure and either:
   - Fixes the task and resumes: `didio run-wave --resume <FXX> <N> developer`
   - Or developer re-runs the task directly in the repo (via `bash tests/run.sh`)
5. Once all tests pass, Wave N completes and Wave N+1 may start.

## Checkpoint / Resume Contract

The global `didio run-wave` command maintains:
- `<FXX>-<N>.checkpoint.json` — state of the Wave (tasks, status, exit codes)
- `<FXX>-<N>.ckpt.at` — timestamp of the checkpoint

If a Wave fails, humans can resume via:
```bash
didio run-wave --resume <FXX> <N> developer
```

This re-runs only the failed tasks, preserving the state of completed tasks.

## Diagram Gate

**No feature is complete without diagrams in sync with implementation.**

## Wave 0 Gate

**Wave 0 must front-load everything the later Waves need** (permissions,
dependencies, scaffolding) so Waves 1..N run unattended in parallel.
