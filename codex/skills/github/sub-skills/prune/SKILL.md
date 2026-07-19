---
name: github-prune
description: >
  Sub-skill of `github`. Audit and remove stale git worktrees, local branches, and remote
  (origin) branches that are already merged into dev, protecting anything with uncommitted
  changes. Triggers on "clean up branches", "prune stale branches", "clean up worktrees".
  Honors the parent Output Contract.
---

# Operation: prune

**Goal.** Remove stale worktrees and branches (local + origin) already merged into `dev`,
protecting anything dirty. Obey the parent **Output Contract**: silent run, errors as they
occur, one concise summary.

---

## Step 1 — Verify dev exists

```bash
git branch --list dev
git branch -r --list origin/dev
```

Missing locally or on origin → stop; without `dev` there is no merge base for "stale".

---

## Step 2 — Fetch, prune, detect merge strategy

```bash
git fetch origin --prune
git log dev --merges --max-count=10 --oneline
```

- Fewer than 2 merge commits → `MERGE_STRATEGY=squash` (use `git cherry`).
- Several merge commits → `MERGE_STRATEGY=standard` (use `--merged` / `--is-ancestor`).

---

## Step 3 — Categorize worktrees, local branches, remote branches

Parse `git worktree list --porcelain` (skip the first/main entry). Exclude `dev`, `main`,
`master`, `origin/HEAD`, and any branch checked out in a worktree.

**Merged check:**
- *standard:* `git merge-base --is-ancestor <HEAD> dev` (exit 0 = merged), or
  `git branch --merged dev` / `git branch -r --merged dev`.
- *squash:* `git cherry dev <branch>` — every line starts with `-` (and non-empty) = merged;
  any `+` line, or empty output, = keep.

**Dirty check** (worktrees): `git -C <path> status --porcelain` — any output = dirty.

Categorize: merged + clean → stale (deletion candidate); merged + dirty → blocked (never
delete); not merged → active (ignore).

---

## Step 4 — Present and confirm

Show a grouped list (worktrees / local branches / remote branches) plus a "blocked — dirty"
section. If nothing is stale, say so and stop. Otherwise ask the user a plain, concise
question — delete all listed, or exclude some (follow up with a list of items to **keep**) —
and wait for the answer. Confirm the final list.

---

## Step 5 — Delete (worktrees → local → remote)

```bash
git worktree remove <path>            # retry with --force if the branch is checked out there
git branch -d <branch>                # safe delete only; never silently escalate to -D
git push origin --delete <branch>     # strip the origin/ prefix
```

Track each result (success / failure with stderr). Apply the **Windows worktree-lock footgun**
rule from the parent skill if a worktree dir resists removal.

---

## Step 6 — Summary (only expected output)

```
Removed 3 (worktree feat/login + its local & remote branch). Skipped 1 dirty (fix/wip). Failed 0.
```

Write no audit file. Git history is the archive of record for what was deleted; a tracked log
would only restate it, and would land as an uncommitted file on `dev` every run.
