# Developer Learnings

(QA appends to this file at the end of every feature retrospective.
Each entry is a lesson that generalizes beyond a single bug.)

## F02 — 2026-06-17
**What worked:** Using `<<'PY'` single-quoted heredoc + `sys.argv` to pass data to Python scripts (instead of interpolating into `-c "..."`) is a clean, injection-safe pattern that preserves observable output byte-for-byte.
**What to avoid:** Writing ADR/diagram with a placeholder env-var or constant name early in development and never updating it once the implementation settles on a different name. The divergence persists silently until TechLead or QA catches it.
**Pattern to repeat:** After settling on a named constant (env var, function, flag) in the implementation, grep ADRs and diagrams for any stale placeholder before opening for review. Takes 30 seconds and prevents a class of documentation drift.

## F01 — 2026-06-14
**What worked:** Driver-contract abstraction + golden tests made AC3
(byte-for-byte unchanged) verifiable and gave a clean place to ratify a
fidelity fix (carrying `--effort`/`--allowedTools`) without touching
dispatch logic.
**What to avoid:** Wiring a new compile/sync pipeline (skills/ ->
compile-skills -> templates/.claude/commands/) without a one-time
regeneration pass over the parallel synced tree (templates/commands/, the
real .claude/commands symlink target) — left a header-only byte-identity
gap breaking F10/F14. Also: adding new top-level keys to
templates/didio.config.json without grepping tests/ for
NO_CHANGE/idempotency fixtures that assert on that file's full key set.
**Pattern to repeat:** When a feature regenerates artifacts under
templates/, diff against ALL known consumers before declaring done. When
adding a config schema key, grep tests/ for idempotency assertions on that
config file and update fixtures in the same change.
