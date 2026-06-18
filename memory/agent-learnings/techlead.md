# TechLead Learnings

(QA appends to this file at the end of every feature retrospective.
Each entry is a lesson that generalizes beyond a single bug.)

## F02 — 2026-06-17
**What worked:** Providing specific "Retrospective Seeds" with role attribution made QA's ceremony straightforward — lessons were already distilled and generalized.
**What to avoid:** Reviewing named constants (env vars, flags) only in prose — the ADR and diagram used `DIDIO_DRIVER_SAFE` while the implementation used `DIDIO_DRIVER_DRYRUN`. A quick grep during review catches this class of error in seconds.
**Pattern to repeat:** During code review, explicitly grep every named constant that appears in ADRs and diagrams against the actual implementation. For isolation tests, note when the claimed guarantee ("no shell credential leakage") is only partially machine-verified — be explicit about the gap so future reviewers know what's still human-asserted.
