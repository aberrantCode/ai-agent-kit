# Command-Usage Opportunity Audit

**Date:** 2026-10-23 · **Branch:** `feat/commands-usage-opportunities` · **Handoff:** `cmd-opps-26a`
**Method:** orchestrated fleet — 1 Haiku enumeration subagent + 4 Sonnet per-group scanners, Opus synthesis.
**Scope:** every slash command actually invoked across the local Claude Code transcript corpus, scanned for improvement opportunities. **This is discovery only — no command or skill definition was changed.** Opportunities are findings for a later effort.

---

## Executive summary

Mining the full local transcript corpus (51 project dirs, 127 top-level session transcripts) for genuine command *invocations* yields **16 distinct commands and 89 marker-serialized invocations**. Excluding non-improvable built-ins (`clear`, `init`) and commands with no definition file in this archive (`loop`, `upgrade-host`, `honcho:status`, `youtube-toolkit`), **10 improvable commands** carried real usage and were scanned across 4 owning-skill groups. The scan returned **45 improvement opportunities** (11 high, 15 med, 19 low; 38 verified `[V]`, 7 suspected `[?]`).

The highest-value findings cluster into a **concrete definition bug**, a **deployment-drift root cause**, and a set of under-specified guardrails:

1. **A reproducible definition bug in the most-used workflow command.** `ship` (and `merge` and `repo-init`) tell the agent to run `gh repo view --json autoMergeAllowed`, but `autoMergeAllowed` is not a valid `gh --json` field — it fails with a literal "Unknown JSON field" error in two independent repos, silently disabling the auto-merge path (ship-1). Cleanest, cheapest, most verifiable item in the audit; appears in **three** sub-skills.
2. **Installed copies drift behind — or were never pushed to — the profile.** The archive definitions are mostly correct; what actually *ran* was stale or absent. `start-app` has no deployed skill bundle at all (`~/.claude/skills/start-app/` does not exist), so its `Skill` invocation returns a loaded-marker with no body and every run re-hunts for instructions (sa-1); its installed command is two feature generations behind the archive (sa-2); its designed discovery cache has therefore never been written (sa-3, a downstream symptom). Separately, the `opbta-service` skill's `references/` were missing at session time, costing repeated failed `Read` calls under both its command aliases (upd-2 ≡ opb-2, one bug surfaced twice). This is a *deployment/sync-pipeline* problem, not an authoring one.
3. **Under-specified guardrails on blocked and destructive paths.** `ship` has no recovery when a repo's own pre-commit guard blocks the commit (ship-2); `continue-tasks` silently strands genuinely-finished work whose sentinel drifted to `Status: done` (ct-2); and `opbta-service` resolved a mutating op's target from conversational memory rather than its documented 3-tier order (opb-1).

**Verified as already fixed (not actionable):** the loose-skill *colon/args dispatch* failure — where `Skill(skill:"continue-tasks", args:…)` injected only a marker, not the body, and a whole orchestration session ran with **zero** workers spawned (ct-1) — was repaired on **2026-08-05** (commits `b4dbbf0`/`41dbb6c` for project-manager, `cba2a8b` for github). The ct-1 evidence session is dated 2026-07-28, *before* the fix; the current wrappers already instruct "read the sub-skill as a file … do not colon-dispatch," and the one post-fix `continue-tasks` session (804e3c5e, 2026-10-14) shows no recurrence. It is recorded below for provenance only.

---

## Measurement caveats (read before trusting any count)

