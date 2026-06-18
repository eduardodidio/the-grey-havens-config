#!/usr/bin/env bash
#
# Docs consistency check for F02 (F02-T10).
#
# Verifies that every `didio <subcommand>` referenced in agents/** and
# .claude/commands/** either maps to a repo bin script or is in the
# documented allow-list of global-install commands.
#
# Allow-list (documented global commands):
#   - spawn-agent: bin/didio-spawn-agent.sh (repo)
#   - run-wave, dashboard, compile-skills, providers, t800, t1000, archive, sync: global install
#   - command, commands, menu, decisions, poc-from-minutes: framework utilities (global install)

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define allow-list
declare -A ALLOW_LIST=(
  [spawn-agent]="repo (bin/didio-spawn-agent.sh)"
  [run-wave]="global install"
  [dashboard]="global install"
  [compile-skills]="global install"
  [providers]="global install"
  [t800]="global install (Gandalf meta-agent)"
  [t1000]="global install (Saruman meta-agent)"
  [archive]="global install"
  [sync]="global install"
  [command]="global install (framework)"
  [commands]="global install (framework)"
  [menu]="global install (framework)"
  [decisions]="global install (framework)"
  [poc-from-minutes]="global install (framework)"
)

FAILURES=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "Extracting didio subcommands from agents/** and .claude/commands/**..."

# Extract all didio <token> references (token must be [a-z0-9_-])
# We grep for "didio " followed by a word character pattern
FOUND_TOKENS=$(
  grep -r "didio " \
    "$ROOT_DIR/agents/" \
    "$ROOT_DIR/.claude/commands/" \
    2>/dev/null \
    | grep -oE "didio [a-z0-9_-]+" \
    | sed 's/^didio //' \
    | grep -v '^$' \
    | sort -u
)

echo "Found tokens: $FOUND_TOKENS"
echo ""

# Check each token against the allow-list
for token in $FOUND_TOKENS; do
  if [[ -v ALLOW_LIST["$token"] ]]; then
    echo "PASS: '$token' is in allow-list (${ALLOW_LIST[$token]})"
  else
    echo "FAIL: '$token' is not in allow-list"
    FAILURES=$((FAILURES + 1))
  fi
done

echo ""
check "Repo bin script spawn-agent exists" test -f "$ROOT_DIR/bin/didio-spawn-agent.sh"
check "orchestrator.md documents repo vs. global boundary" grep -q "Repo Scripts vs\. Global Install" "$ROOT_DIR/agents/orchestrator.md"
check "feature-workflow.md documents Wave orchestration boundary" grep -q "Orchestration" "$ROOT_DIR/agents/workflows/feature-workflow.md"
check "feature-workflow.md documents checkpoint/resume contract" grep -q "Checkpoint / Resume Contract" "$ROOT_DIR/agents/workflows/feature-workflow.md"
check "feature-workflow.md documents testing gate" grep -q "No Wave advances without passing tests" "$ROOT_DIR/agents/workflows/feature-workflow.md"

echo ""
if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed."
  exit 1
fi

echo "All F02 docs consistency checks passed."
