# CLAUDE.md

Project: **The Grey Havens**
Stack: **Blank / custom** — multi-provider (Claude Code + OpenAI Codex CLI)
Framework: [claude-didio-config](https://github.com/eduardodidio/claude-didio-config)

## Mission

Reference / dogfooding project for the
[claude-didio-config](https://github.com/eduardodidio/claude-didio-config)
framework. It exercises the framework's multi-provider orchestration
(Architect → Developer → TechLead → QA Waves, the `drivers/` execution layer,
and neutral skill-compile) end-to-end against a real codebase, and is the one
consumer project that carries a real shell test suite (`tests/run.sh`) as the
quality gate. Features here harden the framework itself rather than ship an
application: F01 (multi-provider, implemented upstream), F02 (security/test
hardening), F03 (test reconciliation), F04–F07 (review follow-ups). The repo
has no application stack — its product is a green, well-documented framework.

## Architecture

No stack assumptions. Edit CLAUDE.md and agents/prompts/*.md to match
your project conventions.

## Commands

- **Build:** `bash tests/F02-shellcheck.sh` (lint; no compiled artifact — skips gracefully if shellcheck absent)
- **Test:** `bash tests/run.sh`
- **Run:** `didio <subcommand>` (global install at `~/.local/bin/didio`)

## Agent Workflow

This project uses the **4-agent Waves workflow** from claude-didio-config:

1. **Architect** — plans minimal tasks grouped in parallel Waves.
   Wave 0 front-loads permissions/setup.
2. **Developer** — implements each task in a clean bash context.
3. **Tech Lead** — reviews architecture, tests, diagrams.
4. **QA** — validates end-to-end and fills test gaps.

All agents run via `didio spawn-agent <role>` in isolated bash processes.
Logs: `logs/agents/*.jsonl`. Dashboard: `didio dashboard` (phase 2).

### Trigger a feature

```
/create-feature F01 <short description of the feature>
```

See `agents/orchestrator.md` for the full pipeline and
`agents/workflows/feature-workflow.md` for the quality gates.

## Providers

Each agent role can run on **Claude Code** (default) or the **OpenAI Codex
CLI** (`codex exec`). Set `models.<role>.provider = "codex"` in
`didio.config.json` to switch a role; omit it to keep the Claude-only,
byte-for-byte-unchanged default. See the multi-provider section of
`README.md` for setup, the `didio compile-skills` / `didio providers`
commands, and documented gaps. Architecture decisions:
`docs/adr/0002-multi-provider-driver-architecture.md` and
`docs/adr/0003-neutral-skill-compile-model.md`. Diagrams:
`docs/diagrams/F01-architecture.mmd` and `docs/diagrams/F01-journey.mmd`.

## Project Layout

```
.
├── CLAUDE.md                    (this file)
├── docs/
│   ├── adr/                     Architecture Decision Records
│   ├── prd/                     Product Requirements Documents
│   ├── diagrams/                Mermaid flowcharts (live docs)
│   └── README.md                Docs index
├── tasks/
│   └── features/                Per-feature task manifests + task files
├── agents/
│   ├── orchestrator.md
│   ├── workflows/feature-workflow.md
│   └── prompts/                 Role prompts (architect, developer, techlead, qa)
├── logs/agents/                 Agent run logs (gitignored)
└── .claude/
    ├── settings.json            Claude Code settings
    ├── commands/                Slash commands (/create-feature, /dashboard, ...)
    └── agents/                  Subagent definitions
```

## Documentation Maintenance Rules

- **ADRs**: every significant architecture decision creates a new ADR under
  `docs/adr/`. Number them sequentially (`0001-*.md`, `0002-*.md`).
- **PRDs**: every feature has a PRD under `docs/prd/` before Architect runs.
- **Diagrams**: every feature MUST produce (or update) at least two Mermaid
  diagrams under `docs/diagrams/`:
  1. **Architecture** (`<FXX>-architecture.mmd`) — component / data-flow
  2. **User Journey** (`<FXX>-journey.mmd`) — BPMN-style user flow
  Diagrams are living documentation — keep them in sync with code.
- **README.md auto-update**: every feature that ships MUST update the
  project `README.md` with a short note of what was delivered (new
  endpoints, new views, new commands, changed behavior). This is not
  optional — if the feature doesn't change the README, either the README
  is stale or the feature shouldn't have shipped.

## Agent Learnings (Retrospective)

At the end of every feature, QA runs a retrospective ceremony and appends
lessons per role to `memory/agent-learnings/<role>.md`. Each agent reads
its own learnings file at the start of every run — the agents improve
with every feature that ships. Do NOT edit these files manually unless
you are clearly adding a durable lesson.

## Guardrails de Segurança

Regras que o Claude Code DEVE seguir neste projeto. Nenhuma exceção sem
confirmação explícita do usuário.

**Git**
- NUNCA rodar `git rebase` em branches compartilhadas (`main`, `master`,
  `develop`)
- NUNCA rodar `git push --force` ou `--force-with-lease` sem pedir
- NUNCA rodar `git reset --hard` sobre trabalho não commitado
- NUNCA usar `--no-verify` para pular hooks (pre-commit, pre-push)
- NUNCA usar `git add -A` ou `git add .` — stage arquivo por arquivo
- NUNCA commitar arquivos com segredos (`.env`, `credentials.*`, chaves
  privadas, tokens, `*.pem`, `*.key`)
- NUNCA amendar commits já pushados a uma branch compartilhada

**Código**
- NUNCA desabilitar validação, auth ou testes "só pra fazer funcionar"
- NUNCA hardcodear secrets — sempre variáveis de ambiente
- Validar input nas fronteiras do sistema (user input, APIs externas)
- Não introduzir dependências novas sem confirmação

**Infra / operações destrutivas**
- NUNCA modificar CI/CD sem confirmação explícita
- NUNCA rodar `rm -rf`, `DROP TABLE`, `kill -9` sem confirmar
- Mudanças em estado compartilhado (Slack, PRs, GitHub Issues,
  infraestrutura) exigem confirmação explícita antes de cada ação

**Quando em dúvida: pare e pergunte ao usuário.** O custo de uma pausa é
baixo; o custo de uma ação destrutiva não autorizada é alto.


