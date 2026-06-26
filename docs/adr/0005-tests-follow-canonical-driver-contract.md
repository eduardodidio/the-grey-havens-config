# ADR-0005: Tests follow the canonical driver contract (F03)

**Status:** accepted
**Date:** 2026-06-19
**Deciders:** @eduardodidio

## Context

The F02 test runner (`tests/run.sh`) revealed pre-existing failures inherited
from F01 — they were not F02 regressions, only newly surfaced by the runner.
Three test files were red:

- **`tests/F01-spawn-dispatch.sh` (schema drift):** the test asserted
  `"type":"echo"` and `"task_id":"task"`, but the shipped, canonical
  `drivers/echo-driver.sh` emits `"type":"system","subtype":"echo-driver"` with
  the field `task`. The F02 simulation suites (`F02-sim-dispatch.sh`,
  `F02-sim-parallel.sh`) were already written against this canonical shape.
- **`tests/F01-spawn-dispatch.sh` (exit-code mismatch):** the boundary case
  exported `DIDIO_ECHO_EXIT_CODE=1`, but the driver reads `ECHO_DRIVER_EXIT`
  (`drivers/echo-driver.sh:15`, `DRIVER_CONTRACT.md:33`). With the wrong
  variable name the driver always exited 0, so the test never exercised the
  failure path. Production propagation in `bin/didio-spawn-agent.sh`
  (`EXIT_CODE=$?` → `status:failed` → `exit $EXIT_CODE`) was inspected and
  verified correct — this was a test-only defect, **not** a production bug.
- **`bin/test_didio_events.py` (mapper contradiction):** `bin/didio-events-lib.py`
  listed `"reasoning"` in `_CODEX_TOOL_ITEM_TYPES`, mapping it to `kind="tool"`,
  which contradicts the module's own docstring citing `reasoning` as the
  canonical "no Claude analogue → degrade to raw" example.

A fourth failure was discovered during execution: `tests/F02-secrets-scan.sh`
self-matched — its Check B greps tracked files for literal secret-pattern
strings (e.g. `BEGIN .* PRIVATE KEY`), and those strings appear verbatim in the
scanner itself and in the `tasks/` markdown spec that documents them. Neither
file contains a real secret.

## Decision

The driver contract (`drivers/DRIVER_CONTRACT.md`) and the shipped echo-driver
are the **canonical source** of the event schema and the exit-variable name
(`ECHO_DRIVER_EXIT`). When a test diverges from the contract, the **test** is
corrected to follow the contract — never the reverse.

1. **`tests/F01-spawn-dispatch.sh`** is aligned to the canonical schema
   (`subtype:echo-driver`, field `task`) and the canonical exit variable
   (`ECHO_DRIVER_EXIT`). No production code or driver changes.
2. **`bin/didio-events-lib.py`** removes `"reasoning"` from
   `_CODEX_TOOL_ITEM_TYPES` so it degrades to `kind="raw"` (category preserved)
   via the existing fallback, matching the documented contract. The other 12
   `test_didio_events.py` cases stay green (`count_tool_errors` never counted
   `reasoning`).
3. **`tests/F02-secrets-scan.sh`** excludes the scanner itself and the `tasks/`
   spec directory (markdown documentation, like the already-excluded `docs/`),
   so pattern definitions stop registering as false positives. The secret
   detection over code/config is otherwise unchanged.

## Consequences

**Easier:**
- `bash tests/run.sh` is now fully green (**14 passed, 0 failed**) and the F01
  dispatch suite exercises the real failure path it was meant to cover.
- The event normalizer matches its own documented contract; `reasoning` is never
  mislabelled as a tool.
- The secrets scanner no longer produces false positives on its own pattern
  definitions, so a real future hit is not lost in noise.

**Trade-offs accepted:**
- Excluding `tasks/` from the secret scan means a literal secret pasted into a
  task markdown spec would not be flagged. This is consistent with the existing
  `docs/` exclusion — both are human-authored documentation, not deployed
  code/config — and the Check A tracked-artifact guard still applies repo-wide.

## Alternatives considered

- **Change the driver/contract to match the old test** — rejected: it would
  break the F02 simulation suites and `DRIVER_CONTRACT.md`, which are the
  canonical definition.
- **Treat the exit-code failure as a production bug in `didio-spawn-agent.sh`**
  — rejected after inspection: propagation is correct; only the test's variable
  name was wrong.
- **Obfuscate the pattern strings in the secrets scanner** (so it stops
  self-matching) — rejected: less readable than an explicit self/`tasks/`
  exclusion and would not fix the documentation match in `F02-T07.md`.
