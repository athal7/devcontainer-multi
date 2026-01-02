#!/usr/bin/env bash
#
# ocdc-poll-config.bash - Poll configuration schema and validation
#
# This library provides functions for loading, validating, and working
# with poll configuration files.
#
# Usage:
#   source "$(dirname "$0")/ocdc-poll-config.bash"
#   poll_config_validate "/path/to/config.yaml"
#
# Required: ruby (for YAML parsing), jq (for JSON manipulation)

# Source paths for OCDC_POLLS_DIR if available
if [[ -z "${OCDC_POLLS_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${SCRIPT_DIR}/ocdc-paths.bash" ]]; then
    source "${SCRIPT_DIR}/ocdc-paths.bash"
  fi
  OCDC_POLLS_DIR="${OCDC_POLLS_DIR:-${OCDC_CONFIG_DIR:-$HOME/.config/ocdc}/polls}"
fi

# =============================================================================
# YAML to JSON conversion
# =============================================================================

# Convert YAML file to JSON using Ruby's built-in YAML support
# Outputs directly to stdout - pipe to jq for processing
# Usage: _yaml_to_json "/path/to/file.yaml"
_yaml_to_json() {
  local yaml_file="$1"
  
  if [[ ! -f "$yaml_file" ]]; then
    echo "Error: File not found: $yaml_file" >&2
    return 1
  fi
  
  # Pass filename as argument to avoid shell injection
  ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV[0]))' "$yaml_file" 2>/dev/null
}

# Get a field from YAML file using jq path
# Pipes directly from ruby to jq to avoid bash variable issues with multiline strings
# Usage: _yaml_get "/path/to/file.yaml" ".field.subfield"
_yaml_get() {
  local yaml_file="$1"
  local jq_path="$2"
  
  if [[ ! -f "$yaml_file" ]]; then
    echo "Error: File not found: $yaml_file" >&2
    return 1
  fi
  
  # Pass filename as argument to avoid shell injection
  ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV[0]))' "$yaml_file" 2>/dev/null | \
    jq -r "$jq_path | if . == null then empty else . end" 2>/dev/null
}

# Get a field from YAML with a default value
# Usage: _yaml_get_default "/path/to/file.yaml" ".field" "default"
_yaml_get_default() {
  local yaml_file="$1"
  local jq_path="$2"
  local default="$3"
  
  local value
  value=$(_yaml_get "$yaml_file" "$jq_path")
  
  if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# =============================================================================
# Source Type Defaults
# =============================================================================

# Get default item mapping for a source type as JSON
# Usage: poll_config_get_default_item_mapping "linear_issue"
poll_config_get_default_item_mapping() {
  local source_type="$1"
  
  case "$source_type" in
    linear_issue)
      cat << 'EOF'
{
  "key": ".identifier",
  "repo": ".team.key",
  "repo_short": ".team.key",
  "number": ".identifier",
  "title": ".title",
  "body": ".description // \"\"",
  "url": ".url",
  "branch": ".identifier"
}
EOF
      ;;
    github_issue)
      cat << 'EOF'
{
  "key": "\"\\(.repository.full_name)-issue-\\(.number)\"",
  "repo": ".repository.full_name",
  "repo_short": ".repository.name",
  "number": ".number",
  "title": ".title",
  "body": ".body // \"\"",
  "url": ".html_url",
  "branch": "\"issue-\\(.number)\""
}
EOF
      ;;
    github_pr)
      cat << 'EOF'
{
  "key": "\"\\(.repository.full_name)-pr-\\(.number)\"",
  "repo": ".repository.full_name",
  "repo_short": ".repository.name",
  "number": ".number",
  "title": ".title",
  "body": ".body // \"\"",
  "url": ".html_url",
  "branch": ".headRefName"
}
EOF
      ;;
    *)
      echo "{}" 
      ;;
  esac
}

# Get default prompt template for a source type
# Usage: poll_config_get_default_prompt "linear_issue"
poll_config_get_default_prompt() {
  local source_type="$1"
  
  case "$source_type" in
    linear_issue)
      cat << 'EOF'
