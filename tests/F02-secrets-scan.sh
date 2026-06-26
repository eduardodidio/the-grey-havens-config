#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIOLATIONS=0
REPORT=""

# Check A: no tracked artifacts or secret files
echo "Check A: verifying no tracked artifacts or secret files..."

PATTERNS=(
  "logs/agents/*.jsonl"
  "logs/agents/*.meta.json"
  "logs/agents/*.checkpoint.json"
  "logs/agents/*.ckpt.at"
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "credentials.*"
)

TRACKED_ARTIFACTS=()
while IFS= read -r file; do
  for pattern in "${PATTERNS[@]}"; do
    if [[ "$file" == $pattern ]]; then
      TRACKED_ARTIFACTS+=("$file")
      break
    fi
  done
done < <(git -C "$ROOT" ls-files 2>/dev/null || true)

if [[ ${#TRACKED_ARTIFACTS[@]} -gt 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check A FAILED: Tracked artifacts or secret files found:"
  for file in "${TRACKED_ARTIFACTS[@]}"; do
    REPORT+=$'\n'"  - $file"
  done
fi

# Check B: grep tracked files for secret patterns (exclude fixtures, docs, _brief)
echo "Check B: scanning tracked files for secret patterns..."

TRACKED_FILES=()
while IFS= read -r file; do
  TRACKED_FILES+=("$file")
done < <(git -C "$ROOT" ls-files 2>/dev/null || true)

MATCHED_SECRETS=()
for file in "${TRACKED_FILES[@]}"; do
  # Skip excluded directories and documentation. `tasks/` holds markdown task
  # specs (documentation, like docs/); this scanner itself defines the patterns
  # as literal strings and would self-match — neither contains real secrets.
  if [[ "$file" =~ ^(tests/fixtures/|tests/F02-secrets-scan\.sh|docs/|tasks/|_brief/) ]]; then
    continue
  fi

  # Skip non-existent files (e.g., deleted in working tree)
  [[ -f "$ROOT/$file" ]] || continue

  # Check secret patterns
  if grep -qE -- 'BEGIN .* PRIVATE KEY' "$ROOT/$file" || \
     grep -qE -- 'AKIA[0-9A-Z]{16}' "$ROOT/$file" || \
     grep -qE -- 'xox[baprs]-' "$ROOT/$file" || \
     grep -qE -- 'ghp_[0-9A-Za-z]{20,}' "$ROOT/$file" || \
     grep -qE -- '^-+BEGIN' "$ROOT/$file" || \
     grep -qE -- 'api[_-]?key\s*[:=]\s*['"'"'""][^'"'"'"\"]{16,}' "$ROOT/$file"; then
    MATCHED_SECRETS+=("$file")
  fi
done

if [[ ${#MATCHED_SECRETS[@]} -gt 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check B FAILED: Secret patterns found in tracked files:"
  for file in "${MATCHED_SECRETS[@]}"; do
    REPORT+=$'\n'"  - $file"
  done
fi

# Check C: scan untracked-but-not-ignored files for secret patterns.
# `git ls-files --others --exclude-standard` lists files that are neither
# tracked nor matched by .gitignore — i.e. exactly the files at risk of being
# `git add`-ed with a secret in them. Gitignored files (.env, *.pem, ...) are
# intentionally excluded; they are caught by Check A if ever tracked.
echo "Check C: scanning untracked (non-ignored) files for secret patterns..."

UNTRACKED_SECRETS=()
while IFS= read -r file; do
  # Reuse Check B's exclusions (scanner self-match, docs/specs, fixtures).
  if [[ "$file" =~ ^(tests/fixtures/|tests/F02-secrets-scan\.sh|docs/|tasks/|_brief/) ]]; then
    continue
  fi
  [[ -f "$ROOT/$file" ]] || continue
  if grep -qE -- 'BEGIN .* PRIVATE KEY' "$ROOT/$file" || \
     grep -qE -- 'AKIA[0-9A-Z]{16}' "$ROOT/$file" || \
     grep -qE -- 'xox[baprs]-' "$ROOT/$file" || \
     grep -qE -- 'ghp_[0-9A-Za-z]{20,}' "$ROOT/$file" || \
     grep -qE -- '^-+BEGIN' "$ROOT/$file" || \
     grep -qE -- 'api[_-]?key\s*[:=]\s*['"'"'""][^'"'"'"\"]{16,}' "$ROOT/$file"; then
    UNTRACKED_SECRETS+=("$file")
  fi
done < <(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

if [[ ${#UNTRACKED_SECRETS[@]} -gt 0 ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
  REPORT+=$'\n'"Check C FAILED: Secret patterns found in untracked files:"
  for file in "${UNTRACKED_SECRETS[@]}"; do
    REPORT+=$'\n'"  - $file"
  done
fi

if [[ $VIOLATIONS -eq 0 ]]; then
  echo "✓ All checks passed"
  exit 0
else
  echo "$REPORT"
  exit 1
fi
