---
name: github-release
description: Sub-skill of `github`. Promote dev to main as a versioned production release — rebase dev if behind, auto-derive the next semantic version from conventional commits, merge with a merge commit, tag, publish a GitHub Release, and sync dev. Honors the parent Output Contract.
---

# Operation: release

**Goal.** Promote `dev` → `main` as a versioned release. Obey the parent **Output Contract**:
silent run, errors as they occur, one concise summary.

---

## Output Contract (binding — inlined, not a reference)

The `/release` command may load this file without the parent `github` SKILL.md in context, in
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
`ship`, not here.

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

## Step 5 — Detect the release route

**Before merging, decide whether `main` accepts a direct push or is PR-only.** Many repos
forbid direct pushes to `main` (a pre-push hook, GitHub branch protection, or a project rule
like a CLAUDE.md "`main` is updated only by a release PR" clause). Attempting the direct push
first and reacting to the rejection is wrong — it leaves a local merge commit to unwind and
burns a round-trip. Detect up front:

```bash
# 1. Project rule — grep the repo contract for a PR-only mandate on main
PR_ONLY_RULE=$(grep -riE "release PR|only .*(via|through) .*PR|push.*main.*forbidden" \
  CLAUDE.md AGENTS.md GEMINI.md docs/ 2>/dev/null | grep -ic main || true)
# 2. GitHub branch protection on main
PROTECTED=$(gh api "repos/{owner}/{repo}/branches/main/protection" --jq '.url' 2>/dev/null | grep -c . || true)
# 3. A tracked pre-push hook that refuses main (best-effort textual signal)
HOOK_BLOCKS=$(grep -rilE "refus.*push.*main|push.*main.*forbidden" .githooks .git/hooks 2>/dev/null | grep -c . || true)
```

If **any** of the three is non-zero, `main` is **PR-only** → take **Route B**. Otherwise
**Route A**. When unsure, prefer Route B: a release PR is always safe; a forbidden direct push
is not.

### Route A — direct merge + push (unprotected `main`)

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

If this push is unexpectedly rejected by a hook/protection, do **not** retry or bypass with
`--no-verify` / `SKIP_*` — discard the local merge (`git reset --hard origin/main`) and switch
to Route B.

### Route B — release PR + merge (PR-only `main`)

Do **not** create a local merge commit; open a PR from `dev` and let the merge happen on the
forge:

```bash
gh pr create --base main --head dev --title "release: $VERSION" \
  --body $'## Summary\n- Release '"$VERSION"' — <N> commits since '"$LAST_TAG"'.\n\n## Test Plan\n- [ ] gates green on dev\n- [ ] merge commit onto main; tag + Release; dev synced'
gh pr merge <PR#> --merge --subject "release: $VERSION"
```

**If the merge is blocked by a required review** (`mergeStateStatus: BLOCKED`,
`reviewDecision: REVIEW_REQUIRED`) and there is no second reviewer, the merge cannot proceed
normally. Check whether the owner may override:

```bash
gh api "repos/{owner}/{repo}/branches/main/protection/enforce_admins" --jq '.enabled'
```

- `enforce_admins == false` → an **admin override is the only path** for a solo release.
  Confirm once via `AskUserQuestion` (admin-merge / self-approve / stop), then
  `gh pr merge <PR#> --merge --admin`. Anticipate this rather than discovering it: a
  review-required rule on a repo with no other reviewer *always* needs the override.
- `enforce_admins == true` → the owner cannot override. **STOP** and tell the user a reviewer
  is required.

After the merge, `git fetch origin` so `origin/main` reflects the new merge commit before
tagging in Step 6 (tag `origin/main`, not a stale local `main`).

---

## Step 6 — Tag and publish

Guard against an existing tag (`git rev-parse "$VERSION"` succeeds → `AskUserQuestion`: pick a
new version or abort). Then:

```bash
git tag "$VERSION" origin/main   # tag the merged commit, not a possibly-stale local HEAD
```

### Roll the changelog BEFORE pushing the tag

