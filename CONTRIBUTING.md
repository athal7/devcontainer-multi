# Contributing to devcontainer-multi

Thanks for your interest in contributing!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/athal7/devcontainer-multi.git
   cd devcontainer-multi
   ```

2. Symlink the scripts to your PATH for local testing:
   ```bash
   ln -sf "$(pwd)/bin/"* /usr/local/bin/
   # or for Homebrew on macOS:
   ln -sf "$(pwd)/bin/"* /opt/homebrew/bin/
   ```

3. Install dependencies:
   - `jq` - JSON processor (required)
   - `devcontainer` CLI - `npm install -g @devcontainers/cli` (required for actual container operations)

## Running Tests

Run the full test suite:
```bash
./test/run_tests.bash
```

Run individual test files:
```bash
./test/test_dcup.bash
./test/test_dclist.bash
```

## Writing Tests

Tests live in the `test/` directory. Each command should have a corresponding `test_<command>.bash` file.

Tests use the helper functions from `test/test_helper.bash`:

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/test_helper.bash"

setup() {
  setup_test_env  # Creates isolated temp directories
}

teardown() {
  cleanup_test_env
}

test_my_feature() {
  # Test implementation
  assert_equals "expected" "actual"
  assert_contains "$output" "substring"
}

# Run tests
for test_func in test_my_feature; do
  setup
  run_test "description" "$test_func"
  teardown
done

print_summary
```

### Environment Variables for Testing

Scripts support these env vars to allow test isolation:
- `DCMULTI_CONFIG_DIR` - Config directory (default: `~/.config/devcontainer-multi`)
- `DCMULTI_CACHE_DIR` - Cache directory (default: `~/.cache/devcontainer-multi`)
- `DCMULTI_CLONES_DIR` - Clones directory (default: `~/.cache/devcontainer-clones`)

## Code Style

- Use `set -euo pipefail` at the top of scripts
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Add help text in comments at the top of each script (extracted by `--help`)
- Prefix log messages with the script name: `[dcup] message`

## Submitting Changes

1. Create a feature branch: `git checkout -b my-feature`
2. Make your changes
3. Run tests: `./test/run_tests.bash`
4. Commit with a clear message
5. Push and open a pull request

## Releasing

Releases are automated via GitHub Actions. To create a release:

1. Tag the commit: `git tag v1.0.0`
2. Push the tag: `git push origin v1.0.0`

The release workflow will run tests, then create a GitHub release with the tarball.
