/**
 * Git operations for opencode-devcontainers
 * 
 * Provides async wrappers around git commands using child_process.
 * Zero-dependency implementation.
 */

import { spawn } from 'child_process'

/**
 * Run a git command and return the output
 * 
 * @param {string[]} args - Git command arguments
 * @param {string} cwd - Working directory
 * @returns {Promise<{stdout: string, stderr: string, exitCode: number}>}
 */
async function runGit(args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn('git', args, {
      cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
    })

    let stdout = ''
    let stderr = ''

    child.stdout.on('data', data => {
      stdout += data.toString()
    })

    child.stderr.on('data', data => {
      stderr += data.toString()
    })

    child.on('close', exitCode => {
      resolve({ stdout: stdout.trim(), stderr: stderr.trim(), exitCode })
    })

    child.on('error', reject)
  })
}

/**
 * Check if a directory is a git repository
 * 
 * @param {string} dir - Directory to check
 * @returns {Promise<boolean>}
 */
export async function isGitRepo(dir) {
  try {
    const result = await runGit(['rev-parse', '--git-dir'], dir)
    return result.exitCode === 0
  } catch {
    return false
  }
}

/**
 * Get the root directory of a git repository
 * 
 * @param {string} dir - Directory within the repository
 * @returns {Promise<string|null>} Absolute path to repo root, or null if not in a repo
 */
export async function getRepoRoot(dir) {
  try {
    const result = await runGit(['rev-parse', '--show-toplevel'], dir)
    if (result.exitCode === 0 && result.stdout) {
      return result.stdout
    }
    return null
  } catch {
    return null
  }
}

/**
 * Get the current branch name
 * 
 * @param {string} dir - Repository directory
 * @returns {Promise<string|null>} Branch name, or null if not in a repo
 */
export async function getCurrentBranch(dir) {
  try {
    const result = await runGit(['branch', '--show-current'], dir)
    if (result.exitCode === 0 && result.stdout) {
      return result.stdout
    }
    return null
  } catch {
    return null
  }
}

/**
 * Get the remote URL for a repository
 * 
 * @param {string} dir - Repository directory
 * @param {string} remote - Remote name (default: 'origin')
 * @returns {Promise<string|null>} Remote URL, or null if not set
 */
export async function getRemoteUrl(dir, remote = 'origin') {
  try {
    const result = await runGit(['remote', 'get-url', remote], dir)
    if (result.exitCode === 0 && result.stdout) {
      return result.stdout
    }
    return null
  } catch {
    return null
  }
}

/**
 * Clone a git repository
 * 
 * @param {object} options
 * @param {string} options.url - Repository URL or local path
 * @param {string} options.dest - Destination directory
 * @param {string} [options.branch] - Branch to clone (optional)
 * @param {string} [options.reference] - Reference repository for efficiency (optional)
 * @param {boolean} [options.dissociate] - Dissociate from reference (default: true when reference provided)
 * @returns {Promise<void>}
 */
export async function clone(options) {
  const { url, dest, branch, reference, dissociate = true } = options

  const args = ['clone']

  if (reference) {
    args.push('--reference', reference)
    if (dissociate) {
      args.push('--dissociate')
    }
  }

  if (branch) {
    args.push('--branch', branch)
  }

  args.push(url, dest)

  const result = await runGit(args, process.cwd())
  if (result.exitCode !== 0) {
    throw new Error(`git clone failed: ${result.stderr}`)
  }
}

/**
 * Checkout a branch in a repository
 * 
 * @param {string} dir - Repository directory
 * @param {string} branch - Branch name
 * @param {object} [options]
 * @param {boolean} [options.createBranch] - Create branch if it doesn't exist
 * @returns {Promise<void>}
 */
export async function checkout(dir, branch, options = {}) {
  const { createBranch = false } = options

  const args = ['checkout']
  if (createBranch) {
    args.push('-b')
  }
  args.push(branch)

  const result = await runGit(args, dir)
  if (result.exitCode !== 0) {
    throw new Error(`git checkout failed: ${result.stderr}`)
  }
}

/**
 * Fetch from a remote
 * 
 * @param {string} dir - Repository directory
 * @param {string} [remote] - Remote name (default: all remotes)
 * @returns {Promise<void>}
 */
export async function fetch(dir, remote) {
  const args = ['fetch']
  if (remote) {
    args.push(remote)
  }

  const result = await runGit(args, dir)
  // Fetch can fail gracefully (no network, etc.)
  if (result.exitCode !== 0) {
    // Don't throw, just log to stderr
    console.error(`git fetch warning: ${result.stderr}`)
  }
}

/**
 * Get list of files ignored by git but present in working tree
 * 
 * @param {string} dir - Repository directory
 * @returns {Promise<string[]>} Array of relative paths
 */
export async function listIgnoredFiles(dir) {
  try {
    const result = await runGit(['ls-files', '--others', '--ignored', '--exclude-standard'], dir)
    if (result.exitCode !== 0 || !result.stdout) {
      return []
    }
    return result.stdout.split('\n').filter(Boolean)
  } catch {
    return []
  }
}

export default {
  isGitRepo,
  getRepoRoot,
  getCurrentBranch,
  getRemoteUrl,
  clone,
  checkout,
  fetch,
  listIgnoredFiles,
}
