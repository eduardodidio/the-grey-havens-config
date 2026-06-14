# Component C — CLI / UX / config surface

## `didio` entry point (`${DIDIO_HOME}/bin/didio`)

Dispatch `case "$SUBCMD"` with `exec` to the matching `bin/didio-*.sh`. Existing:
`spawn-agent`, `run-wave`, `dashboard`, `log-watcher`, `easter-egg`,
`sync-project`, `sync-all`, `menu`, `version`, `help`. The `help` heredoc must be
extended for any new subcommand.

New subcommands to add:

- `didio compile-skills [--dry-run] [--target claude|codex|all]` → exec
  `bin/didio-compile-skills.sh`. (Component B.)
- `didio providers [list|validate]` → exec a new `bin/didio-providers.sh` that
  lists configured providers and validates the relevant CLI binary exists on
  `PATH` (`command -v claude`, `command -v codex`) and, where feasible, is
  authed. `validate` returns non-zero if a configured provider's binary is
  missing.

## Config schema (`didio.config.json` + `templates/didio.config.json`)

Current shape (relevant keys): `economy` (bool), `models.<role>{model,fallback,
effort}`, `models_economy.<role>{...}`. Roles present: architect, developer,
techlead, qa, readiness, tea, meeting-parser, t800, t1000.

Additions (backward-compatible — every new key optional, absence ⇒ Claude):

```jsonc
{
  "providers": {
    "claude": { "bin": "claude", "default": true },
    "codex":  { "bin": "codex" }
  },
  "models": {
    "developer": { "provider": "claude", "model": "sonnet", "fallback": "haiku", "effort": "medium" },
    "techlead":  { "provider": "codex",  "model": "gpt-5-codex" }
  },
  "models_economy": {
    "developer": { "provider": "codex", "model": "o4-mini" }
  }
}
```

- `provider` is read per role; absent ⇒ `claude` (AC3).
- Codex needs an **economy-equivalent**: `models_economy.<role>` already exists;
  just allow `provider`+Codex model ids there.
- The template at `${DIDIO_HOME}/templates/didio.config.json` (copied by
  `didio_write_config` fallback and sync) must include the `providers` block and
  documented commented examples, while keeping all roles on Claude by default.

## Preflight (doctor-style gate before a Wave)

`bin/didio-run-wave.sh` (and/or `didio-spawn-agent.sh`) must verify, before
launching, that every role's configured provider binary is installed/authed —
reusing `didio providers validate`. On failure: clear message naming the missing
binary + how to install/auth, and abort the Wave (do not spend a half-run).
Claude-only projects with no `codex` configured must NOT be blocked by a missing
`codex` binary (only validate providers actually in use this Wave).
