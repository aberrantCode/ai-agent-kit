---
name: worktree-task-lifecycle
description: >
  Sub-skill of `github`. Full per-task worktree lifecycle: create an isolated worktree under
  `<repo>-wt/.worktrees/`, work in it safely, and remove it idempotently after merge — with
  Windows file-lock recovery, credentials-stay-in-primary-checkout rules, same-branch
  collision guards, and identical-file pull-collision handling. Use when starting feature
  work that needs isolation from the primary checkout, when running agent work that must not
  collide with concurrent edits, or when a worktree needs to be cleaned up after its branch
  merged. Triggers on "create a worktree", "set up an isolated workspace", "work in a
  worktree", "remove the worktree", "worktree won't delete", "permission denied removing
  worktree", and similar phrasings. Single lifecycle authority — the github merge/prune
  operations and multi-agent worktree-per-agent harnesses delegate here.
---

# Worktree Task Lifecycle

One worktree per task, created in a predictable place, torn down idempotently after merge.
This sub-skill is the **single authority** for worktree mechanics in the archive — `merge`
and `prune` delegate their worktree handling here; agent harnesses that run one worktree per
agent delegate here. Honors the parent `github` Output Contract: silent run, errors as they
occur, one concise summary.

---

## Canonical location

Create worktrees under a **sibling directory of the repo**, outside the checkout entirely:

```
<repo>-wt/.worktrees/<branch-name>/
```

E.g. work for `C:\development\myrepo` on branch `feat/auth` lives at
`C:\development\myrepo-wt\.worktrees\feat\auth`. Being outside the repo, it needs no
`.gitignore` entry and can never pollute `git status`.

**Legacy locations** are recognized, not migrated: if the repo already has an in-repo
`.worktrees/` or `worktrees/` directory in active use, keep using it (`.worktrees` wins if
both exist), but **verify it is ignored first** — `git check-ignore -q .worktrees` — and if
it is not, add it to `.gitignore` and commit before creating the worktree. A repo CLAUDE.md
preference for a worktree directory overrides both defaults.

---

## Create

1. Resolve the primary root and target branch:
   `root=$(git rev-parse --show-toplevel)`; branch off latest `dev` unless told otherwise.
2. `git worktree add "<repo>-wt/.worktrees/<branch>" -b <branch> dev`
3. Run project setup inside the worktree, auto-detected from project files
   (`package.json` → `npm install`, `Cargo.toml` → `cargo build`, `requirements.txt` /
   `pyproject.toml` → pip/poetry, `go.mod` → `go mod download`). Skip when none match.
4. Verify a clean baseline: run the project's test command. If tests fail, report the
   failures and ask (via `AskUserQuestion`) whether to proceed — a dirty baseline makes new
   breakage indistinguishable from pre-existing breakage.

All work for the task happens **only inside the worktree** — never touch the primary
checkout for in-flight work.

---

## Credentials stay in the primary checkout

Tokens, OAuth caches, and `.env` files belong to the **primary checkout** (or the user
profile), never to the worktree:

- A worktree-local `.env` or credential cache is **destroyed with the worktree** at teardown
  — sessions have lost OAuth tokens this way and had to re-authenticate everything.
- Never copy secrets into a worktree. If the task needs them, read them from the primary
  checkout's path at runtime, or use environment variables scoped to the machine/user.
- If a tool insists on writing auth state into the working directory, run that auth step in
  the primary checkout and symlink or reference it — or accept re-auth and say so in the
  summary.

---

## Working rules

- **Same-branch collision guard.** A worktree isolates *across* branches, not *within* a
  branch shared by two sessions. Before any `git add`/commit, check the target for
  `MERGE_HEAD`, `REBASE_HEAD`, or `CHERRY_PICK_HEAD` — if present, another session is
  mid-operation: wait, notify, or pivot to a fresh worktree on a different branch.
- **Identical-file pull collision.** When a pull/rebase into the worktree conflicts on files
  whose two sides are byte-identical (regenerated artifacts committed on both sides, e.g.
  `manifest.json`, lockfiles), verify equality first (`git diff` shows no content delta, or
  hash both sides), then resolve by taking either side (`git checkout --theirs <file>` +
  `git add`) — never hand-merge content that is already identical.
- **Commit inside the worktree**, on the feature branch, following the parent bundle's
  commit conventions; rebase onto `origin/dev` before opening the PR.

---

## Merge from the primary checkout — never from inside the worktree

On Windows, merging or fast-forwarding while standing inside the worktree can collide with
file locks held on the primary checkout. Sequence:

1. Push the branch and open the PR from the worktree (allowed).
2. Merge from the **primary** checkout (`cd "$(git rev-parse --show-toplevel)"` of the main
   repo), or via `gh pr merge`.
3. Fast-forward the primary checkout's `dev`, then tear down.

---

## Remove (post-merge, idempotent)

Safe to re-run at any point; every step skips cleanly if already done:

1. `git worktree remove "<path>"` — if it refuses on modified/untracked files, confirm the
   branch is merged, then `--force`.
2. `git worktree prune` — clears metadata even when step 1 half-succeeded.
3. If the directory lingers, force-remove it (`rm -rf` / `Remove-Item -Recurse -Force`).
   **Windows lock recovery:** a transient "Permission denied" here is benign — git has
   already untracked the worktree. Retry prune + remove once; if the directory still
   resists (lingering file handle), leave it on disk and state that in the summary
   ("worktree dir left on disk — locked handle; delete manually") rather than looping.
4. Delete the backing branch separately — removing a worktree never deletes its branch.
   Cleanup order is **worktree → local branch → remote branch** (parent principle).

---

## Red flags

- Creating an in-repo worktree directory without verifying it is git-ignored.
- Copying `.env`/tokens into a worktree "temporarily".
- Merging from inside the worktree on Windows.
- Looping on a locked directory instead of reporting and moving on.
- Proceeding past a failing baseline without asking.
- Two sessions committing to the same branch without checking in-progress operation markers.
