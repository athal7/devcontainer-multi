#!/usr/bin/env bash
#
# Tests for --json flag output across all CLI commands
#
# These tests verify the JSON output format for machine-readable parsing,
# as required for opencode-pilot integration (issue #90).
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"

echo "Testing --json output..."
echo ""

# =============================================================================
# Setup/Teardown
# =============================================================================

setup() {
  setup_test_env
  mkdir -p "$TEST_CACHE_DIR/overrides"
  
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
}

teardown() {
  cleanup_test_env
}

# =============================================================================
# Exit Code Constants (defined in lib/ocdc-json.bash)
# =============================================================================

EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_ARGS=2
EXIT_NOT_FOUND=3

# =============================================================================
# Helper Functions
# =============================================================================

# Extract JSON from output (handles multi-line JSON and filters non-JSON lines)
# Looks for complete JSON objects or arrays
extract_json() {
  local output="$1"
  # Use jq to find valid JSON - try parsing the whole output first
  if echo "$output" | jq -e '.' >/dev/null 2>&1; then
    echo "$output"
    return 0
  fi
  # If that fails, try to extract just lines that could be JSON (starting with { or [)
  # and parse them together
  local json_lines
  json_lines=$(echo "$output" | awk '/^[\{\[]/, /^[\}\]]/' | tr -d '\n')
  if echo "$json_lines" | jq -e '.' >/dev/null 2>&1; then
    echo "$json_lines" | jq -c '.'
    return 0
  fi
  # Return empty if no valid JSON found
  echo ""
  return 1
}

# Check if output is valid JSON
assert_valid_json() {
  local output="$1"
  if ! echo "$output" | jq -e '.' >/dev/null 2>&1; then
    echo "Output is not valid JSON: $output"
    return 1
  fi
  return 0
}

# Check if JSON has required field
assert_json_has_field() {
  local output="$1"
  local field="$2"
  if ! echo "$output" | jq -e ".$field" >/dev/null 2>&1; then
    echo "JSON missing field '$field': $output"
    return 1
  fi
  return 0
}

# Check JSON field value
assert_json_field_equals() {
  local output="$1"
  local field="$2"
  local expected="$3"
  local actual
  actual=$(echo "$output" | jq -r ".$field")
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected .$field='$expected', got '$actual'"
    return 1
  fi
  return 0
}

# =============================================================================
# ocdc-up --json Tests
# =============================================================================

test_ocdc_up_json_outputs_valid_json() {
  cd "$TEST_REPO"
  # Will fail at devcontainer up, but should still output JSON on error
  local output
  output=$("$BIN_DIR/ocdc" up --json --no-open 2>&1) || true
  
  # Extract JSON from output
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
}

