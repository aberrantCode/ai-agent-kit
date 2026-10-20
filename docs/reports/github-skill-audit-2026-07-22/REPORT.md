# GitHub Skill Audit — 7-Day Transcript Mining

**Generated:** 2026-07-22
**Scope:** All top-level Claude Code session transcripts modified in the last 7 days (2026-07-15 → 2026-07-22), across 11 projects. Nested `subagents/` logs excluded to avoid double-counting.
**Method:** Four Sonnet scanner subagents, partitioned by project, grep-mined the JSONL transcripts for git/gh activity, command invocations, error/friction signals, and user-correction language — reading only small windows around hits. Findings written to `partials/`, deduped and synthesized here.
**Coverage:** 87 transcripts scanned (repo-radar 33, AC-OPBTA 18, ai-agent-kit+AC-OSM 20, AC-DESIGN+misc 16). **40 raw findings → 12 deduplicated themes.**

The `github` skill audited: thin-orchestrator bundle at `claude/skills/github/`. Commands `/publish /init-repo /commit /ship /merge /release /release-init /prune` → matching sub-skills, plus `worktree-task-lifecycle` (no command). Codex mirror at `codex/skills/github/`.

---

## Executive Summary

The four scanners, working blind to each other on different repos, **converged on the same handful of root causes**. That convergence is the headline: these are systemic gaps in the skill, not repo-specific accidents.

The dominant themes, by weight of evidence:

1. **The skill is bypassed** — most real PR/merge work ran through raw `git`/`gh` instead of the named commands, so the skill's guarantees (output contract, worktree cleanup, merge-commit policy, preflight checks) went unexercised. *(highest frequency — 19+ instances in one project alone)*
2. **Merge/ship lacks a robust preflight** — no protection-awareness, no `isDraft` check, no `mergeable=UNKNOWN` retry, no CI-wait; failures are discovered *after* a rejected merge and reverse-engineered live. *(6 findings)*
3. **Stale remote-tracking refs** — no forced `git fetch --prune`, and remote-delete/`--delete-branch` steps treat "already gone" as failure. *(4 findings, one recurring 6×)*
4. **Worktree teardown is fragile** — no post-`add` self-check, no live-process-tree lock recovery, no detection of a worktree pruned by a concurrent session, orphaned directories left behind. *(7 findings)*
5. **Output contract under-enforced** — narrated live during a real release; was a dangling pointer in 6 sub-skills; stale standalone global copies never bound it. *(2 findings, one the single highest-severity item)*
6. **Distribution drift** — global profile had no `sub-skills/` at all; Codex mirror lags Claude on fixes. *(4 findings)*
7. **Windows/Git-Bash hazards** — `gh api` path mangling silently no-ops branch protection; heredoc commit hangs; Cygwin fork failures; CRLF shebangs. *(4 findings)*

---

## Prioritized Themes

Priority = frequency × severity × how cheaply it can be fixed in the skill. **P0** = fix now; **P1** = strong; **P2** = worthwhile; **P3** = verify-already-fixed / meta.