Work on Linear issue {number}: {title}
{url}

{body}
EOF
      ;;
    github_issue)
      cat << 'EOF'
Work on issue #{number}: {title}
{url}

{body}
EOF
      ;;
    github_pr)
      cat << 'EOF'
Review PR #{number}: {title}
{url}

{body}
EOF
      ;;
    *)
      echo "Work on {number}: {title}"
      ;;
  esac
}

# Get default session name template for a source type
# Usage: poll_config_get_default_session_name "linear_issue"
poll_config_get_default_session_name() {
  local source_type="$1"
  
  case "$source_type" in
    linear_issue)
      echo "ocdc-linear-{number}"
      ;;
    github_issue)
      echo "ocdc-{repo_short}-issue-{number}"
      ;;
    github_pr)
      echo "ocdc-{repo_short}-review-{number}"
      ;;
    *)
      echo "ocdc-{number}"
      ;;
  esac
}

# Get default agent for a source type
# Usage: poll_config_get_default_agent "github_pr"
poll_config_get_default_agent() {
  local source_type="$1"
  
  case "$source_type" in
    github_pr)
      echo "plan"  # Read-only for reviews
      ;;
    *)
      echo "build"  # Can write code for issues
      ;;
  esac
}

# Get default fetch options for a source type as JSON
# Usage: poll_config_get_default_fetch_options "linear_issue"
poll_config_get_default_fetch_options() {
  local source_type="$1"
  
  case "$source_type" in
    linear_issue)
      cat << 'EOF'
{
  "assignee": "@me",
  "state": ["started", "unstarted"],
  "exclude_labels": []
}
EOF
      ;;
    github_issue)
      cat << 'EOF'
{
  "assignee": "@me",
  "state": "open",
  "labels": [],
  "repo": null,
  "org": null
}
EOF
      ;;
    github_pr)
      cat << 'EOF'
{
  "review_requested": "@me",
  "state": "open",
  "repo": null,
  "org": null
}
EOF
      ;;
    *)
      echo "{}"
      ;;
  esac
}

# =============================================================================
# Fetch Command Building
# =============================================================================

# Shell-quote a string for safe interpolation into a command
# Usage: _shell_quote "value with spaces"
_shell_quote() {
  printf '%q' "$1"
}

# Build fetch command from source type and fetch options
# Usage: poll_config_build_fetch_command "linear_issue" '{"assignee":"@me"}'
poll_config_build_fetch_command() {
  local source_type="$1"
  local fetch_options="${2:-}"
  
  # Merge with defaults
  local defaults
  defaults=$(poll_config_get_default_fetch_options "$source_type")
  
  if [[ -n "$fetch_options" ]] && [[ "$fetch_options" != "null" ]]; then
    fetch_options=$(echo "$defaults" | jq --argjson opts "$fetch_options" '. * $opts')
  else
    fetch_options="$defaults"
  fi
  
  case "$source_type" in
    linear_issue)
      _build_linear_fetch_command "$fetch_options"
      ;;
    github_issue)
      _build_github_issue_fetch_command "$fetch_options"
      ;;
    github_pr)
      _build_github_pr_fetch_command "$fetch_options"
      ;;
    *)
      echo "echo '[]'"
      ;;
  esac
}

# Build Linear fetch command
_build_linear_fetch_command() {
  local opts="$1"
  local cmd="linear issue list"
  
  # Assignee
  local assignee
  assignee=$(echo "$opts" | jq -r '.assignee // "@me"')
  if [[ "$assignee" == "@me" ]]; then
    cmd="$cmd --mine"
  fi
  
  # State - Linear uses comma-separated
  local state
  state=$(echo "$opts" | jq -r 'if .state | type == "array" then .state | join(",") else .state // "started,unstarted" end')
  if [[ -n "$state" ]]; then
    cmd="$cmd --state $state"
  fi
  
  # Output as JSON
  cmd="$cmd --json"
  
  # Exclude labels - filter with jq after
  local exclude_labels
  exclude_labels=$(echo "$opts" | jq -c '.exclude_labels // []')
  if [[ "$exclude_labels" != "[]" ]]; then
    cmd="$cmd | jq '[.[] | select(.labels | map(.name) | any(. as \$l | $exclude_labels | index(\$l)) | not)]'"
  fi
  
  echo "$cmd"
}

