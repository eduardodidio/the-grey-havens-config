# Component E — Docs & guardrails

## ADRs (`docs/adr/`, sequential numbering after `0001-*`)

- **Multi-provider architecture ADR** — context (Claude-only coupling), decision
  (provider drivers behind `didio-spawn-agent.sh`, default `claude`, Codex as
  second provider via `codex exec`), consequences (backward compat, NDJSON schema
  divergence + normalization, no API path / no Python rewrite as non-goals).
- **Skill-compile model ADR** — neutral `skills/` source compiled to Claude
  (`.claude/commands` + `.claude/agents` + `agents/prompts`) and Codex
  (`~/.codex/prompts` + `AGENTS.md`); source-checked-in / outputs-generated
  decision; idempotency; wired into `sync-project`.

Use `docs/adr/0000-template.md` as the structure. In the framework repo these
live at `${DIDIO_HOME}/docs/adr/`; mirror the ADRs into the plan project's
`docs/adr/` too if that is the shipping repo.

## Diagrams (`docs/diagrams/`, MANDATORY — two minimum, per CLAUDE.md)

- `F01-architecture.mmd` — component/data-flow: config → config-lib provider
  resolution → spawn-agent → driver (claude|codex) → JSONL → normalizer →
  {meta/state.json, dashboard, error/rate-limit}; plus skills/ → compiler →
  {.claude/*, ~/.codex/*}.
- `F01-journey.mmd` — BPMN-style swimlanes (User / didio CLI / Provider CLI):
  author skill → compile-skills → set role provider → preflight validate →
  run-wave → driver dispatch → logs/dashboard, with the error branch
  (missing/unauthed provider binary → preflight abort).

Templates: `docs/diagrams/templates/{architecture.mmd,user-journey.mmd}`.

## README + CLAUDE.md (mandatory per CLAUDE.md doc rules)

- `README.md`: new section documenting multi-provider usage — how to set a role's
  `provider`, `didio compile-skills`, `didio providers`, and the Codex
  prerequisites (install/auth `codex`).
- `CLAUDE.md`: update the **Stack** line (no longer "100% Claude") and add the
  multi-provider note; keep the existing "Guardrails de Segurança" intact.

## Guardrails (apply to EVERY task)

From `CLAUDE.md` "Guardrails de Segurança": never `git add -A`/`git add .` (stage
file-by-file), never force push, never `--no-verify`, never rebase shared
branches, never `git reset --hard` over uncommitted work, never commit secrets,
no new dependencies without confirmation, confirm destructive ops. In PLAN_ONLY
mode no commits happen anyway — these bind the Developer wave later.
