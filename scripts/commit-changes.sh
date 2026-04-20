#!/usr/bin/env bash
set -euo pipefail

# Create branch, stage workflow changes, and commit.
# Input: actions-outdated.txt (for count)
# Output: GITHUB_OUTPUT has_changes, branch_name

: "${BRANCH_NAME:?BRANCH_NAME env var is required}"
COMMIT_PREFIX="${COMMIT_PREFIX:-}"

git checkout -B "$BRANCH_NAME"
git add .github/workflows/*.yml

if git diff --cached --quiet; then
  echo "No changes to commit"
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

OUTDATED_COUNT=$(wc -l < actions-outdated.txt | tr -d ' ')
if [[ -n "$COMMIT_PREFIX" ]]; then
  COMMIT_MSG="${COMMIT_PREFIX} update ${OUTDATED_COUNT} GitHub Action(s) to latest versions"
else
  COMMIT_MSG="Update ${OUTDATED_COUNT} GitHub Action(s) to latest versions"
fi

git commit -m "${COMMIT_MSG}

Updates actions to SHA-pinned versions for security.
See workflow file changes for details."

echo "has_changes=true" >> "$GITHUB_OUTPUT"
echo "branch_name=${BRANCH_NAME}" >> "$GITHUB_OUTPUT"
