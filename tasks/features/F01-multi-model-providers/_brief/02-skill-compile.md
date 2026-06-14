# Component B — Unified skill management (authoring → compile)

## Today's skill surface (all Claude-native)

- `.claude/commands/*.md` — slash commands (e.g. `/create-feature`).
- `agents/prompts/*.md` — role prompts. Contain sentinels already substituted at
  spawn time: `{{USE_SECOND_BRAIN}}` (replaced by `didio-spawn-agent.sh` from
  `second_brain.enabled`) and `{{DIDIO_CHECKPOINT}}` (checkpoint block, see
  `agents/prompts/_checkpoint-block.md`).
- `.claude/agents/*.md` — subagent definitions.
- Roles: architect, developer, techlead, qa, readiness, tea, meeting-parser,
  t800 (Gandalf), t1000 (Saruman), narrative-designer.

`bin/didio-sync-project.sh` copies these into downstream projects via
`sync_dir` / `copy_if_missing` (sections: `.claude/agents/`, `.claude/commands/`,
root `agents/prompts/`, `agents/workflows/`). It is **idempotent and additive**
(never deletes, never overwrites beyond a template placeholder; merges
`settings.json` allow arrays; appends missing CLAUDE.md sections).

## Neutral didio skill format (to define in T03 / SPEC.md)

Source of truth: new dir `${DIDIO_HOME}/skills/`. One `.md` per skill with YAML
front-matter + body:

```markdown
---
name: create-feature
description: Run the full pipeline for a new feature
kind: command | role-prompt | subagent
targets: [claude, codex]          # which providers to emit for
role-bindings: [architect]        # optional: roles this skill binds to
---
<neutral body, may contain sentinels and provider-override blocks>
```

**Sentinels** (kept, already understood by the pipeline): `{{USE_SECOND_BRAIN}}`,
`{{DIDIO_CHECKPOINT}}`. The compiler leaves them intact (they are resolved later
at spawn time) UNLESS a target needs a literal swap.

**Provider-override blocks** — for the few places the two CLIs differ (command
invocation syntax, the two sentinels, file-path references like
`CLAUDE.md`↔`AGENTS.md`, `.claude/commands`↔`~/.codex/prompts`):

```markdown
<!-- didio:claude -->
...Claude-specific lines...
<!-- /didio:claude -->
<!-- didio:codex -->
...Codex-specific lines...
<!-- /didio:codex -->
```

Lines outside any override block are shared. When compiling for target X, blocks
for other targets are stripped; blocks for X are inlined (markers removed).

## Compiler: `didio compile-skills`

A new script `${DIDIO_HOME}/bin/didio-compile-skills.sh` (+ optional python
helper). Reads every file in `skills/` and emits, per `targets`:

- **Claude:** `kind: command` → `.claude/commands/<name>.md`;
  `kind: subagent` → `.claude/agents/<name>.md`; `kind: role-prompt` →
  `agents/prompts/<name>.md`.
- **Codex:** `kind: command`/`role-prompt` → `~/.codex/prompts/<name>.md`; role
  prompts + project instructions → an aggregated `AGENTS.md` (Codex's `CLAUDE.md`
  equivalent). Subagents have no Codex analogue → skip with a documented note.

Requirements: **idempotent** (re-run = no diff), deterministic ordering, dry-run
flag (`--dry-run`) mirroring `tests/F14-sync-dry-run.sh` style, and a header
comment in every generated file marking it GENERATED — do not edit.

## Source-checked-in vs generated (decision to document in ADR)

Likely: **source checked in (`skills/`), compiled outputs generated** and wired
into `didio sync-project` so downstream projects receive freshly compiled
artifacts. The migration task seeds `skills/` from the existing
`.claude/commands/*.md` + `agents/prompts/*.md` without behavior change (Claude
output must match today's files modulo the GENERATED header).
