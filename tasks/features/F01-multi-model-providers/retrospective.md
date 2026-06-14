# Retrospective — F01

## What worked
- The driver-contract abstraction (`drivers/{claude,codex}-driver.sh`) plus
  golden tests made AC3 ("byte-for-byte unchanged") verifiable and gave a
  clean place to ratify a fidelity fix (carrying `--effort`/`--allowedTools`)
  without touching `didio-spawn-agent.sh` dispatch logic.
- Skill-compile to two targets (`.claude/commands/` + `~/.codex/prompts/`)
  with sentinel preservation (`{{USE_SECOND_BRAIN}}`, `{{DIDIO_CHECKPOINT}}`)
  kept AC2 mechanical and test-friendly (192 + 22 assertions).

## What to avoid
- Wiring a new compile/sync pipeline (`compile-skills` → `templates/.claude/
  commands/`) without a one-time regeneration pass over the *parallel* synced
  tree (`templates/commands/`, the real `.claude/commands` symlink target).
  This left a header-only byte-identity gap that broke F10/F14 until QA
  diffed both trees and propagated the `GENERATED FILE` header.
- Adding new top-level keys to `templates/didio.config.json` without
  grepping for `NO_CHANGE`/idempotency fixtures elsewhere in `tests/`
  (F12 scenario 2 needed its inline fixture config updated to match).
- Leaving stale ADR cross-references (`CLAUDE.md` cited ADR 0002/0003 when
  the actual files were numbered 0004/0005 due to numbering collisions with
  pre-existing ADRs).

## Patterns to repeat
- When a feature adds/regenerates generated artifacts under `templates/`,
  diff against *all* known consumers of that template (not just the one the
  new compiler writes to) before declaring done.
- When adding a top-level config schema key, grep `tests/` for
  `NO_CHANGE`/"already up to date"/idempotency assertions on that file and
  update fixtures in the same change.

## Propagated to learnings
- memory/agent-learnings/developer.md — generated-artifact pipeline +
  config-schema fixture-sync lessons (F01)
- memory/agent-learnings/qa.md — diff-both-trees check for byte-identity
  regressions, ADR cross-reference check (F01)
