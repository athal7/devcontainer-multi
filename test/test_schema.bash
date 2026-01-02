#!/usr/bin/env bash
#
# Tests for poll configuration schema validation
#
# These tests validate that:
# 1. The JSON schema is valid
# 2. Example configs conform to the schema
# 3. Invalid configs are rejected by the schema
#
# Requires: check-jsonschema (pip install check-jsonschema)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_FILE="$REPO_DIR/share/ocdc/poll-config.schema.json"
EXAMPLES_DIR="$REPO_DIR/share/ocdc/examples"

echo "Testing poll configuration schema..."
echo ""

# =============================================================================
# Setup/Teardown
# =============================================================================

setup() {
  setup_test_env
  
  # Check if check-jsonschema is available
  if ! command -v check-jsonschema >/dev/null 2>&1; then
    echo "Warning: check-jsonschema not installed. Install with: pip install check-jsonschema"
    return 1
  fi
}

teardown() {
  cleanup_test_env
}

# =============================================================================
# Schema Structure Tests
# =============================================================================

test_schema_file_exists() {
  if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Schema file does not exist: $SCHEMA_FILE"
    return 1
  fi
  return 0
}

test_schema_is_valid_json() {
  if ! jq empty "$SCHEMA_FILE" 2>/dev/null; then
    echo "Schema file is not valid JSON"
    return 1
  fi
  return 0
}

# =============================================================================
# Example Config Tests
# =============================================================================

test_linear_assigned_example_validates() {
  local example="$EXAMPLES_DIR/linear-assigned.yaml"
  if [[ ! -f "$example" ]]; then
    echo "Example file does not exist: $example"
    return 1
  fi
  
  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$example" 2>&1; then
    echo "linear-assigned.yaml should validate against schema"
    return 1
  fi
  return 0
}

test_github_issues_example_validates() {
  local example="$EXAMPLES_DIR/github-issues.yaml"
  if [[ ! -f "$example" ]]; then
    echo "Example file does not exist: $example"
    return 1
  fi
  
  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$example" 2>&1; then
    echo "github-issues.yaml should validate against schema"
    return 1
  fi
  return 0
}

test_github_pr_reviews_example_validates() {
  local example="$EXAMPLES_DIR/github-pr-reviews.yaml"
  if [[ ! -f "$example" ]]; then
    echo "Example file does not exist: $example"
    return 1
  fi
  
  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$example" 2>&1; then
    echo "github-pr-reviews.yaml should validate against schema"
    return 1
  fi
  return 0
}

# =============================================================================
# Required Field Tests
# =============================================================================

test_schema_rejects_missing_id() {
  local invalid_config="$TEST_DIR/invalid-missing-id.yaml"
  cat > "$invalid_config" << 'EOF'
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Config missing 'id' should fail schema validation"
    return 1
  fi
  return 0
}

test_schema_rejects_missing_source_type() {
  local invalid_config="$TEST_DIR/invalid-missing-source-type.yaml"
  cat > "$invalid_config" << 'EOF'
id: test
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Config missing 'source_type' should fail schema validation"
    return 1
  fi
  return 0
}

test_schema_rejects_missing_repo_filters() {
  local invalid_config="$TEST_DIR/invalid-missing-repo-filters.yaml"
  cat > "$invalid_config" << 'EOF'
id: test
source_type: github_issue
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Config missing 'repo_filters' should fail schema validation"
    return 1
  fi
  return 0
}

test_schema_rejects_empty_repo_filters() {
  local invalid_config="$TEST_DIR/invalid-empty-repo-filters.yaml"
  cat > "$invalid_config" << 'EOF'
id: test
source_type: github_issue
repo_filters: []
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Config with empty 'repo_filters' should fail schema validation"
    return 1
  fi
  return 0
}

test_schema_rejects_invalid_source_type() {
  local invalid_config="$TEST_DIR/invalid-source-type.yaml"
  cat > "$invalid_config" << 'EOF'
id: test
source_type: invalid_type
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Config with invalid 'source_type' should fail schema validation"
    return 1
  fi
  return 0
}

test_schema_rejects_repo_filter_missing_repo_path() {
  local invalid_config="$TEST_DIR/invalid-filter-missing-path.yaml"
  cat > "$invalid_config" << 'EOF'
id: test
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
EOF

  if check-jsonschema --schemafile "$SCHEMA_FILE" "$invalid_config" 2>/dev/null; then
    echo "Repo filter missing 'repo_path' should fail schema validation"
    return 1
  fi
  return 0
}

# =============================================================================
# Valid Config Tests
# =============================================================================