# Build GitHub issue fetch command
_build_github_issue_fetch_command() {
  local opts="$1"
  local cmd="gh search issues"
  
  # Assignee - quote to prevent injection
  local assignee
  assignee=$(echo "$opts" | jq -r '.assignee // "@me"')
  cmd="$cmd --assignee=$(_shell_quote "$assignee")"
  
  # State - validate against known values
  local state
  state=$(echo "$opts" | jq -r '.state // "open"')
  case "$state" in
    open|closed|all) cmd="$cmd --state=$state" ;;
    *) cmd="$cmd --state=open" ;;  # Default to open for unknown values
  esac
  
  # Labels - quote to prevent injection
  local labels
  labels=$(echo "$opts" | jq -r '.labels // [] | if length > 0 then join(",") else empty end')
  if [[ -n "$labels" ]]; then
    cmd="$cmd --label=$(_shell_quote "$labels")"
  fi
  
  # Repo - quote to prevent injection
  local repo
  repo=$(echo "$opts" | jq -r '.repo // empty')
  if [[ -n "$repo" ]]; then
    cmd="$cmd --repo=$(_shell_quote "$repo")"
  fi
  
  # Org - quote to prevent injection
  local org
  org=$(echo "$opts" | jq -r '.org // empty')
  if [[ -n "$org" ]]; then
    cmd="$cmd --owner=$(_shell_quote "$org")"
  fi
  
  # JSON fields
  cmd="$cmd --json number,title,body,url,repository,labels,assignees"
  
  echo "$cmd"
}

# Build GitHub PR fetch command
_build_github_pr_fetch_command() {
  local opts="$1"
  local cmd="gh search prs"
  
  # Review requested - quote to prevent injection
  local review_requested
  review_requested=$(echo "$opts" | jq -r '.review_requested // "@me"')
  cmd="$cmd --review-requested=$(_shell_quote "$review_requested")"
  
  # State - validate against known values
  local state
  state=$(echo "$opts" | jq -r '.state // "open"')
  case "$state" in
    open|closed|all) cmd="$cmd --state=$state" ;;
    *) cmd="$cmd --state=open" ;;  # Default to open for unknown values
  esac
  
  # Repo - quote to prevent injection
  local repo
  repo=$(echo "$opts" | jq -r '.repo // empty')
  if [[ -n "$repo" ]]; then
    cmd="$cmd --repo=$(_shell_quote "$repo")"
  fi
  
  # Org - quote to prevent injection
  local org
  org=$(echo "$opts" | jq -r '.org // empty')
  if [[ -n "$org" ]]; then
    cmd="$cmd --owner=$(_shell_quote "$org")"
  fi
  
  # JSON fields
  cmd="$cmd --json number,title,body,url,repository,labels,headRefName"
  
  echo "$cmd"
}

# =============================================================================
# Repo Filter Matching
# =============================================================================

