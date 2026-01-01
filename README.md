```
      ⚡
  ___  ___ ___  ___ 
 / _ \/ __/ _ \/ __|
| (_) | (_| (_) | (__ 
 \___/ \___\___/ \___|
      ⚡
   OpenCode DevContainers
```

Run multiple devcontainer instances simultaneously with auto-assigned ports and branch management.

## Why?

When working on multiple branches, you need isolated development environments. Git worktrees don't work with devcontainers because the `.git` file points outside the container.

**ocdc** solves this by:
- Creating shallow clones for each branch (fully self-contained)
- Auto-assigning ports from a configurable range (13000-13099)
- Generating ephemeral override configs (your devcontainer.json stays clean)
- Tracking active instances to avoid conflicts

## Installation

```bash
brew install athal7/tap/ocdc
```

Requires: `jq`, `devcontainer` CLI (`npm install -g @devcontainers/cli`)

## Usage

```bash
ocdc up                 # Start devcontainer (port 13000)
ocdc up feature-x       # Start for branch (port 13001)
ocdc                    # Interactive TUI
ocdc list               # List instances
ocdc exec bash          # Execute in container
ocdc go feature-x       # Navigate to clone
ocdc down               # Stop current
ocdc down --all         # Stop all
```

## Configuration

`~/.config/ocdc/config.json`:
```json
{
  "portRangeStart": 13000,
  "portRangeEnd": 13099
}
```

## How it works

1. **Clones**: `ocdc up feature-x` creates `~/.cache/devcontainer-clones/myapp/feature-x/`. Gitignored secrets are auto-copied.
2. **Ports**: Ephemeral override with unique port, passed via `--override-config`.
3. **Tracking**: `~/.cache/ocdc/ports.json`

## Poll Configuration

ocdc can automatically poll external sources (GitHub PRs, Linear issues) and create devcontainer sessions with OpenCode to work on them.

Poll configs live in `~/.config/ocdc/polls/`. See the example configs in [`share/ocdc/examples/`](share/ocdc/examples/) for the full schema and available template variables.

## License

MIT
