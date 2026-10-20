# Scanner: AC-DESIGN + misc

Files scanned: 16 (AC_DESIGN ×8, phoneinfoga ×2, github-repos-wt-masthead-footer-polish ×2, dropbox-audit ×2, ac-work-launcher ×1, ac-education-host ×1). `dropbox-audit` and `ac-education-host` yielded no github-skill-attributable friction; `ac-work-launcher`'s `/ship` and `/prune` runs were clean (one finding noted purely for context, excluded below as not skill-attributable).

## F-DM-01 — Plain merge silently blocked by branch-protection required-checks, no auto-detect/wait path
- **Type**: missing-capability
- **Maps to**: ship / merge sub-skills
- **Source**: AC-DESIGN/c8f010fa-15f0-4231-984e-1856e17533ab.jsonl (project AC_DESIGN)
- **What happened**: Shipping an AC_OSM change via the merge step hit branch protection requiring 2 CI checks (Pester + PSScriptAnalyzer) that AC_DESIGN's `dev` didn't have. The agent had to manually inspect protection rules (`gh api`), discover auto-merge was disabled, enable it, then poll checks before merging — none of this is encoded in the skill itself. Quote: "AC_OSM's `dev` has branch protection that blocked the plain merge (AC_DESIGN's didn't). Let me see exactly what it requires before deciding how to proceed."
- **Proposed enhancement**: Before attempting a merge, have `ship`/`merge` query the target branch's protection rules and required status checks. If checks are pending, either enable `--auto` merge or poll to completion automatically instead of failing the plain merge attempt and leaving the agent to reverse-engineer the repo's policy live.
- **Frequency/severity**: seen once directly, but the underlying gap (no protection-aware merge path) is structural — any protected repo with required checks will hit it; medium cost (multiple extra tool round-trips per occurrence).

