---
name: github-release
description: Sub-skill of `github`. Promote dev to main as a versioned production release — rebase dev if behind, auto-derive the next semantic version from conventional commits, stamp that version onto the repo's own version references (README badge, manifests) and roll the changelog before tagging, merge with a merge commit, tag, publish a GitHub Release, and sync dev. Honors the parent Output Contract.
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

**Fold Step 4 into this one prompt.** Put the from→into / commit-count summary in the question
text, make the recommended version the first option, and add a fourth **Abort** option — the
version choice *is* the go-ahead. One prompt, not two round-trips; only split them if the
payload assessment needs its own confirmation.

---

## Step 4 — Confirm

Normally folded into Step 3 (see above). Only stands alone when Step 3 was skipped (version
pinned by the invocation message): show a one-block summary (from → into, last → new version,
commit count) and confirm via `AskUserQuestion` (ship it / abort). On abort, stop with zero git
changes made.

---

## Step 4b — Stamp `$VERSION` onto `dev` before tagging

Repos advertise their own version in files that are **not** derived from the tag: a README
shields.io badge, a token/package manifest, a `VERSION` file. Tagging without updating them
ships a release whose own artifacts claim the *previous* version — and if the repo has a
docs-truth gate, that gate will block the tag push mid-release, leaving a half-finished
release to unwind. Stamp first, tag second.

> **EXCEPTION — a gate that keys version refs to the CURRENT tag inverts this order.** Some
> repos enforce that the version refs must *equal the latest existing tag*, resolving "latest
> version" from **local git tags** (e.g. AC_DESIGN's `scripts/check_docs.py` via
> `git tag --sort=-v:refname`, run by the pre-push `validate.ps1`). On such a repo you CANNOT
> stamp `$VERSION` before the tag exists — the gate rejects the bump ("badge cites v0.9.0,
> latest tag is v0.8.0") and blocks *every* push carrying it, including the prepare branch.
> **Detect it cheaply:** stamp into a throwaway edit and run the repo gate; if it fails
> *because the new version ≠ the current tag*, take the **deferred path** —
>   - the prepare PR below rolls the **changelog ONLY** (no version-ref edits), and
>   - the version-ref stamp + rebuild moves to **[Step 6b](#step-6b--deferred-version-stamp-tag-keyed-gate)**, AFTER the tag is created.
>
> The `check_docs`/`validate` idiom is common in the AC repos — when releasing one, assume the
> deferred path unless a quick check proves otherwise.

**This step is conditional. Detect, and skip silently when nothing matches — never create an
empty PR.** In the deferred path this step's *only* content is the changelog roll.

### Detect

```bash
V=${VERSION#v}            # 1.2.3
STAMPED=()

# 1. shields.io version badges in real docs (NOT templates/examples)
grep -rlE 'badge/version-v[0-9]+\.[0-9]+\.[0-9]+' --include=*.md . 2>/dev/null \
  | grep -vE '(^|/)(docs/templates|artifacts/markdown|artifacts/github|\.github/ISSUE_TEMPLATE)/'

# 2. common manifests
[ -f tokens/tokens.json ] && grep -q '"version"' tokens/tokens.json && echo tokens/tokens.json
[ -f package.json ]       && echo package.json
[ -f pyproject.toml ]     && echo pyproject.toml
[ -f VERSION ]            && echo VERSION
```

### Rules

- **Only stamp files that assert *this repo's current* version.** A badge inside a template or
  a worked example is teaching syntax, not a claim. If you find a stale version in an example,
  do **not** bump it on every release — replace the digits with a placeholder (`vX.Y.Z`) once,
  so it can never go stale again. Bumping an example is a bug you will repeat forever.
- **Never touch a generated file.** If the repo generates artifacts from a manifest, edit the
  manifest and re-run its build (e.g. `python scripts/build_tokens.py`), then verify with the
  repo's own drift check rather than hand-editing outputs.
- `package.json` → `npm version "$V" --no-git-tag-version` (it also updates the lockfile).
  Otherwise edit the single version field in place; do not reformat the file.
- Roll the changelog in this same commit when the repo keeps a Keep-a-Changelog `[Unreleased]`
  section: rename it to `## [$VERSION] — YYYY-MM-DD`, open a fresh empty `[Unreleased]`, add
  the `[$VERSION]` compare-link definition, and repoint `[Unreleased]` at `$VERSION...HEAD`.
  One "prepare" commit, not two.

### Land it on `dev`

`dev` is usually PR-only (same detection as Step 5), so do not assume a direct push:

```bash
git checkout -b "chore/prepare-$VERSION" origin/dev
# ...stamp the files, roll the changelog...
git commit -am "chore: prepare $VERSION"
git push -u origin "chore/prepare-$VERSION"
gh pr create --base dev --head "chore/prepare-$VERSION" --title "chore: prepare $VERSION" \
  --body $'## Summary\n- Stamp '"$VERSION"' onto the repo\'s own version references and roll the changelog.\n\n## Test Plan\n- [ ] repo gates green'
gh pr merge <PR#> --merge --delete-branch --subject "chore: prepare $VERSION"
git checkout dev && git pull origin dev
```

### Verify before proceeding

Run the repo's own gate (`scripts/validate.ps1`, `make check`, `npm test` — whatever Step 4's
payload implies). **If the repo has a docs/version-truth check, it must pass here**, because it
is what would otherwise block the tag push in Step 6. Only then continue to Step 5.

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
# 2. GitHub branch protection on main (no leading slash is DELIBERATE — a leading "/..."
#    is rewritten by MSYS on Git-Bash and the call silently no-ops; this form is MSYS-safe)
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

## Step 6b — Deferred version stamp (tag-keyed gate)

**Only when Step 4b detected a current-tag-keyed version gate** (skip entirely otherwise — the
normal path already stamped `dev` in Step 4b and the bump rode the release merge onto `main`).
The tag now exists, so the version refs can finally equal it. Do it once, then carry it to
**both** branches so neither lags a release behind:

```bash
# 1. Create the tag LOCALLY first (Step 6 already did this) so the gate's
#    `git tag --sort=-v:refname` sees $VERSION as latest while you stamp.
git worktree add "<repo>-wt/.worktrees/chore-stamp-$VERSION" -b "chore/stamp-$VERSION" origin/dev
#    ...in that worktree: bump README badge + manifest version to $VERSION, then rebuild
#    (python scripts/build_tokens.py, etc.). Gate now passes: refs == latest local tag.
#    Push the TAG and the branch FROM that worktree (its working tree matches the tag):
git push origin "$VERSION"                       # validate runs on the worktree tree -> passes
git push -u origin "chore/stamp-$VERSION"
```

Then open a `chore:` PR to `dev` and merge it; **then open a `dev`→`main` PR and merge** so
`main`'s own artifacts match the tag (in the deferred path the bump did NOT ride the release
merge, so `main` would otherwise sit one version behind). After this, `dev == main` and Step 7
is a no-op.

