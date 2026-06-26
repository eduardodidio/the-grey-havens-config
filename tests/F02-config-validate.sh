#!/usr/bin/env bash
set -euo pipefail

# F02-config-validate.sh — Validate didio.config.json structure and role assignments
#
# Validates:
#   1. Every role in models/models_economy has non-empty model AND fallback
#   2. Every provider referenced exists in top-level providers
#   3. effort values are valid and only on roles whose provider honors it (claude)
#   4. max_parallel is an int >= 0; turbo/economy/highlander are booleans
#   5. Every spawned role with a prompt has a models entry (or is explicitly exempted)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$ROOT/didio.config.json}"

VIOLATIONS=0
REPORT=""

# Helper: test with a deliberately broken config
test_broken_config() {
  local desc="$1"
  local broken_config="$2"

  # Create temp file with broken config
  local tmp_broken
  tmp_broken="$(mktemp)"
  echo "$broken_config" > "$tmp_broken"
  trap "rm -f '$tmp_broken'" RETURN

  # Should fail
  if bash "$0" "$tmp_broken" 2>/dev/null; then
    VIOLATIONS=$((VIOLATIONS + 1))
    REPORT+=$'\n'"Error check FAILED: expected validation to reject broken config ($desc), but it passed"
  fi
}

# === VALIDATION 1: Every role has model and fallback ===
echo "Check 1: validating role model/fallback assignments..."
python3 - "$CONFIG" <<'PY1'
import json, sys
config_path = sys.argv[1]
with open(config_path) as f:
    c = json.load(f)

errors = []
for section in ['models', 'models_economy']:
    if section not in c:
        continue
    roles = c[section]
    for role, cfg in roles.items():
        if not isinstance(cfg, dict):
            errors.append(f"{section}: {role} is not a dict")
            continue
        if not cfg.get('model'):
            errors.append(f"{section}: {role} missing or empty 'model'")
        if not cfg.get('fallback'):
            errors.append(f"{section}: {role} missing or empty 'fallback'")

if errors:
    for err in errors:
        print(f"FAIL: {err}", file=sys.stderr)
    sys.exit(1)
print("OK")
PY1