## F-DM-02 — Release sub-skill's version-stamp/tag ordering not generic; caused a failed gated push requiring a follow-up PR
- **Type**: bug (since resolved in-session, see note)
- **Maps to**: release sub-skill
- **Source**: AC-DESIGN/4ecc4294-bacc-4646-96f5-6dfca1ccf440.jsonl (project AC_DESIGN)
- **What happened**: `/release` tagged and published `v0.8.0` before the version-ref bump was applied; syncing `dev` afterward tripped the repo's own doc-truth gate ("Exactly the three references that go stale on every release... now caught automatically") because the release process didn't stamp version references before tagging. Required a manual detect → fix → follow-up PR (#131) instead of the release flow handling it inline.
- **Proposed enhancement**: Already addressed in-session as generic Step 4b (detect-and-skip version-ref bump) in this same transcript, then further refined for tag-keyed gates in a later session (see F-DM-03). Flagging here as evidence this needed two iterations to reach — worth double-checking the current archived `release/SKILL.md` Step 4b/6b logic actually covers repos with tag-keyed doc-truth gates by default, not just AC_DESIGN's specific pattern.
- **Frequency/severity**: seen twice across two sessions (this one and c8f010fa) before being fully generalized; medium cost (extra PR + investigation each time).

## F-DM-03 — Codex variant of release sub-skill left stale after Claude variant was patched for tag-keyed gates
- **Type**: doc-gap
- **Maps to**: release sub-skill (Codex flavor)
- **Source**: AC-DESIGN/c8f010fa-15f0-4231-984e-1856e17533ab.jsonl (project AC_DESIGN)
- **What happened**: After fixing the Claude `release` sub-skill for tag-keyed version gates, git-bash Cygwin fork-error retry, and the worktree-blocks-`--delete-branch` footgun (shipped via ai-agent-kit PR #103), the agent explicitly flagged: "Codex variant of the release sub-skill still stale... I updated only the Claude variant... Want me to port the tw[eaks]?" — left as an open item, not resolved in this transcript.
- **Proposed enhancement**: Port the same three fixes (tag-keyed-gate detection, git-bash Cygwin retry via pwsh, worktree-blocks-delete-branch handling) to `codex/skills/github/sub-skills/release/SKILL.md`. Consider a parity-check step in `/audit-skills` that flags when Claude/Codex/Gemini variants of the same sub-skill diverge on substantive (non-harness-specific) content.
- **Frequency/severity**: seen once; low immediate cost but leaves Codex CLI users exposed to bugs already fixed for Claude Code.

## F-DM-04 — Git-bash Cygwin `fork` failure during PR merge left the merge state ambiguous
- **Type**: bug
- **Maps to**: release sub-skill (merge step)
- **Source**: AC-DESIGN/c8f010fa-15f0-4231-984e-1856e17533ab.jsonl (project AC_DESIGN)
- **What happened**: Merging the release PR via `gh pr merge` hit a transient Git-bash fork error; the agent had to separately verify whether the merge landed, then switch to PowerShell to actually execute it. Quote: "Git-bash is failing to fork (a known Windows Cygwin issue after heavy use). Switching to PowerShell for the remaining git/gh commands."
- **Proposed enhancement**: This is now captured as an Error-Recovery row in the Claude release sub-skill per this session's own summary — confirm the row prescribes an automatic pwsh retry (not just a documented recognition) so future runs don't need to re-diagnose it, and confirm it also applies to `ship`/`merge` (not just `release`), since the same git-bash environment issue can hit any operation that shells out to `git`/`gh` heavily.
- **Frequency/severity**: seen once; low-medium cost (one extra diagnostic round-trip), but environment-class issue likely recurring on this workstation.

## F-DM-05 — Commit message silently rewritten mid-`/ship` by a non-git hook/interceptor
- **Type**: bug
- **Maps to**: ship sub-skill (commit step)
- **Source**: AC-DESIGN/b8492004-13d2-4e3c-9bc0-d25d93917846.jsonl (project AC_DESIGN)
- **What happened**: During `/ship`, a `git commit -m "..."` landed with the correct 9 staged files but a completely different, unrelated commit message ("fix: anchor timeline step nodes..."). The agent had to stop, diagnose ("a `prepare-commit-msg` hook hijacked my `-m` message"), confirm no actual git hook was configured (likely a harness-side intercept), and amend the message. This went undetected by the ship flow itself — only caught because the agent proactively verified `HEAD` after committing.
- **Proposed enhancement**: Add a verification step to `ship`'s commit stage: after `git commit`, diff the actual `HEAD` commit message/file list against what was intended before proceeding to push/PR. Bail loudly if they don't match, rather than relying on the agent's own vigilance.
- **Frequency/severity**: seen once; high cost if unnoticed (wrong commit message shipped to `dev` history), caught only by luck/diligence here.

## F-DM-06 — `/merge` and branch-cleanup flows read stale remote-tracking refs because `git fetch --prune` is never forced
- **Type**: bug
- **Maps to**: merge sub-skill / prune sub-skill
- **Source**: AC-DESIGN/b8492004-13d2-4e3c-9bc0-d25d93917846.jsonl (project AC_DESIGN)
- **What happened**: Asked to merge `feat/pm-requirements-doc`, the agent's `git branch -r` showed the branch as present and "1 ahead," but this was a stale remote-tracking ref — the branch (and ~9 sibling `pm-*` branches) were already merged and deleted upstream. Root cause, per the transcript: "an earlier `git fetch` without `--prune` left phantom remote-tracking refs." Needed a full re-investigation to discover there was nothing to do.
- **Proposed enhancement**: Have `merge`/`prune` always run `git fetch --prune` (or `--prune --prune-tags`) as their first step before evaluating remote branch state, so stale refs can't produce false "still needs merging" or "still needs deleting" conclusions.
- **Frequency/severity**: seen once, but the mechanism (unpruned fetch) is generic and will recur on any repo with merged-and-deleted branches; medium cost (full re-diagnosis cycle).

## F-DM-07 — Windows Git Bash (MSYS) silently mangles `gh api` paths, causing branch-protection calls to no-op
- **Type**: bug
- **Maps to**: init-repo sub-skill (branch protection step) / publish sub-skill
- **Source**: phoneinfoga/f9fd19be-6f83-4ff3-816b-5ddfd411b1ee.jsonl (project ai-tag-browser via phoneinfoga session)
- **What happened**: `gh api -X PUT "/repos/$REPO/branches/main/protection" ...` appeared to succeed (no error surfaced) but did nothing — Git Bash's MSYS path-conversion rewrote the leading `/repos/...` into a Windows filesystem path before `gh` ever saw it. Only caught because the agent re-queried protection state afterward. Quote: "The Windows Git Bash is rewriting the `/repos/...` API paths into filesystem paths — that's why the earlier PUTs silently failed. I need `MSYS_NO_PATHCONV=1`."
- **Proposed enhancement**: Any sub-skill step that shells out to `gh api` with a path starting in `/` must set `MSYS_NO_PATHCONV=1` (or `GH_HOST`/leading-slash-avoidance equivalent) on Windows, and should always verify the applied state by reading it back rather than trusting exit code 0. This is squarely in scope for `init-repo`'s branch-protection step, which does exactly this class of call.
- **Frequency/severity**: seen once, but is a silent-failure class bug — trusting `gh api` PUT exit codes on Windows is unsafe workstation-wide; high cost if not caught (branch protection believed applied but isn't).

## F-DM-08 — worktree-task-lifecycle: no self-check that `git worktree add` actually completed; left an empty non-git directory
- **Type**: bug
- **Maps to**: worktree-task-lifecycle sub-skill
- **Source**: github-repos-wt-masthead-footer-polish/da1a479b-1468-4d84-b3ed-a1accd299e9a.jsonl (project ac-repo-radar, worktree checkout)
- **What happened**: At the start of the session, the designated worktree directory (`masthead-footer-polish`) existed but was empty and not a git repo — "it was never actually created as a git worktree." The agent had to manually create the worktree from scratch, including reverse-engineering the project's `node_modules` junction convention from other existing worktrees, none of which the lifecycle skill surfaced directly.
- **Proposed enhancement**: After `git worktree add`, verify the directory is registered (`git worktree list` contains it) and has a valid `.git` file/linkage before declaring setup complete. If a prior setup attempt left an empty directory, the skill should detect and repair it (remove + recreate) rather than requiring the agent to notice and improvise.
- **Frequency/severity**: seen once directly, but represents exactly the failure-recovery scenario the skill's own description claims to cover ("Windows file-lock recovery") — a related but uncovered case; medium-high cost (full manual re-setup, including cross-worktree convention discovery).

## F-DM-09 — Worktree pruned by another concurrent session mid-task, undetected by `/ship`, forcing risky operation on the shared main checkout
- **Type**: bug
- **Maps to**: worktree-task-lifecycle sub-skill / ship sub-skill
- **Source**: github-repos-wt-masthead-footer-polish/5e814c6b-eb1c-4b4a-bbca-80690a1ef367.jsonl (project ac-repo-radar)
- **What happened**: Invoking `/ship`, the agent discovered its isolation worktree had been removed/pruned by another session while this task was still in progress ("My isolation worktree is **gone** ... another session must have pruned it"). It had to fall back to committing directly on the shared main checkout, briefly moving it off `dev` — a state other concurrent sessions could observe or collide with.
- **Proposed enhancement**: `ship` should check that its expected worktree still exists and is registered before proceeding; if it's gone, either recreate it and replay the change there, or explicitly pause and confirm with the user before operating on the shared main checkout (since that briefly perturbs a branch other sessions may depend on), rather than silently proceeding.
- **Frequency/severity**: seen once; high cost/risk (shared main checkout was moved off `dev` mid-flight in a multi-session environment).

## F-DM-10 — Worktree teardown hit a stale `index.lock` + interrupted rebase state, requiring manual abort/retry
- **Type**: bug
- **Maps to**: worktree-task-lifecycle sub-skill (advertised "Windows file-lock recovery")
- **Source**: github-repos-wt-masthead-footer-polish/da1a479b-1468-4d84-b3ed-a1accd299e9a.jsonl (project ac-repo-radar)
- **What happened**: Rebasing the worktree branch onto `origin/dev` before merge hit a stale `index.lock` from an interrupted mid-pick rebase, plus an inconsistent `rebase-merge` state (branch reported "editing a commit" but working tree lacked the actual changes). The agent manually checked for running git processes, then did `git rebase --abort` and retried cleanly — none of this was automated by the lifecycle skill despite it explicitly claiming to handle "Windows file-lock recovery."
- **Proposed enhancement**: Encode this exact recovery sequence (check for live `git`/`gh` processes → if none, and a lock/rebase-state is stale, abort and retry) as a documented, scriptable step in worktree-task-lifecycle rather than leaving it to ad hoc diagnosis each time.
- **Frequency/severity**: seen once; medium cost (several extra diagnostic round-trips), but directly in the skill's stated coverage area.

## F-DM-11 — Worktree removal leaves an undeleted physical directory when the session's cwd is pinned inside it
- **Type**: bug
- **Maps to**: worktree-task-lifecycle sub-skill (teardown step)
- **Source**: github-repos-wt-masthead-footer-polish/da1a479b-1468-4d84-b3ed-a1accd299e9a.jsonl (project ac-repo-radar)
- **What happened**: After `git worktree remove --force` deregistered the worktree (gone from `git worktree list`, branch deleted), the physical directory could not actually be deleted because the harness pins the session's shell cwd inside the very directory being removed. The agent noted it as "a harmless cosmetic remnant that any later session (with a different cwd) can remove" — i.e., every teardown in this harness leaves an orphaned directory behind by construction.
- **Proposed enhancement**: Have the teardown step explicitly `cd` to the main repo (or a neutral parent directory) via a mechanism that actually changes the *session's* effective cwd (not just the subprocess's) before invoking removal — or, if the harness cwd truly can't be changed mid-session, document this as a known limitation and have `prune` clean up these orphaned directories on its next run rather than leaving them indefinitely.
- **Frequency/severity**: recurring by construction — every same-session worktree teardown likely hits this; low-medium cost per occurrence (cosmetic today, but accumulates orphaned directories over time) — should be visible in `/prune`'s stale-worktree audit.

## F-DM-12 — `/merge`'s pre-merge gate doesn't check `isDraft`; a draft PR passes all gate checks but GitHub still refuses the merge
- **Type**: bug
- **Maps to**: merge sub-skill
- **Source**: AC-DESIGN/4f873d08-e64f-451f-94ec-c64ef84aab88.jsonl (project ai-agent-kit)
- **What happened**: Merging two open PRs, one (#125) was a draft. The skill's initial `gh pr list` query surfaced state OPEN/MERGEABLE/CLEAN and the PR passed every gate check, yet the merge call was refused by GitHub because drafts can't be merged regardless of mergeability. Quote: "The initial `gh pr list` didn't surface `isDraft`, so #125 passed the skill's gate ... yet still refused to merge." The agent had to mark it ready for review and retry.
- **Proposed enhancement**: Add `isDraft` to the `gh pr list`/`gh pr view` fields the merge sub-skill queries, and treat draft state as a distinct pre-merge gate: either surface it to the user via `AskUserQuestion` ("PR #N is a draft — mark ready and merge, or skip?") before attempting the merge, rather than discovering it only after a failed merge call.
- **Frequency/severity**: seen once; low-medium cost (one failed merge attempt + manual recovery), but easy to fix and will recur any time a draft PR is in the merge target set.
