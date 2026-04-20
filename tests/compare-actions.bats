#!/usr/bin/env bats

load 'helpers/common'

@test "compare-actions: flags outdated when SHAs differ" {
  cat > actions-latest.txt <<EOF
actions/checkout|old-sha|v4.2.2|new-sha|v5.0.0
EOF

  run bash "${SCRIPT_DIR}/compare-actions.sh"
  [ "$status" -eq 0 ]
  run cat actions-outdated.txt
  [[ "$output" == *"actions/checkout|old-sha|v4.2.2|new-sha|v5.0.0"* ]]
  assert_output_contains "has_outdated=true"
}

@test "compare-actions: reports up-to-date when SHAs match" {
  cat > actions-latest.txt <<EOF
actions/checkout|same-sha|v5.0.0|same-sha|v5.0.0
EOF

  run bash "${SCRIPT_DIR}/compare-actions.sh"
  [ "$status" -eq 0 ]
  run cat actions-outdated.txt
  [ -z "$output" ]
  assert_output_contains "has_outdated=false"
}

@test "compare-actions: mixed — some outdated, some current" {
  cat > actions-latest.txt <<EOF
actions/checkout|sha-a|v4.2.2|sha-b|v5.0.0
actions/setup-node|sha-c|v6.0.0|sha-c|v6.0.0
EOF

  run bash "${SCRIPT_DIR}/compare-actions.sh"
  run cat actions-outdated.txt
  [[ "$output" == *"actions/checkout"* ]]
  [[ "$output" != *"actions/setup-node"* ]]
  assert_output_contains "has_outdated=true"
}
