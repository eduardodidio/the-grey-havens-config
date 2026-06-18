# F02 — Revisão geral & hardening do framework — Overview

**Mode:** PLAN_ONLY (Architect plans; Waves execute later).
**Type:** Transversal technical review + remediation (audit + fix).

## Problem statement

This repo **is** the `claude-didio-config` framework (multi-agent,
multi-provider; bash + Python 3). It orchestrates Architect → Developer →
TechLead → QA with optional gates (readiness, TEA) and meta-agents
(Gandalf=`t800`, Saruman=`t1000`). The user requested a general review
across four axes — **flow/orchestration, agent models, agent-management
simulation tests, and security/best-practices** — organized into the most
parallel Waves possible. This is an **audit + fix**: every relevant finding
becomes a remediation task with a *verifiable* acceptance criterion, not a
standalone report. Findings live embedded in the tasks, prioritized
(high/medium/low).

## Scope (the four axes)

- **A — Flow / orchestration:** pipeline + gates consistency between
  `orchestrator.md`, `feature-workflow.md`, `.claude/commands/*.md`, and the
  *real* `didio` CLI. Known drift: docs reference `didio run-wave`, but the
  repo only ships `bin/didio-spawn-agent.sh` (1 agent at a time) — Wave
  orchestration, checkpoint/resume, and the "no Wave advances without tests"
  gate actually live in the **global install** (`~/.claude-didio-config`),
  out of this repo. See `01-flow-orchestration.md`.
- **B — Agent models:** model↔role↔cost fit, fallback chains, `effort`,
  `economy`/`turbo`/`highlander`, `max_parallel`, `didio_recommend_parallel`.
  See `02-agent-models.md`.
- **C — Simulation tests:** an end-to-end suite that simulates agent
  *management* using the deterministic `echo-driver.sh` as stand-in
  (resolution per role, parallelism, meta/status transitions, failure path,
  context isolation). Also: define the project's real test runner. See
  `03-simulation-tests.md`.
- **D — Security + best practices:** `python3 -c` injection in
  `didio-config-lib.sh` / `didio-spawn-agent.sh` (HIGH), driver permission
  guardrails (`--dangerously-skip-permissions`, `--yolo`), secrets/`.gitignore`
  coverage, shellcheck, CI absence, `set -euo pipefail` consistency. See
  `04-security-hardening.md`.

Wave 0 front-loads shared setup (test runner, shellcheck baseline,
simulation harness/fixtures). See `05-foundations.md`.

## Constraints

- **Audit + fix:** each finding → remediation task with measurable AC.
- **Maximum parallelism:** independent tasks share a Wave; never two
  writers on the same file in the same Wave.
- **No behavior change** to drivers' observable output (F01 AC3 fidelity):
  the injection refactor must preserve byte-for-byte stdout/exit behavior.
- **No new dependencies** without explicit signalling (CLAUDE.md). The
  framework is bash + python3 only; `shellcheck` is already installed locally
  (`/opt/homebrew/bin/shellcheck`) and must be treated as optional in the
  runner (skip-with-note when absent, not a hard dep).
- Respect CLAUDE.md guardrails (git, infra, secrets; stage file-by-file).
- The real `didio` CLI (`~/.local/bin/didio` → `~/.claude-didio-config`) is
  **out of repo and read-only reference** — remediate in-repo files only.
- Produce/update `docs/diagrams/F02-architecture.mmd` + `F02-journey.mmd`,
  an ADR, and a README note (project gates).

## Global acceptance criteria (titles; detail in task files)

- AC1 — Injection closed: config-lib + spawn-agent pass data via
  `sys.argv`/env, never f-string into `python3 -c` source; adversarial input
  (quotes/newlines) is handled, observable output unchanged.
- AC2 — Driver permission guardrails documented and enforced.
- AC3 — No secrets committed; `.gitignore` proven to cover all log/meta
  artifacts.
- AC4 — Project test runner exists; `Build/Test/Run` in CLAUDE.md are real.
- AC5 — Shellcheck baseline green (or documented suppressions).
- AC6 — Agent-management simulation suite passes (resolution, parallelism,
  meta/status, failure path, isolation) via echo-driver.
- AC7 — Flow docs reconciled with the real CLI surface; drift documented.
- AC8 — Model↔role↔cost review applied; config validated by a test.
- AC9 — Diagrams (architecture + journey) + ADR + README note delivered.
