# Component D — JSONL / event normalization (cross-cutting risk)

## The risk

Codex `--json` NDJSON schema ≠ Claude `stream-json` schema. Everything that reads
the per-agent `.jsonl` assumes Claude events. If Codex logs land unmapped, the
dashboard modal, error detection, and rate-limit parsing break for Codex runs.

## JSONL consumers (ground truth in this repo)

- **`.meta.json`** is the dashboard's primary contract (status/model/exit_code),
  written by `didio-spawn-agent.sh`, aggregated by `bin/didio-progress.py` +
  `bin/didio-log-watcher-loop.py` into `logs/agents/state.json`. This layer is
  schema-agnostic (it reads meta, not raw events) — extend it with a `provider`
  field, no parsing change needed.
- **Raw `.jsonl`** is fetched and rendered by the dashboard modal
  `dashboard/src/components/AgentRunDialog.tsx`, which assumes Claude
  stream-json event shapes (types in `dashboard/src/lib/types.ts`,
  selectors/fetch in `dashboard/src/lib/`). This is where Codex events need a
  provider-aware adapter.
- **Error detection / rate-limit parsing**: the mission names
  `didio-jsonl-errors.py` and `didio-rate-limit-lib.sh` as the Claude-schema
  consumers. These are conceptual/target modules — the implementer must locate
  the live equivalents (grep for `tool_result`, `is_error`, `usage`, `rate` in
  `bin/`) and introduce a per-provider adapter rather than branching inline
  everywhere.

## Required approach (common internal event shape)

1. Add a `provider` field to `.meta.json` (cheap, unblocks dashboard to know how
   to parse). Done in spawn-agent dispatch task.
2. Define a **common internal event shape** (e.g. `{type: assistant|tool|result|
   error|usage|rate_limit, ...}`) and a per-provider mapper:
   - `claude` mapper = identity / thin pass (preserve today's behavior exactly).
   - `codex` mapper = translate Codex `--json` events → common shape.
3. Route error-detection + rate-limit classification + the dashboard renderer
   through the mapper keyed off `meta.provider`.
4. **Graceful degradation is acceptable and must be documented:** if a Codex
   event has no analogue (e.g. no rate-limit reset timestamp), the consumer
   degrades (shows raw / "n/a") instead of crashing. AC4 allows a documented gap.

## Testing

Drive the mappers with **canned NDJSON fixtures** for both providers under
`tests/fixtures/` (a Claude stream-json sample + a Codex `--json` sample). Assert
both map to the common shape and that the Claude path is unchanged
(golden-compare against today's behavior). No real model spend.
