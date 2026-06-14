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
