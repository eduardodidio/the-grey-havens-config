# Axis B — Agent models

## Current config (`didio.config.json`)

- `models`: architect=opus(fb sonnet); developer/techlead/qa/readiness/tea/
  meeting-parser=sonnet(fb haiku, effort medium); t800/t1000=opus(fb sonnet).
- `models_economy`: architect=sonnet; workers=haiku; meta=sonnet.
- Flags: `turbo=false`, `economy=false`, `highlander=false`, `max_parallel=0`.
- `didio_recommend_parallel` (config-lib): opus 3-4, sonnet 5-8, haiku 8-12.

## Review questions / findings to produce

- **B1 — model↔role↔cost fit:** is opus justified for architect & meta
  (planning/governance = high-leverage, low-volume) and sonnet for the
  high-volume workers? Confirm and record the rationale.
- **B2 — prompt weight vs. model:** check each `agents/prompts/*.md` against
  its assigned model — a heavy prompt (long reasoning, multi-file synthesis)
  on a light model (haiku in economy) is a risk to flag.
- **B3 — fallback chains & effort:** every role should declare `fallback`;
  `effort` only set where the provider honors it (Claude). Codex driver
  documents `effort`/`fallback` as accepted-but-unused — keep config honest.
- **B4 — parallelism coherence:** `max_parallel=0` (unlimited) +
  `turbo=false`; `didio_recommend_parallel` tiers must cover every model the
  config actually assigns (opus/sonnet/haiku) — no tier should fall through
  to the `*` default silently.

## Constraint

- This axis must **not** edit `bin/didio-config-lib.sh` (owned by the Axis D
  injection task in the same Wave — single-writer rule). Model-tier coverage
  for `didio_recommend_parallel` is asserted by that task's test; this axis
  edits only `didio.config.json` and adds a config-validation test.

## Acceptance criteria (for the remediation task)

- A validation test (`tests/F02-config-validate.sh`) asserts: every role in
  `models`/`models_economy` has both `model` and `fallback`; every referenced
  provider exists in `providers`; `effort` only on roles whose provider
  honors it; numeric/boolean flags well-typed.
- Findings B1–B4 recorded in the task with verdict (keep / change), and any
  applied change to `didio.config.json` justified.