| # | Theme | Priority | Maps to | Evidence (findings) |
|---|---|---|---|---|
| T1 | Skill bypassed — raw git/gh used instead of named commands | **P0** | whole bundle, SKILL.md triggers | F-KO-01, F-KO-02, F-OP-04 |
| T2 | Merge/ship preflight gaps (draft, UNKNOWN, protection, CI, auto-merge) | **P0** | merge, ship | F-KO-06, F-KO-20, F-KO-21, F-DM-01, F-DM-12, F-OP-02 |
| T3 | Stale remote refs — no forced `fetch --prune`; "already-gone" = failure | **P0** | merge, prune | F-RR-01, F-DM-06, F-KO-07, F-KO-08 |
| T4 | Worktree lifecycle robustness (add-verify, lock recovery, concurrent prune, orphans) | **P1** | worktree-task-lifecycle, ship | F-RR-02, F-DM-08, F-DM-09, F-DM-10, F-DM-11, F-KO-14 |
| T5 | Output-contract enforcement | **P1** | all sub-skills | F-KO-03, F-KO-04 |
| T6 | Windows/Git-Bash environment hazards | **P1** | commit, init-repo, release, all | F-DM-07, F-KO-15, F-DM-04, F-KO-19 |
| T7 | Generated/committed-doc merge policy | **P1** | init-repo, merge | F-OP-01, F-OP-02, F-OP-03 |
| T8 | Distribution / mirror drift (profile + Codex) | **P1** | distribution, audit tooling | F-KO-05, F-KO-17, F-DM-03, F-KO-18 |
| T9 | Commit integrity — message rewritten silently | **P2** | ship, commit | F-DM-05, F-KO-15 |
| T10 | Release automation correctness | **P2** | release, release-init | F-DM-02, F-KO-13, F-KO-10, F-KO-11, F-KO-12 |
| T11 | repo-init specifics (YAML frontmatter, hooksPath, auto-merge setting) | **P2** | init-repo, repo-init | F-KO-16, F-KO-14, F-KO-21 |
| T12 | Missing quality/lint gates (meta — would have caught many above) | **P3** | validate.ps1 / audit.ps1 | F-KO-04, F-KO-05, F-KO-10, F-KO-11, F-KO-16, F-KO-17, F-KO-19 |

---

## Theme Detail

### T1 — The skill is bypassed (P0)
Most PR/merge/commit work ran through raw `git`/`gh`, even on near-verbatim trigger phrases (user said "merge PR 76", assistant ran `gh pr merge 76`). In one project the skill fired **once across 8 PR cycles** despite the repo's CLAUDE.md saying "Always use /ship." A 20-repo `/init-repo`-shaped rollout never called `/init-repo` once, hand-rolling its exact logic. A batch of 6 PRs opened with raw `gh pr create` produced an ambiguous summary that confused the user ("I don't understand, what do you need me to do so that you can merge them all?").
**Direction:** strengthen trigger language for autonomous/`/loop`/background contexts; add an explicit "prefer the named skill over reimplementing in Bash" instruction; when the assistant is about to `gh pr create`/`gh pr merge` mid-flow, route through the skill. When a batch of PRs is left pending, surface the merge decision via `AskUserQuestion`, not prose.

### T2 — Merge/ship preflight gaps (P0)
`merge`/`ship` attempt the merge and discover blockers afterward, then reverse-engineer the repo's policy live. Missing checks: `isDraft` (a draft passed every gate then GitHub refused it), transient `mergeable == "UNKNOWN"` right after push (failed 6+ times, assistant hand-wrote a poll loop each time), required status checks / branch protection (plain merge silently blocked), CI-in-flight (ship merged immediately after opening the PR, failing 2–3× before watching checks), and repo-level auto-merge being disabled (`--auto` recovery failed with a GraphQL error).
**Direction:** a shared, protection-aware preflight for both `merge` and `ship`: `gh pr view --json mergeable,mergeStateStatus,isDraft` + `gh pr checks` before any `gh pr merge`; poll UNKNOWN (~5×/15s); treat draft as a distinct gate (AskUserQuestion: mark-ready or skip); detect required checks and either `--auto` or watch-to-green; know whether repo-level auto-merge is even enabled before reaching for `--auto`.

### T3 — Stale remote refs / already-gone deletes (P0)
No step forces `git fetch --prune`, so `git branch -r` shows phantom branches ("1 ahead" for a branch already merged+deleted upstream), producing false "still needs merging/deleting" conclusions. `/prune`'s `git push origin --delete <branch>` treats an already-deleted remote branch as a hard failure (`error: failed to push some refs`) — **recurring 6× across 5 days**, since repos with auto-delete-on-merge (which `/init-repo` itself enables) remove the branch server-side first. `gh pr merge --delete-branch` races the same server-side deletion and prints nothing, reading as a failed merge.
**Direction:** `merge`/`prune` run `git fetch --prune` as step 1; before any remote delete, `git ls-remote --heads origin <branch>` and skip+record "already removed" when absent; treat "branch not found" on `--delete-branch` as success + `git fetch --prune`. Generalize the local-`dev`-resync step to any ad-hoc `gh pr merge --delete-branch`, not just formal `/merge`.

