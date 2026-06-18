# Readiness Report — F02 framework-hardening

**Generated:** 2026-06-16T00:00:00Z
**Feature dir:** tasks/features/F02-framework-hardening/
**Total tasks audited:** 13 (T01–T13)
**Total ACs declared:** 9 (AC1–AC9)

> **Re-run note:** This report supersedes the prior run. The previous report
> incorrectly reported FAILs on Checks 1, 2, and 5 because the task files
> were not readable at generation time. All task files now exist and have been
> read; the findings below reflect the actual plan state.

---

## Check 1 — AC coverage (every AC has ≥1 task)

AC IDs parsed from `## Global acceptance criteria` in F02-README.md
(format `- [ ] ACN:`). Coverage determined from the `**Maps to AC:**` field
in each task header.

| AC ID | Status | Tasks covering | Detail |
|-------|--------|----------------|--------|
| AC1   | PASS   | T04, T05       |        |
| AC2   | PASS   | T06            |        |
| AC3   | PASS   | T07            |        |
| AC4   | PASS   | T01            |        |
| AC5   | PASS   | T02            |        |
| AC6   | PASS   | T03, T08, T09  |        |
| AC7   | PASS   | T10            |        |
| AC8   | PASS   | T11            |        |
| AC9   | PASS   | T12, T13       |        |

---

## Check 2 — Bidirectional traceability (every task cites ≥1 AC)

| Task | Status | ACs cited | Detail |
|------|--------|-----------|--------|
| T01  | PASS   | AC4       |        |
| T02  | PASS   | AC5       |        |
| T03  | PASS   | AC6       |        |
| T04  | PASS   | AC1       |        |
| T05  | PASS   | AC1       |        |
| T06  | PASS   | AC2       |        |
| T07  | PASS   | AC3       |        |
| T08  | PASS   | AC6       |        |
| T09  | PASS   | AC6       |        |
| T10  | PASS   | AC7       |        |
| T11  | PASS   | AC8       |        |
| T12  | PASS   | AC9       |        |
| T13  | PASS   | AC9       |        |

---

## Check 3 — File collision (same-Wave tasks don't share files)

File paths extracted from "Dev Notes", "Implementation details", and "Testing"
sections using the pattern `[\w\-/\.]+\.(md|sh|ts|tsx|js|jsx|json|py|mmd|yml|yaml)`.

**Wave 0 — T01, T02, T03**

| Task | Key output files |
|------|-----------------|
| T01  | `tests/run.sh`, `CLAUDE.md` |
| T02  | `tests/F02-shellcheck.sh` (explicitly defers `drivers/DRIVER_CONTRACT.md` to T06 in Wave 1) |
| T03  | `tests/lib/sim-harness.sh`, `tests/fixtures/F02-task.md` |

| Wave | Status | Colliding paths | Tasks involved |
|------|--------|-----------------|----------------|
| 0    | PASS   | (none)          |                |

**Wave 1 — T04, T05, T06, T07, T10, T11**

| Task | Key output files |
|------|-----------------|
| T04  | `bin/didio-config-lib.sh`, `tests/F02-config-injection.sh` |
| T05  | `bin/didio-spawn-agent.sh`, `tests/F02-spawn-meta.sh` |
| T06  | `drivers/DRIVER_CONTRACT.md`, `drivers/claude-driver.sh`, `drivers/codex-driver.sh`, `tests/F02-driver-guardrails.sh` |
| T07  | `.gitignore`, `tests/F02-secrets-scan.sh` |
| T10  | `agents/orchestrator.md`, `agents/workflows/feature-workflow.md`, `agents/prompts/developer.md`, `agents/prompts/t800.md`, `.claude/commands/create-feature.md`, `tests/F02-docs-consistency.sh` |
| T11  | `didio.config.json`, `tests/F02-config-validate.sh` |

| Wave | Status | Colliding paths | Tasks involved |
|------|--------|-----------------|----------------|
| 1    | PASS   | (none)          |                |

**Wave 2 — T08, T09**

| Task | Key output files / references |
|------|-------------------------------|
| T08  | `tests/F02-sim-dispatch.sh`; references `tests/lib/sim-harness.sh` (sourced read-only) |
| T09  | `tests/F02-sim-parallel.sh`, `tests/fixtures/F02-probe-driver.sh`; references `tests/lib/sim-harness.sh` (sourced read-only) |

| Wave | Status | Colliding paths | Tasks involved |
|------|--------|-----------------|----------------|
| 2    | FAIL   | `tests/lib/sim-harness.sh` | T08, T09 |

> **Heuristic false positive.** `tests/lib/sim-harness.sh` is **created** by
> T03 in Wave 0 and is only **sourced** (read-only) by T08 and T09 in Wave 2.
> Both task files carry an explicit suppression comment:
> `<!-- readiness: tests/lib/sim-harness.sh is read-only (sourced) in Wave 2 — created by T03 in Wave 0 -->`.
> No real write collision exists. Per spec, the tool still counts this as a
> FAIL; the operator has already documented the resolution inline.

**Wave 3 — T12, T13**