**Worktree cleanup footgun:** if you used a helper worktree here, `gh pr merge --delete-branch`
from the primary checkout will fail to delete the LOCAL branch while the worktree still holds
it (`error: cannot delete branch '…' used by worktree`). Remove the worktree **before** the
`--delete-branch` merge (per the parent cleanup order: worktree → local branch → remote).

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
| Version-ref stamp (Step 4b) rejected on the PREPARE push ("badge cites v0.9.0, latest tag is v0.8.0") | The gate keys refs to the **current** tag — you cannot stamp before tagging. This is the Step 4b **EXCEPTION**: revert the version-ref edits (keep the changelog roll), release + tag first, then stamp in **Step 6b** |
| Tag push rejected by a version/docs-truth gate, `dev` already stamped | Step 4b's normal path was right but a file was missed. The tag exists, so refs really are stale: stamp the flagged file on `dev` via a `chore:` PR, re-push the tag, and add it to Step 4b's detection list |
| Tag already exists | AskUserQuestion: new version or abort |
| `$REPO` empty | STOP — `gh auth status` / `git remote -v` before any gh command |
| git-bash throws `fatal error - add_item (…) failed` / `fork` mid-run (Windows Cygwin) | Not a git failure — the bundled bash could not fork. Re-run the same git/gh command through **PowerShell** (`pwsh`); shell state does not persist but the repo state does, so just repeat the last step |
| A helper worktree blocks `--delete-branch` ("branch used by worktree") | Remove the worktree first, then delete the branch (cleanup order: worktree → local → remote). The remote branch was already deleted by `--delete-branch`; only the local delete failed — finish with `git worktree remove <path>` then `git branch -D <branch>` |