### T4 — Worktree lifecycle robustness (P1)
The sub-skill advertises "Windows file-lock recovery" but the documented procedure ("retry once, then leave it on disk") is wrong for the cases seen: (a) a **live dev-server process tree** holding a log file inside the worktree — retry can never succeed while the process lives; resolution needed manual `Get-CimInstance Win32_Process` PID-tree walking. (b) `git worktree add` that **silently didn't complete**, leaving an empty non-git directory. (c) a worktree **pruned by a concurrent session** mid-task, undetected by `/ship`, forcing a risky commit on the shared main checkout (briefly moving it off `dev`). (d) stale `index.lock` + interrupted `rebase-merge` state on teardown. (e) removal leaving an **orphaned directory** because the harness pins cwd inside it. Separately, `core.hooksPath` silently skips hooks on pre-existing worktrees/branches.
**Direction:** post-`add` self-check (`git worktree list` + valid `.git` linkage, repair if empty); lock-diagnosis step that resolves and kills a live holding-process tree rooted in the worktree path *before* the give-up fallback; `ship` verifies its worktree still exists/registered before proceeding, else recreate-and-replay or pause via AskUserQuestion; scriptable stale-lock/rebase-abort recovery; `prune` cleans orphaned worktree directories; `/init-repo` prefers the `.git/hooks` shim over `core.hooksPath` when active worktrees exist.

### T5 — Output-contract enforcement (P1)
During a real `v0.10.0` release, 7 interstitial "now tagging… rolling the changelog…" messages were emitted despite the inlined contract banning narration. Root cause earlier: the contract was a **dangling pointer** ("obey the parent Output Contract") in 6 of 9 sub-skills — resolves to nothing standalone — and stale standalone `~/.claude/skills/{merge,release}` copies never bound it. User complained directly: "I only want to see messages if there are actual errors." (highest-severity finding overall).
**Direction:** keep the contract inlined everywhere (done in-session); add a worked example transcript showing 5+ tool calls with zero interstitial prose; move any necessary narration into tool-call `description` fields; add a lint check flagging pointer-only contract references and drifted standalone op-skill dirs.

### T6 — Windows/Git-Bash environment hazards (P1)
`gh api -X PUT "/repos/.../branches/main/protection"` **silently no-ops** on Windows Git Bash — MSYS rewrites the leading `/repos/...` into a filesystem path before `gh` sees it; branch protection was believed applied but wasn't. The documented heredoc commit pattern (`git commit -m "$(cat <<'EOF' …)"`) **hangs** on Git-Bash and reverts staged changes. Git-bash Cygwin **fork failures** after heavy use leave merge state ambiguous. New hook templates weren't covered by LF-pinning `.gitattributes` — a CRLF shebang would break `sh.exe` downstream.
**Direction:** any `gh api` call with a leading-slash path sets `MSYS_NO_PATHCONV=1` and reads back the applied state rather than trusting exit 0; document plain-`-m`/`-F` temp-file as the primary commit path on Windows; add an Error-Recovery row prescribing automatic `pwsh` retry on Cygwin fork errors, applied to `ship`/`merge`/`release`; extend LF-pinning to `templates/hooks/*`.

