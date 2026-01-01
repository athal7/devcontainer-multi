# Contributing to ocdc

Thanks for your interest in contributing!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/athal7/ocdc.git
   cd ocdc
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
./test/test_ocdc_up.bash
./test/test_ocdc_list.bash
```

## Writing Tests

Tests live in the `test/` directory. Each command should have a corresponding `test_ocdc_<command>.bash` file.

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
- `OCDC_CONFIG_DIR` - Config directory (default: `~/.config/ocdc`)
- `OCDC_CACHE_DIR` - Cache directory (default: `~/.cache/ocdc`)
- `OCDC_CLONES_DIR` - Clones directory (default: `~/.cache/devcontainer-clones`)

## Code Style

- Use `set -euo pipefail` at the top of scripts
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Add help text in comments at the top of each script (extracted by `--help`)
- Prefix log messages with the script name: `[ocdc-up] message`

## Submitting Changes

1. Create a feature branch: `git checkout -b my-feature`
2. Make your changes
3. Run tests: `./test/run_tests.bash`
4. Commit with a clear message
5. Push and open a pull request

## Releasing

Releases are automated via GitHub Actions. To create a release:

1. Update version in `bin/ocdc`
2. Update version and URL in `Formula/ocdc.rb`
3. Commit: `git commit -am "chore: bump version to v1.0.0"`
4. Tag: `git tag v1.0.0`
5. Push: `git push origin main --tags`
6. Calculate SHA256: `curl -L https://github.com/athal7/ocdc/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256`
7. Update `Formula/ocdc.rb` with the SHA256
8. Commit and push the SHA update

The release workflow will run tests and create a GitHub release with the tarball.

## Homebrew Tap Setup

The Homebrew formula lives in `Formula/ocdc.rb` and can be installed from a tap.

### Creating the Tap Repository

If you're setting this up for the first time:

1. Create a new GitHub repo named `homebrew-tap`
2. Add the formula:
   ```bash
   mkdir Formula
   cp Formula/ocdc.rb homebrew-tap/Formula/
   git add Formula/ocdc.rb
   git commit -m "Add ocdc formula"
   git push
   ```

### Installing from the Tap

Users can then install with:
```bash
brew tap athal7/tap
brew install ocdc
```

Or in one command:
```bash
brew install athal7/tap/ocdc
```

### Testing the Formula Locally

Before publishing:
```bash
brew install --build-from-source Formula/ocdc.rb
brew test ocdc
brew audit --strict ocdc
```