| Task | Key output files |
|------|-----------------|
| T12  | `docs/diagrams/F02-architecture.mmd`, `docs/adr/0004-framework-hardening.md`, `README.md` |
| T13  | `docs/diagrams/F02-journey.mmd` |

| Wave | Status | Colliding paths | Tasks involved |
|------|--------|-----------------|----------------|
| 3    | PASS   | (none)          |                |

---

## Check 4 — Wave 0 completeness (deps/perms/scaffolding)

| Item needed by Wave≥1 | Status | Wave 0 covers? | Detail |
|------------------------|--------|----------------|--------|
| `tests/lib/sim-harness.sh` needed by T08, T09 (Wave 2) | PASS | T03 (Wave 0) creates it | `tests/lib/` does not yet exist on disk; T03 creates it. Implementation must include `mkdir -p tests/lib`. |
| `tests/fixtures/` needed by T09 (Wave 2) | PASS | Already exists on disk | Verified: `tests/fixtures/` pre-exists from F01. T03 also adds a fixture in Wave 0. |
| `tests/run.sh` referenced by Wave 1+ test execution | PASS | T01 (Wave 0) creates it | T01 is the sole owner. |
| `docs/diagrams/templates/` referenced by T12, T13 (Wave 3) | PASS | Already exists on disk | Verified: `docs/diagrams/templates/architecture.mmd` and `user-journey.mmd` present. |
| `docs/adr/` referenced by T12 (Wave 3) | PASS | Already exists on disk | Verified: ADRs 0001–0003 present; slot 0004 available. |
| No new npm/pip/external dep declared | PASS | N/A | bash + python3 only; shellcheck opt-in/skippable (T02). |

---

## Check 5 — Testing section non-empty

Each task has a `## Testing` section counted by physical non-empty lines
between the heading and the next `##`. The ≥3 threshold with ≥1 command/framework
mention is applied to all non-Wave-4 tasks (there are no Wave 4 tasks in F02).

| Task | Wave | Status | Lines | Detail |
|------|------|--------|-------|--------|
| T01  | 0    | PASS   | 3     | Mentions `bash tests/run.sh`; self-validating |
| T02  | 0    | PASS   | 3     | 3 bullets (wrapping); mentions `bash tests/F02-shellcheck.sh` |
| T03  | 0    | PASS   | 3     | 3 bullets (wrapping); mentions `bash tests/lib/sim-harness.sh` |
| T04  | 1    | PASS   | 3     | 2 bullets (one wraps); mentions `bash tests/F02-config-injection.sh` |
| T05  | 1    | PASS   | 3     | 1 bullet spanning 3 lines; mentions `bash` + `python3 -m json.tool` |
| T06  | 1    | PASS   | 3     | 2 bullets (one wraps); mentions `tests/F02-driver-guardrails.sh` |
| T07  | 1    | PASS   | 3     | 3 bullets (wrapping); mentions `bash` (git + grep) |
| T08  | 2    | PASS   | 3     | 3 bullets (wrapping); mentions `bash tests/F02-sim-dispatch.sh` |
| T09  | 2    | PASS   | 3     | 2 bullets (second wraps); mentions `bash tests/F02-sim-parallel.sh` |
| T10  | 1    | PASS   | 3     | 3 bullets (wrapping); mentions `bash` (grep) + `tests/F02-docs-consistency.sh` |
| T11  | 1    | PASS   | 3     | 3 bullets (wrapping); mentions `bash` + `python3` |
| T12  | 3    | PASS   | 3     | 1 bullet spanning 3 lines; framework docs; mentions `tests/F02-docs-consistency.sh` |
| T13  | 3    | PASS   | 3     | 3 bullets (wrapping); framework docs; mentions mermaid CLI / editor preview |

---

## Summary

- PASS: 4 checks (1, 2, 4, 5)
- FAIL: 1 check (3 — Wave 2 heuristic false positive, suppression comment already present)

| Check | Result | Notes |
|-------|--------|-------|
| 1 — AC coverage | PASS | All 9 ACs covered |
| 2 — Bidirectional traceability | PASS | All 13 tasks have `**Maps to AC:**` |
| 3 — File collision | FAIL | Wave 2: `tests/lib/sim-harness.sh` referenced by T08 + T09 (false positive — read-only; suppression comment present) |
| 4 — Wave 0 completeness | PASS | All deps/dirs covered |
| 5 — Testing sections | PASS | All 13 tasks have ≥3 non-empty lines + command/framework |

**Verdict:** BLOCKED

---

## Recommended action

Check 3 is the sole blocker and is a known heuristic false positive. The
operator has two options:

1. **Accept and proceed** — both T08 and T09 already carry the inline suppression
   comment `<!-- readiness: tests/lib/sim-harness.sh is read-only (sourced) in Wave 2 — created by T03 in Wave 0 -->`.
   A human review of the Wave manifest confirms there is no real write collision.
   The readiness agent cannot auto-suppress per spec; the human operator can
   authorize execution explicitly.

2. **Structural confirmation** — if stricter auditing is required, T08 could
   explicitly list `tests/lib/sim-harness.sh` only in its "Depends on" field
   (not in "Implementation details"), removing it from the path-extraction
   scan. No behavioral change required.

No other findings require action before Wave 0 execution.
