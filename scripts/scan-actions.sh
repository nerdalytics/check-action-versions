#!/usr/bin/env bash
set -euo pipefail

# Scan workflow files for GitHub Action references.
# Inputs (env):
#   SCAN_GLOBS — newline-separated list of glob patterns
# Output: actions-current.txt (action|sha|version_comment per line)
# Output: GITHUB_OUTPUT action_count

: "${SCAN_GLOBS:?SCAN_GLOBS env var is required}"

declare -A SEEN
ACTION_COUNT=0

# Expand SCAN_GLOBS (newline-separated) to a file list
mapfile -t WORKFLOWS < <(
  while IFS= read -r glob; do
    [[ -z "$glob" ]] && continue
    # shellcheck disable=SC2086
    compgen -G "$glob" || true
  done <<<"$SCAN_GLOBS"
)

for workflow in "${WORKFLOWS[@]}"; do
  [[ -f "$workflow" ]] || continue
  while IFS= read -r line; do
    if [[ "$line" =~ uses:[[:space:]]*([^@]+)@([^[:space:]#]+)([[:space:]]*#[[:space:]]*(.*))? ]]; then
      action="${BASH_REMATCH[1]}"
      sha="${BASH_REMATCH[2]}"
      comment="${BASH_REMATCH[4]:-}"
      action="${action## }"
      action="${action%% }"
      comment="${comment## }"
      comment="${comment%% }"
      if [[ "$action" == ./* ]] || [[ "$action" == .github/* ]]; then
        continue
      fi
      if [[ ! "$action" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        continue
      fi
      if [[ -n "${SEEN[$action]:-}" ]]; then
        continue
      fi
      SEEN[$action]=1
      echo "${action}|${sha}|${comment}"
      ((ACTION_COUNT++)) || true
    fi
  done <"$workflow"
done >actions-current.txt

echo "Found ${ACTION_COUNT} unique actions"
echo "action_count=${ACTION_COUNT}" >>"$GITHUB_OUTPUT"
