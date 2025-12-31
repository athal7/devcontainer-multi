#!/usr/bin/env bash
#
# Integration tests for dcgo command
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing dcgo..."
echo ""

# =============================================================================
# Setup/Teardown
# =============================================================================

setup() {
  setup_test_env
  
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

test_dcgo_shows_help() {
  local output=$("$BIN_DIR/dcgo" --help 2>&1)
  assert_contains "$output" "Usage:"
  assert_contains "$output" "dcgo"
}

test_dcgo_lists_clones_when_no_args() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcgo" 2>&1)
  assert_contains "$output" "Available clones"
}

test_dcgo_shows_no_clones_message() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcgo" 2>&1)
  assert_contains "$output" "No clones found"
}

test_dcgo_lists_existing_clones() {
  # Create a clone directory
  mkdir -p "$TEST_CLONES_DIR/test-repo/feature-branch"
  
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcgo" 2>&1)
  assert_contains "$output" "feature-branch"
}

test_dcgo_errors_on_missing_clone() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/dcgo" nonexistent-branch 2>&1); then
    echo "Should have failed for missing clone"
    return 1
  fi
  assert_contains "$output" "Clone not found"
}

test_dcgo_outputs_cd_command() {
  # Create a clone directory
  mkdir -p "$TEST_CLONES_DIR/test-repo/feature-branch"
  
  # Unset TERM_PROGRAM to avoid VS Code detection
  unset TERM_PROGRAM
  
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcgo" feature-branch 2>&1)
  assert_contains "$output" "cd "
  assert_contains "$output" "feature-branch"
}

test_dcgo_fails_outside_repo_without_branch() {
  cd "$TEST_DIR"
  local output
  if output=$("$BIN_DIR/dcgo" 2>&1); then
    echo "Should have failed outside git repo"
    return 1
  fi
  assert_contains "$output" "Not in a git repository"
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Command Usage Tests:"

for test_func in \
  test_dcgo_shows_help \
  test_dcgo_lists_clones_when_no_args \
  test_dcgo_shows_no_clones_message \
  test_dcgo_lists_existing_clones \
  test_dcgo_errors_on_missing_clone \
  test_dcgo_outputs_cd_command \
  test_dcgo_fails_outside_repo_without_branch
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
