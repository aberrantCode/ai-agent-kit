# Scanner: ai-agent-kit + AC-OSM

Files scanned: 20 (11 ai-agent-kit + 9 AC-OSM). All 20 inspected via grep-based sampling (no whole-file reads); 3 ai-agent-kit files yielded no substantive findings (unrelated `/loop` rollout, an earlier incomplete audit attempt, an unrelated pre-push-gate audit). No literal mojibake byte sequences were found in the 9 AC-OSM files themselves — the referenced "AC_OSM mojibake bug" traces to a subagent transcript outside this file set and to the ai-agent-kit-side incident findings below (F-KO-10).

---

## F-KO-01 — github skill is rarely invoked; raw git/gh used instead even on near-verbatim trigger phrases
- **Type**: trigger-miss
- **Maps to**: /ship, /merge, /commit, /publish, /init-repo (whole bundle)
- **Source**: 9a566327-0c76-4fed-8e77-1d7ea8fb6b7e.jsonl, d1e1e577-efc5-4c63-bca1-eac42e653015.jsonl, ede075e4-e198-428e-bd93-426df1f0a892.jsonl, 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl (project: ai-agent-kit; 2026-07-16 to 2026-07-21)
- **What happened**: Across 4 transcripts, 19+ PR create/merge cycles ran via raw Bash (`git commit`, `gh pr create`, `gh pr merge --merge --delete-branch`) instead of `/ship`/`/merge`. In one session the user's literal request — "merge PR 76 and give me a prompt..." — nearly matches the skill's own documented trigger example ("merge 1209"), yet the assistant ran `gh pr merge 76` directly. In another, the skill fired exactly once across 8 PR cycles despite the repo's own CLAUDE.md saying "Always use /ship."
- **Proposed enhancement**: Investigate why autonomous/`/loop` contexts default to raw git/gh over the named skill even on matching trigger phrases; consider strengthening trigger language or adding an explicit "prefer named skill over reimplementing in Bash" instruction for orchestrated/background sessions.
- **Frequency/severity**: Recurring across 4+ sessions, 19+ instances; high cost — the skill's guarantees (output contract, worktree cleanup, merge-commit policy, error handling) go unexercised for most real usage.

## F-KO-02 — /init-repo never invoked while sessions manually reimplement exactly what it does
- **Type**: trigger-miss
- **Maps to**: /init-repo
- **Source**: d1e1e577-efc5-4c63-bca1-eac42e653015.jsonl (project: ai-agent-kit; 2026-07-17)
- **What happened**: A ~20-repo `/loop` rollout of branch protection/hooks/validation gates never referenced `/init-repo` once, hand-rolling the exact Tier A/B/C probing logic the command already encapsulates.
- **Proposed enhancement**: Make `/init-repo` fire on bulk "bring N repos up to standard" phrasing; have `/loop` suggest delegating matching iterations to it.
- **Frequency/severity**: Seen once, but full-session-scale miss; high cost.

## F-KO-03 — Output contract narrated on every step during a live /release run
- **Type**: output-contract-violation
- **Maps to**: release sub-skill
- **Source**: 18ccc01f-7683-4aec-94fc-7625f89208b2.jsonl (project: ai-agent-kit; 2026-07-21, real v0.10.0 release)
- **What happened**: Despite the inlined contract banning step narration, 7 separate interstitial messages were emitted (e.g. "Merged as `1457a38`. Now tagging locally, rolling the changelog...") before a correctly-formatted final summary.
- **Proposed enhancement**: Add a worked example transcript to the SKILL.md showing 5+ tool calls with zero interstitial prose; move narration into tool-call `description` fields instead.
- **Frequency/severity**: Seen once directly but systemic — all 8 sub-skills inline the same contract; medium-high cost since it's the skill's headline promise.

