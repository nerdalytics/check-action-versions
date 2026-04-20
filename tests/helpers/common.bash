#!/usr/bin/env bash

# Common setup invoked by every bats test file.
# Provides: $TMPDIR (per-test), $REPO_ROOT, $SCRIPT_DIR, mock gh on PATH.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT_DIR="${REPO_ROOT}/scripts"
FIXTURE_DIR="${REPO_ROOT}/tests/fixtures"

setup() {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  # Provide GITHUB_OUTPUT so scripts can write to it
  export GITHUB_OUTPUT="${TMPDIR}/github_output"
  touch "$GITHUB_OUTPUT"
  # Prepend mock gh
  export PATH="${REPO_ROOT}/tests/helpers/bin:${PATH}"
}

teardown() {
  rm -rf "$TMPDIR"
}

# Helper: assert a key=value pair exists in GITHUB_OUTPUT
assert_output_contains() {
  local expected="$1"
  grep -F "$expected" "$GITHUB_OUTPUT"
}
