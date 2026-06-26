# Review follow-ups & backlog

Tracked outcomes of the full-project review (2026-06-26). The four MINOR
TechLead findings from the F02 review (TL-04/05/06/07) were **closed and merged**
(PRs #2, #3). This file tracks the two items that remain — one is a real
environment gap, the other a pair of deferred tests that depend on it.

## FINDING — active framework install is stale (pre-F01)

**Severity: MEDIUM (docs promise commands the installed binary does not have).**

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

## DEFERRED — T4 / T5 (blocked on the finding above)

From the review test plan; **cannot be implemented as in-repo tests** because
the production code they exercise lives in the framework, not in this consumer
repo (`bin/` here holds only `didio-config-lib.sh`, `didio-events-lib.py`,
`didio-spawn-agent.sh` — no `run-wave`, `compile-skills`, or `providers`). This
is consistent with F01 being **upstream-only** here (see
`tasks/features/F01-multi-model-providers/F01-README.md`).

- **T4 — resume re-runs only the failed Wave.** Needs `didio run-wave`'s
  resume logic, which lives in the framework. Best home: a test in
  `~/claude-didio-config`, not here. The F02 journey diagram was already
  corrected to reflect the intended semantics (TL-06).
- **T5 — smoke `didio compile-skills` / `didio providers` against this repo's
  config.** Blocked until the active install carries F01 (see finding). Once
  installed, a thin smoke test here could assert both subcommands resolve and
  `providers validate` passes for this Claude-only config.

## OPEN — Mission still `TBD`

`CLAUDE.md` Mission reads `TBD — fill in after kickoff`. Needs the maintainer's
input (project purpose beyond dogfooding the framework); not derivable from code.
