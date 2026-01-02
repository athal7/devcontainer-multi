#!/usr/bin/env bash
#
# Integration tests for ocdc-go command
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing ocdc-go..."
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

test_ocdc_go_shows_help() {
  local output=$("$BIN_DIR/ocdc" go --help 2>&1)
  assert_contains "$output" "Usage:"
  assert_contains "$output" "ocdc-go"
}

test_ocdc_go_lists_clones_when_no_args() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/ocdc" go 2>&1)
  assert_contains "$output" "Available clones"
}

test_ocdc_go_shows_no_clones_message() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/ocdc" go 2>&1)
  assert_contains "$output" "No clones found"
}

test_ocdc_go_lists_existing_clones() {
  # Create a clone directory
  mkdir -p "$TEST_CLONES_DIR/test-repo/feature-branch"
  
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/ocdc" go 2>&1)
  assert_contains "$output" "feature-branch"
}

test_ocdc_go_errors_on_missing_clone() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/ocdc" go nonexistent-branch 2>&1); then
    echo "Should have failed for missing clone"
    return 1
  fi
  assert_contains "$output" "Clone not found"
}

test_ocdc_go_outputs_cd_command() {
  # Create a clone directory
  mkdir -p "$TEST_CLONES_DIR/test-repo/feature-branch"
  
  # Unset TERM_PROGRAM to avoid VS Code detection
  unset TERM_PROGRAM
  
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/ocdc" go feature-branch 2>&1)
  assert_contains "$output" "cd "
  assert_contains "$output" "feature-branch"
}

test_ocdc_go_fails_outside_repo_without_branch() {
  cd "$TEST_DIR"
  local output
  if output=$("$BIN_DIR/ocdc" go 2>&1); then
    echo "Should have failed outside git repo"
    return 1
  fi
  assert_contains "$output" "Not in a git repository"
}

# =============================================================================
# Repo Flag Tests
# =============================================================================

test_ocdc_go_help_shows_repo_flag() {
  local output=$("$BIN_DIR/ocdc" go --help 2>&1)
  assert_contains "$output" "--repo"
}

test_ocdc_go_resolves_with_repo_flag() {
  # Create clone directories for two repos with same branch name
  mkdir -p "$TEST_CLONES_DIR/repo1/main"
  mkdir -p "$TEST_CLONES_DIR/repo2/main"
  
  # Unset TERM_PROGRAM to avoid VS Code detection
  unset TERM_PROGRAM
  
  cd "$TEST_DIR"  # Not in a git repo
  local output=$("$BIN_DIR/ocdc" go --repo repo1 main 2>&1)
  
  # Should output cd command to repo1's clone
  assert_contains "$output" "cd "
  assert_contains "$output" "repo1/main"
}

test_ocdc_go_repo_flag_short_form() {
  mkdir -p "$TEST_CLONES_DIR/myrepo/feature"
  
  unset TERM_PROGRAM
  
  cd "$TEST_DIR"
  local output=$("$BIN_DIR/ocdc" go -r myrepo feature 2>&1)
  
  assert_contains "$output" "cd "
  assert_contains "$output" "myrepo/feature"
}

test_ocdc_go_warns_on_ambiguous_branch() {
  # Create ports.json with two workspaces same branch different repos
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/test/clones/repo1/develop": {
    "port": 13000,
    "repo": "repo1",
    "branch": "develop",
    "started": "2024-01-01T10:00:00Z"
  },
  "/test/clones/repo2/develop": {
    "port": 13001,
    "repo": "repo2",
    "branch": "develop",
    "started": "2024-01-02T10:00:00Z"
  }
}
EOF
  
  # Create the clone directories
  mkdir -p "$TEST_CLONES_DIR/repo1/develop"
  mkdir -p "$TEST_CLONES_DIR/repo2/develop"
  
  unset TERM_PROGRAM
  
  cd "$TEST_DIR"
  local output=$("$BIN_DIR/ocdc" go develop 2>&1)
  
  # Should warn about ambiguity
  assert_contains "$output" "Multiple workspaces match"
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Command Usage Tests:"

for test_func in \
  test_ocdc_go_shows_help \
  test_ocdc_go_lists_clones_when_no_args \
  test_ocdc_go_shows_no_clones_message \
  test_ocdc_go_lists_existing_clones \
  test_ocdc_go_errors_on_missing_clone \
  test_ocdc_go_outputs_cd_command \
  test_ocdc_go_fails_outside_repo_without_branch \
  test_ocdc_go_help_shows_repo_flag \
  test_ocdc_go_resolves_with_repo_flag \
  test_ocdc_go_repo_flag_short_form \
  test_ocdc_go_warns_on_ambiguous_branch
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
