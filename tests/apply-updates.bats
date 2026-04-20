#!/usr/bin/env bats

load 'helpers/common'

@test "apply-updates: updates SHA and tag preserving indentation" {
  mkdir -p .github/workflows
  cat > .github/workflows/ci.yml <<'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@old-sha-111 # v4.2.2
EOF

  cat > actions-outdated.txt <<EOF
actions/checkout|old-sha-111|v4.2.2|de0fac2e4500dabe0009e67214ff5f5447ce83dd|v5.0.0
EOF

  run bash "${SCRIPT_DIR}/apply-updates.sh"
  [ "$status" -eq 0 ]
  run cat .github/workflows/ci.yml
  [[ "$output" == *"uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v5.0.0"* ]]
  assert_output_contains "changes_made=1"
}

@test "apply-updates: skips row with invalid SHA" {
  mkdir -p .github/workflows
  cp "${FIXTURE_DIR}/workflows/basic.yml" .github/workflows/

  cat > actions-outdated.txt <<EOF
actions/checkout|old|v4.2.2|NOT-A-SHA|v5.0.0
EOF

  run bash "${SCRIPT_DIR}/apply-updates.sh"
  [ "$status" -eq 0 ]
  assert_output_contains "changes_made=0"
}

@test "apply-updates: skips row with invalid tag" {
  mkdir -p .github/workflows
  cp "${FIXTURE_DIR}/workflows/basic.yml" .github/workflows/

  cat > actions-outdated.txt <<EOF
actions/checkout|old|v4.2.2|de0fac2e4500dabe0009e67214ff5f5447ce83dd|not-a-version
EOF

  run bash "${SCRIPT_DIR}/apply-updates.sh"
  [ "$status" -eq 0 ]
  assert_output_contains "changes_made=0"
}
