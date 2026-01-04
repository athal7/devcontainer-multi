# CLI Interface Reference

This document describes the machine-readable JSON interface for ocdc commands. This interface is designed for programmatic integration with tools like opencode-pilot.

## Exit Codes

All commands use standardized exit codes for machine parsing:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Container/workspace not found |

## Common Flags

All commands support these flags:

- `--json`, `-j` - Output JSON for machine parsing
- `--help`, `-h` - Show help text

## Commands

### `ocdc up [branch] --json`

Start a devcontainer with auto-assigned port.

**Request:**
```bash
ocdc up feature-branch --json --no-open
```

**Success Response (exit 0):**
```json
{
  "workspace": "/path/to/workspace",
  "port": 13001,
  "container_id": "abc123...",
  "repo": "myapp",
  "branch": "feature-branch"
}
```

**Error Response (exit 1/2/3):**
```json
{
  "error": "No devcontainer.json found in /path/to/workspace",
  "code": 3
}
```

**Exit Codes:**
- 0: Container started successfully
- 1: General error (e.g., devcontainer command failed)
- 2: Invalid arguments
- 3: Missing devcontainer.json or not in git repo

---

### `ocdc down [workspace] --json`

Stop a devcontainer and release its port.

**Request (current workspace):**
```bash
ocdc down --json
```

**Request (specific workspace):**
```bash
ocdc down /path/to/workspace --json
```

**Success Response (exit 0):**
```json
{
  "success": true,
  "workspace": "/path/to/workspace",
  "port": 13001,
  "repo": "myapp"
}
```

**Error Response (exit 3):**
```json
{
  "error": "No tracked instance for: /path/to/workspace",
  "code": 3
}
```

**Exit Codes:**
- 0: Container stopped successfully
- 1: General error
- 3: Workspace not tracked

---

### `ocdc down --all --json`

Stop all tracked devcontainers.

**Request:**
```bash
ocdc down --all --json
```

**Response (exit 0):**
```json
[
  {
    "success": true,
    "workspace": "/path/to/repo1",
    "port": 13000,
    "repo": "repo1"
  },
  {
    "success": true,
    "workspace": "/path/to/repo2",
    "port": 13001,
    "repo": "repo2"
  }
]
```

---

### `ocdc down --prune --json`

Remove stale port assignments (ports no longer in use).

**Request:**
```bash
ocdc down --prune --json
```

**Response (exit 0):**
```json
{
  "success": true,
  "pruned": 2,
  "items": [
    {"workspace": "/path/to/stale1", "port": 13000, "pruned": true},
    {"workspace": "/path/to/stale2", "port": 13001, "pruned": true}
  ]
}
```

---

### `ocdc exec --json [branch] -- <command>`

Execute a command in a running devcontainer.

**Request:**
```bash
ocdc exec --json feature-branch -- npm test
```

**Request (current workspace):**
```bash
ocdc exec --json -- npm test
```

> **Note:** The `--json` flag must be placed before `--` since arguments after `--` are passed to the container command.

**Success Response (exit code from command):**
```json
{
  "stdout": "All tests passed!\n",
  "stderr": "",
  "code": 0
}
```

**Error Response (exit 3, workspace not tracked):**
```json
{
  "error": "No devcontainer tracked for: /path/to/workspace",
  "code": 3
}
```

**Exit Codes:**
- Command's exit code on success
- 2: Invalid arguments (no command specified)
- 3: Workspace not tracked

---

### `ocdc list --json`

List all devcontainer instances, clones, and sessions.

**Request:**
```bash
ocdc list --json
```

**Response (exit 0):**
```json
[
  {
    "type": "container",
    "workspace": "/path/to/repo",
    "port": 13000,
    "repo": "myapp",
    "branch": "main",
    "status": "up",
    "git": {
      "clean": true,
      "pushed": true,
      "ahead": 0,
      "is_git": true
    }
  },
  {
    "type": "session",
    "workspace": "/path/to/clone",
    "session": "ocdc-pr-123",
    "port": null,
    "repo": "myapp",
    "branch": "feature-x",
    "status": "session",
    "poll_config": "github-prs",
    "item_key": "github:123",
    "git": {
      "clean": false,
      "pushed": true,
      "ahead": 0,
      "is_git": true
    }
  },
  {
    "type": "orphan",
    "workspace": "/path/to/orphan-clone",
    "port": null,
    "repo": "myapp",
    "branch": "old-branch",
    "status": "orphan",
    "git": {
      "clean": true,
      "pushed": true,
      "ahead": 0,
      "is_git": true
    }
  }
]
```

**Fields:**
- `type`: One of `container`, `session`, `orphan`
- `workspace`: Full path to workspace directory
- `port`: Port number (null for sessions/orphans)
- `repo`: Repository name
- `branch`: Branch name
- `status`: One of `up`, `down`, `session`, `orphan`
- `git`: Git status object
  - `clean`: No uncommitted changes
  - `pushed`: No unpushed commits
  - `ahead`: Number of commits ahead of remote
  - `is_git`: Is a git repository

---

## Integration Example

Example of programmatic usage from opencode-pilot:

```javascript
const { execSync } = require('child_process');

function startDevcontainer(branch) {
  try {
    const output = execSync(`ocdc up ${branch} --json --no-open`, {
      encoding: 'utf8'
    });
    return JSON.parse(output);
  } catch (error) {
    if (error.stdout) {
      const result = JSON.parse(error.stdout);
      throw new Error(result.error);
    }
    throw error;
  }
}

function execInContainer(branch, command) {
  const output = execSync(`ocdc exec ${branch} --json -- ${command}`, {
    encoding: 'utf8'
  });
  return JSON.parse(output);
}

// Usage
const container = startDevcontainer('feature-x');
console.log(`Container running on port ${container.port}`);

const result = execInContainer('feature-x', 'npm test');
console.log(`Tests exited with code ${result.code}`);
```

## Backward Compatibility

- All commands continue to work without `--json` flag
- Human-readable output remains the default
- JSON output format is stable; new fields may be added but existing fields won't change
- Exit codes are guaranteed stable
