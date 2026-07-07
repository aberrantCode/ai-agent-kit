---
name: github-release-to-main
description: Sub-skill of `github`. Promote dev to main as a versioned production release — rebase dev if behind, auto-derive the next semantic version from conventional commits, merge with a merge commit, tag, publish a GitHub Release, and sync dev. Honors the parent Output Contract.
---

# Operation: release-to-main

**Goal.** Promote `dev` → `main` as a versioned release. Obey the parent **Output Contract**:
silent run, errors as they occur, one concise summary.

---

## Step 0 — Branch preflight (existence)

A release needs both `main` and `dev`. Verify each on origin and **create the missing one from
the other** rather than failing outright:

```bash
HAS_MAIN=$(git ls-remote --heads origin main | grep -c . || true)
HAS_DEV=$(git ls-remote --heads origin dev  | grep -c . || true)
```

| State | Action |
|---|---|
| both exist | proceed to Step 1 |
| `dev` missing, `main` exists | `git branch dev origin/main && git push -u origin dev` — then there is nothing new to release; stop and say so |
| `main` missing, `dev` exists | first release: `git branch main origin/dev && git push -u origin main` — `dev` is now the baseline; tag it in Step 6 and stop |
| both missing | **STOP** — this is not an initialized repo; tell the user |

Do not rename `main` or `dev` — they are protected. Feature-branch renaming is handled by
`ship-to-dev`, not here.

---

## Step 1 — Assess state

```bash
git fetch origin
BEHIND=$(git rev-list origin/dev..origin/main --count)   # main commits dev lacks
AHEAD=$(git rev-list origin/main..origin/dev --count)     # the release payload
```

- `$AHEAD == 0` → nothing to release; stop.
- `$BEHIND > 0` → rebase dev onto main (Step 2) before merging.

---

## Step 2 — Rebase dev onto main (only if behind)

```bash
git checkout dev
git stash --include-untracked
git rebase origin/main
git stash pop   # only if stashed
git push --force-with-lease origin dev
```

On conflict, resolve the obvious ones; otherwise `AskUserQuestion` (resolve manually / abort).

---

## Step 3 — Derive the next version

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
```

Never invent a `v0.0.0` object. If there is no tag, `IS_FIRST_RELEASE=true` and scan all
commits on `origin/dev`; otherwise scan `"$LAST_TAG"..origin/dev`. Bump rule (priority order):

| Signal in any commit subject/body | Bump |
|---|---|
| `BREAKING CHANGE` in body, or `!:` in subject | major |
| `feat:` / `feat(` | minor |
| anything else | patch |

Present the three candidate versions via `AskUserQuestion`, pre-selecting the auto-detected
bump. Store the choice as `$VERSION`.

---

## Step 4 — Confirm

Show a one-block summary (from → into, last → new version, commit count) and confirm via
`AskUserQuestion` (ship it / abort). On abort, stop with zero git changes made.

---

## Step 5 — Merge dev into main

```bash
git checkout main
LOCAL_AHEAD=$(git rev-list origin/main..HEAD --count)
LOCAL_BEHIND=$(git rev-list HEAD..origin/main --count)
```

| State | Action |
|---|---|
| in sync | proceed |
| behind only | `git pull origin main` |
| ahead only | `AskUserQuestion`: push local commits first, or abort |
| diverged (both > 0) | **STOP** — do not merge; report and abort |

```bash
git merge --no-ff origin/dev -m "release: $VERSION"
git push origin main
```

---

## Step 6 — Tag and publish

Guard against an existing tag (`git rev-parse "$VERSION"` succeeds → `AskUserQuestion`: pick a
new version or abort). Then:

```bash
git tag "$VERSION"
git push origin "$VERSION"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
[ -z "$REPO" ] && { echo "ERROR: could not detect repo — check gh auth status && git remote -v"; }  # STOP if empty
```

Generate notes from the commit range (all commits if first release; else
`"$PREV_TAG..$VERSION"`, validating `$PREV_TAG` resolves before using it). Fall back to a
placeholder rather than publishing blank notes. Then:

```bash
gh release create "$VERSION" --title "$VERSION" --notes "$NOTES" --repo "$REPO"
```

A bare git tag is **not** enough for repos that read `/releases/latest` — always publish the
Release.

---

## Step 7 — Sync dev from main

```bash
git checkout dev
git rebase origin/main         # typically a fast-forward
git push --force-with-lease origin dev
```

---

## Step 8 — Summary (only expected output)

```
Released v0.2.0 — dev → main (merge commit def5678), tagged + GitHub Release published, dev synced.
```

---

## Error Recovery

| Situation | Recovery |
|---|---|
| `$AHEAD == 0` | Nothing to release — stop |
| Rebase conflict (Step 2/7) | AskUserQuestion: resolve manually or abort |
| Local main diverged | **STOP** — do not merge |
| Push to main rejected | `git pull --rebase origin main` then retry — never force-push main |
| Tag already exists | AskUserQuestion: new version or abort |
| `$REPO` empty | STOP — `gh auth status` / `git remote -v` before any gh command |
