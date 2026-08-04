# GitHub Skill — Change Proposal (from the 2026-07-22 audit)

**Status:** proposal only. No skill files edited. The user decides what lands.
**Source:** `REPORT.md` (T1–T12) in this directory.
**Scope of files inspected:** `claude/skills/github/SKILL.md`; all 9 sub-skills; `commands/merge.md`; `repo-init/templates/{hooks,artifacts,*.json}`; `release-init/templates/{Generate-Changelog.ps1,release.yml}`; root `.gitattributes`; `scripts/{validate.ps1,audit.ps1,push-to-profile.ps1}`; the Codex mirror `codex/skills/github/`.

---

## How the dangling-vs-duplication tension (F-KO-04) is resolved in this proposal

The bundle already inlines the full **Output Contract** into every sub-skill because sub-skills load standalone (a `/merge` invocation may not carry `SKILL.md`). New shared rules face the same trap. This proposal uses a **two-tier rule** so nothing becomes a dangling pointer *and* nothing is copy-pasted as a 20-line block into 8 files:

- **Tier A — invariant/policy (one line).** Lives as a named bullet in `SKILL.md` → *Cross-Operation Principles*. Short enough that the sub-skill that executes it carries a **one-line** inline reminder naming the concrete flag/command. The principle is the canonical spec; the inline line is the load-bearing reminder on standalone load.
- **Tier B — executable procedure (a command block).** Lives as a **Step** inside the owning sub-skill(s), because those are what load standalone. It is *not* duplicated into `SKILL.md`; `SKILL.md` only names it in one Tier-A bullet.

This is exactly the pattern the skill already uses for the "Windows worktree-lock footgun" (principle in `SKILL.md`, applied in `merge`/`ship`/`prune` steps). Every change below labels which tier it uses.

---

# PART 1 — NET-NEW CHANGES (ordered by report priority)

## P0

### CU-1 — Anti-bypass: prefer the named op over hand-rolled git/gh (T1 · F-KO-01, F-KO-02, F-OP-04)

**Target:** `claude/skills/github/SKILL.md`
- (a) frontmatter `description:` — add bypass-shaped triggers.
- (b) new short section immediately after the `## Operations` table.
- (c) one Tier-A bullet in *Cross-Operation Principles*.

**Concrete change (b) — new section:**

```markdown
## Prefer the named operation over hand-rolling git/gh

When you are about to run `gh pr create`, `gh pr merge`, a `git push` that opens or lands a
PR, or to replicate init/release/prune logic by hand — **route through the matching operation
instead of reimplementing it in Bash.** `/ship`, `/merge`, `/release`, `/init-repo`, `/prune`
carry the preflight, cleanup, ref-hygiene, and Output-Contract guarantees; a hand-rolled
`gh`/`git` sequence silently drops all of them. This applies most in autonomous, `/loop`, and
background runs, where the temptation to inline a quick `gh pr merge` is highest.

When a **batch** of PRs is left pending, surface the merge decision through `AskUserQuestion`
(a multi-select of PRs to merge) — never a prose paragraph asking the user what to do.
```

**Concrete change (c) — Tier-A bullet under Cross-Operation Principles:**

```markdown
- **Route repository actions through the named operation.** Opening/landing a PR, cutting a
  release, or pruning branches goes through `/ship` `/merge` `/release` `/prune` — not an
  ad-hoc `gh`/`git` sequence that skips their guarantees. See "Prefer the named operation".
```

**Concrete change (a) — append to `description:`** (near the existing trigger list):
`… "merge PR 76", "merge these PRs", "land this branch", "open a PR for this", "cut a release", "clean these branches" — route these through the named operation rather than raw gh/git.`

**Why it is safe / architectural:** additive prose; changes no operation's behavior. Reinforces the thin-orchestrator contract rather than moving logic.
**Verification:** doc-only. Covered by the T12 frontmatter-YAML lint (CU-14) so the added trigger text can't break the frontmatter.

---

### CU-2 — Shared merge/ship preflight: draft, UNKNOWN, protection, checks, auto-merge (T2 · F-KO-06, F-KO-20, F-KO-21, F-DM-01, F-DM-12, F-OP-02)

