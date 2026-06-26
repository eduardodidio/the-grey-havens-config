# ADR-0004: Framework Hardening (F02)

**Status:** accepted
**Date:** 2026-06-17
**Deciders:** @eduardodidio

## Context

An audit of the `claude-didio-config` framework across four axes — flow/
orchestration, agent models, simulation tests, and security/best-practices —
surfaced the following findings that required remediation:

- **D1/D2 (HIGH):** `bin/didio-config-lib.sh` interpolated shell variables
  directly into `python3 -c "..."` source strings. Values containing `'`,
  newlines, or Python syntax fragments could break execution or, in the
  worst case (e.g. `didio_write_config`), execute arbitrary code.
- **D3 (MEDIUM):** `bin/didio-spawn-agent.sh` wrote the initial `.meta.json`
  via an unquoted heredoc, interpolating `$FEATURE`, `$ROLE`, `$TASK_ID`, and
  `$TASK_FILE` directly into JSON. A path containing `"` or a newline would
  produce invalid JSON and break the dashboard parser.
- **D4 (MEDIUM):** `claude-driver.sh` uses `--dangerously-skip-permissions`
  and `codex-driver.sh` uses `--yolo`. These are intentional for autonomous
  agents but were undocumented, leaving no stated threat model or opt-out path
  for audit/test runs.
- **D5 (LOW–MEDIUM):** `.gitignore` coverage for log and meta artifacts needed
  verification; no automated check existed to catch tracked secrets.
- **D6 (LOW):** No shellcheck baseline; `set -euo pipefail` usage was
  inconsistent across sourced vs. executed scripts without documented rationale;
  CI was absent.
- **A1 (MEDIUM):** Repo docs referenced `didio run-wave` and related
  subcommands that live only in the global install (`~/.claude-didio-config`),
  not in this repo — an invisible documentation drift.
- **C (MEDIUM):** No project test runner (`tests/run.sh`) or simulation harness
  existed; `Build/Test/Run` in `CLAUDE.md` were placeholders.

## Decision

### 1. Argv/env over `-c` interpolation (fixes D1/D2/D3)

Every `python3 -c` block in `didio-config-lib.sh` is refactored to pass inputs
via `sys.argv` with the script body in a **quoted** `<<'PY'` heredoc (no shell
expansion inside the heredoc). `didio-spawn-agent.sh` writes the initial
`.meta.json` using the same `python3 - "$@" <<'PY'` pattern with `json.dump`
already used in its final meta-rewrite. Observable stdout/exit behavior is
preserved byte-for-byte (type coercion: bool→`true/false`, dict/list→JSON,
scalar→str).

### 2. Driver permission posture + opt-in dry-run (fixes D4)

A **Security** section is added to `drivers/DRIVER_CONTRACT.md` stating:
- Drivers run with elevated permissions (`--dangerously-skip-permissions` /
  `--yolo`) because they are invoked by a human-supervised orchestration layer,
  not exposed to untrusted input.
- The CLAUDE.md Highlander/sandbox-without-secrets guardrail applies.
- An env var `DIDIO_DRIVER_DRYRUN=1` triggers a dry-run that prints the full
  command instead of executing it, enabling audit and simulation tests without
  changing the default behavior (F01 AC3 preserved).

A guardrail test (`tests/F02-driver-guardrails.sh`) asserts the dangerous flags
are present **and** documented, so a silent removal or addition is caught.

### 3. Project test runner + simulation harness (fixes C)

`tests/run.sh` is the project's canonical test runner; `CLAUDE.md` `Build/Test`
sections point to it. `tests/lib/sim-harness.sh` provides a deterministic
simulation layer using an echo-driver fixture, covering agent resolution,
parallelism, meta/status transitions, failure paths, and context isolation.

### 4. Secrets scan + `.gitignore` validation (fixes D5)

`tests/F02-secrets-scan.sh` (a) fails if any `logs/agents/*.jsonl` or
`*.meta.json` is tracked by git, (b) greps the repo for obvious secret patterns
(private keys, PEM blocks, AWS key prefixes, generic `token = ...` patterns)
outside fixture files, using only `git` + `grep` (no new dependencies).

### 5. Shellcheck baseline + `set -euo pipefail` policy (fixes D6)

`tests/F02-shellcheck.sh` runs shellcheck across `bin/`, `drivers/`, and
`tests/`; it skips gracefully with a note when shellcheck is absent (optional
dep). The `set -euo pipefail` policy is documented in `DRIVER_CONTRACT.md`:
config-lib (sourced) omits `set -e` deliberately (callers manage exit codes);
drivers use `set -uo` to capture driver exit codes; CI absence is noted as a
future recommendation requiring explicit user confirmation.

### 6. Flow/doc reconciliation (fixes A1)

Every `didio <subcommand>` token in `agents/**` and `.claude/commands/**` either
maps to a repo `bin/*` script or is annotated as "provided by the global `didio`
install (`~/.claude-didio-config`)". `tests/F02-docs-consistency.sh` enumerates
referenced subcommands and checks them against an allow-list (repo scripts ∪
documented global commands). The checkpoint/resume + per-Wave test gate contract
is documented in `agents/workflows/feature-workflow.md`.

## Consequences

**Easier:**
- Security posture is explicit and machine-verified: injection vectors are
  closed, driver permissions are documented, secrets cannot be silently
  committed.
- The test suite is now self-bootstrapping: `tests/run.sh` + sim-harness give
  contributors a deterministic local gate.
- Documentation drift between repo and global install is caught automatically
  on every test run.

**Harder:**
- `python3` is a hard runtime dependency for every config-lib call (it was
  already required; this makes it load-bearing for correctness, not just speed).
- The `DIDIO_DRIVER_DRYRUN` dry-run path must be kept in sync with each driver's
  real invocation signature whenever drivers evolve.

**Trade-offs accepted:**
- The simulation harness uses `echo-driver` (not a real LLM call), so it
  validates orchestration logic, not model outputs — integration tests against
  live providers remain a future work item.
- CI is documented as a recommendation but not added; CI changes require
  explicit user confirmation per `CLAUDE.md`.

## Alternatives considered

- **`jq` for JSON generation** — avoids Python for meta writes. Rejected:
  `jq` is not installed by default on macOS; Python 3 is already a stated
  dependency and `json.dump` gives type-safe encoding with no extra dep.
- **Blanket `set -e` in config-lib** — would make error handling uniform.
  Rejected: config-lib is sourced into callers that test exit codes directly;
  `set -e` would break that contract and introduce subtle behavior changes.
- **Wrapper script per config-lib function** — each function becomes a separate
  Python file, eliminating heredocs. Rejected: over-engineering for a pure-bash
  project; heredocs with quoted delimiters solve the injection problem cleanly.
- **Adding CI (GitHub Actions) in this feature** — would immediately validate
  the test runner in a clean environment. Rejected: CLAUDE.md explicitly
  requires user confirmation before CI/CD changes; deferred to a dedicated
  follow-up.
