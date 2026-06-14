# Component A — Provider abstraction (execution)

## Current invocation (verbatim, `${DIDIO_HOME}/bin/didio-spawn-agent.sh`)

Lines ~118–125 launch the agent:

```bash
claude \
  -p "$FULL_PROMPT" \
  --output-format stream-json \
  --verbose \
  ${AGENT_MODEL:+--model "$AGENT_MODEL"} \
  ${AGENT_FALLBACK:+--fallback-model "$AGENT_FALLBACK"} \
  --dangerously-skip-permissions \
  > "$LOG_FILE" 2>&1
EXIT_CODE=$?
```

Note: the live script does NOT currently pass `--effort` or `--allowedTools`
(the mission's quoted form is aspirational); the **claude-driver must reproduce
exactly what the live script does today** — model, fallback,
`--output-format stream-json --verbose --dangerously-skip-permissions` — to keep
AC3 (byte-for-byte unchanged).

Model/fallback come from `bin/didio-config-lib.sh`:
`didio_model_for_role`, `didio_fallback_for_role` → read
`didio.config.json:models.<role>` (or `models_economy.<role>` when `economy:true`).
Values today are Claude-only: `opus` / `sonnet` / `haiku`.

`.meta.json` is written before launch (status `running`, pid, model, fallback)
and rewritten after (status, exit_code, finished_at, phrase). The dashboard's
aggregator (`bin/didio-progress.py`, `bin/didio-log-watcher-loop.py`) reads
`logs/agents/*.meta.json` into `state.json`. The dashboard modal
(`dashboard/src/components/AgentRunDialog.tsx`) fetches the raw `.jsonl` and
renders it assuming Claude stream-json events.

## Codex CLI ↔ Claude Code equivalence map (researched)

| Concern | Claude Code | OpenAI Codex CLI |
|---|---|---|
| Headless run | `claude -p "<prompt>"` | `codex exec "<prompt>"` (stdin via `-`) |
| Streaming events | `--output-format stream-json --verbose` | `--json` (NDJSON, 1 event/state change) |
| Bypass approvals | `--dangerously-skip-permissions` | `--dangerously-bypass-approvals-and-sandbox` / `--yolo` |
| Model select | `--model` / `--fallback-model` | `--model`, or `-c model=...` (no native fallback) |
| Effort | `--effort` | config / model-dependent |
| Project instructions | `CLAUDE.md` | `AGENTS.md` |
| Slash commands / skills | `.claude/commands/*.md` | `~/.codex/prompts/*.md` |
| Config | `.claude/settings.json` | `~/.codex/config.toml` |
| Ignore user config | (n/a) | `--ignore-user-config` |

## Driver contract (the key abstraction)

A driver is a bash script `${DIDIO_HOME}/drivers/<provider>-driver.sh`. Contract:

- **Input** (env vars exported by `didio-spawn-agent.sh`): `DIDIO_PROMPT`
  (full composed prompt), `DIDIO_MODEL`, `DIDIO_FALLBACK`, `DIDIO_EFFORT`,
  `DIDIO_LOG_FILE`, `DIDIO_ROLE`, `DIDIO_FEATURE`, `DIDIO_TASK_ID`. (Exact var
  names are fixed by the contract task T02; drivers and spawn-agent must agree.)
- **Output:** native streaming events appended as NDJSON to `$DIDIO_LOG_FILE`
  (stdout+stderr redirected like today).
- **Exit code:** the driver exits with the underlying CLI's exit code; spawn-agent
  maps non-zero → `failed`. No driver prints anything to stdout except via the log
  redirect performed by the driver itself.
- **Resolution:** spawn-agent picks the driver by
  `driver="${DIDIO_HOME}/drivers/$(didio_provider_for_role "$ROLE")-driver.sh"`.
  Unknown/missing provider → clear error + exit 2. This naming convention means
  adding a third provider later requires zero edits to spawn-agent.

`claude-driver.sh` = today's invocation verbatim. `codex-driver.sh` =
`codex exec --json --yolo ${DIDIO_MODEL:+--model "$DIDIO_MODEL"} - <<< "$DIDIO_PROMPT"`
(prompt via stdin; Codex has no `--fallback-model`, so fallback is emulated or
documented as a gap; `--yolo` == bypass approvals+sandbox).

## Config additions

- Per-role `provider` key under `models.<role>` (and `models_economy.<role>`),
  default absent ⇒ `claude`.
- A top-level `providers` registry: per provider `{ "bin": "...", "models": {...},
  "flags": [...] }` so model namespaces don't collide (Claude `opus/sonnet/haiku`
  vs Codex model ids like `gpt-5-codex` / `o4-mini`). Resolution helper must
  return the provider-correct model id for a role.
- New config-lib helpers: `didio_provider_for_role <role>` (default `claude`),
  `didio_provider_bin <provider>`, `didio_provider_model_for_role <role>`
  (namespaced), backward-compatible with existing helpers.
