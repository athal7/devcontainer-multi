#!/usr/bin/env bash
#
# Integration tests for dcexec command
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing dcexec..."
echo ""

# =============================================================================
# Setup/Teardown
# =============================================================================

setup() {
  setup_test_env
  mkdir -p "$TEST_CACHE_DIR/overrides"
  
  # Create a fake git repo
  export TEST_REPO="$TEST_DIR/test-repo"
  mkdir -p "$TEST_REPO"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
}

teardown() {
  cleanup_test_env
}

# =============================================================================
# Tests
# =============================================================================

test_dcexec_shows_help() {
  local output=$("$BIN_DIR/dcexec" --help 2>&1)
  assert_contains "$output" "Usage:"
  assert_contains "$output" "dcexec"
}

test_dcexec_requires_command() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/dcexec" 2>&1); then
    echo "Should have failed without command"
    return 1
  fi
  assert_contains "$output" "No command specified"
}

test_dcexec_errors_when_not_tracked() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/dcexec" echo hello 2>&1); then
    echo "Should have failed for untracked workspace"
    return 1
  fi
  assert_contains "$output" "No devcontainer tracked"
}

test_dcexec_accepts_workspace_flag() {
  # Add a port assignment
  local real_repo=$(cd "$TEST_REPO" && pwd -P)
  cat > "$TEST_CACHE_DIR/ports.json" << EOF
{
  "$real_repo": {
    "port": 13000,
    "repo": "test-repo",
    "branch": "main"
  }
}
EOF
  
  # This will fail because devcontainer isn't running, but it should get past the tracking check
  local output
  output=$("$BIN_DIR/dcexec" --workspace "$TEST_REPO" echo hello 2>&1) || true
  
  # Should not complain about tracking
  if [[ "$output" == *"No devcontainer tracked"* ]]; then
    echo "Should have found the tracked workspace"
    return 1
  fi
  return 0
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Command Usage Tests:"

for test_func in \
  test_dcexec_shows_help \
  test_dcexec_requires_command \
  test_dcexec_errors_when_not_tracked \
  test_dcexec_accepts_workspace_flag
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
