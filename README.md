# The Grey Havens

Project using the [claude-didio-config](https://github.com/eduardodidio/claude-didio-config)
framework: 4-agent Waves workflow (Architect → Developer → TechLead → QA),
agent logs under `logs/agents/`, and feature task manifests under
`tasks/features/`.

See `CLAUDE.md` for mission, agent workflow, and guardrails.

---

## Multi-provider (Claude + Codex)

Roles (architect, developer, techlead, qa, ...) can each run on **Claude
Code** or the **OpenAI Codex CLI** (`codex exec`, headless). The default
provider is `claude`, and Claude-only projects keep working with **zero
config changes** — the default flow is byte-for-byte unchanged.

### Assigning a provider to a role

In `didio.config.json`, set the provider per role under `models`:

```json
{
  "providers": {
    "claude": { "bin": "claude" },
    "codex": { "bin": "codex" }
  },
  "models": {
    "developer": { "provider": "codex" },
    "techlead": { "provider": "claude" }
  }
}
```

Any role without an explicit `provider` falls back to `claude`.

### Compiling skills for both providers

Skills (slash commands + role prompts) are authored once under `skills/`
and compiled to each provider's native format:

```bash
didio compile-skills                # compile to all configured providers
didio compile-skills --target claude
didio compile-skills --target codex
didio compile-skills --dry-run      # preview without writing files
```

Claude output goes to `.claude/commands/` + `.claude/agents/` +
`agents/prompts/`; Codex output goes to `~/.codex/prompts/` + `AGENTS.md`.

### Checking provider CLIs

```bash
didio providers list       # show each configured provider + binary resolution
didio providers validate   # exit non-zero if a provider used by a role is missing
```

`providers validate` only checks providers actually referenced by the active
config — a Claude-only project never requires `codex` to be installed.

### Codex prerequisites

To use `provider: "codex"` for a role:

1. Install the Codex CLI and make sure `codex` is on `PATH`.
2. Authenticate: run `codex` once and complete its login flow.
3. Confirm `~/.codex/config.toml` exists (created by Codex on first auth).
4. Run `didio providers validate` to confirm the binary and config resolve.

### Documented gaps

- **No Codex fallback/effort flags** — the `effort` / fallback-model knobs
  that exist for Claude roles are not supported for `provider: "codex"`.
- **Subagents are Claude-only** — roles that spawn Claude subagents are
  skipped (not translated) when compiling for Codex.
- **Rate-limit reset may be `n/a` for Codex** — the dashboard and
  rate-limit handling degrade gracefully: if Codex doesn't report a reset
  time, the field is shown as `n/a` instead of erroring.

See `docs/adr/0002-multi-provider-driver-architecture.md` and
`docs/adr/0003-neutral-skill-compile-model.md` for the architecture
decisions, and `docs/diagrams/F01-architecture.mmd` /
`docs/diagrams/F01-journey.mmd` for the data-flow and user-journey diagrams.

---

## F02 — Framework Hardening

Security audit and remediation across the full framework:

- **Injection fix (HIGH):** `bin/didio-config-lib.sh` and the `.meta.json`
  write in `bin/didio-spawn-agent.sh` now pass all shell values via `sys.argv`
  into quoted `<<'PY'` heredocs — no shell variables are interpolated into
  Python source strings. Observable stdout/exit behavior is preserved
  byte-for-byte.
- **Driver permission posture documented (MEDIUM):** `drivers/DRIVER_CONTRACT.md`
  now includes a Security section explaining why `--dangerously-skip-permissions`
  (Claude) and `--yolo` (Codex) are used, the applicable CLAUDE.md guardrails,
  and the `DIDIO_DRIVER_DRYRUN=1` opt-in dry-run hook for audit and test use.
- **Project test runner added:** `tests/run.sh` is the canonical test runner
  (`bash tests/run.sh`). `CLAUDE.md` Build/Test commands now point to real
  scripts.
- **Simulation harness:** `tests/lib/sim-harness.sh` uses an echo-driver
  fixture to simulate agent resolution, parallelism, meta/status transitions,
  failure paths, and context isolation without live LLM calls.
- **Secrets scan:** `tests/F02-secrets-scan.sh` verifies no `logs/agents/`
  artifacts are tracked by git and greps the repo for obvious secret patterns.
- **Shellcheck baseline:** `tests/F02-shellcheck.sh` runs shellcheck across
  `bin/`, `drivers/`, and `tests/` (skips gracefully if shellcheck is absent).
- **Flow/doc reconciliation:** `tests/F02-docs-consistency.sh` asserts every
  `didio <subcommand>` token in docs maps to either a repo script or a
  documented global-install command. `agents/workflows/feature-workflow.md`
  now documents the checkpoint/resume + per-Wave test gate contract.

Architecture decision: `docs/adr/0004-framework-hardening.md`.
Diagrams: `docs/diagrams/F02-architecture.mmd` / `docs/diagrams/F02-journey.mmd`.

## F03 — Test reconciliation

Pre-existing F01 failures surfaced by the F02 test runner, reconciled against
the canonical driver contract (tests follow the contract, not the reverse):

- **Dispatch test aligned to the driver:** `tests/F01-spawn-dispatch.sh` now
  asserts the canonical echo-driver schema (`subtype:echo-driver`, field `task`)
  and uses the canonical exit variable `ECHO_DRIVER_EXIT` (the old
  `DIDIO_ECHO_EXIT_CODE` never triggered the failure path). No production or
  driver changes — exit-code propagation in `bin/didio-spawn-agent.sh` was
  verified already correct.
- **Codex mapper matches its contract:** `bin/didio-events-lib.py` no longer
  lists `reasoning` as a tool item; with no Claude analogue it degrades to
  `kind="raw"` (category preserved), per the module docstring. The other 12
  `bin/test_didio_events.py` cases stay green.
- **Secrets scan false-positive fix:** `tests/F02-secrets-scan.sh` excludes the
  scanner itself and the `tasks/` spec docs, which documented the literal
  pattern strings and self-matched. Detection over code/config is unchanged.

Result: `bash tests/run.sh` → **14 passed, 0 failed**.

Architecture decision: `docs/adr/0005-tests-follow-canonical-driver-contract.md`.
Diagrams: `docs/diagrams/F03-architecture.mmd` / `docs/diagrams/F03-journey.mmd`.
