#!/usr/bin/env bash
#
# ocdc-json.bash - JSON output helpers for ocdc CLI
#
# Provides consistent JSON output and exit codes for machine-readable parsing.
# Used for opencode-pilot integration and other programmatic consumers.
#
# Usage:
#   source "$(dirname "$0")/../lib/ocdc-json.bash"
#   
#   JSON_OUTPUT=true
#   json_success '{"workspace": "/path/to/workspace", "port": 13000}'
#   json_error "Something went wrong" $EXIT_ERROR
#
# Exit Codes:
#   0 = success
#   1 = general error
#   2 = invalid arguments
#   3 = container/workspace not found

# Exit code constants
export EXIT_SUCCESS=0
export EXIT_ERROR=1
export EXIT_INVALID_ARGS=2
export EXIT_NOT_FOUND=3

# JSON output mode flag (set by caller)
JSON_OUTPUT="${JSON_OUTPUT:-false}"

# Output JSON success response
# Usage: json_success '{"key": "value"}'
json_success() {
  local json="$1"
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$json"
  fi
  return $EXIT_SUCCESS
}

# Output JSON error response and exit
# Usage: json_error "Error message" [exit_code]
json_error() {
  local message="$1"
  local exit_code="${2:-$EXIT_ERROR}"
  
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    jq -n --arg msg "$message" --argjson code "$exit_code" \
      '{error: $msg, code: $code}'
  else
    echo "[ocdc] ERROR: $message" >&2
  fi
  
  return "$exit_code"
}

# Suppress normal log output in JSON mode
# Usage: log_json_aware "prefix" "message"
log_json_aware() {
  local prefix="$1"
  shift
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo "[$prefix] $*"
  fi
}
