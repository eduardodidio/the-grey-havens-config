#!/usr/bin/env bash
# didio-spawn-agent.sh — launch a single agent in an isolated bash context via
# its configured provider's driver (drivers/<provider>-driver.sh). Streams
# output as JSONL to logs/agents/ for the dashboard and for auditing.
#
# Usage:
#   didio-spawn-agent.sh <role> <feature-id> <task-file> [extra-prompt]
#
# Roles: architect | developer | techlead | qa
#
# The agent prompt is composed as:
#   <role-prompt-from-agents/prompts/>  +  task context  +  optional extra
#
# The feature-id, task-file path and timestamp compose the log filename, so
# multiple agents from the same Wave can run in parallel without clobbering.

set -euo pipefail

ROLE="${1:?role required: architect|developer|techlead|qa}"
FEATURE="${2:?feature-id required (e.g. F01)}"
TASK_FILE="${3:?task-file required (absolute or relative path)}"
EXTRA="${4:-}"

PROJECT_ROOT="$(pwd)"
AGENTS_DIR="$PROJECT_ROOT/agents"
PROMPT_FILE="$AGENTS_DIR/prompts/${ROLE}.md"
LOG_DIR="$PROJECT_ROOT/logs/agents"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[didio-spawn-agent] role prompt not found: $PROMPT_FILE" >&2
  echo "[didio-spawn-agent] is this a claude-didio-config project? run /install-claude-didio-framework first" >&2
  exit 2
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[didio-spawn-agent] task file not found: $TASK_FILE" >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
TASK_ID="$(basename "$TASK_FILE" .md)"
LOG_FILE="$LOG_DIR/${FEATURE}-${ROLE}-${TASK_ID}-${TS}.jsonl"
META_FILE="${LOG_FILE%.jsonl}.meta.json"

