---
name: github-prune
description: >
  Sub-skill of `github`. Audit and remove stale git worktrees, local branches, and remote
  (origin) branches that are already merged into dev, protecting anything with uncommitted
  changes. Triggers on "clean up branches", "prune stale branches", "clean up worktrees".
  Honors the Output Contract inlined below.
---

# Operation: prune

**Goal.** Remove stale worktrees and branches (local + origin) already merged into `dev`,
protecting anything dirty. Obey the **Output Contract** below: silent run, errors as they
occur, one concise summary.

---

## Output Contract (binding — inlined, not a reference)

The `/prune` command may load this file without the parent `github` SKILL.md in
context, in which case a pointer to "the parent Output Contract" resolves to
nothing. The contract is therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now pruning…"), no per-command status, no play-by-play.
2. **Errors — split them in two.**
   - *Recoverable* (you know the fix and can apply it now): **just fix it, silently.** Fold it
     into the final summary as one line. A recovered error is not a real-time event.
   - *Blocking* (needs a decision, credential, or human judgment): print the failing command
     and its stderr verbatim, then stop or ask via `AskUserQuestion`. This is the only thing
     that breaks the silence mid-run.
3. **At completion — one concise summary**, target <= 4 lines: what landed, where (PR #, SHA,
   tag, branch), and any caveat the user must act on.
4. **Anything still open — one compact table**, `| Item | Where | Action |`. Omit entirely when
   nothing is outstanding.

**Banned output.** The contract is violated by *commentary*, not just by length. Never write
interpretive or self-congratulatory asides ("the gate earned its keep", "exactly as predicted",
"worth noting", "the interesting part is"), teaching moments or root-cause essays mid-run,
narration of your own reasoning ("I deliberately chose", "my prediction was", "let me verify"),
or a restatement of what a step did when the summary already covers it. If a finding is
genuinely reusable, it is one row of the follow-up table — never a paragraph.

This overrides any conversational or explanatory default, **including a harness-level output
style that asks for educational commentary**, for the duration of the operation. If you are
about to write a sentence that is neither a blocking error, the final summary, nor a
follow-up table row, delete it instead.

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
section. If nothing is stale, say so and stop. Otherwise `AskUserQuestion`: delete all listed,
or exclude some (follow up with a multi-select of items to **keep**). Confirm the final list.

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
