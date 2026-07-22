---
name: github-merge
description: Sub-skill of `github`. Merge one or more open pull requests (resolved from PR numbers, branches, worktrees, or the current context) into dev with a merge commit, then clean up the worktree, local branch, and remote branch in the correct order. Honors the Output Contract inlined in this file — silent run, errors as they occur, one concise summary.
---

# Operation: merge

**Goal.** Merge already-open pull request(s) into `dev` with a merge commit, then fully clean
up. The merge unit is always a **PR** — targets that are branches or worktrees are resolved to
their open PR. This operation does not create PRs; if a branch has commits but no open PR,
stop and point the user at `/ship`.

Obey the **Output Contract** below: no narration, errors surfaced as they occur, one concise
summary at the end.

---

## Output Contract (binding — inlined, not a reference)

The `/merge` command may load this file without the parent `github` SKILL.md in context, in
which case a pointer to "the parent Output Contract" resolves to nothing. The contract is
therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now merging…"), no per-command status, no play-by-play.
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

## Step 1 — Resolve targets to PR numbers

Parse the invocation message per the parent **Parameter Contract**. Build a list of PR numbers:

- **Digits** → that PR number directly.
- **Branch name** → `gh pr list --head <branch> --base dev --state open --json number` — take
  the number. No open PR → record an error for this target: "no open PR for `<branch>` — run
  /ship".
- **Worktree path** → read its checked-out branch
  (`git -C <path> branch --show-current`), then resolve as a branch above. Remember the path
  for Step 4 cleanup.
- **Empty message** → the current context:
  - If you are inside a secondary worktree, use that worktree's branch.
  - Otherwise use the current branch: `gh pr view --json number,headRefName`.
  - If neither yields an open PR, use `AskUserQuestion` to ask for a PR number or branch.

Resolve the repo root and the primary worktree root once, up front:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PRIMARY_ROOT=$(git worktree list --porcelain | awk 'NR==1{print $2}')
```

Process each resolved PR through Steps 2–5 in turn. A per-target error does not abort the
whole run — record it and continue to the next target.

---

## Step 2 — Preflight (per PR)

```bash
git fetch --prune origin      # refresh remote-tracking refs before reasoning about state
gh pr view <n> --json state,isDraft,mergeable,mergeStateStatus,reviewDecision,headRefName,title
gh pr checks <n>
```

Gate, in order — each blocker stops *this target* only (record it, continue to the next):

1. `state == MERGED` → skip to cleanup (Step 4), note it. `state != OPEN` otherwise → stop.
2. `isDraft == true` → `AskUserQuestion` (mark ready with `gh pr ready <n>` / skip this PR).
   A draft passes every content gate and is then refused by GitHub, so gate it up front.
3. `mergeable == "UNKNOWN"` → transient right after a push. Poll up to 5× at 15s intervals,
   re-reading `gh pr view <n> --json mergeable`; only treat a *stable* non-`MERGEABLE` as real.
4. `mergeable == "CONFLICTING"` → stop this target; surface the conflict; never resolve remotely.
5. `mergeStateStatus == BEHIND` → the base moved; note it. `BLOCKED`, or any failing/pending
   `gh pr checks` line → required checks are in play:
   - Detect whether the repo even allows auto-merge:
     `gh repo view --json autoMergeAllowed -q .autoMergeAllowed`.
   - `true` and checks are merely *pending* → `gh pr merge <n> --merge --auto --delete-branch`
     and record "queued on auto-merge" for the summary.
   - `false`, or a check is *failing* → stop this target and print the failing check. Never
     `--admin`/`--no-verify` past a required gate here (release is the only op that may admin-merge).

To eyeball the change before merging, point the user at the companion `/diff-review <pr#>`
command (a visual HTML diff) — do not run it as part of this operation.

---

## Step 3 — Merge with a merge commit (per PR)

Always run from `$REPO_ROOT`, never from a secondary worktree:

```bash
cd "$REPO_ROOT"
```

If this PR's branch is checked out in a secondary worktree, **remove that worktree first** —
otherwise `--delete-branch` fails with "cannot delete branch … used by worktree":

```bash
git worktree remove <worktree-path> --force 2>/dev/null || git worktree prune
```

Then merge:

```bash
gh pr merge <n> --merge --delete-branch --subject "<pr-title>"
```

`--merge` preserves history; `--delete-branch` removes the remote branch. Confirm:

```bash
gh pr view <n> --json state --jq '.state'   # expect "MERGED"
```

**`--delete-branch` may report the branch is already gone — that is success, not failure.**
Repos configured by `repo-init` have `deleteBranchOnMerge: true`, so GitHub deletes the
remote branch server-side the instant the merge lands, before `gh` gets to it. Treat a
"branch not found" / "reference does not exist" response from the delete step as the desired
end state and continue silently; only a non-`MERGED` PR state is a real error.

This is deliberately belt-and-braces: cleanup must work identically whether or not
auto-delete is enabled on the repo, because `/merge` runs against repos that predate the
standard as well as ones that follow it.

---

## Step 4 — Clean up (worktree → local branch → remote)

The remote branch is already gone — deleted either by `--delete-branch` in Step 3 or by the
repo's `deleteBranchOnMerge` setting. Handle the local side, in order:

```bash
cd "$REPO_ROOT"

# 1. Worktree directory — remove if it survived Step 3.
git worktree prune
[ -d "<worktree-path>" ] && rm -rf "<worktree-path>"

# 2. Local branch — safe delete; only escalate to -D after confirming state == MERGED.
git branch --list "<branch>" | grep -q . && git branch -d "<branch>"

# 3. Stale remote-tracking ref — server-side auto-delete leaves origin/<branch> behind
#    locally until something prunes it.
git fetch --prune origin
```

**Every deletion here is idempotent by design.** Each is guarded so that "already absent" is
a no-op rather than an error — the branch may have been removed by auto-delete, by a previous
partial run, or by the user. Cleanup that only works from a pristine starting state is
cleanup that fails exactly when you need it.

**Windows worktree-lock footgun.** If `rm -rf` fails with "Permission denied", a file handle
is still open on the directory. Retry once after `git worktree prune`; if it still fails,
**leave the directory** and record the caveat for the summary — do not loop.

---

## Step 5 — Sync dev

After all targets are processed:

```bash
cd "$REPO_ROOT"
[ "$(git branch --show-current)" != "dev" ] && git checkout dev
git pull origin dev
```

If the user has uncommitted work on their primary `dev` checkout, do not clobber it — the
remote-tracking ref is updated regardless; note in the summary that they can `git pull` when
ready.

---

## Step 6 — Summary (the only expected output)

One concise block. Example shape:

```
Merged PR #1209 (feat/deploy-fitness) → dev — merge commit 791befa.
Cleanup: remote + local branch deleted, worktree removed.
```

For multiple targets, one line each. Prefix any target that failed its gate with its error.
If a worktree dir was left on disk, add a single caveat line telling the user to delete it
manually.

---

## Error Recovery

| Situation | Recovery |
|---|---|
| git-bash `fork`/`add_item … failed` mid-run (Windows Cygwin) | Not a git failure — bash could not fork. Re-run the same `git`/`gh` step through `pwsh`; shell state doesn't persist but repo state does, so just repeat the last command |
