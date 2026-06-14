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