# Match an item against repo filters and return the matching repo_path
# Returns empty string if no match (caller should skip item)
# Usage: poll_config_match_repo_filter '{"team":{"key":"ENG"}}' '[{"team":"ENG","repo_path":"~/code"}]'
poll_config_match_repo_filter() {
  local item_json="$1"
  local filters_json="$2"
  
  # Calculate specificity and find best match
  echo "$filters_json" | jq -r --argjson item "$item_json" '
    # Helper to check if item matches a filter (case-insensitive)
    def matches_filter:
      . as $filter |
      
      # Check team match (Linear)
      (if $filter.team then
        ($item.team.key // "" | ascii_downcase) == ($filter.team | ascii_downcase)
      else true end) and
      
      # Check labels match (any label matches)
      (if $filter.labels and ($filter.labels | length) > 0 then
        ($item.labels // []) | map(.name | ascii_downcase) | 
        any(. as $l | ($filter.labels | map(ascii_downcase)) | index($l))
      else true end) and
      
      # Check repo match (GitHub)
      (if $filter.repo then
        ($item.repository.full_name // $item.repo // "" | ascii_downcase) == ($filter.repo | ascii_downcase)
      else true end) and
      
      # Check org match (GitHub)
      (if $filter.org then
        ($item.repository.owner.login // "" | ascii_downcase) == ($filter.org | ascii_downcase)
      else true end) and
      
      # Check project match
      (if $filter.project then
        (($item.project.name // $item.project.title // "") | ascii_downcase) == ($filter.project | ascii_downcase)
      else true end) and
      
      # Check milestone match
      (if $filter.milestone then
        (($item.milestone.title // $item.milestone.name // "") | ascii_downcase) == ($filter.milestone | ascii_downcase)
      else true end);
    
    # Calculate specificity (count of non-null filter criteria)
    def specificity:
      [.team, .labels, .repo, .org, .project, .milestone] |
      map(select(. != null and . != [] and . != "")) |
      length;
    
    # Find matching filters with specificity
    [.[] | select(matches_filter) | {repo_path, specificity: specificity}] |
    
    # Sort by specificity descending, take first
    sort_by(-.specificity) |
    first |
    .repo_path // ""
  ' 2>/dev/null || echo ""
}

# =============================================================================
# Schema Validation
# =============================================================================

# Validate a poll configuration file against the JSON schema
# Requires: check-jsonschema (pip install check-jsonschema)
# Returns 0 if valid, 1 if invalid or tool not available
# Usage: poll_config_validate_schema "/path/to/config.yaml" "/path/to/schema.json"
poll_config_validate_schema() {
  local config_file="$1"
  local schema_file="${2:-}"
  
  # Find schema file if not provided
  if [[ -z "$schema_file" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    schema_file="$(dirname "$script_dir")/share/ocdc/poll-config.schema.json"
  fi
  
  # Check if check-jsonschema is available
  if ! command -v check-jsonschema >/dev/null 2>&1; then
    echo "Warning: check-jsonschema not installed, skipping schema validation" >&2
    return 0
  fi
  
  # Check files exist
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Config file not found: $config_file" >&2
    return 1
  fi
  
  if [[ ! -f "$schema_file" ]]; then
    echo "Warning: Schema file not found: $schema_file, skipping schema validation" >&2
    return 0
  fi
  
  # Run schema validation
  if ! check-jsonschema --schemafile "$schema_file" "$config_file" 2>&1; then
    return 1
  fi
  
  return 0
}

# Validate a poll configuration file (basic validation)
# Returns 0 if valid, 1 if invalid
# Usage: poll_config_validate "/path/to/config.yaml"
poll_config_validate() {
  local config_file="$1"
  local errors=()
  
  # Check file exists
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Config file not found: $config_file" >&2
    return 1
  fi
  
  # Check YAML can be parsed
  if ! _yaml_to_json "$config_file" > /dev/null 2>&1; then
    echo "Error: Failed to parse YAML: $config_file" >&2
    return 1
  fi
  
  # Required: id
  local id
  id=$(_yaml_get "$config_file" ".id")
  if [[ -z "$id" ]]; then
    errors+=("Missing required field: id")
  fi
  
  # Required: source_type (must be one of the valid types)
  local source_type
  source_type=$(_yaml_get "$config_file" ".source_type")
  if [[ -z "$source_type" ]]; then
    errors+=("Missing required field: source_type")
  elif [[ "$source_type" != "linear_issue" ]] && [[ "$source_type" != "github_issue" ]] && [[ "$source_type" != "github_pr" ]]; then
    errors+=("Invalid source_type: $source_type (must be linear_issue, github_issue, or github_pr)")
  fi
  
  # Required: repo_filters (must be non-empty array)
  local repo_filters_count
  repo_filters_count=$(_yaml_get "$config_file" ".repo_filters | length")
  if [[ -z "$repo_filters_count" ]] || [[ "$repo_filters_count" == "0" ]]; then
    errors+=("Missing or empty required field: repo_filters")
  fi
  
  # Each repo_filter must have repo_path
  local missing_paths
  missing_paths=$(_yaml_get "$config_file" '[.repo_filters[] | select(.repo_path == null or .repo_path == "")] | length')
  if [[ -n "$missing_paths" ]] && [[ "$missing_paths" != "0" ]]; then
    errors+=("All repo_filters must have repo_path")
  fi
  
  # Mutual exclusion: fetch and fetch_command
  local has_fetch has_fetch_command
  has_fetch=$(_yaml_get "$config_file" ".fetch")
  has_fetch_command=$(_yaml_get "$config_file" ".fetch_command")
  if [[ -n "$has_fetch" ]] && [[ -n "$has_fetch_command" ]]; then
    errors+=("fetch and fetch_command are mutually exclusive")
  fi
  
  # If prompt.file is specified, check it exists (relative to config dir)
  local prompt_file
  prompt_file=$(_yaml_get "$config_file" ".prompt.file")
  if [[ -n "$prompt_file" ]]; then
    local config_dir
    config_dir=$(dirname "$config_file")
    local full_prompt_path="$config_dir/$prompt_file"
    if [[ ! -f "$full_prompt_path" ]]; then
      errors+=("Prompt file not found: $prompt_file (looked in $full_prompt_path)")
    fi
  fi
  
  # Report errors
  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "Validation errors in $config_file:" >&2
    for error in "${errors[@]}"; do
      echo "  - $error" >&2
    done
    return 1
  fi
  
  return 0
}

# =============================================================================
# Config Access Functions
# =============================================================================

# Get a field from a poll config file
# Usage: poll_config_get "/path/to/config.yaml" ".field.path"
poll_config_get() {
  local config_file="$1"
  local jq_path="$2"
  
  _yaml_get "$config_file" "$jq_path"
}

# Get the effective fetch command (built from fetch options or fetch_command)
# Usage: poll_config_get_effective_fetch_command "/path/to/config.yaml"
poll_config_get_effective_fetch_command() {
  local config_file="$1"
  
  # Check for explicit fetch_command first
  local fetch_command
  fetch_command=$(_yaml_get "$config_file" ".fetch_command")
  if [[ -n "$fetch_command" ]]; then
    echo "$fetch_command"
    return 0
  fi
  
  # Build from source_type and fetch options
  local source_type fetch_options
  source_type=$(_yaml_get "$config_file" ".source_type")
  fetch_options=$(_yaml_to_json "$config_file" | jq -c '.fetch // null')
  
  poll_config_build_fetch_command "$source_type" "$fetch_options"
}

# Get the effective item mapping (merged with defaults)
# Usage: poll_config_get_effective_item_mapping "/path/to/config.yaml"
poll_config_get_effective_item_mapping() {
  local config_file="$1"
  
  local source_type
  source_type=$(_yaml_get "$config_file" ".source_type")
  
  local defaults
  defaults=$(poll_config_get_default_item_mapping "$source_type")
  
  local custom
  custom=$(_yaml_to_json "$config_file" | jq -c '.item_mapping // {}')
  
  # Merge custom over defaults
  echo "$defaults" | jq --argjson custom "$custom" '. * $custom'
}

# Get the effective prompt template (or default)
# Usage: poll_config_get_effective_prompt "/path/to/config.yaml"
poll_config_get_effective_prompt() {
  local config_file="$1"
  
  # Check for inline template first
  local template
  template=$(_yaml_get "$config_file" ".prompt.template")
  if [[ -n "$template" ]]; then
    echo "$template"
    return 0
  fi
  
  # Check for file reference
  local prompt_file
  prompt_file=$(_yaml_get "$config_file" ".prompt.file")
  if [[ -n "$prompt_file" ]]; then
    local config_dir
    config_dir=$(dirname "$config_file")
    local full_path="$config_dir/$prompt_file"
    if [[ -f "$full_path" ]]; then
      cat "$full_path"
      return 0
    fi
  fi
  
  # Return default
  local source_type
  source_type=$(_yaml_get "$config_file" ".source_type")
  poll_config_get_default_prompt "$source_type"
}

# Get the effective session name template (or default)
# Usage: poll_config_get_effective_session_name "/path/to/config.yaml"
poll_config_get_effective_session_name() {
  local config_file="$1"
  
  local session_name
  session_name=$(_yaml_get "$config_file" ".session.name_template")
  if [[ -n "$session_name" ]]; then
    echo "$session_name"
    return 0
  fi
  
  local source_type
  source_type=$(_yaml_get "$config_file" ".source_type")
  poll_config_get_default_session_name "$source_type"
}

# Get the effective agent (or default)
# Usage: poll_config_get_effective_agent "/path/to/config.yaml"
poll_config_get_effective_agent() {
  local config_file="$1"
  
  local agent
  agent=$(_yaml_get "$config_file" ".session.agent")
  if [[ -n "$agent" ]]; then
    echo "$agent"
    return 0
  fi
  
  local source_type
  source_type=$(_yaml_get "$config_file" ".source_type")
  poll_config_get_default_agent "$source_type"
}

# Get repo filters as JSON
# Usage: poll_config_get_repo_filters "/path/to/config.yaml"
poll_config_get_repo_filters() {
  local config_file="$1"
  _yaml_to_json "$config_file" | jq -c '.repo_filters // []'
}

# Get a field from a poll config with a default value
# Usage: poll_config_get_with_default "/path/to/config.yaml" ".field" "default"
poll_config_get_with_default() {
  local config_file="$1"
  local jq_path="$2"
  local default="$3"
  
  _yaml_get_default "$config_file" "$jq_path" "$default"
}

# Get the prompt content from a config (handles both template and file)
# Usage: poll_config_get_prompt "/path/to/config.yaml"
poll_config_get_prompt() {
  local config_file="$1"
  
  # Check for inline template first
  local template
  template=$(_yaml_get "$config_file" ".prompt.template")
  
  if [[ -n "$template" ]]; then
    echo "$template"
    return 0
  fi
  
  # Check for file reference
  local prompt_file
  prompt_file=$(_yaml_get "$config_file" ".prompt.file")
  
  if [[ -n "$prompt_file" ]]; then
    local config_dir
    config_dir=$(dirname "$config_file")
    local full_path="$config_dir/$prompt_file"
    
    if [[ -f "$full_path" ]]; then
      cat "$full_path"
      return 0
    else
      echo "Error: Prompt file not found: $full_path" >&2
      return 1
    fi
  fi
  
  echo "Error: No prompt template or file specified" >&2
  return 1
}

# =============================================================================
# Config Listing Functions
# =============================================================================

# List all config files in a directory
# Usage: poll_config_list "/path/to/polls/dir"
poll_config_list() {
  local polls_dir="${1:-$OCDC_POLLS_DIR}"
  
  if [[ ! -d "$polls_dir" ]]; then
    return 0
  fi
  
  find "$polls_dir" -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | \
    while read -r file; do
      basename "$file"
    done
}

# List only enabled config files
# Usage: poll_config_list_enabled "/path/to/polls/dir"
poll_config_list_enabled() {
  local polls_dir="${1:-$OCDC_POLLS_DIR}"
  
  if [[ ! -d "$polls_dir" ]]; then
    return 0
  fi
  
  for file in "$polls_dir"/*.yaml "$polls_dir"/*.yml; do
    [[ -f "$file" ]] || continue
    local enabled
    enabled=$(_yaml_get_default "$file" ".enabled" "true")
    # Handle both string "true" and boolean true from YAML
    if [[ "$enabled" == "true" ]]; then
      basename "$file"
    fi
  done
}

# =============================================================================
# Template Rendering
# =============================================================================

# Render a template string with variable substitutions
# Usage: poll_config_render_template "template {var}" var=value var2=value2
poll_config_render_template() {
  local template="$1"
  shift
  
  local result="$template"
  
  # Process each var=value argument
  for arg in "$@"; do
    local var="${arg%%=*}"
    local value="${arg#*=}"
    
    # Replace {var} with value
    result="${result//\{$var\}/$value}"
  done
  
  echo "$result"
}

# =============================================================================
# Exports
# =============================================================================

export OCDC_POLLS_DIR
