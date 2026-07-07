---
name: git-cleanup
description: Audits and removes stale git worktrees and branches (local + remote origin) that have been merged into `dev`. Use this whenever the user wants to clean up branches, prune stale worktrees, remove merged branches, tidy up the repo, or do any kind of branch housekeeping. Also trigger when the user says things like "let's clean up the repo", "what branches can I delete", "remove old branches", or asks about git branch hygiene — even if they don't use the word "stale". Always invoke this skill before manually running git branch -d or git worktree remove commands.
status: deprecated
---

> **Deprecated — folded into the `github` skill.** Use `/git-cleanup` from the `github`
> bundle (`claude/skills/github/`), which runs this workflow under the parent skill's
> minimal-output contract. This file is retained for history only.

# Git Cleanup

Identifies and removes stale git worktrees, local branches, and remote (origin) branches that have already been merged into `dev`. Protects anything with uncommitted local changes.

## Step 1 — Verify `dev` exists

Run both:
```bash
git branch --list dev
git branch -r --list origin/dev
```

If `dev` does not exist locally OR on origin, stop immediately and tell the user clearly. This skill requires `dev` as the merge-base reference — without it, "stale" cannot be defined.

## Step 2 — Fetch and prune remote state

```bash
git fetch origin --prune
```

This ensures remote branch data is current and already-deleted remote refs are cleaned up before analysis.

## Step 2b — Detect merge strategy

Before scanning branches, determine whether this repo uses squash merges or standard merges. This controls which detection method is used in Steps 3–5.

```bash
git log dev --merges --max-count=10 --oneline
```

- **Output is empty (or fewer than 2 results)** → repo uses squash merges → set `MERGE_STRATEGY=squash`
- **Output has several merge commits** → repo uses standard merges → set `MERGE_STRATEGY=standard`

Tell the user which strategy was detected, e.g.:
> "Detected squash-merge strategy (no merge commits found on dev) — using `git cherry` for stale detection."

The two strategies use different merged-check commands in the steps below, but everything else (dirty check, presentation, deletion, logging) is identical.

## Step 3 — Collect and categorize worktrees

Run:
```bash
git worktree list --porcelain
```

Parse the output. Skip the **first** entry (the main worktree). For each remaining worktree, extract its `worktree` path, `HEAD` commit hash, and `branch` ref.

For each non-main worktree, perform two checks:

**Merged check** — use the method matching the detected strategy:

*Standard merge repos:*
```bash
git merge-base --is-ancestor <HEAD-commit> dev
```
Exit code 0 = merged. Exit code 1 = not merged (skip).

*Squash-merge repos:*
```bash
git cherry dev <branch-name>
```
If every output line starts with `-` (and there is at least one line), the branch's changes are fully in dev — treat as merged. If any line starts with `+`, the branch has unshipped work — skip it. If there is no output at all (empty branch), treat as NOT merged (skip).

**Dirty check** — does the worktree have uncommitted or untracked changes?
```bash
git -C <worktree-path> status --porcelain
```
Any output = dirty.

Categorize:
- Merged + clean → **stale worktree** (candidate for deletion)
- Merged + dirty → **blocked worktree** (list as skipped — never offer to delete)
- Not merged → **active** (ignore entirely)

## Step 4 — Collect and categorize local branches

Get all local branches:
```bash
git branch
```

From this list, exclude permanently: `dev`, `main`, `master`, and any branch currently checked out in a worktree.

For each remaining branch, run the merged check using the detected strategy:

*Standard merge repos:*
```bash
git branch --merged dev
```
Any branch appearing in this output is stale.

*Squash-merge repos:*
```bash
git cherry dev <branch-name>
```
If all output lines start with `-` (and output is non-empty) → stale. Any `+` line or empty output → skip.

## Step 5 — Collect remote branches (origin only)

Get all remote branches:
```bash
git branch -r
```

Exclude permanently: `origin/dev`, `origin/main`, `origin/master`, `origin/HEAD`.

For each remaining remote branch, run the merged check using the detected strategy:

