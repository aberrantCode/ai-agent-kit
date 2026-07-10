---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for shipping to dev via PR, keeping the branch, or discarding it. Integration into dev is delegated to the github bundle's ship operation.
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

Branch integration always goes through a PR — never a local merge into the base branch. The PR
path is owned by the `github` bundle's `ship` operation (`/ship`), which this skill delegates to.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with shipping until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD dev 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from dev - is that correct?"

### Step 3: Present Options

Present exactly these 3 options:

```
Implementation complete. What would you like to do?

1. Ship to dev (PR-based merge via the github ship operation)
2. Keep the branch as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 4: Execute Choice

#### Option 1: Ship to dev

Delegate to the `github` bundle's `ship` operation (invoke the `ship` sub-skill, or `/ship` where
commands are available). It handles the full integration path: staging anything uncommitted,
conventional branch naming, pushing, opening a PR against `dev`, merging with a merge commit, and
cleaning up the local and remote branch.

Do not merge locally and do not push directly to `dev` — `ship` is the only integration path.

Then: Cleanup worktree (Step 5)

#### Option 2: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 3: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

### Step 5: Cleanup Worktree

**For Options 1 and 3:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 2:** Keep worktree.

## Quick Reference

| Option | PR-merge to dev | Keep Worktree | Cleanup Branch |
|--------|-----------------|---------------|----------------|
| 1. Ship to dev | ✓ (via github ship) | - | ✓ (by ship) |
| 2. Keep as-is | - | ✓ | - |
| 3. Discard | - | - | ✓ (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Ship broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Present exactly 3 structured options

**Merging locally instead of shipping**
- **Problem:** Local merges bypass PR review, branch protection, and the merge-commit history convention
- **Fix:** Always integrate through the github ship operation

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2)
- **Fix:** Only cleanup for Options 1 and 3

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge locally into the base branch (dev/main)
- Push directly to dev or main
- Delete work without confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 3 options
- Delegate integration to the github ship operation
- Get typed confirmation for Option 3
- Clean up worktree for Options 1 & 3 only

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Delegates to:**
- **github (ship operation)** - PR-based integration into dev (Option 1)

**Pairs with:**
- **github (worktree-task-lifecycle sub-skill)** - Cleans up worktrees created by that sub-skill

## Diagram

[View diagram](diagram.html)
