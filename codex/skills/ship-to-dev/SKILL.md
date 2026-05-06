---
name: ship-to-dev
description: Use when the user wants to ship current working changes through a feature branch PR into the DEV branch — covers pulling latest, staging, committing, pushing, PR creation, merge, branch cleanup, and syncing DEV locally.
---

# Ship to DEV

Automates the full feature-branch → DEV merge workflow for this repository.
Run this whenever you have uncommitted work ready to integrate into DEV.

---

## Prerequisites: Ensure DEV Exists

Before starting the main workflow, confirm `dev` exists on the remote.
If it does not, create it from `main` now:

```bash
# Check whether dev exists on origin
git ls-remote --heads origin dev

# If nothing was returned — create it:
git fetch origin main
git checkout -b dev origin/main
git push -u origin dev
git checkout main   # return to main (or wherever you were)
```

> If `dev` already exists, skip this block entirely.

---

## Workflow

Follow every step in order. Do not skip steps, do not reorder them.

### Step 1 — Ask the user for a branch name and commit message

Before touching git, collect:

| Input | Format | Example |
|---|---|---|
| **Feature branch name** | `feature/<short-slug>` | `feature/add-versioning` |
| **Commit message** | Conventional commit | `feat: embed version number in build artifact` |

If the user does not supply these, ask:
```
What should the feature branch be called? (e.g. feature/my-change)
What is the commit message? (e.g. feat: describe the change)
```

Store them as `$BRANCH` and `$MSG` for the rest of the steps.

---

### Step 2 — Pull latest on the current branch

```bash
git pull --rebase
```

If git refuses with `cannot pull with rebase: You have unstaged changes`, the working-tree changes block the rebase. Stash them first, pull, then restore — the changes will be staged in Step 3:

```bash
git stash --include-untracked
git pull --rebase
git stash pop
```

If rebase produces conflicts after the pull:
1. Show the conflicting files with `git status`.
2. Ask the user to resolve them, or resolve obvious ones (whitespace, generated files) yourself.
3. After resolution: `git add <resolved-files>` then `git rebase --continue`.
4. If the rebase is unresolvable, abort with `git rebase --abort` and stop — report the conflict to the user.

---

### Step 3 — Stage changes (preview, then add)

**Never run `git add --all` blind.** The working tree often holds pre-existing WIP from
other sessions or branches; sweeping all of it into one commit is the most destructive
thing this workflow can do. Preview, then decide.

**Preview what would be staged:**

```bash
git status --short
git diff --stat
TO_STAGE=$(git status --short | grep -c . || true)
echo "Would stage $TO_STAGE file(s)."
```

If `$TO_STAGE` is 0 → stop and tell the user there is nothing to ship.

**Decision:**

- **`$TO_STAGE` ≤ 10 AND every listed file relates to this session's work** → proceed
  with `git add --all`. State briefly which files are being staged.

- **`$TO_STAGE` > 10, OR any file looks unrelated to this session, OR you cannot
  account for any path** → ask the user what to stage:
  - "Stage everything (`git add --all`)"
  - "Stage only these paths: …" (have the user list paths/globs, then `git add <paths>`)
  - "Abort — let me clean up the working tree first"

**After staging — final summary before commit:**

```bash
git status --short
git diff --cached --stat
```

If the staging area is empty after that (e.g. user picked a subset that matched nothing),
stop and tell the user.

---

### Step 4 — Create the feature branch and commit

```bash
git checkout -b $BRANCH
git commit -m "$MSG"
```

Verify the commit was created:

```bash
git log --oneline -1
```

---

### Step 5 — Push the feature branch to origin

```bash
git push -u origin $BRANCH
```

---

### Step 6 — Create a PR targeting DEV

```bash
gh pr create \
  --base dev \
  --head $BRANCH \
  --title "$MSG" \
  --body "$(cat <<'EOF'
## Summary
Automated feature branch PR targeting DEV.

## Changes
See commit diff for details.

## Test plan
- [ ] Smoke-tested locally before shipping
EOF
)"
```

Capture and display the PR URL from the output.

---

### Step 7 — Merge the PR (squash merge)

```bash
gh pr merge $BRANCH \
  --squash \
  --delete-branch \
  --subject "$MSG"
```

`--delete-branch` removes the **remote** feature branch automatically.
Wait for the merge to complete — confirm with:

```bash
gh pr view $BRANCH --json state --jq '.state'
# Expected: "MERGED"
```

---

### Step 8 — Delete the local feature branch

```bash
git checkout main
git branch -d $BRANCH
```

If `git branch -d` reports the branch is not found, `gh pr merge` already removed it during the merge checkout — this is not an error, continue to Step 9.

If `-d` refuses with "not fully merged", use `-D` only after confirming the remote merge state in Step 7 returned `"MERGED"`.

---

### Step 9 — Switch to DEV and pull

```bash
git checkout dev
git pull origin dev
```

Show the final state:

```bash
git log --oneline -5
```

---

## Quick Reference

```
1. Ensure DEV exists on remote (create from main if missing)
2. Pull latest + resolve conflicts          git pull --rebase
3. Stage all changes                        git add --all
4. Create feature branch + commit           git checkout -b $BRANCH && git commit
5. Push                                     git push -u origin $BRANCH
6. Open PR into DEV                         gh pr create --base dev
7. Merge PR (squash) + delete remote        gh pr merge --squash --delete-branch
8. Delete local branch                      git branch -d $BRANCH
9. Switch to DEV and pull                   git checkout dev && git pull
```

---

## Error Recovery

| Situation | Recovery |
|---|---|
| Rebase conflict can't be resolved | `git rebase --abort` — stop and tell user |
| Push rejected (non-fast-forward) | `git pull --rebase origin $BRANCH` then retry push |
| PR merge fails (status checks) | Show failure reason with `gh pr checks $BRANCH` — do not force merge |
| `gh` not authenticated | `gh auth login` — pause workflow until authenticated |
| Feature branch already exists | Ask user whether to reuse it or choose a different name |