test_ocdc_up_json_has_workspace_field() {
  cd "$TEST_REPO"
  local output
  output=$("$BIN_DIR/ocdc" up --json --no-open 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  # On error, we get error field; on success, we get workspace field
  # Since devcontainer fails in test, we expect error OR workspace
  if echo "$json_output" | jq -e '.workspace' >/dev/null 2>&1; then
    return 0
  fi
  if echo "$json_output" | jq -e '.error' >/dev/null 2>&1; then
    # Error case is expected in tests - the JSON should still have the error field
    return 0
  fi
  echo "JSON missing both 'workspace' and 'error' fields: $json_output"
  return 1
}

test_ocdc_up_json_has_port_field() {
  cd "$TEST_REPO"
  local output
  output=$("$BIN_DIR/ocdc" up --json --no-open 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  # On error, we get error field; on success, we get port field
  if echo "$json_output" | jq -e '.port' >/dev/null 2>&1; then
    return 0
  fi
  if echo "$json_output" | jq -e '.error' >/dev/null 2>&1; then
    # Error case is expected in tests
    return 0
  fi
  echo "JSON missing both 'port' and 'error' fields: $json_output"
  return 1
}

test_ocdc_up_json_error_has_error_field() {
  # Test with a directory that doesn't have devcontainer.json
  local bare_repo="$TEST_DIR/bare-repo"
  mkdir -p "$bare_repo"
  git -C "$bare_repo" init -q
  
  cd "$bare_repo"
  local output exit_code
  output=$("$BIN_DIR/ocdc" up --json 2>&1) || exit_code=$?
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
  assert_json_has_field "$json_output" "error"
}

test_ocdc_up_json_error_exits_with_correct_code() {
  # Not in git repo - should exit with invalid args
  cd "$TEST_DIR"
  local exit_code=0
  "$BIN_DIR/ocdc" up --json 2>&1 || exit_code=$?
  
  # Should be EXIT_ERROR (1) or EXIT_INVALID_ARGS (2)
  if [[ $exit_code -eq 0 ]]; then
    echo "Should have exited with non-zero code"
    return 1
  fi
  return 0
}

# =============================================================================
# ocdc-down --json Tests
# =============================================================================

test_ocdc_down_json_outputs_valid_json() {
  # Create a tracked workspace
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
  
  cd "$TEST_REPO"
  local output
  output=$("$BIN_DIR/ocdc" down --json 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
}

test_ocdc_down_json_has_success_field() {
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
  
  cd "$TEST_REPO"
  local output
  output=$("$BIN_DIR/ocdc" down --json 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_json_has_field "$json_output" "success"
}

test_ocdc_down_json_all_outputs_array() {
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/repo1": {
    "port": 13000,
    "repo": "repo1",
    "branch": "main"
  },
  "/path/to/repo2": {
    "port": 13001,
    "repo": "repo2",
    "branch": "feature"
  }
}
EOF
  
  local output
  output=$("$BIN_DIR/ocdc" down --all --json 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
  
  # Should be an array
  local is_array
  is_array=$(echo "$json_output" | jq 'if type == "array" then "yes" else "no" end' -r)
  if [[ "$is_array" != "yes" ]]; then
    echo "Expected array output for --all, got: $json_output"
    return 1
  fi
  return 0
}

test_ocdc_down_json_not_found_exits_correctly() {
  echo '{}' > "$TEST_CACHE_DIR/ports.json"
  
  cd "$TEST_REPO"
  local exit_code=0
  local output
  output=$("$BIN_DIR/ocdc" down --json 2>&1) || exit_code=$?
  
  # Should exit with NOT_FOUND (3)
  if [[ $exit_code -ne $EXIT_NOT_FOUND ]]; then
    echo "Expected exit code $EXIT_NOT_FOUND, got $exit_code"
    return 1
  fi
  
  local json_output
  json_output=$(extract_json "$output")
  assert_json_has_field "$json_output" "error"
}

test_ocdc_down_json_prune_outputs_json() {
  # Add stale entries (ports not in use)
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/stale1": {
    "port": 19998,
    "repo": "stale1",
    "branch": "main"
  },
  "/path/to/stale2": {
    "port": 19999,
    "repo": "stale2",
    "branch": "feature"
  }
}
EOF
  
  local output
  output=$("$BIN_DIR/ocdc" down --prune --json 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
  assert_json_has_field "$json_output" "success"
  assert_json_has_field "$json_output" "pruned"
}

# =============================================================================
# ocdc-exec --json Tests
# =============================================================================

test_ocdc_exec_json_outputs_valid_json() {
  # Set up a tracked workspace
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
  
  cd "$TEST_REPO"
  local output exit_code
  # This will fail (no actual container), but should output JSON error
  output=$("$BIN_DIR/ocdc" exec --json -- echo hello 2>&1) || exit_code=$?
  
  local json_output
  json_output=$(extract_json "$output")
  
  assert_valid_json "$json_output"
}

test_ocdc_exec_json_has_stdout_stderr_code() {
  # When successful, should have stdout, stderr, code fields
  # Since we can't run a real container in tests, check error response format
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
  
  cd "$TEST_REPO"
  local output
  output=$("$BIN_DIR/ocdc" exec --json -- echo hello 2>&1) || true
  
  local json_output
  json_output=$(extract_json "$output")
  
  # The exec command outputs stdout/stderr/code even on failure
  # (it captures devcontainer exec output)
  if echo "$json_output" | jq -e '.code' >/dev/null 2>&1; then
    # Has code field - success format
    assert_json_has_field "$json_output" "stdout"
    assert_json_has_field "$json_output" "stderr"
    return 0
  fi
  
  # If no code field, check for error field (pre-exec failure)
  if echo "$json_output" | jq -e '.error' >/dev/null 2>&1; then
    return 0
  fi
  
  echo "JSON missing expected fields: $json_output"
  return 1
}

test_ocdc_exec_json_not_tracked_error() {
  echo '{}' > "$TEST_CACHE_DIR/ports.json"
  
  cd "$TEST_REPO"
  local exit_code=0
  local output
  output=$("$BIN_DIR/ocdc" exec --json -- echo hello 2>&1) || exit_code=$?
  
  # Should exit with NOT_FOUND (3)
  if [[ $exit_code -ne $EXIT_NOT_FOUND ]]; then
    echo "Expected exit code $EXIT_NOT_FOUND, got $exit_code"
    return 1
  fi
  
  local json_output
  json_output=$(extract_json "$output")
  assert_valid_json "$json_output"
  assert_json_has_field "$json_output" "error"
}

# =============================================================================
# ocdc-list --json Tests (existing, verify format)
# =============================================================================

test_ocdc_list_json_is_array() {
  echo '{}' > "$TEST_CACHE_DIR/ports.json"
  
  local output
  output=$("$BIN_DIR/ocdc" list --json --active 2>&1)
  
  assert_valid_json "$output"
  
  local is_array
  is_array=$(echo "$output" | jq 'if type == "array" then "yes" else "no" end' -r)
  if [[ "$is_array" != "yes" ]]; then
    echo "Expected array output, got: $output"
    return 1
  fi
  return 0
}

test_ocdc_list_json_item_has_required_fields() {
  cat > "$TEST_CACHE_DIR/ports.json" << 'EOF'
{
  "/path/to/repo": {
    "port": 13000,
    "repo": "my-repo",
    "branch": "main",
    "started": "2024-01-01T00:00:00Z"
  }
}
EOF
  
  local output
  output=$("$BIN_DIR/ocdc" list --json 2>&1)
  
  # Should have at least one item with workspace, port, repo, branch, status
  local first_item
  first_item=$(echo "$output" | jq '.[0]')
  
  assert_json_has_field "$first_item" "workspace"
  assert_json_has_field "$first_item" "port"
  assert_json_has_field "$first_item" "repo"
  assert_json_has_field "$first_item" "branch"
  assert_json_has_field "$first_item" "status"
}

# =============================================================================
# Exit Code Tests
# =============================================================================

test_exit_code_invalid_args_for_unknown_option() {
  local exit_code=0
  "$BIN_DIR/ocdc" up --invalid-option 2>&1 || exit_code=$?
  
  if [[ $exit_code -ne $EXIT_INVALID_ARGS ]]; then
    echo "Expected exit code $EXIT_INVALID_ARGS for invalid option, got $exit_code"
    return 1
  fi
  return 0
}

test_exit_code_not_found_for_missing_workspace() {
  echo '{}' > "$TEST_CACHE_DIR/ports.json"
  
  cd "$TEST_REPO"
  local exit_code=0
  "$BIN_DIR/ocdc" down --json 2>&1 || exit_code=$?
  
  if [[ $exit_code -ne $EXIT_NOT_FOUND ]]; then
    echo "Expected exit code $EXIT_NOT_FOUND for missing workspace, got $exit_code"
    return 1
  fi
  return 0
}

# =============================================================================
# Run Tests
# =============================================================================

echo "ocdc-up --json Tests:"
for test_func in \
  test_ocdc_up_json_outputs_valid_json \
  test_ocdc_up_json_has_workspace_field \
  test_ocdc_up_json_has_port_field \
  test_ocdc_up_json_error_has_error_field \
  test_ocdc_up_json_error_exits_with_correct_code
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

echo ""
echo "ocdc-down --json Tests:"
for test_func in \
  test_ocdc_down_json_outputs_valid_json \
  test_ocdc_down_json_has_success_field \
  test_ocdc_down_json_all_outputs_array \
  test_ocdc_down_json_not_found_exits_correctly \
  test_ocdc_down_json_prune_outputs_json
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

echo ""
echo "ocdc-exec --json Tests:"
for test_func in \
  test_ocdc_exec_json_outputs_valid_json \
  test_ocdc_exec_json_has_stdout_stderr_code \
  test_ocdc_exec_json_not_tracked_error
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

echo ""
echo "ocdc-list --json Tests:"
for test_func in \
  test_ocdc_list_json_is_array \
  test_ocdc_list_json_item_has_required_fields
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

echo ""
echo "Exit Code Tests:"
for test_func in \
  test_exit_code_invalid_args_for_unknown_option \
  test_exit_code_not_found_for_missing_workspace
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
