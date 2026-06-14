# F01 — Multi-model evolution — Overview

## Problem statement

`claude-didio-config` is today 100% coupled to Claude Code (`claude -p`). Every
agent role (architect, developer, techlead, qa, readiness, tea, meeting-parser,
t800, t1000, narrative-designer) is launched by `didio-spawn-agent.sh` with a
hardcoded `claude -p ... --output-format stream-json ...` invocation, and every
downstream consumer of the resulting JSONL assumes Claude's stream-json schema.
We must evolve the framework into a **multi-model orchestration framework** where
each role is independently assignable to **Claude Code** or the **OpenAI Codex
CLI** (`codex exec`, headless), and where **skills** (slash commands + role
prompts) are authored once in a neutral source and compiled to each provider's
native format. This is an **incremental evolution that reuses ALL existing
engineering** (Waves, spawn-agent, rate-limit handling, dashboard, JSONL logs,
readiness/TEA gates, retrospectives) — not a rewrite.

## Implementation target (where the code lives)

The framework source of truth is the install dir `${DIDIO_HOME:-~/.claude-didio-config}`
(this is the "ground truth — already explored" referenced by the mission). All
`bin/`, `drivers/` (new), and `skills/` (new) work lands there. `didio.config.json`
and `bin/didio-config-lib.sh` have a **project-local-first** precedence:
`didio-spawn-agent.sh` sources `$PROJECT_ROOT/bin/didio-config-lib.sh` when present,
else the global install. Plan files (this directory) live in the downstream project
`/Users/eduardodidio/the-grey-havens-config`.

## High-level scope

- **A. Provider abstraction (execution)** — see `01-execution-provider-abstraction.md`
- **B. Unified skill management (authoring → compile)** — see `02-skill-compile.md`
- **C. CLI / UX / config surface** — see `03-cli-config-surface.md`
- **D. JSONL / event normalization (cross-cutting risk)** — see `04-jsonl-normalization.md`
- **E. Docs & guardrails** — see `05-docs-guardrails.md`

## Locked architecture decisions (do NOT re-open)

1. Second provider = **OpenAI Codex CLI** (`codex exec`, headless). Each role is
   assignable to a provider. Not API-direct.
2. Skill management = **single neutral source compiled to both** providers.
3. Execution layer = **provider adapter over the existing bash**. KEEP
   `didio-spawn-agent.sh`; extract the hardcoded `claude -p` into pluggable
   drivers (`claude-driver.sh`, `codex-driver.sh`). Do NOT rewrite orchestration
   in another language.

## Constraints

- **Backward compatibility is mandatory:** existing Claude-only projects keep
  working with **zero config changes** (default provider = `claude`). The
  Claude-only flow must be byte-for-byte unchanged when no provider is set.
- Respect `CLAUDE.md` "Guardrails de Segurança": stage file-by-file (never
  `git add -A`/`.`), no force push, no `--no-verify`, no rebase on shared
  branches, confirm destructive ops, never commit secrets, no new deps without
  confirmation.
- **Non-goals:** Codex-via-API path; rewriting orchestration in Python;
  providers beyond Claude + Codex.

## Acceptance criteria (titles — detail lives in component shards + task files)

1. A role set to `provider: codex` runs via `codex exec`, logging usable JSONL.
2. A skill authored once in `skills/` compiles to BOTH `.claude/commands/` and
   `~/.codex/prompts/` with provider-correct syntax.
3. Existing Claude-only flow byte-for-byte unchanged when no provider is set.
4. Dashboard / rate-limit / error-detection work for Codex runs (or degrade
   gracefully with a documented gap).
5. ADRs + diagrams + README + CLAUDE.md updated.

## Testing convention (from the framework repo)

- Integration/smoke tests are bash scripts under `tests/` named `FXX-*.sh`
  (e.g. `F14-commands-smoke.sh`, `F14-sync-dry-run.sh`, `F03-integration-test.sh`).
- Python units use `unittest` next to the file (e.g. `bin/test_didio_progress.py`,
  run with `python3 bin/test_didio_progress.py`).
- New tests for F01 live under `${DIDIO_HOME}/tests/F01-*.sh` (+ python units
  beside any new `.py`). Tests MUST avoid real network/CLI spend: stub `claude`
  and `codex` binaries on `PATH` (a fake script that echoes canned NDJSON) so the
  driver contract is exercised without invoking the real models.