## F-KO-04 — Output contract was a dangling pointer, unenforced in 6 of 9 sub-skills, plus stale standalone global copies
- **Type**: output-contract-violation | bug
- **Maps to**: commit, prune, publish, release-init, repo-init, worktree-task-lifecycle; standalone global merge/release copies
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl, 5116a7fa-1034-445f-9ec3-abeb7907e7b3.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: 6 sub-skills said only "obey the parent Output Contract" — a pointer that resolves to nothing standalone. Separately, `~/.claude/skills/{merge,release}` were stale non-bundled duplicates, so the contract never bound during a real run. User complained directly: "I only want to see messages if there are actual errors."
- **Proposed enhancement**: Fixed in-session (contract inlined everywhere). Durable fix: add a lint check flagging pointer-only contract references and drifted standalone op-skill dirs.
- **Frequency/severity**: Highest-severity finding overall — systemic, caused a direct user complaint, required cross-session detective work.

## F-KO-05 — Archive/global-profile drift left github skill running incomplete/stale
- **Type**: bug
- **Maps to**: whole bundle distribution
- **Source**: 928e6e78-fa52-4f87-be45-ea36cbbda8c9.jsonl, 5116a7fa-1034-445f-9ec3-abeb7907e7b3.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: The global profile's `~/.claude/skills/github/` had no `sub-skills/` directory at all (the sync script `push-to-profile.ps1` is a documented stub that throws silently), so every profile-run `/ship`/`/merge`/`/commit`/`/prune` improvised behavior from memory, missing Windows worktree-lock recovery and credential rules. Separately, standalone `merge`/`release` dirs had diverged in both directions from the archive.
- **Proposed enhancement**: Add a check verifying every command's referenced sub-skill path resolves in each installed location; treat standalone duplicate op-dirs as an audit error.
- **Frequency/severity**: High — silently affected every profile invocation for an unknown span.

## F-KO-06 — /merge has no retry for transient mergeable=UNKNOWN right after push
- **Type**: bug | missing-capability
- **Maps to**: merge sub-skill
- **Source**: ede075e4-e198-428e-bd93-426df1f0a892.jsonl (project: ai-agent-kit; 2026-07-16)
- **What happened**: `gh pr merge` failed 6+ times with "Pull Request is not mergeable" immediately post-push because GitHub was still computing mergeability; each time the assistant hand-wrote its own polling loop. The skill's documented steps only cover MERGEABLE/CONFLICTING/BLOCKED/BEHIND, not transient UNKNOWN.
- **Proposed enhancement**: Add a built-in 5-attempt/~15s poll for `mergeable == "UNKNOWN"` before falling to the stop-and-surface path.
- **Frequency/severity**: Recurring 6+ times in one session; medium cost, likely to recur in any multi-PR run.

## F-KO-07 — /merge assumed --delete-branch always deletes the remote branch
- **Type**: bug
- **Maps to**: merge sub-skill
- **Source**: 928e6e78-fa52-4f87-be45-ea36cbbda8c9.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: `gh pr merge --delete-branch` raced against server-side `deleteBranchOnMerge` (which /init-repo itself enables), printing nothing and looking like a failed merge. "Before this PR, that silence would have read as a failed merge."
- **Proposed enhancement**: Fixed — treat "branch not found" as success + `git fetch --prune`. Verify the patch is present in all deployed copies given the drift finding in F-KO-05.
- **Frequency/severity**: Would recur on every merge into a deleteBranchOnMerge-enabled repo — increasingly common since /init-repo sets that flag; high-value fix.

## F-KO-08 — Cross-repo gh pr merge --delete-branch left local dev stale, triggering a false "unmerged content" alarm
- **Type**: ux-friction | missing-capability
- **Maps to**: merge sub-skill
- **Source**: 20bf6338-fc48-48dd-825a-e4e93ab0b999.jsonl (project: ai-agent-kit; 2026-07-15)
- **What happened**: Merging the same fix across sibling repos left local `dev` stale in one repo; the assistant misread reappeared files as unmerged work and proposed a wrong PR before self-correcting: "I need to stop and correct myself — I got this wrong."
- **Proposed enhancement**: Generalize the sub-skill's dev-resync step as a rule for any ad hoc `gh pr merge --delete-branch` call, not just formal `/merge` invocations.
- **Frequency/severity**: Seen once; burned a multi-step investigation before resolving as a no-op.

