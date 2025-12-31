#!/usr/bin/env bash
#
# Run all tests for devcontainer-multi
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  devcontainer-multi test suite"
echo "========================================"
echo ""

FAILED=0

for test_file in "$SCRIPT_DIR"/test_*.bash; do
  if [[ -f "$test_file" ]] && [[ "$test_file" != *"test_helper.bash"* ]]; then
    echo "----------------------------------------"
    if ! bash "$test_file"; then
      FAILED=1
    fi
    echo ""
  fi
done

echo "========================================"
if [[ $FAILED -eq 0 ]]; then
  echo "  All test suites passed!"
else
  echo "  Some tests failed!"
  exit 1
fi
echo "========================================"
