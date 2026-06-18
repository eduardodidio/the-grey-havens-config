# QA Learnings

(QA appends to this file at the end of every feature retrospective.
Each entry is a lesson that generalizes beyond a single bug.)

## F02 — 2026-06-17
**What worked:** Classifying pre-existing failures by their TechLead IDs (TL-03) before running the suite made it unambiguous which failures were in-scope vs. known pre-existing. Fixing TechLead IMPORTANT findings (TL-01, TL-02) before issuing the verdict ensures the report reflects the true final state.
**What to avoid:** Issuing a PASSED verdict without resolving IMPORTANT findings flagged by TechLead — even if ACs are all green, open IMPORTANTs should be closed or explicitly deferred with justification.
**Pattern to repeat:** Before finalizing the verdict, grep for every env var / constant name referenced in ADRs and diagrams and confirm they match the implementation. When a test suite excludes a sub-directory (e.g. `tests/lib/`), add it to the shellcheck and discovery globs in the same QA pass.

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