**Target (Tier A):** `SKILL.md` → Cross-Operation Principles, one new bullet.
**Target (Tier B):** `merge/SKILL.md` **Step 2** (replace) and `ship/SKILL.md` (new **Step 6.5**, between "Open the PR" Step 6 and "Merge and clean up" Step 7).

**Tier-A bullet (SKILL.md):**

```markdown
- **Never merge before a preflight passes.** Before any `gh pr merge`, read
  `gh pr view <n> --json state,isDraft,mergeable,mergeStateStatus,reviewDecision` and
  `gh pr checks <n>`. A `mergeable == "UNKNOWN"` right after a push is transient — poll, don't
  fail. `isDraft` is its own gate (ask: mark-ready or skip). Required checks / `BLOCKED` mean
  either `--auto` (only if the repo has auto-merge enabled) or watch-to-green — never bypass.
  `merge` and `ship` carry the executable preflight; see their steps.
```

**Tier-B — replace `merge/SKILL.md` Step 2 body with:**

```markdown
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
```

**Tier-B — insert `ship/SKILL.md` Step 6.5 (before Step 7 merge):**

```markdown
## Step 6.5 — Merge preflight

`ship` opened the PR moments ago, so `mergeable` is almost always `UNKNOWN` on first read and
CI has not started. Do not merge blind (the recurring "failed 2–3× then watched checks"):

```bash
gh pr view "$BRANCH" --json isDraft,mergeable,mergeStateStatus,reviewDecision
```

- Poll `mergeable == UNKNOWN` up to 5× / 15s before treating it as real.
- `isDraft` (only if you opened it draft) → `gh pr ready`.
- `mergeStateStatus == BLOCKED` + pending checks → if `gh repo view --json autoMergeAllowed`
  is `true`, use `--auto` in Step 7's merge; else watch `gh pr checks "$BRANCH" --watch` to
  green, then merge. A *failing* check stops the ship — surface it (Error-Recovery already
  covers this).
```
Then Step 7's `gh pr merge` gains `--auto` conditionally (leave the `--merge --delete-branch --subject` as-is).

**Why it is safe / architectural:** the executable block lives in the two ops that load standalone (Tier B); `SKILL.md` gains one naming bullet (Tier A). No new op, no narration added (all polling is silent per the contract).
**Verification:** in a scratch repo, open a PR and immediately `gh pr view --json mergeable` (expect `UNKNOWN`), confirm the poll loop resolves it; mark a PR draft and confirm the gate fires; add a required check and confirm `--auto`-vs-watch branches correctly.

---

### CU-3 — Forced `fetch --prune` + already-gone remote deletes (T3 · F-RR-01, F-DM-06, F-KO-07, F-KO-08)

`merge` already treats `--delete-branch` "branch not found" as success (F-KO-07, Step 3) — that half is done (see Part 2). The open gaps:

**Target (Tier A):** `SKILL.md` → Cross-Operation Principles, one bullet.
**Target (Tier B):**
- `prune/SKILL.md` **Step 5** — guard the remote delete.
- `merge/SKILL.md` — the `git fetch --prune origin` is added by CU-2 Step 2 (covers merge). 

**Tier-A bullet (SKILL.md):**

