---
name: github-ship
description: Sub-skill of `github`. Ship current working changes (or an already-committed feature branch) into dev through a feature-branch PR — stage, commit, push, open the PR, merge with a merge commit, and clean up. Honors the Output Contract inlined in this file.
---

# Operation: ship

**Goal.** Take whatever is ready — uncommitted changes or a pre-committed feature branch — and
land it on `dev` through a PR, then clean up. Obey the **Output Contract** below: silent run,
errors as they occur, one concise summary.

---

## Output Contract (binding — inlined, not a reference)

The `/ship` command may load this file without the parent `github` SKILL.md in context, in
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

## Step 0a — Branch preflight (existence + naming)

**Ensure `dev` exists** on origin — create it if missing so the PR has a base:

```bash
if ! git ls-remote --heads origin dev | grep -q .; then
  git fetch origin main
  git branch dev origin/main 2>/dev/null || git branch dev main
  git push -u origin dev
fi
```

**Branch-name convention.** Feature branches must match
`^(feat|fix|refactor|docs|test|chore|perf|ci)/[a-z0-9._-]+$`. Any branch that ships to `dev`
must conform — validate below and **create or rename** as required (never rename `dev`/`main`):

```bash
CONV='^(feat|fix|refactor|docs|test|chore|perf|ci)/[a-z0-9._-]+$'
```

---

## Step 0b — Detect context

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PRIMARY_ROOT=$(git worktree list --porcelain | awk 'NR==1{print $2}')
[ "$REPO_ROOT" != "$PRIMARY_ROOT" ] && IN_WORKTREE=true || IN_WORKTREE=false
CURRENT_BRANCH=$(git branch --show-current)
AHEAD=$(git rev-list origin/dev..HEAD --count 2>/dev/null || echo 0)
DIRTY=$(git status --short | grep -c . || true)
```

- **Pre-committed** — `$CURRENT_BRANCH` is not `dev` and `$AHEAD > 0`: skip Steps 1–3, set
  `$BRANCH=$CURRENT_BRANCH`, infer `$MSG` from `git log -1 --format=%s`. If `$DIRTY > 0`, the
  dirty files would not ship — use `AskUserQuestion` (ship committed only / include as new
  commit / abort).
  - **Naming check:** if `$CURRENT_BRANCH` does not match `$CONV`, it must be **renamed**
    before it can ship. Infer a conventional name from the commit type (`git log -1 --format=%s`
    → `feat:`→`feat/…`, `fix:`→`fix/…`, else `chore/…`) plus a slug of the subject, then
    confirm the new name via `AskUserQuestion` (proposed name / keep current / enter a name).
    Apply with `git branch -m "$NEW_NAME"`, and if the old branch was already pushed,
    re-point the remote: `git push origin -u "$NEW_NAME"` and
    `git push origin --delete "$CURRENT_BRANCH"`. Update `$BRANCH=$NEW_NAME`.
- **Normal** — continue to Step 1. Step 5 will **create** the conforming branch with
  `git checkout -b "$BRANCH"`.

---

## Step 1 — Branch name and commit message

If the user supplied both, use them. Otherwise infer up to two suggestions each from the diff
and recent commits and ask with `AskUserQuestion` (headers `Branch name`, `Commit msg`).
Branch: `<type>/<slug>`. Message: conventional commit. Store as `$BRANCH`, `$MSG`.

Validate `$BRANCH` against `$CONV` before continuing. If it does not match (e.g. the user typed
a bare slug), normalize it — prefix the type inferred from `$MSG` and re-confirm — so the branch
created in Step 5 always conforms.

---

## Step 2 — Pull only if behind

```bash
git fetch origin
BEHIND=$(git rev-list HEAD..origin/$(git branch --show-current) --count 2>/dev/null || echo 0)
```

If `$BEHIND > 0`: `git stash --include-untracked && git pull --rebase && git stash pop`.
On rebase conflict, resolve the obvious ones; for the rest use `AskUserQuestion` (resolve
manually / abort). If unresolvable, `git rebase --abort` and stop.

---

## Step 3 — Stage (preview, then add)

Never `git add --all` blind. Preview:

```bash
git status --short
TO_STAGE=$(git status --short | grep -c . || true)
```

- `$TO_STAGE == 0` → nothing to ship, stop.
- `$TO_STAGE ≤ 10` and every path plausibly belongs to this change → `git add --all`.
- `$TO_STAGE > 10`, or any path looks unrelated → `AskUserQuestion` (stage all / stage a
  subset you name / abort).

---

## Step 4 — Test gate (generic runner)

Run the repo's own test runner if one is detectable — do not assume any specific stack layout.
First match wins:

```bash
cd "$REPO_ROOT"
if   [ -f scripts/Start-Tests.ps1 ]; then pwsh -NonInteractive -File scripts/Start-Tests.ps1 -NoPrompt -Parallel -SkipE2E
elif [ -f Makefile ] && grep -qE '^test:' Makefile; then make test
elif [ -f package.json ] && grep -qE '"test"[[:space:]]*:' package.json; then npm test
elif command -v pytest >/dev/null 2>&1 && { [ -f pytest.ini ] || [ -f pyproject.toml ] || [ -d tests ]; }; then pytest
else echo "[ship] no recognized test runner — skipping the gate"; fi
```

If the runner exits non-zero → **stop**, surface the failure, do not merge. If none was
detected, proceed but say so in the summary.

**Optional pre-PR review gate.** If the user asked to review before shipping (or the change is
substantial), offer to run `/code-review` on the staged diff before Step 6 — it blocks on
CRITICAL/HIGH findings. This is a companion command, not part of this operation; skip it
silently when not requested.

---

## Step 5 — Branch, commit, push

```bash
git checkout -b "$BRANCH"   # skip if already on the pre-committed branch
git commit -m "$MSG"        # skip if pre-committed
git push -u origin "$BRANCH"
```

---

## Step 6 — Open the PR into dev

```bash
PR_OUTPUT=$(gh pr create --base dev --head "$BRANCH" --title "$MSG" \
  --body "$(printf '## Summary\nFeature branch PR targeting dev.\n\n## Test plan\n- [ ] Smoke-tested locally')" 2>&1)