## F-KO-09 — /prune's docs/git-log.md step created untracked debris across 7 repos (fixed)
- **Type**: bug
- **Maps to**: prune sub-skill
- **Source**: 20bf6338-fc48-48dd-825a-e4e93ab0b999.jsonl (project: ai-agent-kit; 2026-07-14/15)
- **What happened**: Every `/prune` run left an untracked `docs/git-log.md` on protected `dev`, requiring its own follow-up PR — already spread to 6 other repos before the user ordered its removal everywhere.
- **Proposed enhancement**: Already fixed (PR #75). Add a pattern check: scrutinize any sub-skill step that writes a new file as a side effect of a routine operation.
- **Frequency/severity**: Recurring on every invocation until fixed; high cumulative cost.

## F-KO-10 — Mojibake corruption in Generate-Changelog.ps1 — two independent causes
- **Type**: bug
- **Maps to**: release-init template
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl, 5116a7fa-1034-445f-9ec3-abeb7907e7b3.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: A literal warning-triangle glyph plus em-dashes corrupted to `ΓÇö`-style bytes under `-NoProfile` invocation (how CI/validate.ps1 actually runs it). Already caused a real incident — AC_OSM needed its own fix-PR before this session (matches the "AC_OSM inherited mojibake bug" noted in prior memory).
- **Proposed enhancement**: Fixed (ASCII glyph, pinned UTF-8 console encoding). Add a CI check for non-ASCII bytes in any `templates/*.ps1`.
- **Frequency/severity**: Recurring — real production incident before root-cause, independently present in 2 consumer repos.

## F-KO-11 — release-init template shipped with lint violations and silently-swallowable Write-Host output
- **Type**: bug
- **Maps to**: release-init template
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: Template had an unapproved PowerShell verb plus 3 `Write-Host` calls; a naive fix to `Write-Information` would have silently dropped output since `$InformationPreference` defaults to SilentlyContinue. Already copied to 2 consumer repos before caught.
- **Proposed enhancement**: Add PSScriptAnalyzer to validate.ps1 for release-init templates.
- **Frequency/severity**: Once at source, inherited by every already-provisioned repo.

## F-KO-12 — release-init doesn't provision the changelog-staleness gate to consumer repos
- **Type**: missing-capability
- **Maps to**: release-init
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: The archive's own validate.ps1 checks that every tag has a changelog section; /release-init doesn't provision this to consumers. AC_OSM silently fell a release behind as a result.
- **Proposed enhancement**: Make the staleness check a first-class provisioned artifact (script + CI + pre-push hook), not archive-only.
- **Frequency/severity**: Structural — affects every pre-existing /release-init-provisioned repo.

## F-KO-13 — /release: three latent bugs in tag/verification steps (mostly self-caught)
- **Type**: bug
- **Maps to**: release sub-skill
- **Source**: 5116a7fa-1034-445f-9ec3-abeb7907e7b3.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: (1) Tag/push ordering trap — pushing the tag before the changelog PR landed, rejected by the new staleness gate, cost an unplanned PR #91; (2) branch-protection detection used `grep -c .` which counts the literal string `null` as a match, so it's always "protected" regardless of truth; (3) `git tag` had no ref, so it tagged local HEAD rather than the merged commit — a silent wrong-commit risk, caught proactively rather than from failure.
- **Proposed enhancement**: (1) fixed — reordered with an Error Recovery row; (2) switch to `--jq '.url // empty'`; (3) fixed — tag `origin/main` explicitly.
- **Frequency/severity**: (1) medium cost, now documented; (2) latent, will misfire on any unprotected-main repo; (3) latent, now fixed.

## F-KO-14 — core.hooksPath silently skips hooks on pre-existing worktree branches
- **Type**: bug
- **Maps to**: /init-repo, worktree-task-lifecycle
- **Source**: d1e1e577-efc5-4c63-bca1-eac42e653015.jsonl (project: ai-agent-kit; 2026-07-17)
- **What happened**: `core.hooksPath` overrides repo-wide, but only branches/worktrees already containing the commit that added it get the hook — every pre-existing branch/worktree silently gets no enforcement. One repo (ac-repo-radar) had already worked around this with a `.git/hooks` shim.
- **Proposed enhancement**: Have /init-repo detect active worktrees/stale branches before wiring core.hooksPath and default to the shim approach.
- **Frequency/severity**: Seen once directly; structural bug in the standard's mechanism, high severity (silent control failure) — would affect any repo with active worktrees.

## F-KO-15 — Heredoc commit-message pattern (the sub-skill's own reference command) hangs on Git-Bash/Windows
- **Type**: bug
- **Maps to**: /commit
- **Source**: ede075e4-e198-428e-bd93-426df1f0a892.jsonl (project: ai-agent-kit; 2026-07-17)
- **What happened**: `git commit -q -m "$(cat <<'EOF' ...)"` — the literal pattern documented in commit/SKILL.md — hung with no error; staged changes reverted to unstaged. Plain `-m` flags "committed instantly" once tried instead.
- **Proposed enhancement**: Document the plain-flags (or `-F` temp-file) fallback as primary on Windows/Git-Bash.
- **Frequency/severity**: Seen once, but reproduces the skill's own documented reference command verbatim — latent, likely to recur.

## F-KO-16 — /init-repo shipped with a broken YAML frontmatter description (silent trigger degradation)
- **Type**: bug
- **Maps to**: repo-init / /init-repo
- **Source**: 928e6e78-fa52-4f87-be45-ea36cbbda8c9.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: A colon-space sequence broke YAML parsing; the harness silently fell back to using the command body as the description, degrading trigger matching with no warning. Caught only via a proactive diff.
- **Proposed enhancement**: Add a frontmatter-YAML lint pass over all command/sub-skill files to pre-ship validation.
- **Frequency/severity**: Once, but invisible failure mode; needed a follow-up PR after the original had already merged.

## F-KO-17 — Codex mirror drift: publish double-hardens, 4 sub-skills skip AskUserQuestion
- **Type**: bug
- **Maps to**: publish, commit, release-init, prune (Codex mirrors)
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl (project: ai-agent-kit; 2026-07-21)
- **What happened**: Codex's `publish` still inlined old hardening logic that Claude's version delegates to repo-init (a double-hardening hazard on drift). Separately, 4 Codex sub-skills used plain-text prompting, contradicting Codex's own parent-level "all prompts via AskUserQuestion" rule.
- **Proposed enhancement**: Both fixed (PR #99, normalized). Add a Claude-vs-Codex body-diff check to audit.ps1 to catch future drift.
- **Frequency/severity**: Same defect independently found in 4 sub-skills — recurring within one bundle; high severity for the publish double-execution case.

## F-KO-18 — worktree-task-lifecycle never mirrored to Codex; inconsistent naming
- **Type**: missing-capability | doc-gap
- **Maps to**: worktree-task-lifecycle
- **Source**: 2d90e08c-4ea4-49ea-9abc-36fa6c9495f8.jsonl (project: ai-agent-kit; 2026-07-19/21)
- **What happened**: The sub-skill existed only under Claude, leaving Codex users without worktree lifecycle/lock-recovery/credential guidance. Also named inconsistently vs. the `github-<op>` sibling convention.
- **Proposed enhancement**: Both fixed (mirrored + renamed). Confirm mirror/naming checks actually run in CI, not just ad hoc.
- **Frequency/severity**: Seen once each; caught only by manual dogfooding.

## F-KO-19 — CRLF shebang hazard in new repo-init hook templates (near-miss)
- **Type**: bug (near-miss)
- **Maps to**: repo-init templates/hooks
- **Source**: 928e6e78-fa52-4f87-be45-ea36cbbda8c9.jsonl (project: ai-agent-kit; 2026-07-19)
- **What happened**: New hook templates weren't covered by the LF-pinning `.gitattributes` rule; a CRLF shebang would break Git-for-Windows `sh.exe` in any downstream repo, invisibly, since templates are inert data in the source repo.
- **Proposed enhancement**: Fixed pre-merge. Consider a test that deploys templates into a scratch repo and executes them, since this class of bug is invisible by construction in the source repo.
- **Frequency/severity**: Caught before shipping; illustrates a structural blind spot in repo-init's test coverage.

## F-KO-20 — /ship's merge step skips the pre-merge mergeability/CI check that /merge and /release both do
- **Type**: bug
- **Maps to**: /ship (sub-skill's merge step)
- **Source**: 62ecb139-cd13-43b1-b748-bb626f95a2cf.jsonl, aab5ef8b-33eb-4084-a7c7-868d7edf582c.jsonl (project: AC-OSM; 2026-07-16)
- **What happened**: In both sessions `/ship` was explicitly invoked, and its merge step called `gh pr merge <branch> --merge --delete-branch` immediately after opening the PR, with no prior check of mergeability or CI status. Both times it failed on the first attempt — PR #181: "the base branch policy prohibits the merge"; PR #196 failed twice in a row for two different reasons ("the head branch is not up to date with the base branch", then again "the base branch policy prohibits the merge" after a rebase+force-push) — before falling back to `gh pr checks --watch` and succeeding on a third attempt. By contrast, in 5fc74837-0051-439f-80ec-6a767bbfc2df.jsonl, `/merge` and `/release` both check `gh pr view --json mergeable,mergeStateStatus` + `gh pr checks` *before* attempting the merge and succeed first try.
- **Proposed enhancement**: Have `/ship`'s merge step adopt the same check-before-merge pattern already implemented in `/merge` and `/release`: `gh pr view --json mergeable,mergeStateStatus` + `gh pr checks` (optionally `--watch`) before calling `gh pr merge`, only merging once state is MERGEABLE/CLEAN.
- **Frequency/severity**: Recurring — 2 confirmed occurrences under explicit `/ship` invocation (3 failed merge attempts total), plus a similar failure in an ad hoc non-skill merge sequence in 10601f9a-5d6f-40b1-95b7-efb23278fdc4.jsonl. Medium cost (each failure adds a diagnose→wait→retry cycle of several tool calls, ~1-3 min CI wait each); no data loss.

## F-KO-21 — Repo-level auto-merge assumption fails silently, forcing a manual poll loop
- **Type**: ux-friction
- **Maps to**: /merge (ad hoc merge sequencing) / /init-repo (branch-protection & merge-policy setup)
- **Source**: 10601f9a-5d6f-40b1-95b7-efb23278fdc4.jsonl (project: AC-OSM)
- **What happened**: After a blocked merge, the assistant tried enabling auto-merge as the recovery path (`gh pr merge 182 --merge --delete-branch --auto`), which failed with "GraphQL: Auto merge is not allowed for this repository (enablePullRequestAutoMerge)" — the repo has auto-merge disabled at the GitHub settings level, something the skill had no visibility into ahead of time.
- **Proposed enhancement**: `/init-repo` could detect and surface whether GitHub's repo-level "Allow auto-merge" setting is enabled (and offer to turn it on) as part of hardening branch-protection/merge-policy config, so downstream `/ship`/`/merge` runs know whether `--auto` is a viable recovery path before reaching for it.
- **Frequency/severity**: Seen once; low cost (one extra failed command), but symptomatic of the same missing-status-check pattern as F-KO-20.
