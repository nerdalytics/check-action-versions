#!/usr/bin/env bats

load 'helpers/common'

@test "resolve-latest: resolves release tag and SHA for a single action" {
  export RATE_LIMIT_SLEEP=0
  cat > actions-current.txt <<EOF
actions/checkout|old-sha|v4.2.2
EOF

  run bash "${SCRIPT_DIR}/resolve-latest.sh"
  [ "$status" -eq 0 ]
  [ -f actions-latest.txt ]
  run cat actions-latest.txt
  [[ "$output" == "actions/checkout|old-sha|v4.2.2|de0fac2e4500dabe0009e67214ff5f5447ce83dd|v5.0.0" ]]
}

@test "resolve-latest: handles multiple actions" {
  export RATE_LIMIT_SLEEP=0
  cat > actions-current.txt <<EOF
actions/checkout|old-sha-1|v4.2.2
actions/setup-node|old-sha-2|v3.8.2
EOF

  run bash "${SCRIPT_DIR}/resolve-latest.sh"
  [ "$status" -eq 0 ]
  run cat actions-latest.txt
  [[ "$output" == *"actions/checkout|old-sha-1|v4.2.2|de0fac2e4500dabe0009e67214ff5f5447ce83dd|v5.0.0"* ]]
  [[ "$output" == *"actions/setup-node|old-sha-2|v3.8.2|53b83947a5a98c8d113130e565377fae1a50d02f|v6.0.0"* ]]
}

@test "resolve-latest: skips action when latest SHA is invalid" {
  skip "requires bad-SHA fixture — add in a follow-up"
}
