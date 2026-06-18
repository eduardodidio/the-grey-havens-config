# Driver contract (F01-T02)

A driver is `drivers/<provider>-driver.sh`, resolved by
`didio_provider_for_role <role>` in `didio-spawn-agent.sh`. Adding a new
provider requires zero edits to spawn-agent — only a new driver file.

## Input (exported env vars)

- `DIDIO_PROMPT` — the full composed prompt
- `DIDIO_MODEL` — resolved model id (may be empty)
- `DIDIO_FALLBACK` — resolved fallback model id (may be empty)
- `DIDIO_EFFORT` — resolved effort (may be empty)
- `DIDIO_LOG_FILE` — absolute path the driver must append NDJSON output to
- `DIDIO_ROLE` — role name (architect | developer | techlead | qa | ...)
- `DIDIO_FEATURE` — feature id (e.g. F01)
- `DIDIO_TASK_ID` — task id (e.g. F01-T07)

## Output

Native streaming events as NDJSON, appended to `$DIDIO_LOG_FILE` (the driver
performs the redirect itself — stdout+stderr — exactly like today's
`> "$LOG_FILE" 2>&1`).

## Exit code

The driver exits with the underlying CLI's exit code. spawn-agent maps
non-zero to `status: "failed"` in `.meta.json`.

## Example: echo-driver.sh

`drivers/echo-driver.sh` is a minimal test fixture: it writes one canned
NDJSON line containing the contract env vars to `$DIDIO_LOG_FILE` and exits
`${ECHO_DRIVER_EXIT:-0}`. Used by tests to validate dispatch without real
model spend.

## Security posture

Drivers execute autonomous agents (Architect, Developer, TechLead, QA) with
elevated permissions to minimize approval friction. This section documents the
threat model, permission flags, and guardrails.

### Threat model & elevated permissions

**claude-driver.sh** runs the Claude Code CLI with:
- `--dangerously-skip-permissions` — bypasses interactive approval prompts for
  file edits, bash commands, and other elevated operations
- `--allowedTools "Edit Write MultiEdit Read Bash Glob Grep"` — auto-approves
  these tools without prompting

**codex-driver.sh** runs the Codex CLI with:
- `--yolo` — bypasses approval prompts and sandbox restrictions

**echo-driver.sh** (test fixture) has no elevated flags and is safe for
simulation tests.

The trade-off: agents can autonomously edit files, run commands, and fetch
external data. In return, agents run in **isolated contexts** with:

1. **Isolation per agent run**: each spawn-agent invocation in a clean bash
   context (no access to prior run state, credentials, or shared environment).
2. **JSONL audit log**: all prompt/response/command content logged to
   `logs/agents/*.jsonl` (transcripts rotated per role/run, not tracked by
   git; see `.gitignore`).
3. **Execution boundary validation**: CLAUDE.md Highlander/Sandbox rule
   restricts agents from committing secrets, disabling validation, or
   modifying CI/CD without explicit user confirmation.
4. **No shell credential leakage**: agents run without shell `$HISTORY` or
   `$HOME/.ssh` access; sensitive env vars are not exported to driver subshells.

### Dry-run / safe mode hook

For testing, auditing, or dry-run scenarios, set `DIDIO_DRIVER_DRYRUN` to any
non-empty value. When set, drivers print the resolved CLI command as one NDJSON
line to `$DIDIO_LOG_FILE` and exit 0 **without invoking the provider CLI**.
Default (unset): drivers behave normally. This hook preserves F01 AC3 fidelity
(no observable change to the real invocation).
