---
name: worktree-isolated-loop
description: Use when running multi-turn or batch agent work (refactoring, feature loops) that must stay isolated from concurrent edits in the primary checkout, and when setting up a self-perpetuating /loop that hands off context between turns via git state rather than chat memory.
status: active
version: 2026-07-05
---

# Worktree-Isolated Loop

## When to use

- Multi-turn agent work where the primary checkout might be touched by the operator or another session concurrently, and edits need to land on a dedicated feature branch without blocking on file locks.
- Batch refactoring across many similar files (e.g. a family of shell scripts) where each batch should be reviewable/mergeable independently.
- Designing a `/loop`-style workflow that must resume correctly across sessions using only repo state (branch, commits, plan files) — never relying on conversation memory.

## Method

1. **Initialize the worktree once per feature branch.** Run a setup script (e.g. `bash scripts/agent-worktree-setup.sh <branch-name>`) that creates `.worktrees/<branch-name>/` off the target branch. All work for that unit of change happens only inside that directory — never touch the primary checkout for in-flight work.

2. **Discover work in coherent, bounded batches.** For batch refactors: grep a regex across the target file set to find candidates, filter out a standing skip list (regex-based skips plus a documented permanent-skip list), then pick one coherent name-glob cluster (e.g. `pihole-*`, `sync-*`) to work on at a time. Keep each batch under ~800 LOC of change; split further if it's larger.

3. **Migrate with judgment, not blind substitution.** Apply edits per file individually — never a blind `sed` across the whole cluster — since naming clusters can still hide file-specific structure.

4. **Verify before committing.** Run a syntax check, confirm required sourcing/imports precede first use, confirm no orphaned variables, and exercise the contract (smoke test) before moving to commit.

5. **Log the batch.** Prepend a `progress.md` entry describing the batch scope and any new skip categories discovered, so later batches (or later sessions) don't rediscover the same edge cases.

6. **Commit, rebase, merge from the worktree.**
   - Stage and commit inside the worktree, on the feature branch.
   - `git fetch` + rebase onto `origin/dev` (or target base) before opening a PR.
   - Push, open the PR, wait for CI to go green, then merge from the **primary** checkout (not the worktree) — this avoids Windows file-lock issues during merge.
   - Fast-forward the primary checkout, then tear down: `git worktree remove`. On Windows, a transient "Permission denied" during removal is benign — git has already untracked the worktree; retry with `git worktree prune` then `rm -rf` if the directory lingers.

7. **Guard against same-branch collisions.** The worktree primitive isolates *across* branches, not *within* a branch shared by two sessions. Before any `git add`/commit, check for `MERGE_HEAD`, `REBASE_HEAD`, or `CHERRY_PICK_HEAD` in the target — if present, either wait/notify the other session or pivot to a fresh worktree on a different branch. Record this as a lessons-learned entry so future sessions don't repeat the collision.

8. **Design the loop to trust git state, not chat history.** Each iteration should independently: `git fetch` + `git log` to confirm the current tip, re-read the plan/task file for the next eligible item, and derive next-action purely from repo state. Emit a handoff prompt at the end of each turn carrying forward only what's reproducible from git (branch name, evidence links) — never rely on the model "remembering" prior turns. Define explicit pause conditions: no eligible todo task remains, a release isn't authorized, or the token budget is approaching its limit. When self-pacing a loop, wait roughly 2–2.5 minutes after a merge before firing the next iteration, to keep any prompt cache warm for the next discovery step.

## Gotchas

- Never merge from inside the worktree on Windows — file locks during the primary checkout's fast-forward can conflict; always merge from primary.
- `rm -rf` on worktree teardown can fail with a transient Windows lock error even after `git worktree remove` succeeds logically — treat this as benign, retry `prune` + `rm -rf`.
- A worktree does not protect two sessions from colliding on the *same* branch — always check for in-progress merge/rebase/cherry-pick markers first.
- A loop that reasons from chat history instead of re-reading git/plan state on every iteration will drift and duplicate or skip work across sessions.

## Diagram

[View diagram](diagram.html)
