# F02 — Wave 3 summary

**Status:** completed
**Tasks:** F02-T12, F02-T13
**Generated:** 2026-06-17T00:00:00Z

## Files touched
- `docs/diagrams/F02-architecture.mmd` (T12: component/data-flow diagram — Repo/Test/Global layers, security boundaries, echo-driver/probe-driver in sim layer)
- `docs/adr/0004-framework-hardening.md` (T12: ADR recording injection-fix, driver-permission posture, test-runner, doc-reconciliation decisions with alternatives)
- `README.md` (T12: "F02 — Framework Hardening" section listing all shipped changes)
- `docs/diagrams/F02-journey.mmd` (T13: BPMN-style swimlane journey — Maintainer / Pipeline / Quality gate per Wave; per-Wave gate nodes with fix-and-retry failure branches)

## Decisions
- Architecture diagram extended the T12 stub to include probe-driver fixture and DIDIO_DRIVER_SAFE dry-run hook, following Wave 2's note that simulation layer branching should be depicted.
- Journey diagram expanded the single test-gate stub to four per-Wave gate nodes (G_W0–G_W3), each with an explicit `no → fix & re-run` branch back to Maintainer — matches T10's "no Wave advances without tests" mandate.

## Notes for next Wave
- Wave 3 is the final Wave for F02; no follow-on Waves are defined.
- All global acceptance criteria (AC1–AC9) map to tasks that are marked **done**; QA should validate against the full AC checklist in `F02-README.md` before closing the feature.
- `tests/run.sh` auto-discovers all `tests/F02-*.sh` suites — no runner edits needed for future F02 fixes.
- ADR 0004 is numbered; next feature ADR must use 0005.
