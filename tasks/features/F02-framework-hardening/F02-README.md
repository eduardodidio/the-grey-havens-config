# Feature F02 — Revisão geral & hardening do framework claude-didio-config

**Status:** planned
**Owner:** @eduardodidio
**Mode:** PLAN_ONLY (Architect plan only — no execution)
**PRD / brief:** [`_brief/00-overview.md`](./_brief/00-overview.md) (sharded)

## Goal

Run a transversal review + remediation of the `claude-didio-config` framework
across four axes — **flow/orchestration (A)**, **agent models (B)**,
**agent-management simulation tests (C)**, and **security/best-practices
(D)** — turning every relevant finding into a fix with a verifiable
acceptance criterion. The headline hardening is closing the `python3 -c`
source-injection seams in `didio-config-lib.sh` and `didio-spawn-agent.sh`
(HIGH), while preserving the drivers' observable output (F01 AC3). Findings
are embedded in the tasks, prioritized high/medium/low — no standalone report.

## Architecture impact

- **Config/exec layer** — `bin/didio-config-lib.sh` (injection refactor),
  `bin/didio-spawn-agent.sh` (meta-header hardening), `drivers/*.sh` +
  `drivers/DRIVER_CONTRACT.md` (permission guardrails), `didio.config.json`
  (model review).
- **Test layer** — new `tests/run.sh` runner, `tests/lib/sim-harness.sh`,
  `tests/F02-*.sh` (injection, meta, guardrails, secrets, shellcheck, config
  validate, sim-dispatch, sim-parallel, docs-consistency).
- **Docs layer** — `agents/orchestrator.md`, `agents/workflows/feature-
  workflow.md`, `.claude/commands/create-feature.md` (flow reconciliation);
  `docs/diagrams/F02-architecture.mmd` + `F02-journey.mmd`; new ADR;
  `README.md` + `CLAUDE.md` (Build/Test/Run).

The real `didio` CLI (`~/.local/bin/didio` → `~/.claude-didio-config`) is
**out-of-repo, read-only reference**; all remediation lands in-repo.

## Waves

<!--
  didio run-wave parses these lines. Keep the format exactly:
  - **Wave <N>**: FXX-T01, FXX-T02, ...
-->

- **Wave 0**: F02-T01, F02-T02, F02-T03                       (test runner, shellcheck baseline, simulation harness — front-loaded setup)
- **Wave 1**: F02-T04, F02-T05, F02-T06, F02-T07, F02-T10, F02-T11   (remediations: injection D1/D2, meta D3, driver guardrails D4, secrets D5, flow docs A, model review B — all distinct files, parallel)
- **Wave 2**: F02-T08, F02-T09                                (simulation suite C: dispatch/resolution/meta/failure + parallelism/isolation)
- **Wave 3**: F02-T12, F02-T13                                (closeout: architecture diagram + ADR + README; journey diagram)

## Dependency graph

```
Wave 0 (no deps):  T01 (runner)   T02 (shellcheck)   T03 (sim-harness)

Wave 1 (no cross-deps; distinct files):
  T04 config-lib injection ── bin/didio-config-lib.sh
  T05 spawn meta hardening ── bin/didio-spawn-agent.sh
  T06 driver guardrails    ── drivers/*.sh + DRIVER_CONTRACT.md
  T07 secrets/.gitignore   ── .gitignore + tests/F02-secrets-scan.sh
  T10 flow docs (Axis A)   ── agents/**, .claude/commands/create-feature.md
  T11 model review (Axis B)── didio.config.json + tests/F02-config-validate.sh

Wave 2 (sim suite, needs harness + hardened code):
  T08 sim dispatch/resolution/meta/failure  <- T03, T04, T05
  T09 sim parallelism/isolation/no-clobber  <- T03, T05

Wave 3 (closeout, documents what shipped):
  T12 F02-architecture.mmd + ADR + README   <- T04..T11
  T13 F02-journey.mmd                        <- T04..T11
```

## Findings register (embedded in tasks, prioritized)

| ID | Finding | Severity | Task |
|----|---------|----------|------|
| D1/D2 | `python3 -c` injection in config-lib (`$value`/`$key`/`$role`/`$config`) | **HIGH** | T04 |
| D3 | spawn-agent meta-header heredoc unquoted JSON interpolation | MEDIUM | T05 |
| D4 | driver elevated-permission flags undocumented (`--dangerously-skip-permissions`, `--yolo`) | MEDIUM | T06 |
| D5 | secrets / `.gitignore` coverage proof | LOW–MED | T07 |
| D6 | shellcheck baseline / `set -euo` policy / CI absence | LOW | T02 (+ T12 doc) |
| A1 | `run-wave` doc drift (orchestration lives in global install) | MEDIUM | T10 |
| B1–B4 | model↔role↔cost fit, fallbacks, effort, parallel tiers | LOW–MED | T11 |
| C | missing agent-management simulation suite | MEDIUM | T03, T08, T09 |
| — | no real Build/Test/Run command | MEDIUM | T01 |

## Global acceptance criteria

- [ ] AC1: config-lib + spawn-agent pass data via `sys.argv`/env (no f-string
      into `python3 -c`); adversarial input handled; observable output
      unchanged; F01 tests still green (T04, T05).
- [ ] AC2: driver permission posture documented + guardrail test (T06).
- [ ] AC3: no secrets committed; `.gitignore` coverage proven by test (T07).
- [ ] AC4: `tests/run.sh` runs all suites; CLAUDE.md Build/Test/Run are real (T01).
- [ ] AC5: shellcheck baseline green or documented suppressions (T02).
- [ ] AC6: simulation suite passes (resolution, parallelism, meta/status,
      failure, isolation) via echo-driver (T08, T09).
- [ ] AC7: flow docs reconciled with real CLI; consistency test passes (T10).
- [ ] AC8: model review applied; `tests/F02-config-validate.sh` passes (T11).
- [ ] AC9: F02 diagrams + ADR + README note delivered (T12, T13).
- [ ] All tasks tested (happy/edge/error/boundary). Tech Lead + QA approved.
- [ ] Backward compatibility + CLAUDE.md guardrails respected throughout.

## Diagrams

- `docs/diagrams/F02-architecture.mmd` — owner: **F02-T12**
- `docs/diagrams/F02-journey.mmd` — owner: **F02-T13**
