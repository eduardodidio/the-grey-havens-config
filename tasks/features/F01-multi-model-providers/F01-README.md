# Feature F01 — Multi-model evolution: Claude + Codex providers + unified skill management

**Status:** planned
**Owner:** @eduardodidio
**Mode:** PLAN_ONLY (Architect plan only — no execution)
**PRD / brief:** [`_brief/00-overview.md`](./_brief/00-overview.md)

## Goal

Evolve the Claude-only `claude-didio-config` framework into a multi-model
orchestration framework where each agent role runs on either Claude Code
(`claude -p`) or the OpenAI Codex CLI (`codex exec`), and where skills (slash
commands + role prompts) are authored once in a neutral `skills/` source and
compiled to each provider's native format — reusing ALL existing engineering
(Waves, spawn-agent, rate-limit, dashboard, JSONL, gates, retrospectives) with
**zero config changes required for existing Claude-only projects**.

## Architecture impact

- **Execution layer** — `bin/didio-spawn-agent.sh` (extract invocation),
  new `drivers/{claude,codex}-driver.sh`, `bin/didio-config-lib.sh` (provider
  helpers), `didio.config.json` + `templates/didio.config.json` (schema).
- **Skill layer** — new `skills/` neutral source, new
  `bin/didio-compile-skills.sh`, outputs to `.claude/commands`, `.claude/agents`,
  `agents/prompts`, `~/.codex/prompts`, `AGENTS.md`; wired into
  `bin/didio-sync-project.sh`.
- **Observability layer** — `.meta.json` (+`provider`), per-provider event
  normalizer feeding error-detection, rate-limit parsing, and the dashboard
  (`dashboard/src/...`).
- **CLI/UX** — `bin/didio` (new `compile-skills`, `providers` subcommands +
  help), preflight in `bin/didio-run-wave.sh`.
- **Docs** — `docs/adr/`, `docs/diagrams/F01-*.mmd`, `README.md`, `CLAUDE.md`.

Target repo for implementation: the framework install
`${DIDIO_HOME:-~/.claude-didio-config}` (project-local-first precedence applies
for `didio.config.json` and `bin/didio-config-lib.sh`). See
[`_brief/00-overview.md`](./_brief/00-overview.md).

## Waves

<!--
  didio run-wave parses these lines. Keep the format exactly:
  - **Wave <N>**: FXX-T01, FXX-T02, ...
-->

- **Wave 0**: F01-T01, F01-T02, F01-T03            (config schema, driver contract, skill-format spec — scaffolding/perms)
- **Wave 1**: F01-T04, F01-T05, F01-T06            (config-lib helpers, claude-driver extraction, skill source migration)
- **Wave 2**: F01-T07, F01-T08, F01-T09            (spawn-agent dispatch, codex-driver, compiler → Claude target)
- **Wave 3**: F01-T10, F01-T11, F01-T12, F01-T13   (compiler → Codex target, JSONL normalization, CLI subcommands, preflight)
- **Wave 4**: F01-T14, F01-T15, F01-T16, F01-T17   (wire compile into sync-project, ADRs, diagrams, README/CLAUDE)

## Dependency graph

```
T01 ─┬─> T04 ─┬─> T07 ─┬─> T11
     │        │        │
T02 ─┴─> T05 ─┴─> T08 ─┘
                 │
T03 ─┬─> T06 ───┴─> T09 ─┬─> T10 ─> T14
     │                   │
     └───────────────────┴─> T12 ─> T14
T04 ─> T13
T14,T15,T16,T17 (Wave 4 docs/integration)
```

## Global acceptance criteria

- [ ] AC1: a role set to `provider: codex` runs via `codex exec`, logging usable JSONL (T07, T08).
- [ ] AC2: a skill authored once in `skills/` compiles to BOTH `.claude/commands/` and `~/.codex/prompts/` with provider-correct syntax (T09, T10).
- [ ] AC3: existing Claude-only flow byte-for-byte unchanged when no provider is set (T05, T07 — regression test mandatory).
- [ ] AC4: dashboard / rate-limit / error-detection work for Codex runs, or degrade gracefully with a documented gap (T11).
- [ ] AC5: ADRs + diagrams + README + CLAUDE.md updated (T15, T16, T17).
- [ ] All tasks implemented and tested (happy/edge/error/boundary).
- [ ] Tech Lead approved; QA passed.
- [ ] Backward compatibility + `CLAUDE.md` guardrails respected throughout.

## Diagrams

- `docs/diagrams/F01-architecture.mmd` — owner: **F01-T16**
- `docs/diagrams/F01-journey.mmd` — owner: **F01-T16**