- **The usage table is a FLOOR, and only for marker-serialized slash commands.** Counts come from `role="user"` turns carrying a `<command-name>` marker. Work triggered by **natural language → skill** (not a slash command) is structurally invisible: e.g. `/handoff` shows **0** invocations here despite heavy real use.
- **The leading-slash signal returned 0 across every command.** The CLI expands a typed `/cmd` into the `<command-name>` marker block, so the literal leading-slash text is replaced — the two detection signals effectively collapse into the marker signal. Reported separately per the method; both are shown as a single reconciled union because they coincided.
- **`repo-status` reconciled from an inflated baseline of 30 to a verified ~10.** The prior handoff baseline counted *raw marker occurrences* (54 across all jsonl incl. subagent transcripts), which double-counts the marker **quoted as data** — and `repo-status` is exactly the command that got quoted all over recent analysis transcripts. Counting only genuine `role="user"` invocation turns gives ~10 (9 distinct sessions). `clear 48` and `ship 8` matched independent spot-checks, confirming the user-role method.
- **Never read a count here as "every invocation does X."** Low-usage commands (1–3 invocations) lean on the definition text plus one or two episodes; those opportunities are marked `[?]` where behavior is unproven.
- **The Stage-A JSON's `improvable` flag is unreliable — this report overrides it.** `_stage-a-command-usage.json` tags `loop`, `upgrade-host`, `honcho:status`, and `youtube-toolkit` as `"improvable": true` while also recording `"definition_file": null` for each — a contradiction. The scanned-improvable set (10) is derived from *having an archive definition file*, not from that flag. Trust the table below, not the raw flag.

---

## Usage table (all detected commands)

| Command | Invocations | Distinct sessions | Owning skill | Improvable | Notes |
|---|---:|---:|---|:--:|---|
| `clear` | 48 | 48 | — | ✗ | built-in |
| `repo-status` | 10 | 9 | github | ✓ | summary depth here — see `feat/repo-status-usage-analysis` |
| `ship` | 8 | 8 | github | ✓ | |
| `opbta-update` | 3 | 2 | opbta-service | ✓ | alias of `update-service` |
| `start-app` | 3 | 3 | start-app | ✓ | |
| `update-service` | 3 | 3 | opbta-service | ✓ | |
| `continue-tasks` | 2 | 2 | project-manager | ✓ | |
| `loop` | 2 | 2 | — | — | plugin skill; no archive definition |
| `prune` | 2 | 2 | github | ✓ | |
| `upgrade-host` | 2 | 2 | — | — | no archive definition |
| `honcho:status` | 1 | 1 | — | — | plugin; no archive definition |
| `init` | 1 | 1 | — | ✗ | CLI built-in |
| `init-features` | 1 | 1 | project-manager | ✓ | |
| `init-project` | 1 | 1 | project-manager | ✓ | |
| `release` | 1 | 1 | github | ✓ | |
| `youtube-toolkit` | 1 | 1 | — | — | plugin; no archive definition |

**Totals:** 16 distinct commands, 89 union invocations. 10 improvable commands scanned.

---

## Prioritized shortlist — highest value across all commands

Ranked by **evidence strength × blast radius × fix cost**, not by any single command's local severity. (This ranking was revised after an adversarial skeptic pass: the originally-#1 colon-dispatch finding was verified *already fixed* — see the executive summary — and is excluded here.)

| # | Opportunity | Commands | Tag | Why it ranks here |
|---|---|---|:--:|---|
| **P1** | **`gh repo view --json autoMergeAllowed` is an invalid field — fails every time** | ship (ship-1), merge, repo-init | `[V]` | Reproducible CLI error confirmed in two repos; silently disables the auto-merge path. Appears in **three** sub-skills. Highest confidence, lowest fix cost in the audit. |
| **P2** | **Installed copies drift behind — or were never pushed to — the profile** | start-app (sa-1, sa-2, sa-3), opbta-service (upd-2 ≡ opb-2) | `[V]` | A deployment/sync-pipeline gap, not authoring. `start-app` has no deployed skill bundle at all; `opbta-service`'s `references/` were missing at run time. Designed caches never fire; every run pays full re-discovery / wasted `Read` calls. One verify-after-deploy step clears the cluster. |
| **P3** | **`ship` has no recovery when a repo's own pre-commit guard blocks the commit** | ship (ship-2) | `[V]` | `ship` is the most-used *workflow* command (8 sessions). A repo-owned pre-commit hook rejected the commit; recovery (a `PM_GUARD_BYPASS=1` path) was improvised and is undocumented, while `release` already documents an analogous bypass. Reproducible quote. |
| **P4** | **Destructive-op target resolution / autonomy contract is under-specified** | opbta-update (opb-1), update-service (upd-1) | `[V]` | A mutating infra op resolved its target from conversational memory instead of the documented 3-tier order (opb-1); another stopped on a safety blocker outside the 5 enumerated STOP conditions (upd-1 — the agent made the *right* call; the gap is documentary, not a safety failure). |
| **P5** | **`continue-tasks` silently strands finished work when the completion sentinel drifts** | continue-tasks (ct-2) | `[V]` | A strict `success\|failure\|blocked` enum means real task files that drifted to `Status: done` are read as malformed and never archived. Concrete, verified, high severity; a one-line normalization rule fixes it. |
| **P6** | **`start-app` prerequisite check dumps a live secret into the transcript** | start-app (sa-5) | `[V]` | `cat .env` printed `TELEGRAM_API_HASH=…` in cleartext. Secret exposure — ranked by exception regardless of its single-session frequency. Cheap fix: presence-check, don't dump values. |
| **P7** | **`start-app` reports exit 0 "success" for a GUI app whose window never rendered** | start-app (sa-4) | `[V]` | Real correctness bug: a detached background launch has no interactive desktop; the success indicators can't tell headless success from a GUI false-positive. |
| **P8** | **Approval/seed `AskUserQuestion` menus omit the option the real user chose** | init-features (if-1), init-project (ip-1) | `[V]` | Cheap, high-UX wins: real users answered these exact gates off-menu (adversarial-review-first; interview-me-now). The transcripts are a free list of the options the menus should have had. |

