#!/usr/bin/env bash
#
# Docs check for F01 diagrams (F01-T16).
#
# Verifies:
#  - docs/diagrams/F01-architecture.mmd and F01-journey.mmd exist
#  - both parse as valid Mermaid (via mermaid-cli if available, else a
#    structural check for flowchart/subgraph)
#  - architecture diagram references the provider-driver split and the
#    skills-compiler flow (drivers/, didio-compile-skills.sh, normalizer)
#  - journey diagram includes both the success path and the preflight
#    abort branch

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="$ROOT_DIR/docs/diagrams/F01-architecture.mmd"
JOURNEY="$ROOT_DIR/docs/diagrams/F01-journey.mmd"

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

check "F01-architecture.mmd exists" test -f "$ARCH"
check "F01-journey.mmd exists" test -f "$JOURNEY"

if [ -f "$ARCH" ] && [ -f "$JOURNEY" ]; then
  if command -v mmdc >/dev/null 2>&1; then
    check "F01-architecture.mmd parses with mermaid-cli" \
      mmdc -i "$ARCH" -o /tmp/F01-architecture-check.svg
    check "F01-journey.mmd parses with mermaid-cli" \
      mmdc -i "$JOURNEY" -o /tmp/F01-journey-check.svg
  else
    check "F01-architecture.mmd has flowchart/subgraph structure" \
      bash -c "grep -qE '^\s*flowchart' '$ARCH' && grep -q 'subgraph' '$ARCH'"
    check "F01-journey.mmd has flowchart/subgraph structure" \
      bash -c "grep -qE '^\s*flowchart' '$JOURNEY' && grep -q 'subgraph' '$JOURNEY'"
  fi

  # Architecture: provider-driver split + skills-compiler flow
  check "architecture references drivers/" grep -q "drivers/" "$ARCH"
  check "architecture references claude-driver.sh" grep -q "claude-driver.sh" "$ARCH"
  check "architecture references codex-driver.sh" grep -q "codex-driver.sh" "$ARCH"
  check "architecture references didio-compile-skills.sh" grep -q "didio-compile-skills.sh" "$ARCH"
  check "architecture references didio-config-lib.sh" grep -q "didio-config-lib.sh" "$ARCH"
  check "architecture references didio-spawn-agent.sh" grep -q "didio-spawn-agent.sh" "$ARCH"
  check "architecture references event normalizer" grep -qi "normaliz" "$ARCH"

  # Journey: success path + preflight abort branch
  check "journey references preflight" grep -qi "preflight" "$JOURNEY"
  check "journey references abort branch" grep -qi "abort" "$JOURNEY"
  check "journey references claude provider dispatch" grep -q "claude" "$JOURNEY"
  check "journey references codex provider dispatch" grep -q "codex" "$JOURNEY"
fi

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed."
  exit 1
fi

echo "All F01 docs checks passed."
