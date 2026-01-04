/**
 * Tests for plugin/core/git.js
 * 
 * Run with: node --test test/unit/git.test.js
 */

import { test, describe, beforeEach, afterEach } from 'node:test'
import assert from 'node:assert'
import { join } from 'path'
import { homedir } from 'os'
import { mkdirSync, rmSync, writeFileSync, existsSync } from 'fs'
import { execSync } from 'child_process'

// Module under test
import { 
  getRemoteUrl,
  getCurrentBranch,
  getRepoRoot,
  clone,
  checkout,
  fetch,
  isGitRepo
} from '../../plugin/core/git.js'

describe('isGitRepo', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-git-' + Date.now())
  
  beforeEach(() => {
    mkdirSync(testDir, { recursive: true })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('returns true for git repository', async () => {
    execSync('git init', { cwd: testDir })
    const result = await isGitRepo(testDir)
    assert.strictEqual(result, true)
  })

  test('returns false for non-git directory', async () => {
    const result = await isGitRepo(testDir)
    assert.strictEqual(result, false)
  })

  test('returns false for non-existent directory', async () => {
    const result = await isGitRepo('/nonexistent/path')
    assert.strictEqual(result, false)
  })
})

describe('getRepoRoot', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-root-' + Date.now())
  
  beforeEach(() => {
    mkdirSync(testDir, { recursive: true })
    execSync('git init', { cwd: testDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('returns repo root from repo root', async () => {
    const root = await getRepoRoot(testDir)
    assert.strictEqual(root, testDir)
  })

  test('returns repo root from subdirectory', async () => {
    const subDir = join(testDir, 'sub', 'dir')
    mkdirSync(subDir, { recursive: true })
    const root = await getRepoRoot(subDir)
    assert.strictEqual(root, testDir)
  })

  test('returns null for non-git directory', async () => {
    const nonGitDir = join(homedir(), '.cache/ocdc-test-nongit-' + Date.now())
    mkdirSync(nonGitDir, { recursive: true })
    try {
      const root = await getRepoRoot(nonGitDir)
      assert.strictEqual(root, null)
    } finally {
      rmSync(nonGitDir, { recursive: true, force: true })
    }
  })
})

describe('getCurrentBranch', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-branch-' + Date.now())
  
  beforeEach(() => {
    mkdirSync(testDir, { recursive: true })
    execSync('git init -b main', { cwd: testDir })
    // Create initial commit so branch exists
    writeFileSync(join(testDir, 'README.md'), '# Test')
    execSync('git add .', { cwd: testDir })
    execSync('git commit -m "Initial commit"', { cwd: testDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('returns current branch name', async () => {
    const branch = await getCurrentBranch(testDir)
    assert.strictEqual(branch, 'main')
  })

  test('returns new branch after checkout', async () => {
    execSync('git checkout -b feature-branch', { cwd: testDir })
    const branch = await getCurrentBranch(testDir)
    assert.strictEqual(branch, 'feature-branch')
  })

  test('returns null for non-git directory', async () => {
    const nonGitDir = join(homedir(), '.cache/ocdc-test-nongit2-' + Date.now())
    mkdirSync(nonGitDir, { recursive: true })
    try {
      const branch = await getCurrentBranch(nonGitDir)
      assert.strictEqual(branch, null)
    } finally {
      rmSync(nonGitDir, { recursive: true, force: true })
    }
  })
})

describe('getRemoteUrl', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-remote-' + Date.now())
  
  beforeEach(() => {
    mkdirSync(testDir, { recursive: true })
    execSync('git init', { cwd: testDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('returns null when no remote', async () => {
    const url = await getRemoteUrl(testDir)
    assert.strictEqual(url, null)
  })

  test('returns origin URL when remote exists', async () => {
    execSync('git remote add origin https://github.com/test/repo.git', { cwd: testDir })
    const url = await getRemoteUrl(testDir)
    assert.strictEqual(url, 'https://github.com/test/repo.git')
  })
})

describe('clone', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-clone-' + Date.now())
  const sourceDir = join(testDir, 'source')
  const destDir = join(testDir, 'dest')
  
  beforeEach(() => {
    mkdirSync(sourceDir, { recursive: true })
    // Create source repo
    execSync('git init -b main', { cwd: sourceDir })
    writeFileSync(join(sourceDir, 'README.md'), '# Test')
    execSync('git add .', { cwd: sourceDir })
    execSync('git commit -m "Initial commit"', { cwd: sourceDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('clones from local path', async () => {
    await clone({
      url: sourceDir,
      dest: destDir,
    })
    
    assert.ok(existsSync(destDir))
    assert.ok(existsSync(join(destDir, '.git')))
    assert.ok(existsSync(join(destDir, 'README.md')))
  })

  test('clones specific branch', async () => {
    // Create branch in source
    execSync('git checkout -b feature', { cwd: sourceDir })
    writeFileSync(join(sourceDir, 'feature.txt'), 'feature content')
    execSync('git add .', { cwd: sourceDir })
    execSync('git commit -m "Feature commit"', { cwd: sourceDir })
    execSync('git checkout main', { cwd: sourceDir })
    
    await clone({
      url: sourceDir,
      dest: destDir,
      branch: 'feature',
    })
    
    const branch = await getCurrentBranch(destDir)
    assert.strictEqual(branch, 'feature')
    assert.ok(existsSync(join(destDir, 'feature.txt')))
  })

  test('clones with reference for efficiency', async () => {
    const refDir = join(testDir, 'ref')
    
    // First clone the source to ref
    await clone({ url: sourceDir, dest: refDir })
    
    // Clone from source with reference to ref
    await clone({
      url: sourceDir,
      dest: destDir,
      reference: refDir,
    })
    
    assert.ok(existsSync(destDir))
    // Should still work even if reference isn't perfectly set up
  })
})

describe('checkout', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-checkout-' + Date.now())
  
  beforeEach(() => {
    mkdirSync(testDir, { recursive: true })
    execSync('git init -b main', { cwd: testDir })
    writeFileSync(join(testDir, 'README.md'), '# Test')
    execSync('git add .', { cwd: testDir })
    execSync('git commit -m "Initial commit"', { cwd: testDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('checks out existing branch', async () => {
    execSync('git branch feature', { cwd: testDir })
    await checkout(testDir, 'feature')
    const branch = await getCurrentBranch(testDir)
    assert.strictEqual(branch, 'feature')
  })

  test('creates new branch with createBranch option', async () => {
    await checkout(testDir, 'new-branch', { createBranch: true })
    const branch = await getCurrentBranch(testDir)
    assert.strictEqual(branch, 'new-branch')
  })

  test('throws for non-existent branch without create', async () => {
    await assert.rejects(
      () => checkout(testDir, 'nonexistent'),
      /error/i
    )
  })
})

describe('fetch', () => {
  const testDir = join(homedir(), '.cache/ocdc-test-fetch-' + Date.now())
  const remoteDir = join(testDir, 'remote')
  const localDir = join(testDir, 'local')
  
  beforeEach(async () => {
    mkdirSync(remoteDir, { recursive: true })
    
    // Create remote repo
    execSync('git init --bare', { cwd: remoteDir })
    
    // Clone it locally
    execSync(`git clone ${remoteDir} ${localDir}`, { cwd: testDir })
    
    // Add initial commit to local
    execSync('git config user.email "test@test.com"', { cwd: localDir })
    execSync('git config user.name "Test"', { cwd: localDir })
    writeFileSync(join(localDir, 'README.md'), '# Test')
    execSync('git add .', { cwd: localDir })
    execSync('git commit -m "Initial commit"', { cwd: localDir })
    execSync('git push origin main', { cwd: localDir })
  })

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true })
  })

  test('fetches from remote', async () => {
    // Should not throw
    await fetch(localDir)
  })

  test('fetches specific remote', async () => {
    await fetch(localDir, 'origin')
  })
})