test_schema_accepts_minimal_linear_config() {
  local valid_config="$TEST_DIR/minimal-linear.yaml"
  cat > "$valid_config" << 'EOF'
id: linear-test
source_type: linear_issue
repo_filters:
  - team: "ENG"
    repo_path: "~/code/eng"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Minimal Linear config should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_minimal_github_issue_config() {
  local valid_config="$TEST_DIR/minimal-github-issue.yaml"
  cat > "$valid_config" << 'EOF'
id: github-test
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Minimal GitHub issue config should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_minimal_github_pr_config() {
  local valid_config="$TEST_DIR/minimal-github-pr.yaml"
  cat > "$valid_config" << 'EOF'
id: github-pr-test
source_type: github_pr
repo_filters:
  - org: "myorg"
    repo_path: "~/code/myorg"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Minimal GitHub PR config should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_fetch_options() {
  local valid_config="$TEST_DIR/with-fetch-options.yaml"
  cat > "$valid_config" << 'EOF'
id: with-fetch
source_type: github_issue
fetch:
  assignee: "@me"
  state: "open"
  labels: ["ready"]
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with fetch options should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_fetch_command() {
  local valid_config="$TEST_DIR/with-fetch-command.yaml"
  cat > "$valid_config" << 'EOF'
id: with-fetch-command
source_type: github_issue
fetch_command: "gh issue list --json number,title"
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with fetch_command should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_multiple_repo_filters() {
  local valid_config="$TEST_DIR/multiple-filters.yaml"
  cat > "$valid_config" << 'EOF'
id: multi-filter
source_type: linear_issue
repo_filters:
  - team: "ENG"
    labels: ["backend"]
    repo_path: "~/code/backend"
  - team: "ENG"
    labels: ["frontend"]
    repo_path: "~/code/frontend"
  - team: "ENG"
    repo_path: "~/code/eng-default"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with multiple repo_filters should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_all_filter_criteria() {
  local valid_config="$TEST_DIR/all-criteria.yaml"
  cat > "$valid_config" << 'EOF'
id: all-criteria
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    org: "owner"
    labels: ["ready", "approved"]
    project: "Q1"
    milestone: "v1.0"
    repo_path: "~/code/repo"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with all filter criteria should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_custom_prompt() {
  local valid_config="$TEST_DIR/custom-prompt.yaml"
  cat > "$valid_config" << 'EOF'
id: custom-prompt
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
prompt:
  template: "Custom prompt for {title}"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with custom prompt should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_custom_session() {
  local valid_config="$TEST_DIR/custom-session.yaml"
  cat > "$valid_config" << 'EOF'
id: custom-session
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
session:
  name_template: "custom-{number}"
  agent: architect
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with custom session should pass schema validation"
    return 1
  fi
  return 0
}

test_schema_accepts_config_with_custom_item_mapping() {
  local valid_config="$TEST_DIR/custom-mapping.yaml"
  cat > "$valid_config" << 'EOF'
id: custom-mapping
source_type: github_issue
repo_filters:
  - repo: "owner/repo"
    repo_path: "~/code/repo"
item_mapping:
  key: ".custom_id"
  branch: ".custom_branch"
EOF

  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$valid_config" 2>&1; then
    echo "Config with custom item_mapping should pass schema validation"
    return 1
  fi
  return 0
}

# =============================================================================
# Run Tests
# =============================================================================

# Check for required tool first
if ! command -v check-jsonschema >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIPPED${NC}: check-jsonschema not installed"
  echo "Install with: pip install check-jsonschema"
  exit 0
fi

echo "Schema Validation Tests:"

for test_func in \
  test_schema_file_exists \
  test_schema_is_valid_json \
  test_linear_assigned_example_validates \
  test_github_issues_example_validates \
  test_github_pr_reviews_example_validates \
  test_schema_rejects_missing_id \
  test_schema_rejects_missing_source_type \
  test_schema_rejects_missing_repo_filters \
  test_schema_rejects_empty_repo_filters \
  test_schema_rejects_invalid_source_type \
  test_schema_rejects_repo_filter_missing_repo_path \
  test_schema_accepts_minimal_linear_config \
  test_schema_accepts_minimal_github_issue_config \
  test_schema_accepts_minimal_github_pr_config \
  test_schema_accepts_config_with_fetch_options \
  test_schema_accepts_config_with_fetch_command \
  test_schema_accepts_config_with_multiple_repo_filters \
  test_schema_accepts_config_with_all_filter_criteria \
  test_schema_accepts_config_with_custom_prompt \
  test_schema_accepts_config_with_custom_session \
  test_schema_accepts_config_with_custom_item_mapping
do
  setup
  run_test "${test_func#test_}" "$test_func"
  teardown
done

print_summary