**Create the tag locally, regenerate the changelog, land it, and only then push the tag.**
Any repo with a persistent changelog generator hits a hard ordering constraint here: the
`## [<version>]` section cannot exist until the tag object does, but a changelog-staleness
gate (pre-push hook or `validate.ps1`) refuses to publish a tag while that section is missing.
Pushing first and reacting to the rejection wastes a round-trip — the local tag created above
is already enough to generate the section.

```bash
ls scripts/Generate-Changelog.ps1 2>/dev/null   # skip this whole block if absent
pwsh ./scripts/Generate-Changelog.ps1           # local tag exists -> emits ## [<version>]
```

Then land `CHANGELOG.md` on `dev` the way any other change lands — a `chore:` branch and PR
(`chore: regenerate CHANGELOG for $VERSION`), never a direct push to a protected branch.
**Never** bypass the gate with `--no-verify` or a `SKIP_*` env var: that gate is what stops the
committed changelog falling one release behind after every release.

Now push the tag:

```bash
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
`release-init` operation (`sub-skills/release-init`, `/release-init`).

While tagging, check the repo's artifacts. If either check trips, print the one-line warning
and continue the release — do **not** auto-fix here:

| Check | Warning |
|---|---|
| `.github/workflows/release.yml` extracts notes from the committed `CHANGELOG.md` with an `[Unreleased]` fallback and no regenerate step (or shallow checkout) | `WARNING: release.yml publishes notes from the committed changelog — run /release-init to fix.` |
| `CHANGELOG.md` has content under `[Unreleased]` but no `## [<version>]` section for `$LAST_TAG` | `WARNING: CHANGELOG.md is stale (released content still under [Unreleased]) — run /release-init.` |

---

## Step 7 — Sync dev from main

Bring the release merge commit back onto `dev` so the branches share history. **The route mirrors
Step 5** — `dev` is usually PR-only too, and force-pushing it is both blocked and a policy
violation there.

### Route A — `dev` accepts direct push

```bash
git checkout dev
git rebase origin/main         # typically a fast-forward
git push --force-with-lease origin dev
```

### Route B — `dev` is PR-only

Open a sync PR instead of force-pushing (matches the `chore: sync dev with main after vX` history):

```bash
git checkout -b chore/sync-dev-after-$VERSION dev
git merge origin/main -m "chore: sync dev with main after $VERSION"   # usually a fast-forward
git push -u origin chore/sync-dev-after-$VERSION
gh pr create --base dev --head chore/sync-dev-after-$VERSION \
  --title "chore: sync dev with main after $VERSION" \
  --body $'## Summary\n- Merge the release merge commit from main back into dev.\n\n## Test Plan\n- [ ] No-op content merge; brings the release merge commit onto dev.'
gh pr merge <PR#> --merge --admin        # same admin-override rationale as Step 5 Route B
git checkout dev && git branch -D chore/sync-dev-after-$VERSION && git fetch origin --prune
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
| `main` is PR-only (hook/protection/project rule) | Detect in **Step 5** and take **Route B** from the start — do not attempt a direct push first |
| Push to main rejected by hook/protection | Not "behind" — discard local merge (`git reset --hard origin/main`) and switch to Route B. Never `--no-verify` / `SKIP_*` / force-push main |
| Push to main rejected as non-fast-forward | `git pull --rebase origin main` then retry — never force-push main |
| PR merge `BLOCKED` / `REVIEW_REQUIRED`, no reviewer | Check `enforce_admins`: if `false`, `AskUserQuestion` then `gh pr merge --admin`; if `true`, STOP — a reviewer is required |
| Tag push rejected by a changelog-staleness gate | Not a gate bug — regenerate `CHANGELOG.md` (the local tag already exists), land it on `dev` via a `chore:` PR, then push the tag. Never `--no-verify` |
| Tag already exists | AskUserQuestion: new version or abort |
| `$REPO` empty | STOP — `gh auth status` / `git remote -v` before any gh command |
