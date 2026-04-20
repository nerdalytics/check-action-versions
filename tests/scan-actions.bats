#!/usr/bin/env bats

load 'helpers/common'

@test "scan-actions: extracts actions from basic workflow" {
  mkdir -p .github/workflows
  cp "${FIXTURE_DIR}/workflows/basic.yml" .github/workflows/

  export SCAN_GLOBS=".github/workflows/*.yml"

  run bash "${SCRIPT_DIR}/scan-actions.sh"
  [ "$status" -eq 0 ]
  [ -f actions-current.txt ]

  run cat actions-current.txt
  [[ "$output" == *"actions/checkout|11bd71901bbe5b1630ceea73d27597364c9af683|v4.2.2"* ]]
  [[ "$output" == *"actions/setup-node|1a4442cacd436585916779262731d5b162bc6ec7|v3.8.2"* ]]
  assert_output_contains "action_count=2"
}

@test "scan-actions: skips local actions and reusable workflows" {
  mkdir -p .github/workflows
  cp "${FIXTURE_DIR}/workflows/malformed.yml" .github/workflows/

  export SCAN_GLOBS=".github/workflows/*.yml"

  run bash "${SCRIPT_DIR}/scan-actions.sh"
  [ "$status" -eq 0 ]
  run cat actions-current.txt
  [[ "$output" == *"actions/checkout"* ]]
  [[ "$output" != *"./local-action"* ]]
  [[ "$output" != *"reusable.yml"* ]]
  [[ "$output" != *"notvalid"* ]]
  assert_output_contains "action_count=1"
}

@test "scan-actions: emits zero count when no actions found" {
  mkdir -p .github/workflows
  cp "${FIXTURE_DIR}/workflows/no-actions.yml" .github/workflows/

  export SCAN_GLOBS=".github/workflows/*.yml"

  run bash "${SCRIPT_DIR}/scan-actions.sh"
  [ "$status" -eq 0 ]
  assert_output_contains "action_count=0"
}

@test "scan-actions: honors SCAN_GLOBS override with multiple patterns" {
  mkdir -p .github/workflows other
  cp "${FIXTURE_DIR}/workflows/basic.yml" .github/workflows/
  cp "${FIXTURE_DIR}/workflows/basic.yml" other/action.yml

  export SCAN_GLOBS=$'.github/workflows/*.yml\nother/action.yml'

  run bash "${SCRIPT_DIR}/scan-actions.sh"
  [ "$status" -eq 0 ]
  # dedupe means still 2 unique actions
  assert_output_contains "action_count=2"
}
