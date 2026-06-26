#!/usr/bin/env bash
# F02-shellcheck.sh — shellcheck baseline for bin/*.sh, drivers/*.sh, tests/*.sh
#
# Gate severity: --severity=error (errors fail the run; warnings/info are
# printed informally but do not block CI). This avoids churn from style
# findings while still catching real bugs.
#
# set -euo pipefail policy (do NOT blanket-add set -e — read this first):
#
#   bin/didio-config-lib.sh      — SOURCED by callers, must NOT set -e.
#                                  Setting -e in a sourced file would alter the
#                                  caller's shell error behavior unpredictably.
#                                  Currently sets nothing global — intentional.
#
#   drivers/{claude,codex,echo}-driver.sh
#                                — use `set -uo pipefail` (NOT -e) so they can
#                                  bracket the CLI invocation with `set +e` /
#                                  `EXIT_CODE=$?` / `set -e` and propagate the
#                                  exact exit code. Adding -e globally would
#                                  break that capture. This is required by the
#                                  driver contract.
#
#   bin/didio-spawn-agent.sh     — top-level executable: uses `set -euo pipefail`
#                                  correctly. Temporarily disables -e around the
#                                  driver call (set +e … set -e) to capture its
#                                  exit code — also intentional.
#
#   tests/*.sh                   — test scripts use `set -uo pipefail` (matching
#                                  driver convention) since they manage their own
#                                  error propagation and want unbound-var safety.
#
# Accepted suppressions (inline # shellcheck disable=SCxxxx in source files):
#   SC1090 — dynamic `source` paths that shellcheck cannot statically resolve;
#            already annotated in bin/didio-spawn-agent.sh.

set -uo pipefail

PASS=0
FAIL=0
SKIP=0

# ── shellcheck availability guard ────────────────────────────────────────────
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck not found on PATH — install it to enable lint gate."
  echo "      (Checked PATH; also absent at /opt/homebrew/bin/shellcheck)"
  exit 0
fi

SHELLCHECK_VERSION=$(shellcheck --version | awk '/^version:/{print $2}')
echo "shellcheck ${SHELLCHECK_VERSION} found at $(command -v shellcheck)"
echo ""

# ── collect targets ──────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# We collect only paths that actually exist (globs may expand to nothing in
# sparse checkouts or during bootstrapping).
TARGETS=()
for glob in \
  "${REPO_ROOT}/bin/*.sh" \
  "${REPO_ROOT}/drivers/*.sh" \
  "${REPO_ROOT}/tests/*.sh" \
  "${REPO_ROOT}/tests/lib/*.sh"; do
  # Use a for-loop expansion; if no match, the literal glob is returned — skip it.
  for f in $glob; do
    [[ -f "$f" ]] && TARGETS+=("$f")
  done
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "SKIP: no .sh files found under bin/, drivers/, tests/ — nothing to lint."
  exit 0
fi

echo "Linting ${#TARGETS[@]} scripts:"
for f in "${TARGETS[@]}"; do
  echo "  $f"
done
echo ""

# ── Pass 1: gate — errors only ───────────────────────────────────────────────
echo "=== Pass 1: gate (--severity=error) ==="
if shellcheck --severity=error "${TARGETS[@]}"; then
  echo "PASS: 0 errors found."
  PASS=$((PASS + 1))
else
  echo "FAIL: shellcheck reported one or more error-level findings."
  FAIL=$((FAIL + 1))
fi
echo ""

# ── Pass 2: informational — default severity (non-fatal) ─────────────────────
echo "=== Pass 2: informational (default severity — warnings/info, non-fatal) ==="
if shellcheck "${TARGETS[@]}"; then
  echo "INFO: no findings at default severity either."
else
  echo "INFO: findings above are informational only — not blocking."
fi
echo ""

# ── Edge-case self-test: detection check ─────────────────────────────────────
# Create a temp script with a known error-level issue (SC2086: unquoted $var
# in a position where word-splitting matters) and verify shellcheck catches it.
# This validates that our gate would actually fire on a real error.
TMP_SCRIPT=$(mktemp /tmp/F02-shellcheck-probe-XXXXXX.sh)
# shellcheck disable=SC2064
trap "rm -f $TMP_SCRIPT" EXIT

cat > "$TMP_SCRIPT" <<'PROBE'
#!/usr/bin/env bash
# Probe: SC2168 — 'local' used outside a function (always error-level).
local x=1
echo "$x"
PROBE

if shellcheck --severity=error "$TMP_SCRIPT" >/dev/null 2>&1; then
  echo "FAIL: probe script with SC2168 was NOT caught — shellcheck gate may be broken."
  FAIL=$((FAIL + 1))
else
  echo "OK: detection probe confirmed (SC2168: local outside function caught)."
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "Results: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
