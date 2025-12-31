#!/usr/bin/env bash
#
# Integration tests for dcup command
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing dcup..."
echo ""

# =============================================================================
# Setup/Teardown
# =============================================================================

setup() {
  setup_test_env
  
  # Create a fake git repo with devcontainer.json
  export TEST_REPO="$TEST_DIR/test-repo"
  mkdir -p "$TEST_REPO/.devcontainer"
  
  cat > "$TEST_REPO/.devcontainer/devcontainer.json" << 'EOF'
{
  "name": "Test Container",
  "image": "node:18",
  "forwardPorts": [3000]
}
EOF
  
  # Initialize git repo
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "Initial commit"
  
  # Override config paths for testing
  export CONFIG_DIR="$TEST_CONFIG_DIR"
  export CACHE_DIR="$TEST_CACHE_DIR"
  export CLONES_DIR="$TEST_CLONES_DIR"
}

teardown() {
  cleanup_test_env
}

# =============================================================================
# Tests
# =============================================================================

test_dcup_shows_help() {
  local output=$("$BIN_DIR/dcup" --help 2>&1)
  assert_contains "$output" "Usage:"
  assert_contains "$output" "dcup"
}

test_dcup_fails_outside_git_repo() {
  cd "$TEST_DIR"
  local output
  if output=$("$BIN_DIR/dcup" 2>&1); then
    echo "Should have failed outside git repo"
    return 1
  fi
  assert_contains "$output" "Not in a git repository"
}

test_dcup_fails_without_devcontainer_json() {
  # Create repo without devcontainer.json
  local bare_repo="$TEST_DIR/bare-repo"
  mkdir -p "$bare_repo"
  git -C "$bare_repo" init -q
  
  cd "$bare_repo"
  local output
  if output=$("$BIN_DIR/dcup" 2>&1); then
    echo "Should have failed without devcontainer.json"
    return 1
  fi
  assert_contains "$output" "No devcontainer.json found"
}

test_dcup_detects_workspace() {
  cd "$TEST_REPO"
  # Use --no-open and capture output (will fail at devcontainer up, but that's ok)
  local output=$("$BIN_DIR/dcup" --no-open 2>&1 || true)
  assert_contains "$output" "Workspace:"
  assert_contains "$output" "$TEST_REPO"
}

test_dcup_assigns_port() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcup" --no-open 2>&1 || true)
  assert_contains "$output" "Port mapping:"
  assert_contains "$output" "localhost:13"  # Port in 13000 range
}

test_dcup_creates_clone_for_branch() {
  cd "$TEST_REPO"
  
  # Create a branch first
  git checkout -q -b test-branch
  git checkout -q main 2>/dev/null || git checkout -q master
  
  local output=$("$BIN_DIR/dcup" test-branch --no-open 2>&1 || true)
  assert_contains "$output" "clone"
}

test_dcup_no_open_flag_works() {
  cd "$TEST_REPO"
  local output=$("$BIN_DIR/dcup" --no-open 2>&1 || true)
  # Should not contain "Opening" message
  if [[ "$output" == *"Opening in VS Code"* ]]; then
    echo "Should not attempt to open VS Code with --no-open"
    return 1
  fi
  return 0
}

# =============================================================================
# Run Tests
# =============================================================================

echo "Command Usage Tests:"

# Run each test with setup/teardown
for test_func in \
  test_dcup_shows_help \
  test_dcup_fails_outside_git_repo \
  test_dcup_fails_without_devcontainer_json \
  test_dcup_detects_workspace \
  test_dcup_assigns_port \
  test_dcup_creates_clone_for_branch \
  test_dcup_no_open_flag_works
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