if [[ $? -ne 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check 1 FAILED: role model/fallback validation"
fi

# === VALIDATION 2: Every provider referenced exists ===
echo "Check 2: validating provider registrations..."
python3 - "$CONFIG" <<'PY2'
import json, sys
config_path = sys.argv[1]
with open(config_path) as f:
    c = json.load(f)

errors = []
providers = set(c.get('providers', {}).keys())
providers.add('claude')  # default

# Check all roles in models and models_economy
for section in ['models', 'models_economy']:
    if section not in c:
        continue
    roles = c[section]
    for role, cfg in roles.items():
        if not isinstance(cfg, dict):
            continue
        provider = cfg.get('provider', 'claude')
        if provider not in providers:
            errors.append(f"{section}: {role} references unknown provider '{provider}'")

if errors:
    for err in errors:
        print(f"FAIL: {err}", file=sys.stderr)
    sys.exit(1)
print("OK")
PY2

if [[ $? -ne 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check 2 FAILED: provider validation"
fi

# === VALIDATION 3: effort values valid and only on Claude roles ===
echo "Check 3: validating effort assignments..."
python3 - "$CONFIG" <<'PY3'
import json, sys
config_path = sys.argv[1]
with open(config_path) as f:
    c = json.load(f)

errors = []
VALID_EFFORTS = ['low', 'medium', 'high']

for section in ['models', 'models_economy']:
    if section not in c:
        continue
    roles = c[section]
    for role, cfg in roles.items():
        if not isinstance(cfg, dict):
            continue
        if 'effort' not in cfg:
            continue

        effort = cfg['effort']
        if effort not in VALID_EFFORTS:
            errors.append(f"{section}: {role} has invalid effort '{effort}' (must be one of {VALID_EFFORTS})")

        provider = cfg.get('provider', 'claude')
        if provider != 'claude':
            errors.append(f"{section}: {role} has effort on non-Claude provider '{provider}'")

if errors:
    for err in errors:
        print(f"FAIL: {err}", file=sys.stderr)
    sys.exit(1)
print("OK")
PY3

if [[ $? -ne 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check 3 FAILED: effort validation"
fi

# === VALIDATION 4: Top-level flags are correct types ===
echo "Check 4: validating top-level flag types..."
python3 - "$CONFIG" <<'PY4'
import json, sys
config_path = sys.argv[1]
with open(config_path) as f:
    c = json.load(f)

errors = []

# Boolean flags
for flag in ['turbo', 'economy', 'highlander']:
    if flag in c and not isinstance(c[flag], bool):
        errors.append(f"'{flag}' is not a boolean (got {type(c[flag]).__name__})")

# max_parallel must be int >= 0
if 'max_parallel' in c:
    val = c['max_parallel']
    if not isinstance(val, int) or val < 0:
        errors.append(f"'max_parallel' must be int >= 0 (got {val})")

if errors:
    for err in errors:
        print(f"FAIL: {err}", file=sys.stderr)
    sys.exit(1)
print("OK")
PY4

if [[ $? -ne 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check 4 FAILED: flag type validation"
fi

# === VALIDATION 5: Spawned roles with prompts have models entries ===
echo "Check 5: validating prompt↔model coverage..."
python3 - "$CONFIG" "$ROOT" <<'PY5'
import json, sys, os
config_path, root = sys.argv[1], sys.argv[2]
with open(config_path) as f:
    c = json.load(f)

# List of roles that are spawned (from create-feature.md and elsewhere)
SPAWNED_ROLES = {
    'architect': True,
    'developer': True,
    'techlead': True,
    'qa': True,
    'readiness': True,
    'tea': True,
    'meeting-parser': True,
    't800': True,
    't1000': True,
    'narrative-designer': True,  # spawned by create-feature.md line 92
}

# Roles explicitly exempted from models requirement
EXEMPTED = {}

errors = []
prompts_dir = os.path.join(root, 'agents', 'prompts')

for role, is_spawned in SPAWNED_ROLES.items():
    if not is_spawned:
        continue

    # Check if prompt exists
    prompt_file = os.path.join(prompts_dir, f"{role}.md")
    if not os.path.exists(prompt_file):
        continue  # no prompt, no requirement

    # Check if role is in models
    if 'models' not in c or role not in c['models']:
        if role not in EXEMPTED:
            errors.append(f"Spawned role '{role}' has a prompt but no models entry (exemption: {EXEMPTED.get(role, 'none')})")

if errors:
    for err in errors:
        print(f"FAIL: {err}", file=sys.stderr)
    sys.exit(1)
print("OK")
PY5

if [[ $? -ne 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check 5 FAILED: prompt↔model coverage"
fi

# === Test error scenarios with broken configs ===
echo "Check 6: testing error detection with broken fixtures..."

# Test: missing fallback
test_broken_config "missing fallback" '{
  "models": {
    "test-role": {"model": "sonnet"}
  },
  "providers": {"claude": {"bin": "claude"}}
}'

# Test: unknown provider
test_broken_config "unknown provider" '{
  "models": {
    "test-role": {"model": "sonnet", "fallback": "haiku", "provider": "unknown-provider"}
  },
  "providers": {"claude": {"bin": "claude"}}
}'

# Test: bad max_parallel
test_broken_config "bad max_parallel" '{
  "max_parallel": "invalid",
  "models": {},
  "providers": {"claude": {"bin": "claude"}}
}'

# Test: bad turbo flag
test_broken_config "bad turbo flag" '{
  "turbo": "true",
  "models": {},
  "providers": {"claude": {"bin": "claude"}}
}'

# Test: effort on non-claude provider
test_broken_config "effort on non-claude" '{
  "models": {
    "test-role": {"model": "gpt-5", "fallback": "gpt-4", "provider": "codex", "effort": "medium"}
  },
  "providers": {"claude": {"bin": "claude"}, "codex": {"bin": "codex"}}
}'

# === Summary ===
if [[ $VIOLATIONS -eq 0 ]]; then
  echo "✓ All config validation checks passed"
  exit 0
else
  echo "$REPORT"
  exit 1
fi
