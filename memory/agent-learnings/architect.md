# Architect Learnings

(QA appends to this file at the end of every feature retrospective.
Each entry is a lesson that generalizes beyond a single bug.)

## F02 — 2026-06-17
**What worked:** Front-loading test infrastructure (runner, shellcheck, sim-harness) in Wave 0 gave later Waves a working gate immediately — no test retrofitting needed mid-feature.
**What to avoid:** Shellcheck target globs that only cover top-level directories silently miss `tests/lib/` or any helper sub-directory introduced in the same feature.
**Pattern to repeat:** When adding a `tests/lib/` sub-directory, include widening the shellcheck (and test-discovery) globs as an explicit Wave 0 acceptance criterion. When a task introduces a new/modified shared driver or fixture, add an explicit AC: "existing cross-feature tests that use this fixture still pass."
