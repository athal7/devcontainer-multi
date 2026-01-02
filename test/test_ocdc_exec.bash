#!/usr/bin/env bash
#
# Integration tests for ocdc-exec command
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing ocdc-exec..."
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

test_ocdc_exec_shows_help() {
  local output=$("$BIN_DIR/ocdc" exec --help 2>&1)
  assert_contains "$output" "Usage:"
  assert_contains "$output" "ocdc-exec"
}

test_ocdc_exec_requires_command() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/ocdc" exec 2>&1); then
    echo "Should have failed without command"
    return 1
  fi
  assert_contains "$output" "No command specified"
}

test_ocdc_exec_errors_when_not_tracked() {
  cd "$TEST_REPO"
  local output
  if output=$("$BIN_DIR/ocdc" exec echo hello 2>&1); then
    echo "Should have failed for untracked workspace"
    return 1
  fi
  assert_contains "$output" "No devcontainer tracked"
}

test_ocdc_exec_accepts_workspace_flag() {
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
  output=$("$BIN_DIR/ocdc" exec --workspace "$TEST_REPO" -- echo hello 2>&1) || true
  
  # Should not complain about tracking
  if [[ "$output" == *"No devcontainer tracked"* ]]; then
    echo "Should have found the tracked workspace"
    return 1
  fi
  return 0
}

# =============================================================================
# Branch Identifier Tests
# =============================================================================

test_ocdc_exec_resolves_branch_identifier() {
  # Set up ports.json with a workspace
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/feature-branch": {
    "port": 13000,
    "repo": "myrepo",
    "branch": "feature-branch",
    "started": "2024-01-01T10:00:00Z"
  }
}
EOF
  
  # This will fail at devcontainer exec, but should get past identifier resolution
  local output
  output=$("$BIN_DIR/ocdc" exec feature-branch -- echo hello 2>&1) || true
  
  # Should NOT say "No workspace found"
  if [[ "$output" == *"No workspace found"* ]]; then
    echo "Should have resolved the branch identifier"
    echo "Output: $output"
    return 1
  fi
  return 0
}

test_ocdc_exec_resolves_branch_with_repo_flag() {
  # Set up ports.json with two workspaces, same branch different repos
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/repo1/main": {
    "port": 13000,
    "repo": "repo1",
    "branch": "main",
    "started": "2024-01-01T10:00:00Z"
  },
  "/path/to/repo2/main": {
    "port": 13001,
    "repo": "repo2",
    "branch": "main",
    "started": "2024-01-01T11:00:00Z"
  }
}
EOF
  
  # Should resolve to repo1 when --repo is specified
  local output
  output=$("$BIN_DIR/ocdc" exec --repo repo1 main -- echo hello 2>&1) || true
  
  # Should NOT say "No workspace found"
  if [[ "$output" == *"No workspace found"* ]]; then
    echo "Should have resolved with --repo flag"
    echo "Output: $output"
    return 1
  fi
  
  # Should NOT warn about ambiguity (because repo was specified)
  if [[ "$output" == *"Multiple workspaces match"* ]]; then
    echo "Should not warn when repo is explicitly specified"
    echo "Output: $output"
    return 1
  fi
  return 0
}

test_ocdc_exec_errors_on_unknown_branch() {
  echo '{}' > "$TEST_CACHE_DIR/ports.json"
  
  local output
  if output=$("$BIN_DIR/ocdc" exec nonexistent-branch -- echo hello 2>&1); then
    echo "Should have failed for unknown branch"
    return 1
  fi
  
  assert_contains "$output" "No workspace found"
}

test_ocdc_exec_without_separator_uses_current_dir() {
  # Without --, all args are treated as the command and current dir is used
  cd "$TEST_REPO"
  
  local output
  if output=$("$BIN_DIR/ocdc" exec feature echo hello 2>&1); then
    echo "Should have failed (untracked workspace)"
    return 1
  fi
  
  # Should try to use current dir (which is untracked), not resolve "feature" as branch
  assert_contains "$output" "No devcontainer tracked"
}

test_ocdc_exec_with_separator_uses_identifier() {
  # With --, arg before separator is the identifier
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/feature": {
    "port": 13000,
    "repo": "myrepo",
    "branch": "feature",
    "started": "2024-01-01T10:00:00Z"
  }
}
EOF
  
  # With --, "feature" is the identifier
  local output
  output=$("$BIN_DIR/ocdc" exec feature -- echo hello 2>&1) || true
  
  # Should NOT say "No devcontainer tracked" for current dir
  # (it should have resolved "feature" to /path/to/feature)
  if [[ "$output" == *"No devcontainer tracked for:"*"$TEST_REPO"* ]]; then
    echo "Should have used identifier, not current dir"
    echo "Output: $output"
    return 1
  fi
  return 0
}

test_ocdc_exec_help_shows_identifier_usage() {
  local output=$("$BIN_DIR/ocdc" exec --help 2>&1)
  assert_contains "$output" "--repo"
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Command Usage Tests:"

for test_func in \
  test_ocdc_exec_shows_help \
  test_ocdc_exec_requires_command \
  test_ocdc_exec_errors_when_not_tracked \
  test_ocdc_exec_accepts_workspace_flag \
  test_ocdc_exec_resolves_branch_identifier \
  test_ocdc_exec_resolves_branch_with_repo_flag \
  test_ocdc_exec_errors_on_unknown_branch \
  test_ocdc_exec_without_separator_uses_current_dir \
  test_ocdc_exec_with_separator_uses_identifier \
  test_ocdc_exec_help_shows_identifier_usage
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