# Resolve model/provider for this role from didio.config.json.
# Prefer project-local lib (newer helpers) over the global install fallback.
if [[ -f "$PROJECT_ROOT/bin/didio-config-lib.sh" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/bin/didio-config-lib.sh"
else
  # shellcheck disable=SC1090
  source "${DIDIO_HOME:-$HOME/.claude-didio-config}/bin/didio-config-lib.sh"
fi
AGENT_MODEL=$(didio_model_for_role "$ROLE")
AGENT_FALLBACK=$(didio_fallback_for_role "$ROLE")
PROVIDER="$(didio_provider_for_role "$ROLE")"

AGENT_EFFORT=""
if declare -F didio_effort_for_role >/dev/null 2>&1; then
  AGENT_EFFORT="$(didio_effort_for_role "$ROLE" 2>/dev/null || true)"
fi

DRIVER="${DIDIO_HOME:-$HOME/.claude-didio-config}/drivers/${PROVIDER}-driver.sh"
if [[ -f "$PROJECT_ROOT/drivers/${PROVIDER}-driver.sh" ]]; then
  DRIVER="$PROJECT_ROOT/drivers/${PROVIDER}-driver.sh"
fi
if [[ ! -x "$DRIVER" ]]; then
  echo "[didio-spawn-agent] unknown/unsupported provider '$PROVIDER'" >&2
  exit 2
fi

# Meta header for dashboard consumption — built via python3/json.dump so that
# task ids or paths containing quotes or newlines can't produce invalid JSON.
python3 - "$META_FILE" "$FEATURE" "$ROLE" "$TASK_ID" "$TASK_FILE" \
  "$LOG_FILE" "$$" "${AGENT_MODEL:-default}" "${AGENT_FALLBACK:-none}" \
  "$PROVIDER" <<'PY'
import json, sys
from datetime import datetime, timezone
(path, feature, role, task, task_file,
 log, pid, model, fallback, provider) = sys.argv[1:11]
m = {
    "feature": feature,
    "role": role,
    "task": task,
    "task_file": task_file,
    "started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "log": log,
    "status": "running",
    "pid": int(pid),
    "model": model,
    "fallback_model": fallback,
    "provider": provider,
}
with open(path, "w") as f:
    json.dump(m, f, indent=2)
    f.write("\n")
PY

# Compose the prompt: role instructions + task body + optional extra
ROLE_PROMPT="$(cat "$PROMPT_FILE")"
TASK_BODY="$(cat "$TASK_FILE")"

# Substitute the {{USE_SECOND_BRAIN}} sentinel based on second_brain.enabled.
# Helpers return "true"/"false"; if unavailable (older config-lib installed),
# default to "false" so the prompt falls back to the local learnings file.
SB_ENABLED="false"
if declare -F didio_second_brain_enabled >/dev/null 2>&1; then
  SB_ENABLED="$(didio_second_brain_enabled 2>/dev/null || echo "false")"
fi
ROLE_PROMPT="${ROLE_PROMPT//\{\{USE_SECOND_BRAIN\}\}/$SB_ENABLED}"

FULL_PROMPT=$(cat <<PROMPT
$ROLE_PROMPT

---

You are working on feature **$FEATURE**, task **$TASK_ID**.

Task details:

$TASK_BODY

---

$EXTRA

Constraints:
- You are running in a clean, isolated context. You do not share memory with
  other agents. All facts you need must come from the task file, the project
  files, or the role prompt above.
- Write your work directly to files in the project.
- When done, print a one-line summary starting with "DIDIO_DONE:".
PROMPT
)

echo "[didio-spawn-agent] role=$ROLE feature=$FEATURE task=$TASK_ID model=$AGENT_MODEL log=$LOG_FILE" >&2

# Launch the resolved provider driver in a new process, clean env. We inherit
# PATH so the provider CLI is findable, but we deliberately do not pass any
# other state — the agent's context is ONLY the prompt.
export DIDIO_PROMPT="$FULL_PROMPT"
export DIDIO_MODEL="$AGENT_MODEL"
export DIDIO_FALLBACK="$AGENT_FALLBACK"
export DIDIO_EFFORT="$AGENT_EFFORT"
export DIDIO_LOG_FILE="$LOG_FILE"
export DIDIO_ROLE="$ROLE"
export DIDIO_FEATURE="$FEATURE"
export DIDIO_TASK_ID="$TASK_ID"

set +e
"$DRIVER"
EXIT_CODE=$?
set -e

# Update meta with final status
FINAL_STATUS="completed"
[[ $EXIT_CODE -ne 0 ]] && FINAL_STATUS="failed"

# Pick a thematic phrase for this role+outcome (may be empty if disabled)
PHRASE=""
if [[ -x "${DIDIO_HOME:-$HOME/.claude-didio-config}/bin/didio-easter-egg.sh" ]]; then
  PHRASE="$("${DIDIO_HOME:-$HOME/.claude-didio-config}/bin/didio-easter-egg.sh" "$ROLE" "$EXIT_CODE" || true)"
fi

# Rewrite meta atomically with final status, timestamp, and phrase
python3 - "$META_FILE" "$FINAL_STATUS" "$EXIT_CODE" "$PHRASE" <<'PY' || true
import json, sys
from datetime import datetime, timezone
path, status, code, phrase = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
with open(path) as f:
    m = json.load(f)
m["status"] = status
m["exit_code"] = code
m["finished_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
if phrase:
    m["phrase"] = phrase
with open(path, "w") as f:
    json.dump(m, f, indent=2)
PY

[[ -n "$PHRASE" ]] && echo "$PHRASE" >&2
echo "[didio-spawn-agent] $ROLE/$TASK_ID -> $FINAL_STATUS (exit=$EXIT_CODE)" >&2

PROGRESS_LIB="${DIDIO_HOME:-$HOME/.claude-didio-config}/bin/didio-progress-lib.sh"
if [[ -f "$PROGRESS_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$PROGRESS_LIB"
  didio_feature_progress "$FEATURE" >&2 || true
fi

exit $EXIT_CODE
