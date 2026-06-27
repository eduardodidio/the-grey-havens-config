# Review follow-ups & backlog

Tracked outcomes of the full-project review (2026-06-26..27). The four MINOR
TechLead findings from the F02 review (TL-04/05/06/07) were **closed and merged**
(PRs #2, #3). **As of 2026-06-27 every item below is also closed** — kept here
as a record. Summary: install gap fixed, T4/T5 confirmed already covered
upstream, a real upstream `run-wave` bug fixed as a side effect, Mission filled.

## FINDING — active framework install is stale (pre-F01) — ✅ RESOLVED

**Severity: MEDIUM (docs promise commands the installed binary does not have).**

> **RESOLVED 2026-06-27.** `~/.local/bin/didio` was re-pointed to the F01 source
> repo (`ln -sf ~/claude-didio-config/bin/didio ~/.local/bin/didio`); `~/.zshrc`
> already exported `DIDIO_HOME=~/claude-didio-config`. `didio providers list/
> validate` and `didio compile-skills` now resolve and pass. The dotted
> install's 2 unpushed local commits were left intact (see "orphan commits"
> below). Revert: `ln -sf ~/.claude-didio-config/bin/didio ~/.local/bin/didio`.

There are **two** framework directories in `$HOME`:

| Path | Role | State |
|------|------|-------|
| `~/claude-didio-config` (no dot) | F01 **source repo** | branch `main`, HEAD `050df9d feat(F01): multi-model providers …` — has `bin/didio-compile-skills.{py,sh}`, `bin/didio-providers.sh`, F01 `run-wave` |
| `~/.claude-didio-config` (dotted) | **active install** (`DIDIO_HOME` default; `~/.local/bin/didio` → here) | dated 2026-05-08, **pre-F01** — NO `compile-skills` / `providers` |

Because the global `didio` symlink resolves to the **dotted install**, the
multi-provider commands this repo advertises do not exist at runtime:

```
$ didio providers list
didio: unknown subcommand 'providers'. Try 'didio help'.
```

Yet `README.md` and `CLAUDE.md` in this repo document `didio compile-skills`
and `didio providers` as available. **F01 was committed to the source repo but
never installed/synced into the active framework dir.**

### Remediation (requires explicit go-ahead — modifies `~/.claude-didio-config`)

Update the active install from the F01-bearing source. Candidate paths (to be
confirmed by the maintainer; this is an infra change outside this repo):

- re-point the `~/.local/bin/didio` symlink / `DIDIO_HOME` at
  `~/claude-didio-config`, **or**
- run the framework's own install/update step to sync `~/claude-didio-config`
  (source) → `~/.claude-didio-config` (install).

Until then, `providers` / `compile-skills` are documented-but-not-runnable in
this environment.

## T4 / T5 — ✅ CLOSED (already covered upstream, verified 2026-06-27)

These cannot — and need not — be in-repo tests: the production code lives in the
framework, not this consumer repo (`bin/` here holds only `didio-config-lib.sh`,
`didio-events-lib.py`, `didio-spawn-agent.sh`). Investigating the framework
(`~/claude-didio-config`) showed **both are already covered there and green**, so
porting them would be redundant:

- **T5 — `compile-skills` / `providers` smoke** → covered by
  `tests/F01-cli-subcommands.sh` ("smoke tests for the `didio compile-skills` and
  `didio providers` subcommands"), `F01-compile-claude.sh`, `F01-compile-codex.sh`,
  `F01-preflight.sh`. All pass.
- **T4 — resume re-runs only the failed/pending tasks** → the resume model is
  `logs/agents/_pending/`-based (`didio resume-pending` re-spawns only pending
  jobs), covered by `tests/F07-pause-resume-e2e.sh`, `F22-e2e-smoke.sh`,
  `F22-idempotency.sh`. All pass.

## Orphan commits on the dotted install — ✅ RESOLVED (not cherry-picked)

The dotted install `~/.claude-didio-config` carried 2 unpushed local commits
(`333ae5c` run-wave DIDIO_HOME fix, `1f780a5` sync(F16)). Investigation:

- `1f780a5` sync(F16) is **superseded** — the source tree (F01/F27) already has
  newer versions of every file it touched; cherry-picking would regress them.
- `333ae5c`'s one-line fix targeted a line the F01 refactor removed, but its
  intent (guard bare `$DIDIO_HOME` under `set -u`) revealed a **still-present
  upstream bug**: `bin/didio-run-wave.sh` ran `set -euo pipefail` yet used bare
  `"$DIDIO_HOME"` at the post-Wave summary, crashing with "unbound variable"
  when `DIDIO_HOME` was unexported. Fixed fresh upstream via a single
  top-level normalization — **claude-didio-config PR #2 (`fd29f25`)**, merged
  2026-06-27. The orphan commits themselves were left intact on the dotted
  install (not deleted) but are obsolete and were not cherry-picked.

## Mission — ✅ DONE

`CLAUDE.md` Mission was filled (PR #5, `562d068`): the-grey-havens-config is the
reference / dogfooding project for the framework.

## Framework test-suite hygiene — ✅ DONE (claude-didio-config PR #3, `96fcbd2`)

Running the framework's 54 `tests/*.sh` showed 47 pass / 5 fail / 2 timeout, but
triage proved **none of the 7 are bugs** — they have skip/arg/infra contracts a
naive `bash tests/*.sh` loop ignores:

- `F12-wave-summary-smoke` — passes; only fails **inside a sandbox** that blocks
  writes to `tasks/` (an agent-harness constraint, not a test issue).
- `F06-integration-test`, `F07-pause-resume-e2e`, `F10-readiness-smoke`,
  `F13-tea-e2e` — **e2e**: need live `claude` auth or are SIGTERM/PID-timing
  sensitive.
- `F13-tea-smoke` — **parametrized helper** (requires positional args).
- `F07-budget-smoke` — needs **`ccusage`** (external tool, not installed).

Fix: added `tests/run.sh` to the framework — runs the pure suite to green and
skips the e2e / infra / param tests by default with a printed reason (opt in via
`DIDIO_RUN_E2E=1`). Result un-sandboxed: **48 passed, 0 failed, 6 skipped**.
This mirrors the green-gate runner this consumer repo already has.
