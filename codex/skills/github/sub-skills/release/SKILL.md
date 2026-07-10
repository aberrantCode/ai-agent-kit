---
name: github-release
description: >
  Sub-skill of `github`. Promote dev to main as a versioned production release — rebase dev if
  behind, auto-derive the next semantic version from conventional commits, merge with a merge
  commit, tag, publish a GitHub Release, and sync dev. Triggers on "release this", "cut a
  release", "promote dev to main". Honors the parent Output Contract.
---

# Operation: release

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

Do not rename `main` or `dev` — they are protected. Feature-branch renaming is handled by the
ship operation, not here.

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

On conflict, resolve the obvious ones; otherwise ask the user a plain, concise question
(resolve manually / abort) and wait for the answer.

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

Present the three candidate versions to the user as a plain, concise question, pre-selecting
the auto-detected bump, and wait for the answer. Store the choice as `$VERSION`.

---

## Step 4 — Confirm

Show a one-block summary (from → into, last → new version, commit count) and confirm with the
user — ask a plain, concise question (ship it / abort) and wait for the answer. On abort, stop
with zero git changes made.

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
| ahead only | ask the user: push local commits first, or abort |
| diverged (both > 0) | **STOP** — do not merge; report and abort |

```bash
git merge --no-ff origin/dev -m "release: $VERSION"
git push origin main
```

---

## Step 6 — Tag and publish

Guard against an existing tag (`git rev-parse "$VERSION"` succeeds → ask the user to pick a new
version or abort). Then:

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

## Release-Automation Standard (verify and warn — never fix here)

Release notes must be derived from git **at tag time**; a committed `CHANGELOG.md` is a cache,
never the source of truth. The full spec and the provisioning/repair operation live in the
`release-init` operation (`sub-skills/release-init`).

While tagging, check the repo's artifacts. If either check trips, print the one-line warning
and continue the release — do **not** auto-fix here:

| Check | Warning |
|---|---|
| `.github/workflows/release.yml` extracts notes from the committed `CHANGELOG.md` with an `[Unreleased]` fallback and no regenerate step (or shallow checkout) | `WARNING: release.yml publishes notes from the committed changelog — run the release-init operation to fix.` |
| `CHANGELOG.md` has content under `[Unreleased]` but no `## [<version>]` section for `$LAST_TAG` | `WARNING: CHANGELOG.md is stale (released content still under [Unreleased]) — run the release-init operation.` |

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
| Rebase conflict (Step 2/7) | Ask the user: resolve manually or abort |
| Local main diverged | **STOP** — do not merge |
| Push to main rejected | `git pull --rebase origin main` then retry — never force-push main |
| Tag already exists | Ask the user: new version or abort |
| `$REPO` empty | STOP — `gh auth status` / `git remote -v` before any gh command |
