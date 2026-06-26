# Axis A — Flow / Orchestration

## Current state (grounded)

- `bin/didio-spawn-agent.sh` is the only orchestration script **in this
  repo**: it launches exactly **one** agent, resolves model/provider via
  `didio-config-lib.sh`, writes `logs/agents/<F>-<role>-<task>-<ts>.jsonl`
  plus a `.meta.json` (status `running` → `completed`/`failed`), and exits
  with the driver's exit code.
- The **global install** `~/.claude-didio-config/bin/` ships the rest of the
  pipeline: `didio` (dispatcher), `didio-run-wave.sh`, `didio-dashboard.sh`,
  `didio-progress-lib.sh`, `didio-archive-feature.sh`, `didio-sync-*.sh`.
  `didio-run-wave.sh` is where Wave parallelism, the per-Wave test gate, and
  checkpoint/resume (`*.checkpoint.json`, `*.ckpt.at`) live.

## The drift (finding A1 — MEDIUM)

Repo docs reference subcommands the **repo** does not contain:

- `agents/orchestrator.md:21,24` → `didio run-wave <FXX> <N> developer`
- `agents/workflows/feature-workflow.md:14,16` → `didio run-wave <FXX> 0/1..N`
- `.claude/commands/create-feature.md:149` → `didio run-wave <FXX> <N> developer`
- `agents/prompts/developer.md:65` → "EXTRA prompt injected by run-wave.sh"
- `agents/prompts/t800.md:60,105` → `run-wave` as a launcher action

These are **real in the global CLI** but invisible from the repo, so a reader
of this repo cannot trace `run-wave` to any shipped code. Reconcile by
documenting *where* Wave orchestration lives (global install vs. repo) and
making every `didio <subcommand>` referenced in repo docs resolve to either
a repo script or an explicitly-noted global-install command.

## Gates to verify / document

- **Phase 0** meta-agents (Gandalf/Saruman) — disabled by default
  (`meta_agents.t800/t1000.enabled = false`).
- **Phase 1.5** readiness gate, **Phase 1.6** TEA gate (`tea.enabled = false`).
- **"No Wave advances without tests"** mandate (`orchestrator.md:92`).
- **Wave-failure handling** + checkpoint/resume contract.

## Acceptance criteria (for the remediation task)

- Every `didio <subcmd>` token in `agents/**` and `.claude/commands/**`
  either maps to a repo `bin/*` script or is annotated as
  "provided by the global `didio` install (`~/.claude-didio-config`)".
- A consistency test (`tests/F02-docs-consistency.sh`) enumerates the
  `didio` subcommands referenced in docs and asserts each is in a known
  allow-list (repo scripts ∪ documented global commands); unknown tokens fail.
- The checkpoint/resume + per-Wave test gate contract is documented in one
  place the repo owns (e.g. `feature-workflow.md`), citing the artifact names.
