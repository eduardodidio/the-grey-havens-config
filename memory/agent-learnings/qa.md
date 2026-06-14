# QA Learnings

(QA appends to this file at the end of every feature retrospective.
Each entry is a lesson that generalizes beyond a single bug.)

## F01 — 2026-06-14
**What worked:** Root-causing "non-F01" test regressions by git-stashing
the F01-touched tracked files and re-running the suite to get a clean
before/after diff isolated the true cause (header-only drift) quickly.
**What to avoid:** Don't assume a regression list handed to QA is fully
attributable to the named feature — verify against a stashed baseline
before fixing.
**Pattern to repeat:** When a feature touches generated `templates/*`
artifacts, diff the new output tree against any parallel/legacy tree that
feeds the same live symlink target. When CLAUDE.md/docs cite ADR numbers,
verify the numbered files actually exist with that number (numbering
collisions happen when ADRs are added across parallel feature branches).