if echo "$PR_OUTPUT" | grep -qi "already exists"; then
  PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://github\.com[^[:space:]]+')
else
  PR_URL="$PR_OUTPUT"
fi
```

---

## Step 7 — Merge and clean up

From `$REPO_ROOT`, stash any post-hook working-tree changes so the post-merge checkout is not
blocked. If `$IN_WORKTREE`, remove the worktree before merging:

```bash
cd "$REPO_ROOT"
( ! git diff --quiet || ! git diff --cached --quiet ) && git stash --include-untracked && STASHED=true
[ "$IN_WORKTREE" = true ] && { git worktree remove "$REPO_ROOT" --force 2>/dev/null || git worktree prune; }
gh pr merge "$BRANCH" --merge --delete-branch --subject "$MSG"
gh pr view "$BRANCH" --json state --jq '.state'   # expect "MERGED"
```

Conditional cleanup and sync:

```bash
[ "$(git branch --show-current)" != "dev" ] && git checkout dev
git branch --list "$BRANCH" | grep -q . && git branch -d "$BRANCH"
git worktree prune
git pull origin dev
[ "$STASHED" = true ] && git stash pop
```

Apply the **Windows worktree-lock footgun** rule from the parent skill if a worktree dir
resists deletion.

---

## Step 8 — Summary (only expected output)

```
Shipped feat/foo → dev — PR #123, merge commit abc1234. Branch + worktree cleaned.
```

---

## Error Recovery

| Situation | Recovery |
|---|---|
| Tests fail (Step 4) | Stop; surface output; user fixes before retrying |
| Rebase conflict | AskUserQuestion: resolve manually or abort |
| Push rejected (non-fast-forward) | `git pull --rebase origin $BRANCH` then retry |
| PR checks failing | `gh pr checks $BRANCH` — do not force merge |
| `dev` used by worktree on merge | `cd $REPO_ROOT`; remove the worktree before `gh pr merge` |
| Local changes block post-merge checkout | Stash before merge (Step 7 does this); PR may already be merged — check `gh pr view` |
