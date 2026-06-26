# Retrospective — F02

## What worked
- Front-loading test infrastructure in Wave 0 (runner, shellcheck, sim-harness) meant Waves 1–2 had a working gate from the start — no retrofitting needed.
- The sim-harness echo-driver pattern let the simulation suite validate orchestration logic without live LLM calls; test isolation was clean.
- Per-criterion acceptance criteria on each task file made AC mapping during QA straightforward — no ambiguity about what "done" meant.
- The multi-file parallel Wave 1 (T04–T07, T10, T11) with distinct file ownership had zero conflicts and landed cleanly.
- TechLead retrospective seeds were specific and actionable — easy to propagate as generalizable lessons.

## What to avoid
- Writing ADR/diagram early with a placeholder name (e.g. `DIDIO_DRIVER_SAFE`) and never updating it once the implementation settles on a different name (`DIDIO_DRIVER_DRYRUN`). This creates a documentation/code divergence that persists until QA catches it.
- Shellcheck target globs that only cover top-level directories — any `tests/lib/` or sub-directory with shell helpers is silently excluded.
- Introducing a new or modified shared driver/fixture (e.g. echo-driver NDJSON schema) without explicitly adding "cross-feature test compatibility" as an AC for the task that changes it.

## Patterns to repeat
- When adding a `tests/lib/` sub-directory, widen all shellcheck and discovery globs in the same PR.
- After settling on a named constant (env var, function, flag) in an implementation, do a fast grep across ADRs and diagrams to catch any stale placeholders before review.
- When a task changes a shared driver/fixture schema, add an explicit AC: "existing tests that use this driver still pass."

## Propagated to learnings
- memory/agent-learnings/architect.md — shellcheck glob width + shared fixture cross-feature AC rule
- memory/agent-learnings/developer.md — ADR name sync after implementation settles + shellcheck lib/ coverage
- memory/agent-learnings/techlead.md — grep named constants in ADRs/diagrams during review; isolation test coverage gap pattern
- memory/agent-learnings/qa.md — verify TechLead IMPORTANT findings are fixed before issuing PASSED verdict; pre-existing failure classification protocol