### T7 — Generated/committed-doc merge policy (P1)
A repo accumulated "merge debt — 7 PRs stalled 4–5 days" because `docs/STATUS.md` is generated-and-committed and hook-regenerated (75 commits/2 weeks) so any two branches collide. Date-sensitive generated docs go stale across a day boundary and produce a CI `BLOCKED` only discovered after a merge attempt. Append-then-periodically-drained files (`_intake.md`) need judgment-heavy manual conflict resolution (flagged as a near-miss on real data loss).
**Direction:** `/init-repo` provisions a `.gitattributes` merge-driver policy (registered locally, since GitHub's server-side merge ignores `.gitattributes`) + regen-after-rebase hook for declared generated-and-committed files; `merge` proactively regenerates date-sensitive docs before attempting; document a repeatable "append-then-drained" third file class with a diff-and-keep-new helper.

### T8 — Distribution / mirror drift (P1)
The global profile's `~/.claude/skills/github/` had **no `sub-skills/` directory at all** (the `push-to-profile.ps1` sync is a documented stub that throws silently), so every profile-run `/ship`/`/merge`/`/commit`/`/prune` improvised from memory, missing worktree-lock recovery and credential rules. The Codex mirror lagged: `publish` still inlined old hardening (double-hardening hazard), 4 Codex sub-skills used plain-text prompting against Codex's own AskUserQuestion rule, the `release` variant stayed stale after Claude's was patched, and `worktree-task-lifecycle` was never mirrored to Codex.
**Direction:** fix the profile-push so sub-skills actually deploy; add an audit check that every command's referenced sub-skill path resolves in each installed location and that standalone duplicate op-dirs are an error; add a Claude-vs-Codex(-vs-Gemini) body-diff parity check to `/audit-skills` for substantive (non-harness) divergence.

### T9 — Commit integrity (P2)
During `/ship`, a `git commit -m "..."` landed the correct 9 files but a **completely unrelated commit message** (a `prepare-commit-msg` hook / harness intercept hijacked `-m`). Caught only because the assistant proactively checked `HEAD`.
**Direction:** `ship`'s commit stage diffs the actual `HEAD` message/file-list against intent after committing and bails loudly on mismatch, rather than relying on vigilance. (Overlaps the heredoc hang in T6.)

### T10 — Release automation correctness (P2)
Version-ref stamp/tag **ordering** wasn't generic — tagged before the version bump, tripping a doc-truth gate (took two iterations to generalize). Three latent `/release` bugs: tag pushed before changelog PR landed (staleness gate rejection, unplanned PR); branch-protection detection via `grep -c .` counts the literal string `null` as protected; `git tag` with no ref tagged local HEAD not the merged commit. Template `Generate-Changelog.ps1` shipped **mojibake** under `-NoProfile` (real prior incident in AC_OSM) and lint violations (unapproved verb, `Write-Host`→`Write-Information` would silently drop output). `/release-init` doesn't provision the changelog-staleness gate to consumers (AC_OSM silently fell a release behind).
**Direction:** verify the generalized Step 4b/6b covers tag-keyed doc-truth gates by default; `--jq '.url // empty'` for protection detection; tag `origin/main` explicitly; ASCII glyphs + pinned UTF-8 console encoding in templates; provision the staleness gate (script + CI + pre-push hook) as a first-class `/release-init` artifact.

### T11 — repo-init specifics (P2)
`/init-repo` shipped with a colon-space that **broke its YAML frontmatter**, so the harness silently used the body as the description, degrading trigger matching. `core.hooksPath` silently skips hooks on pre-existing worktrees (see T4). Repo-level "Allow auto-merge" isn't detected/surfaced, so `/ship`/`/merge` don't know whether `--auto` is viable.
**Direction:** frontmatter-YAML lint over all command/sub-skill files pre-ship; hooksPath shim when worktrees exist; `/init-repo` detects and offers to enable repo-level auto-merge as part of merge-policy hardening.

### T12 — Missing quality/lint gates (P3, meta)
A striking number of findings are self-described as "add a lint check for this." Collectively they argue for a pre-ship gate over the bundle: pointer-only output-contract references; sub-skill path resolution in every installed location; non-ASCII bytes in `templates/*.ps1`; PSScriptAnalyzer on templates; YAML frontmatter validity; Claude-vs-Codex body diff; and a template-execution smoke test (deploy into a scratch repo and run the hooks). Many T-level bugs above are invisible-by-construction in the source repo and only a deploy-and-execute test would catch them.

---

## Already-Fixed — Verify Deployment, Don't Re-Solve

These were flagged from older sessions but fixed in-session/in-archive. Given the distribution drift (T8), the action is **confirm the fix is present in every deployed copy** (archive + global profile + Codex/Gemini), not re-implement.

| Finding | What was fixed | Verify |
|---|---|---|
| F-RR-03 | `/release` no longer assumes direct push to `main`; routes to release-PR + `--admin` fallback | present in archive `release/SKILL.md` |
| F-KO-04 | Output contract inlined across sub-skills | all 9 sub-skills, both harnesses |
| F-KO-07 | `--delete-branch` "branch not found" treated as success | all deployed merge copies |
| F-KO-09 | `/prune` no longer writes `docs/git-log.md` debris (PR #75) | all repos it touched |
| F-KO-10 | Mojibake in `Generate-Changelog.ps1` (ASCII + UTF-8 pin) | archive template + AC_OSM consumer |
| F-KO-11 | release-init template lint / Write-Host | archive template |
| F-KO-13 | Tag ordering, `null`-match, tag-ref bugs | archive `release/SKILL.md` |
| F-KO-17 | Codex publish double-harden + AskUserQuestion (PR #99) | Codex mirror |
| F-KO-18 | worktree-task-lifecycle mirrored + renamed for Codex | Codex mirror |
| F-DM-02 | Release version-stamp/tag ordering generalized (PR #131) | archive `release/SKILL.md` Step 4b/6b |
| F-DM-04 | git-bash Cygwin fork → pwsh retry Error-Recovery row | confirm it auto-retries and applies to ship/merge |
| F-DM-03 | Codex `release` variant port | **OPEN in source session** — likely still stale |

---

## Appendix — Raw Findings Index

Full per-scanner detail in `partials/`:
- `partials/repo-radar.md` — F-RR-01..03 (3)
- `partials/opbta.md` — F-OP-01..04 (4)
- `partials/kit-osm.md` — F-KO-01..21 (21)
- `partials/design-misc.md` — F-DM-01..12 (12)

| Finding | Theme | Type | Maps to |
|---|---|---|---|
| F-RR-01 | T3 | bug | prune |
| F-RR-02 | T4 | missing-capability | worktree-task-lifecycle |
| F-RR-03 | (fixed) | bug (historical) | release |
| F-OP-01 | T7 | missing-capability | init-repo, merge |
| F-OP-02 | T2/T7 | ux-friction | merge |
| F-OP-03 | T7 | missing-capability | merge |
| F-OP-04 | T1 | trigger-miss | ship, merge |
| F-KO-01 | T1 | trigger-miss | whole bundle |
| F-KO-02 | T1 | trigger-miss | init-repo |
| F-KO-03 | T5 | output-contract-violation | release |
| F-KO-04 | T5 | output-contract-violation/bug | 6 sub-skills |
| F-KO-05 | T8 | bug | distribution |
| F-KO-06 | T2 | bug/missing-capability | merge |
| F-KO-07 | T3 | bug | merge |
| F-KO-08 | T3 | ux-friction/missing-capability | merge |
| F-KO-09 | (fixed) | bug | prune |
| F-KO-10 | T10 | bug | release-init template |
| F-KO-11 | T10 | bug | release-init template |
| F-KO-12 | T10 | missing-capability | release-init |
| F-KO-13 | T10 | bug | release |
| F-KO-14 | T4/T11 | bug | init-repo, worktree-task-lifecycle |
| F-KO-15 | T6/T9 | bug | commit |
| F-KO-16 | T11 | bug | repo-init |
| F-KO-17 | T8 | bug | Codex publish/commit/release-init/prune |
| F-KO-18 | T8 | missing-capability/doc-gap | worktree-task-lifecycle |
| F-KO-19 | T6 | bug (near-miss) | repo-init templates/hooks |
| F-KO-20 | T2 | bug | ship |
| F-KO-21 | T2/T11 | ux-friction | merge, init-repo |
| F-DM-01 | T2 | missing-capability | ship, merge |
| F-DM-02 | T10 | bug (resolved) | release |
| F-DM-03 | T8 | doc-gap | release (Codex) |
| F-DM-04 | T6 | bug | release (merge step) |
| F-DM-05 | T9 | bug | ship |
| F-DM-06 | T3 | bug | merge, prune |
| F-DM-07 | T6 | bug | init-repo, publish |
| F-DM-08 | T4 | bug | worktree-task-lifecycle |
| F-DM-09 | T4 | bug | worktree-task-lifecycle, ship |
| F-DM-10 | T4 | bug | worktree-task-lifecycle |
| F-DM-11 | T4 | bug | worktree-task-lifecycle |
| F-DM-12 | T2 | bug | merge |