```markdown
- **Refresh remote refs before reasoning; treat an already-gone remote delete as success.**
  Any op that decides "merged?" or "still needs deleting?" from local refs runs
  `git fetch --prune origin` first — `deleteBranchOnMerge` (which `repo-init` enables) removes
  branches server-side, so unpruned `origin/*` refs are phantoms. Before deleting a remote
  branch, `git ls-remote --heads origin <b>`; absent → record "already removed", not a failure.
```

**Tier-B — replace `prune/SKILL.md` Step 5 delete block:**

```bash
git worktree remove <path>            # retry with --force if the branch is checked out there
git branch -d <branch>                # safe delete only; never silently escalate to -D

# remote branch — skip cleanly if the server already deleted it (deleteBranchOnMerge).
if git ls-remote --heads origin "<branch>" | grep -q .; then
  git push origin --delete "<branch>"   # strip any origin/ prefix from <branch> first
else
  : # already gone server-side — record "remote already removed", not a failure
fi
```
Add one sentence under it: *"A `push origin --delete` that still races the server-side deletion and returns `remote ref does not exist` is also success — record it and move on, never surface it."*

**Why it is safe / architectural:** idempotent-by-design guard, matching the skill's stated cleanup philosophy; no behavior change on repos without auto-delete.
**Verification:** on a `deleteBranchOnMerge`-enabled repo, merge a PR then run `/prune` — the remote-delete must report "already removed" not "failed to push some refs" (the 6× recurring error).

---

## P1

### CU-4 — Worktree lifecycle robustness (T4 · F-RR-02, F-DM-08..11, F-KO-14)

**Target:** `worktree-task-lifecycle/SKILL.md` (create + remove sections), and `ship/SKILL.md` Step 7.

**(4a) Post-`add` self-check — append to the "Create" list as step 5:**

```markdown
5. **Verify the add completed.** `git worktree add` can exit apparently-fine yet leave an
   empty, non-git directory. Confirm both: the path appears in `git worktree list`, and
   `git -C "<path>" rev-parse --is-inside-work-tree` returns `true`. If the dir exists but is
   not linked, `git worktree prune` and re-add once; if it still fails, stop and surface it.
```

**(4b) Live-process-tree lock recovery — replace the Windows lock-recovery bullet in "Remove" step 3:**

```markdown
3. If the directory lingers, diagnose the lock **before** giving up. A retry can never win
   while a live process holds a handle inside the worktree (a dev server writing a log there):
   - Windows: find holders rooted in the path and end their tree —
     `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*<path>*" }`,
     then `Stop-Process -Id <pid> -Force` for each (children first).
   - Then `git worktree prune` + `rm -rf`/`Remove-Item -Recurse -Force` once more.
   Only if it *still* resists (a handle you cannot attribute) leave it on disk and say so in
   the summary ("worktree dir left on disk — locked handle; delete manually"). Never loop.
```

**(4c) Stale lock / interrupted rebase on teardown — new "Remove" step:**

```markdown
   - If teardown finds a stale `index.lock` or a half-finished `rebase-merge`/`rebase-apply`
     in the worktree's gitdir, clear it first: remove the `*.lock`, `git rebase --abort` (or
     `git merge --abort`) inside the worktree, then proceed. A locked index blocks both remove
     and prune.
```

**(4d) `ship` verifies its worktree still exists — prepend to `ship/SKILL.md` Step 7:**

```markdown
If `$IN_WORKTREE`, first confirm the worktree is still registered
(`git worktree list --porcelain | grep -q "$REPO_ROOT"`). A concurrent session may have pruned
it mid-task; if it is gone, do **not** silently fall through onto the shared primary checkout
(that briefly moves `main`/`dev` off-branch). Pause via `AskUserQuestion` (recreate the
worktree and replay the commit / continue on the primary checkout deliberately / abort).
```

**(4e) `prune` cleans orphaned worktree dirs — add to `prune/SKILL.md` Step 3 categorization:** a directory under the canonical `<repo>-wt/.worktrees/` (or a legacy in-repo `.worktrees/`) that is **not** in `git worktree list` is an orphan; offer it for deletion alongside stale worktrees.

**Why it is safe / architectural:** all additions live in the single worktree authority (per charter §4); `ship` gains a guard, not worktree logic. Silent per contract; only the concurrent-prune case breaks silence, correctly, via `AskUserQuestion`.
**Verification:** (4a) `git worktree add` then delete the dir contents and re-run — self-check must catch it. (4d) create a worktree, `git worktree remove` it from another shell, run `/ship` in the first — must pause, not commit on primary.

---

### CU-5 — Windows / Git-Bash hazards (T6 · F-DM-07, F-KO-15, F-DM-04, F-KO-19)

**(5a) `gh api` MSYS path mangling — Tier-A bullet in `SKILL.md`, plus inline reminders where `gh api` uses a leading-slash path.**

Tier-A bullet:
```markdown
- **`gh api` leading-slash paths on Git-Bash need `MSYS_NO_PATHCONV=1`, and read back the
  result.** MSYS rewrites a leading `/repos/...` into a Windows filesystem path before `gh`
  sees it, so the call silently no-ops (branch protection *looked* applied but wasn't). Prefix
  such calls `MSYS_NO_PATHCONV=1 gh api "/repos/…"` (or drop the leading slash:
  `gh api "repos/…"`), and confirm the applied state by re-reading it — never trust exit 0.
```
Inline one-line reminders at the concrete call sites:
- `repo-init/SKILL.md` Step 2 (the `gh api "/repos/$REPO/rulesets"` etc. block) and Step 5 (ruleset PUT/POST).
- `release/SKILL.md` Step 5 detection uses `gh api "repos/{owner}/{repo}/branches/main/protection"` (no leading slash — already safe); note that form is deliberate.

**(5b) heredoc commit hangs — replace `commit/SKILL.md` Step 3 commit form:**

```markdown
## Step 3 — Commit

Draft a conventional-commit message (`type: subject`, subject < 72 chars, optional short body).
**On Git-Bash, do not use the `git commit -m "$(cat <<'EOF' … EOF)"` heredoc form** — it hangs
and reverts staged changes here. Use a single `-m` for a one-line message, or a temp file for a
body:

```bash
# one line:
git commit -m "fix: …"
# with a body:
printf '%s\n\n%s\n' "fix: subject" "- bullet one" > "$TMP" && git commit -F "$TMP"; rm -f "$TMP"
```
```
Same substitution anywhere else the heredoc form appears (grep the bundle — `release` Step 4b/6b use `-am` and `--body $'…'` which are safe; `commit` is the only heredoc).

**(5c) Cygwin fork failure → `pwsh` retry — extend from `release` to `ship`+`merge`.** `release/SKILL.md` Error Recovery already has this row (F-DM-04). Add the identical row to `ship/SKILL.md` and `merge/SKILL.md` Error-Recovery tables:

```markdown
| git-bash `fork`/`add_item … failed` mid-run (Windows Cygwin) | Not a git failure — bash could not fork. Re-run the same `git`/`gh` step through `pwsh`; shell state doesn't persist but repo state does, so just repeat the last command |
```
And a Tier-A bullet naming it once in `SKILL.md`.

**(5d) CRLF hook shebangs — VERIFY ONLY, effectively already done.** Root `.gitattributes` already pins `claude/…/repo-init/templates/hooks/*` **and** `codex/…/repo-init/templates/hooks/*` to `text eol=lf` (confirmed). F-KO-19 is closed at source. See Part 2 for the standing check.

**Why it is safe / architectural:** each is a correctness fix on the primary environment; the MSYS and Cygwin rules are one-line Tier-A invariants with inline reminders, not duplicated blocks.
**Verification:** (5a) run the ruleset apply on Git-Bash, then `gh api "/repos/$REPO/rulesets"` read-back must show the ruleset. (5b) commit a multi-line body on Git-Bash — must not hang.

---

### CU-6 — Generated/committed-doc merge policy (T7 · F-OP-01, F-OP-02, F-OP-03)

**Target:** `repo-init/SKILL.md` Group 6 artifacts + manifest; `merge/SKILL.md` Step 2.

**(6a) `repo-init` provisions a local merge-driver policy + regen-after-rebase hook for declared generated-and-committed files.** Add to the manifest schema (`.github/repo-standard.yml`) a new key:

```yaml
generatedCommitted:            # files regenerated AND committed; declared per repo
  - path: docs/STATUS.md
    regen: pwsh ./scripts/sync-status.ps1
  - path: CATALOG.md
    regen: pwsh ./scripts/generate-catalog.ps1 -Force
```
For each declared path, `repo-init`:
- registers a **local** `merge=union` (or a keep-ours + regen) driver in `.gitattributes` **and** `git config merge.<driver>` locally — stated plainly in the summary that GitHub's server-side merge ignores `.gitattributes`, so this only helps local merges/rebases;
- installs/extends a `post-rewrite` (and `post-merge`) hook that re-runs each `regen` command so a rebase leaves the generated file correct rather than conflicted.

**(6b) `merge` proactively regenerates date-sensitive generated docs before attempting.** Add to `merge/SKILL.md` Step 2, after the fetch:

```markdown
If the repo declares `generatedCommitted` files in `.github/repo-standard.yml`, run each
`regen` command on `dev`'s tip before the merge and stage the result — a date-keyed generated
doc (e.g. a changelog/status file) goes stale across a midnight boundary and only surfaces as a
CI `BLOCKED` *after* a failed merge attempt. Regenerating first turns that into a no-op.
```

**Why it is safe / architectural:** opt-in per repo via an explicit manifest declaration; no repo without the declaration changes behavior. `merge` reads the declaration, it does not invent the policy.
**Verification:** declare `docs/STATUS.md` in a scratch repo, create two branches that both regenerate it, and confirm the rebase-regen hook resolves the collision instead of conflicting.

---

### CU-7 — Distribution / mirror drift (T8 · F-KO-05, F-KO-17, F-DM-03, F-KO-18)

Three separable pieces:

**(7a) Fix the profile push so sub-skills actually deploy.** `scripts/push-to-profile.ps1` is a **documented stub that `throw`s** (confirmed line 81). Implement it to copy `SKILL.md` + `sub-skills/` + `commands/` + `references/` + `rules/` into `~/.claude/skills/<name>/`, stamping `installed-from: ai-agent-kit`, honoring the documented `-Name -TargetDir -Force -WhatIf -Json` surface and the back-up-before-clobber safety rule already in its help block. This is the root cause of "global profile had no `sub-skills/` at all". **Sizable (new script body) — its own PR.**

**(7b) Codex `release` mirror is stale (F-DM-03, flagged OPEN).** Confirmed: `codex/skills/github/sub-skills/release/SKILL.md` is missing everything the Claude copy gained — no **Step 4b** (version-ref stamp), no **Step 6b** (deferred tag-keyed-gate path), and its Error-Recovery table lacks the Cygwin-fork row and the two version-ref-stamp rows. Port the Claude `release/SKILL.md` body verbatim (keeping only Codex harness-specific wording). Same review pass for the other 3 Codex sub-skills the report flags as using plain-text prompts against Codex's AskUserQuestion rule (F-KO-17 was PR #99 — verify it actually landed in the mirror).

**(7c) Audit checks that would have caught the drift** — see CU-12/CU-13 (T12). Specifically: sub-skill path resolution, standalone duplicate op-dir = error, and a Claude↔Codex **body** diff (not just name presence).

**Why it is safe / architectural:** (7a) implements an already-specified surface; (7b) brings the mirror to parity — no new logic, just propagation.
**Verification:** (7a) `pwsh ./scripts/push-to-profile.ps1 -Name github -Force` then confirm `~/.claude/skills/github/sub-skills/` is populated. (7b) `diff` the two `release/SKILL.md` bodies — should differ only in harness-specific lines.

---

## P2

### CU-8 — Commit integrity: verify HEAD after committing (T9 · F-DM-05, F-KO-15)

**Target:** `ship/SKILL.md` Step 5 (and mirror the guard into `commit/SKILL.md` Step 3).

Append to Step 5:

```markdown
After committing, verify the commit is the one you intended — a `prepare-commit-msg` hook or a
harness intercept can hijack `-m` (observed: correct 9 files, unrelated message). Do not rely
on vigilance:

```bash
HEAD_MSG=$(git log -1 --format=%s)
HEAD_FILES=$(git show --name-only --format= HEAD | sort)
```
If `$HEAD_MSG` does not match `$MSG`, or the file list differs from what was staged, **bail
loudly** (print both, stop) rather than pushing a mislabeled commit.
```

**Why it is safe / architectural:** a read-only post-condition check; only breaks silence on a genuine mismatch (a blocking error per the contract).
**Verification:** install a `prepare-commit-msg` hook that rewrites the message in a scratch repo; `/ship` must detect the mismatch and stop.

---

### CU-9 — Release automation correctness (T10 · F-KO-12; rest are verify-only)

Most of T10 is already fixed in the Claude `release/SKILL.md` (tag ordering, `null`-match, tag-ref, Step 4b/6b generalization) — see Part 2. The one net-new gap:

**F-KO-12 — `/release-init` doesn't provision the changelog-staleness gate to consumers.** `release-init` currently ships the generator + `release.yml` only. AC_OSM "silently fell a release behind" because the *gate* (the check that fails when a released section is missing) was never provisioned downstream. Add a **third artifact** to the Release-Automation Standard in `release-init/SKILL.md`:

- a `validate` step (script + `pre-push` hook wiring) asserting every `v*` tag has a `## [<version>]` section — the exact logic already implemented locally in `scripts/validate.ps1` Check 3 (lines 208–242). Package that check as a deployable template (`release-init/templates/check-changelog-staleness.ps1`) and have `release-init` Step 3A install it and register it in the repo's `pre-push` gate.

Update the Standard table (currently "two artifacts") to three, and the CONFORMANT detection in Step 1 to require the gate.

**Why it is safe / architectural:** `release-init` owns the Release-Automation Standard; this closes the standard's own gap. Idempotent like the rest of the op.
**Verification:** run `/release-init` on a repo with a tag but no matching changelog section — must install the gate and flag STALE CHANGELOG.

---

### CU-10 — repo-init specifics (T11 · F-KO-16, F-KO-14, F-KO-21)

- **F-KO-16 (YAML frontmatter broken by a colon-space):** fix belongs to the T12 lint (CU-14) — it is a *detection* gap, not a one-off. No content edit needed beyond the lint catching future occurrences; spot-check the current `init-repo.md`/`repo-init` frontmatter parses (audit already validates SKILL.md frontmatter; commands are the gap — CU-14).
- **F-KO-14 (`core.hooksPath` skips hooks on pre-existing worktrees):** add to `repo-init/SKILL.md` Group 5. When `git worktree list` shows secondary worktrees, prefer installing a `.git/hooks` shim (or per-worktree hook link) over `core.hooksPath`, because `core.hooksPath` is not honored uniformly across linked worktrees. State the trade-off in the summary.
- **F-KO-21 (auto-merge not detected/surfaced):** Group 2 already sets `allowAutoMerge: true`; add to Step 2 probe `autoMergeAllowed` (it's already in the `gh repo view --json …` list) and to Step 3 diff — if auto-merge is *disabled*, surface it as merge-group drift, because `/ship` and `/merge`'s `--auto` path (CU-2) depends on it.

**Why it is safe / architectural:** all within `repo-init`'s existing standard/probe/diff structure.
**Verification:** on a repo with a secondary worktree, confirm `repo-init` chooses the shim and hooks fire in the worktree; disable auto-merge and confirm it shows as drift.

---

# PART 2 — VERIFY-DEPLOYMENT (already fixed; propose the CHECK, not a re-fix)

The report's "Already-Fixed" table maps to distribution drift (T8). Rather than re-editing, add a **parity/presence check** (mostly delivered by the T12 audit additions, CU-12/CU-13) and spot-confirm each in the three deploy targets (archive / global profile / Codex).

| Finding | Confirmed state in archive | Proposed check |
|---|---|---|
| F-KO-04 output contract inlined | ✅ present in all 9 Claude sub-skills (verified) | CU-12: lint asserts each sub-skill contains the inlined-contract heading, not a bare "parent Output Contract" pointer |
| F-KO-07 `--delete-branch` not-found = success | ✅ `merge` Step 3 | CU-13 Codex body-diff confirms the Codex `merge` carries it too |
| F-KO-19 CRLF hook shebangs | ✅ root `.gitattributes` pins both Claude+Codex `templates/hooks/*` | CU-14: lint asserts every `templates/hooks/**` path is covered by an `eol=lf` attribute |
| F-KO-10 changelog mojibake (ASCII+UTF-8 pin) | verify `release-init/templates/Generate-Changelog.ps1` | CU-14: non-ASCII-byte scan over `templates/**/*.ps1` |
| F-KO-11 template lint / Write-Host | verify template | CU-14: PSScriptAnalyzer over `templates/**/*.ps1` |
| F-KO-13 tag ordering / `null`-match / tag-ref | ✅ Claude `release` Steps 6/6b + Error-Recovery | CU-13 body-diff → Codex `release` (currently STALE, CU-7b) |
| F-DM-02 version-stamp/tag ordering generalized | ✅ Claude `release` Step 4b/6b | CU-13 body-diff → Codex `release` (STALE) |
| F-DM-04 Cygwin→pwsh retry row | ✅ Claude `release` only | CU-5c adds it to `ship`+`merge`; CU-13 confirms Codex parity |
| F-KO-05 profile has no sub-skills | root cause = push stub | CU-7a implements the push; then re-run `/audit-skills` |
| F-KO-17 / F-KO-18 Codex publish/worktree | verify PR #99 / mirror | CU-13 Codex body-diff |
| F-DM-03 Codex `release` port | ❌ **still stale (confirmed)** | Net-new CU-7b (not a verify item) |

---

# PART 3 — META-GATE (T12) — lint/test additions

`scripts/validate.ps1` **exists** and is the pre-PR gate: it wraps (1) CATALOG staleness, (2) `audit.ps1`, (3) CHANGELOG staleness, propagating `audit.ps1`'s exit code. `audit.ps1` runs 8 findings-based checks via `Add-Finding {error|warn|info}`. New static lints belong in **`audit.ps1`** (they emit findings and fold into the gate automatically); the deploy-and-run smoke test belongs in a **new script** invoked by `validate.ps1`.

### CU-11 — Pointer-only Output-Contract lint (audit.ps1, `error`)
New check: for every `*/sub-skills/*/SKILL.md`, assert the body contains the inlined-contract marker (`Output Contract (binding — inlined`). A file that references "parent Output Contract" **without** the inlined block is a dangling pointer (the F-KO-04 regression) → `error`. Reuse the existing file-enumeration pattern.

### CU-12 — Sub-skill path resolution + no standalone duplicate op-dirs (audit.ps1, `error`)
Two sub-checks:
- For each command in `claude/skills/github/commands/*.md`, parse its `sub-skills/<x>` reference and assert `claude/skills/github/sub-skills/<x>/SKILL.md` exists. Generalize to any bundle. Missing target → `error` (this is how a renamed sub-skill silently 404s).
- Assert no *top-level* archive skill dir shares a name with a bundle sub-skill (the standalone-duplicate op-dir that shadows — the archive analogue of audit's existing profile-shadowing warn, but here it is an `error` because it's the archive's own state).

### CU-13 — Claude↔Codex **body** parity (audit.ps1, escalate mirror-gap)
The existing Check 7 compares only skill *names* (`info`). Add a body-diff for mirrored skills: strip harness-specific lines (frontmatter, any `AskUserQuestion`↔Codex-prompt idioms) and diff the remainder; a substantive divergence (e.g. Codex `release` missing Step 4b) is a finding. **Severity is a user decision** (see Decisions #3) — recommend `warn` so it surfaces on every `/audit-skills` without failing unrelated archive PRs, matching the existing mirror-gap philosophy.

### CU-14 — Template hygiene lints (audit.ps1, mixed)
- **Non-ASCII bytes in `**/templates/**/*.ps1`** → `error` (the mojibake class, F-KO-10). Byte scan; report file:line of the first non-ASCII byte.
- **PSScriptAnalyzer over `**/templates/**/*.ps1`** → `warn` (unapproved verbs, `Write-Host`; F-KO-11). Gate on `PSScriptAnalyzer` being available; degrade to a skipped-note when absent (mirrors the gitleaks-absent degrade pattern).
- **YAML frontmatter validity over `commands/*.md`** → `error`. `audit.ps1` already validates SKILL.md frontmatter via `generate-manifest.py`; **command files are the uncovered gap** (F-KO-16 — a colon-space broke `init-repo.md`'s frontmatter and the harness used the body as the description). Extend the validation to command `.md` files (a leading `---` block that must parse as YAML).
- **`templates/hooks/**` LF-attribute coverage** → `error`. Assert each hook-template path matches an `eol=lf` rule in `.gitattributes` (closes F-KO-19 permanently even as new hooks are added).

### CU-15 — Template-execution smoke test (new `scripts/test-github-templates.ps1`)
Deploy the `repo-init` + `release-init` templates into a throwaway git repo (temp dir, `git init`), install the hooks, make a commit, and run each hook + `Generate-Changelog.ps1` under `pwsh -NoProfile`; assert exit 0, ASCII output, and a non-empty changelog. This is the only thing that catches deploy-only bugs (mojibake under `-NoProfile`, CRLF shebang, hook that hard-fails when a tool is absent) — all invisible in source. **Runtime/where-it-runs is a user decision** (see Decisions #4): it needs a scratch repo and possibly `pwsh`/`gh`, which may push `validate.ps1` past its <60s target. Recommend: a separate `-IncludeSmoke` opt-in flag on `validate.ps1` (default off locally, on in the tag-release CI carve-out).

---

# PART 4 — SEQUENCING & PR BATCHING

Repo warns at 400 lines changed, hard-limits at 800. Estimates are of changed lines.

**Independent (no cross-dependencies) — can go in any order, in parallel:**
- CU-1 (anti-bypass docs)
- CU-3 (fetch --prune / prune deletes)
- CU-5 (Windows hazards)
- CU-4 (worktree robustness)
- CU-8 (commit integrity)
- CU-7b (Codex `release` port)

**Dependent:**
- CU-2 (merge/ship preflight) — CU-10's auto-merge-drift surfacing and CU-2's `--auto` path reference each other; land CU-2 first, then CU-10.
- CU-6 (generated-doc policy) depends on the `generatedCommitted` manifest key → land the `repo-init` manifest half before the `merge` read half (or same PR).
- CU-7a (implement push-to-profile) must land before re-running `/audit-skills` to close F-KO-05.
- CU-11..15 (T12 lints) are independent of the content fixes but should land *early* so they guard the subsequent content PRs — recommend the T12 PR(s) go **first**.

**Suggested PRs (each < 400 lines):**

| PR | Contents | Priority | Est. lines |
|---|---|---|---|
| PR-A | CU-11, CU-12, CU-14 (audit.ps1 static lints) + CU-1 (anti-bypass docs) | P3+P0 | ~250 |
| PR-B | CU-2 (merge/ship preflight) + CU-3 (fetch-prune/prune deletes) | P0 | ~180 |
| PR-C | CU-4 (worktree robustness) | P1 | ~120 |
| PR-D | CU-5 (Windows hazards across commit/merge/ship + Tier-A bullets) | P1 | ~150 |
| PR-E | CU-6 (generated-doc policy: repo-init manifest + merge read) | P1 | ~160 |
| PR-F | CU-7a (implement push-to-profile.ps1) | P1 | ~250 (new script) |
| PR-G | CU-7b + CU-13 (Codex `release` port + body-diff check) | P1 | ~300 |
| PR-H | CU-8 (commit integrity) + CU-10 (repo-init hooksPath shim + auto-merge drift) | P2 | ~120 |
| PR-I | CU-9 (release-init staleness-gate artifact) + template it | P2 | ~200 |
| PR-J | CU-15 (template smoke test) | P3 | ~200 (new script) |

Land order: **PR-A first** (lints guard the rest) → PR-B → PR-C/D/E in parallel → PR-F → PR-G → PR-H/I → PR-J.

---

# Decisions for the user

1. **push-to-profile.ps1 (CU-7a):** implement it now as a full script (root cause of the profile having no sub-skills), or keep it a documented stub and deploy sub-skills another way? It is a ~250-line new script — its own PR either way.
2. **Generated-doc merge policy (CU-6):** the `generatedCommitted` manifest declaration is a new per-repo schema surface. Approve the schema shape (`path` + `regen` command) and the local-only merge-driver approach (GitHub server-side merge ignores `.gitattributes`), or prefer a different mechanism (e.g. a CI carve-out)?
3. **Codex body-diff severity (CU-13):** `warn` (surfaces on `/audit-skills`, never fails an archive PR — matches existing mirror-gap `info` philosophy) or `error` (blocks a PR whenever the mirrors diverge)?
4. **Template smoke test placement (CU-15):** opt-in `-IncludeSmoke` on `validate.ps1` (default off locally, on in the tag-release CI carve-out), or a standalone test never wired into the pre-PR gate? It needs a scratch repo and may exceed validate's <60s target.
5. **Auto-merge as standard (CU-2/CU-10):** `repo-init` Group 2 already sets `allowAutoMerge: true`, so the `--auto` path assumes it. Confirm auto-merge-disabled should be reported as *drift* (fixable) rather than a silent per-repo choice.
