# Axis D — Security + best practices

## D1 — `python3 -c` source injection (HIGH)

`bin/didio-config-lib.sh` builds Python source with shell variables
interpolated directly into the `python3 -c "..."` string:

- `didio_read_config`: `'$config'`, `c.get('$key', '')`.
- `didio_write_config`: `path, key, raw = '$config', '$key', '$value'`
  — **worst case**: `$value` comes from user/menu input; a value containing
  `'`, newline, or Python code breaks the script or executes arbitrary code.
- `didio_model_for_role`, `didio_fallback_for_role`, `didio_effort_for_role`,
  `didio_provider_for_role`, `didio_provider_bin`: `'$role'` / `'$provider'`
  interpolated.

**Fix pattern (already used in the repo):** `bin/didio-spawn-agent.sh:158`
passes values as `sys.argv` to a `python3 - "$A" "$B" <<'PY'` heredoc with a
**quoted** `'PY'` delimiter (no shell expansion inside). Refactor every
config-lib python block to read inputs from `sys.argv`/`os.environ`, with the
script body in a quoted heredoc or a `-c` program that takes no interpolation.
Preserve exact stdout (type coercion: bool→`true/false`, dict/list→JSON,
scalar→str) so callers and F01 tests stay green.

## D2 — `didio_write_config` path/seam (HIGH, part of D1)

Same function also interpolates `$config` (a path) — harden together with the
value injection. Keep the type-detection semantics (`true/false`→bool,
`isdigit`→int, else str).

## D3 — spawn-agent meta-header heredoc (MEDIUM)

`bin/didio-spawn-agent.sh:75-89` writes `.meta.json` via an **unquoted**
heredoc interpolating `$FEATURE`, `$ROLE`, `$TASK_ID`, `$TASK_FILE` directly
into JSON. A task path or id containing `"` / newline produces invalid JSON
(dashboard parse break) — a robustness/injection seam. Build the initial meta
with `python3 - "$@" <<'PY'` (json.dump), mirroring the already-correct final
rewrite at lines 158-171. Output JSON must stay equivalent for clean inputs.

## D4 — driver permission guardrails (MEDIUM)

- `claude-driver.sh`: `--dangerously-skip-permissions` +
  `--allowedTools "Edit Write MultiEdit Read Bash Glob Grep"`.
- `codex-driver.sh`: `--yolo` (bypass approvals + sandbox).

These are intentional (autonomous agents) but undocumented as a security
posture. Add a **Security** section to `DRIVER_CONTRACT.md` stating the
threat model, that drivers run with elevated permissions, the CLAUDE.md
Highlander/sandbox-without-secrets rule, and an env opt-out hook
(e.g. honor a `DIDIO_DRIVER_SAFE`/dry-run that prints the command instead of
running, for audit/tests) **without changing default observable behavior**
(F01 AC3). A guardrail test asserts the dangerous flags are present *and*
documented (so a silent removal/addition is caught).

## D5 — secrets & `.gitignore` (LOW/MEDIUM)

`.gitignore` already covers `logs/agents/*.jsonl`, `*.meta.json`,
`state.json`, `*.checkpoint.json`, `*.ckpt.at`. JSONL transcripts may contain
secrets — confirm coverage is complete, no log/meta artifact is tracked, and
no secret is committed. Add a `tests/F02-secrets-scan.sh` that (a) fails if
any `logs/agents/*.jsonl|*.meta.json` is tracked by git, (b) greps the repo
for obvious secret patterns (private keys, `*.pem`, AWS keys, tokens) outside
fixtures, (c) is dependency-free (git + grep only).

## D6 — best practices (LOW)

- **shellcheck** baseline across `bin/*.sh`, `drivers/*.sh`, `tests/*.sh`
  (installed: `/opt/homebrew/bin/shellcheck`).
- **`set -euo pipefail` policy:** document why config-lib (sourced) and the
  drivers (`set -uo` to capture exit codes) intentionally differ — do **not**
  blanket-add `set -e`; record the policy so future lint doesn't "fix" it.
- **CI absence:** note as a finding; a future GitHub Actions workflow that
  runs `tests/run.sh` + shellcheck is recommended but **CI changes require
  explicit user confirmation** (CLAUDE.md) — so this axis only *documents*
  the recommendation, it does not add CI.

## Priority summary

| ID | Finding | Severity |
|----|---------|----------|
| D1/D2 | config-lib python injection | HIGH |
| D3 | spawn-agent meta heredoc | MEDIUM |
| D4 | driver permission guardrails | MEDIUM |
| D5 | secrets / .gitignore | LOW–MEDIUM |
| D6 | shellcheck / set -e policy / CI | LOW |
