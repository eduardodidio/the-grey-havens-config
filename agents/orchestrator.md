# Agent Orchestrator — The Grey Havens

Coordinates the 4 agents (Architect → Developer → TechLead → QA) for the
claude-didio-config framework.

## Architecture — Where orchestration lives

### Repo Scripts vs. Global Install

This repo ships **only** the agent launchers in `bin/`:
- `didio spawn-agent` (via `bin/didio-spawn-agent.sh`) — launches a single agent in a clean bash context
- `didio-config-lib.sh` — resolves model/provider for each role
- `didio-events-lib.py` — event normalizer (Claude vs. OpenAI drivers)

**Wave orchestration, checkpoint/resume, and gates live in the global `didio` CLI install** (`~/.claude-didio-config/bin/`):
- `didio run-wave <FXX> <N> <role>` — runs all tasks in a Wave in parallel, enforces test gate, writes checkpoint/resume artifacts
- `didio dashboard` — visual task status
- `didio compile-skills`, `didio providers`, `didio archive`, `didio sync` — framework utilities
- `didio t800` (Gandalf), `didio t1000` (Saruman) — meta-agents for strategic decision-making and governance

When docs reference `didio run-wave` or other global commands, they are **provided by the installed `didio` CLI**, not by scripts in this repo. This boundary is intentional: the repo is stateless; the global install handles state (checkpoint files, dashboards, logs).

## Core principle

**Every agent runs in a new, clean bash process via `didio spawn-agent`.**
No agent inherits the context of the orchestrator. This is intentional:
each role reads *only* the task file and the project state, which makes
their output reproducible and auditable (via `logs/agents/*.jsonl`).

## Flow

```
/create-feature "<description>"
  ↓
1. Architect   — didio spawn-agent architect <FXX> <feature-description>
                 Produces tasks/features/<FXX>-*/ with Waves manifest
  ↓
2. Wave 0      — didio run-wave <FXX> 0 developer
                 Setup, permissions, scaffolding (front-loaded)
  ↓
3. Waves 1..N  — didio run-wave <FXX> <N> developer     (in order; within each Wave, tasks in parallel)
  ↓
4. Tech Lead   — didio spawn-agent techlead <FXX> tasks/features/<FXX>-*/<FXX>-README.md
  ↓
5. QA          — didio spawn-agent qa <FXX> tasks/features/<FXX>-*/<FXX>-README.md
```

## Meta-Agent Layer (opt-in)

Above the standard pipeline sit two meta-agents that provide strategic
decision-making and governance:

> **Name ↔ identifier map:** the display names **Gandalf** and **Saruman**
> map to the stable internal identifiers `t800` and `t1000` respectively —
> used for config keys (`meta_agents.t800`), CLI subcommands (`didio t800`),
> role prompts (`agents/prompts/t800.md`) and filenames. The rename is
> display-only; identifiers are unchanged.

```
User -> Gandalf (decision) -> Saruman (governance) -> Pipeline
                                                      |
                                        Architect -> Waves -> TechLead -> QA
```

### Gandalf — Strategic Orchestrator

- **Role:** Takes strategic decisions (feature priority, sequencing,
  go/no-go on quality gates, block resolution)
- **Output:** Decision records in `logs/decisions/D-YYYYMMDD-NNN.json`
- **Must always** consider 2+ options with pros/cons before deciding
- **Does NOT** execute the pipeline — only decides what should be done
- **Config:** `meta_agents.t800.enabled` (default: `false`)
- **Models:** `models.t800` (default: Opus/Sonnet)

### Saruman — Governance Reviewer

- **Role:** Independent reviewer with fresh eyes — catches blind spots
  and cognitive biases in Gandalf decisions
- **Output:** Governance reports in `logs/governance/G-<decision-id>.json`
- **Reading restricted to:** decision records, CLAUDE.md, didio.config.json
- **Verdicts:** `agree` (proceed) | `challenge` (re-evaluate, max 1 round) |
  `escalate` (block pipeline, notify human)
- **Bias checklist:** sunk cost, anchoring, scope creep, optimism, recency
- **Config:** `meta_agents.t1000.enabled` (default: `false`)

### Decision Flow

1. Gandalf receives request -> analyzes options -> writes decision record
2. Saruman reads ONLY the decision record -> emits verdict
3. If `agree`: pipeline executes as decided
4. If `challenge`: Gandalf re-evaluates (max 1 round)
5. If `escalate`: pipeline blocked, user notified
6. Pipeline executes normally per the approved decision

Both meta-agents are **disabled by default** for backward compatibility.
Enable via `didio.config.json`:

```json
{
  "meta_agents": {
    "t800": { "enabled": true, "auto_governance": true },
    "t1000": { "enabled": true }
  }
}
```

## Mandates

- **Testing** — every Wave ends only when the stack's test command passes
- **Diagrams** — every feature ends with diagrams in sync with code
- **Logs** — every agent invocation leaves a `logs/agents/*.jsonl` + `*.meta.json`
- **Clean context** — never reuse an agent across tasks; always spawn anew