---

## Cross-command themes

- **Deployment, not authoring (P1, P2):** the single strongest pattern. The archive definitions are mostly correct; what *ran* was stale (installed copy lags two generations), absent (`start-app` never deployed), or out-of-sync (`opbta-service` `references/` missing). Verifying the archive→profile sync — and confirming the `Skill` tool actually injects body text after a deploy — would clear more findings than any authoring change. The related *colon-dispatch* failure class was already fixed in Aug 2026 (see exec summary); deployment freshness is the part still open.
- **Mutating-op safety (P4):** `opbta-service`'s routing/autonomy contract enumerates a fixed set of STOP conditions and a 3-tier target resolution, but real sessions hit unenumerated safety blockers and resolved targets from conversation — the contract needs sanctioned exits rather than forcing ad-hoc improvisation that reads as a violation.
- **Prose-vs-snippet:** several commands narrate a procedure ("diff `ls .worktrees/` against `git worktree list`", "poll `statusCheckRollup` until all green") instead of shipping a tested snippet; each prose step becomes a per-run re-derivation, and at least one produced a bug (ct-6's false-positive GREEN match). See ship-3, ct-6, prune-1.
- **Menu completeness (P8):** approval and seed gates repeatedly missed the answer the operator actually gave (if-1, ip-1). The transcripts are a free list of the options the menus should have had.
- **Reconciliation integrity:** `continue-tasks` has three related gaps where state silently diverges from reality — sentinel drift (ct-2), un-released stale locks (ct-4, 18 accumulated), and a STATUS.md "auto-regenerated" claim that didn't hold across ad-hoc sessions (ct-5). Each is a place the orchestrator trusts a convention that real usage broke.
- **Output hygiene (sa-5, sa-7):** one secret leak and one recurring mojibake — both cheap, both recur on every relevant invocation.

---

## All opportunities by command

Each row: `id` · severity · tag · title — *evidence pointer*. Full detail (with proposed change) in the per-group JSON under `docs/reports/_stage-b-*.json`.

### github — `ship` (7)
- **ship-1** · high · `[V]` · `gh repo view --json autoMergeAllowed` is an invalid field — fails every time — *sessions 22a4e3db / 0f868571: "Unknown JSON field: autoMergeAllowed"*
- **ship-2** · high · `[V]` · No documented recovery when a repo's own pre-commit guard blocks the commit — *session 5df20d93: "commit is blocked by the project-manager pre-commit guard"*
- **ship-3** · high · `[V]` · Test-gate worktrees invented ad hoc in colliding non-canonical locations — *session d313ed1a: "already used by worktree at '…/.claude/worktrees/…'"*
- **ship-4** · med · `[V]` · Windows build-server file lock strands the post-merge local `dev` sync — *session b48d9415: "unable to unlink old 'PaperlessWinClient.csproj'"*
- **ship-5** · med · `[V]` · `ToolSearch(select:AskUserQuestion)` round-trip fires on nearly every ship — *sessions 22a4e3db, 5df20d93, d313ed1a*
- **ship-6** · med · `[V]` · No check for a concurrent session mutating the primary checkout mid-ship — *session d313ed1a: "Stop — the working tree changed under me"*
- **ship-7** · low · `[V]` · Same excluded scratch paths re-flagged every run instead of being gitignored — *sessions b48d9415, e3b744b3*

### github — `prune` (2)
- **prune-1** · low · `[V]` · Orphan-worktree enumeration is prose-only, improvised each run — *prune/SKILL.md Step 3*
- **prune-2** · low · `[?]` · Follow-up table sometimes carries findings outside prune's scope — *session 39dc8450*

### github — `release` (2)
- **release-1** · med · `[V]` · PR-only-`main` detection relies on a fragile textual grep over CLAUDE.md/AGENTS.md — *release/SKILL.md Step 5*
- **release-2** · low · `[?]` · Only observed release run ends at the version question; post-version path execution-unverified — *session b48d9415*

### github — `repo-status` (2 — summary depth; defer to `feat/repo-status-usage-analysis`)
- **repo-status-1** · low · `[?]` · Closing `/ship` offer premature when dirty set mixes real work with scratch — *session 1a620a5f*
- **repo-status-2** · low · `[V]` · No other friction in sampled runs (correct recommendations, no repeats) — *sessions 0f868571, dd59140a*

### opbta-service — `update-service` (6)
- **upd-1** · high · `[V]` · Second plan-gate fires on a safety blocker outside the 5 documented STOP conditions — *session cae7b38b: "vendored installer is fresh-install-only"*
- **upd-2** · med · `[V]` · Missing installed `references/` → repeated failed `Read` calls — *session 5d231e21: "File does not exist" ×4*
- **upd-3** · med · `[V]` · "Three-perspective" smoke test silently ran 2-of-3 (no DoH leg) — *session 5d231e21*
- **upd-4** · low · `[?]` · GHCR tags/list returned a stale `latest` before self-correcting to Releases — *session 5d231e21*
- **upd-5** · low · `[V]` · grep-wrapped exit-code check produced ambiguous `failed: rc=0`, needed rerun — *session 5d231e21*
- **upd-6** · low · `[?]` · Breadcrumb lookup runs even after an explicit slug resolved the target — *session be10d3e2*

### opbta-service — `opbta-update` (6)
- **opb-1** · high · `[V]` · Bare invocation resolved its target from conversational memory, not the 3-tier order — *session 9f35dd14*
- **opb-2** · med · `[V]` · Same missing-`references/` failure as upd-2, confirming it's systemic — *session 9eb6fc97*
- **opb-3** · med · `[V]` · Public-DoH leg skipped for an internal-only FQDN with no documented carve-out — *session 9f35dd14*
- **opb-4** · low · `[V]` · Mis-scoped grep matched ~66KB of docker-inspect JSON instead of deploy-log markers — *session 9f35dd14*
- **opb-5** · low · `[V]` · Clean fallback clone placed outside the `.worktrees/` convention — *session 9f35dd14*
- **opb-6** · low · `[?]` · Read-only probes SSH'd directly to the docker host, bypassing the documented double-hop — *session 9f35dd14*

### start-app — `start-app` (8)
- **sa-1** · high · `[V]` · `Skill` reports loaded but never injects `SKILL.md`; 3/3 sessions fall back to manual file hunting — *sessions 6272da95/99fef80f/f0ae5e0a: "already loaded above; instructions unchanged"*
- **sa-2** · high · `[V]` · Installed global command is two feature generations behind the archive (no cache/probe/`--restart`) — *transcript cat in all 3 sessions*
- **sa-3** · high · `[V]` · Discovery cache + runtime sidecar never written in any of the 3 sampled repos — *`ls docs/framework/` absent in all 3*
- **sa-4** · high · `[V]` · GUI app launched as detached background task reports exit 0 while the window never appears — *session f0ae5e0a*
- **sa-5** · med · `[V]` · Prerequisite check `cat .env` dumps a live secret into the transcript — *session 99fef80f: "TELEGRAM_API_HASH=…"*
- **sa-6** · med · `[V]` · No guidance for one-shot CLI apps needing interactive first-run auth — *session 99fef80f*
- **sa-7** · low · `[V]` · Mojibake (`�`) in the command description when read back via `cat` — *all 3 sessions*
- **sa-8** · low · `[V]` · Launch-method lesson hand-recorded into the repo's CLAUDE.md instead of the skill's own cache — *session f0ae5e0a*

### project-manager — `continue-tasks` (6)
- **ct-1** · ~~high~~ **FIXED** · `[V]` · `Skill(…, args)` never expands the sub-skill body → total protocol bypass (0 workers spawned) — *session 1a48e018 (2026-07-28), predates fix `b4dbbf0` (2026-08-05); current wrapper already reads-as-file. Provenance only — not actionable.*
- **ct-2** · high · `[V]` · Completion sentinel drifts to `Status: done`; gate has no normalization step — *session 804e3c5e*
- **ct-3** · med · `[V]` · No defined handling for out-of-band "operational" tasks outside the plan pipeline — *session 804e3c5e (8 accumulated)*
- **ct-4** · med · `[V]` · Stale lock files accumulate with no release step (18 dead locks) — *session 804e3c5e*
- **ct-5** · med · `[V]` · `docs/STATUS.md` auto-regeneration claim doesn't hold across ad hoc sessions — *session 804e3c5e (stale since 2026-08-04)*
- **ct-6** · low · `[V]` · PR CI-polling hand-rolled fresh each time, with an early-match false-positive — *session 1a48e018: "I matched too early"*

### project-manager — `init-features` (3)
- **if-1** · med · `[V]` · Step 3 approval question has no "adversarial review first" option — *session 6216f16f (user answered off-menu)*
- **if-2** · low · `[V]` · Specs embed point-in-time counts with no freshness marker — *session 6216f16f ("97 artifacts … not 78")*
- **if-3** · low · `[?]` · Only `/continue-tasks` suggested as next step; real usage branched to a handoff chain — *session 6216f16f*

### project-manager — `init-project` (3)
- **ip-1** · med · `[V]` · PRD-seed options omit an "interview me now" choice, which is what real usage asked for — *session 6216f16f*
- **ip-2** · low · `[V]` · `git add -A | wc -l` inventory check mutates the index, needs `git reset` cleanup — *session 6216f16f*
- **ip-3** · low · `[V]` · Default `scope-manifest.md` is web-app-shaped with no repo-shape detection — *session 6216f16f*

---

## Methodology & provenance

- **Corpus:** `~/.claude/projects/` — 51 project dirs, 127 top-level session transcripts (283 jsonl incl. subagent transcripts, which were excluded from invocation counting).
- **Enumeration (Stage A, Haiku):** two detection signals reconciled — the `<command-name>` marker in `role="user"` turns, and a leading-`/name` in user text. `cc_transcripts.is_injected()` is *not* used to filter invocation turns (it flags the marker as injected); it only cleans surrounding quoted evidence. Script: `scripts/_mine_command_usage.py`; output: `docs/reports/_stage-a-command-usage.json`.
- **Per-command scan (Stage B, 4 Sonnet agents in parallel):** each read the command's definition (wrapper + sub-skill) and its real usage episodes, returning opportunities at a *reasonable-suspicion* inclusion bar, each tagged `[V]`/`[?]` with a one-line evidence pointer. Outputs: `docs/reports/_stage-b-{github,opbta,startapp,pm}.json`.
- **Synthesis (Opus):** grouping, cross-command root-cause identification, and this prioritization. An adversarial skeptic pass then challenged the shortlist and **materially revised it**: it caught that the originally-#1 colon-dispatch finding (ct-1) was already fixed in Aug 2026, which the orchestrator verified directly against git history and the session's internal timestamps before demoting it; ship-1 was promoted to #1, and ship-2/ct-2 were promoted into the shortlist.
- **Not changed:** no command or skill definition was edited. Transcript access was strictly read-only.
</content>
</invoke>