*Standard merge repos:*
```bash
git branch -r --merged dev
```
Any branch appearing in this output is stale.

*Squash-merge repos:*
```bash
git cherry dev <remote-branch-name>
```
Strip the `origin/` prefix for the cherry command. Same pass/fail rules as Step 4.

## Step 6 — Present stale list to the user

Display a clear summary before asking for confirmation. Format it like this:

```
Stale items found (all merged into dev):

WORKTREES
  .worktrees/feat-login       [branch: feat/login]
  .worktrees/fix-typo         [branch: fix/typo]

LOCAL BRANCHES
  feat/login
  fix/typo

REMOTE BRANCHES (origin)
  origin/feat/login
  origin/fix/typo

Blocked — merged but have uncommitted changes (will NOT be deleted):
  .worktrees/fix-wip          [branch: fix/wip]
```

If no stale items are found, say so and exit. No further steps needed.

Then use the `AskUserQuestion` tool to ask:
> "Should I delete all stale items listed above, or would you like to exclude some?"

Options:
- **Delete all listed** — proceed with everything shown
- **Let me exclude some** — follow up with a second AskUserQuestion listing each stale item as a multi-select of items to **keep** (skip deletion)

If the user excludes specific items, confirm the final deletion list before proceeding.

## Step 7 — Execute deletions

Process in this order: **worktrees → local branches → remote branches**.

**Remove a worktree:**
```bash
git worktree remove <path>
```
If the worktree branch is still checked out there and causes an error, retry with `--force`. Note that removing a worktree does NOT delete the backing local branch — that is handled separately in the local branch step.

**Delete a local branch:**
```bash
git branch -d <branch-name>
```
Use `-d` (safe delete — only works if merged). If this unexpectedly fails (rare edge case), log the failure with the stderr output. Do NOT silently escalate to `-D`.

**Delete a remote branch:**
```bash
git push origin --delete <branch-name>
```
Strip the `origin/` prefix from the branch name before running this command.

Track each result:
- **Success**: command exited with code 0
- **Failure**: command exited non-zero — capture the full stderr message

## Step 8 — Report results

After all deletions are attempted, print a final summary:

```
✓ Successfully removed (3):
  - .worktrees/feat-login     [worktree]
  - feat/login                [local branch]
  - origin/feat/login         [remote branch]

✗ Failed to remove (1):
  - origin/fix/typo           [remote branch]
    Error: remote: refusing to delete protected branch

⚠ Skipped — uncommitted changes (1):
  - .worktrees/fix-wip        [worktree, branch: fix/wip]
```

## Step 9 — Update docs/git-log.md

Locate `docs/git-log.md` in the repository root. If it does not exist, create it automatically with this skeleton:

```markdown
# Git Cleanup Log

## Successfully Removed

| Date | Item | Scope | Notes |
|------|------|-------|-------|

## Failed to Remove

| Date | Item | Scope | Notes |
|------|------|-------|-------|

## Skipped — Uncommitted Changes

| Date | Item | Scope | Notes |
|------|------|-------|-------|
```

If the file exists but is missing any of these three sections, append the missing section(s) to the end of the file.

Then append one row per item to the appropriate section. Use today's date in `YYYY-MM-DD` format. The **Scope** column should describe what was deleted (e.g., `worktree`, `local branch`, `remote branch`, `worktree + local branch`, etc.). The **Notes** column should contain `Success`, `Failed: <error message>`, or `Skipped: uncommitted changes`.

Example rows:
```markdown
| 2026-03-21 | feat/login | worktree + local branch + remote | Success |
| 2026-03-21 | fix/typo   | remote branch                    | Failed: remote protected branch |
| 2026-03-21 | fix/wip    | worktree                         | Skipped: uncommitted changes |
```

Append rows directly after the last row in each section's table. Do not rewrite the entire file — use the Edit tool to insert rows at the correct location within each section.

If a section has no new entries for this run, leave it untouched.

## Diagram

[View diagram](diagram.html)
