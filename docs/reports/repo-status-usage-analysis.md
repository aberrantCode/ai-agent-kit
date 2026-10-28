# `/repo-status` usage analysis — mining all transcripts

**Date:** 2026-10-23 · **Branch:** `feat/repo-status-usage-analysis` · **Handoff:** `rs-usage-26a`
**Prompt:** `docs/PROMPTS/2026-10-23-repo-status-usage-analysis.md`
**Target skill:** `claude/skills/github` → `/repo-status` command → `sub-skills/inspect` operation

Every count tagged `[V]` was computed from the logs by the scripts in `scripts/analysis/`;
`[?]` marks an inference. Evidence is cited by session id (first 12 chars) and quoted verbatim
from the extracted episode slices.

---

## Method (reproducible)

1. **Detect** — `scripts/analysis/detect_repo_status_invocations.py` (built on the read-only
   `cc_transcripts` library) scans every main transcript for a real invocation. Because
   `cc_transcripts.is_injected()` classifies a `<command-name>` turn as *injected*, the detector
   treats the `<command-name> … repo-status …` marker as the **positive** signal (not something to
   filter out) and separately looks for an operator who literally typed `/repo-status` in a
   non-injected turn.
2. **Extract** — `scripts/analysis/extract_episodes.py` dumps each invocation's episode (invocation
   turn → gathering tool calls → report → follow-up turns) as a compact JSON slice.
3. **Characterize** — 9 parallel `haiku` subagents, one per episode, extracted the gathering
   commands, duplication, report text, recommendation, and whether the user acted.
4. **Verify** — checkable counts were re-computed directly (grep/`gh`), and each change-driving
   finding was handed to a skeptic `haiku` subagent instructed to *refute* it. All four survived
   (two CONFIRMED, two PARTIAL-with-refinement; none refuted).

---

## Corpus & invocation set `[V]`

| Metric | Value |
|---|---|
| Project dirs scanned | 50 |
| Main transcripts scanned | 126 |
| Sessions with a real invocation | **9** |
| Total invocations | **10** (one session invoked twice) |
| Invocation signal | `<command-name>` marker: **10/10**; typed: **0** |

The detector's 9 marker-bearing sessions **exactly match** the prompt's independent sanity check
("9 carry a `<command-name>`-style invocation marker"). The prompt's larger figures are correctly
excluded: the loose string `repo-status` (≈211 files) is inflated by skill/command *definitions*,
`CATALOG.md`, and planning chatter; the ~268 `.jsonl` count includes subagent sidechain transcripts,
which cannot receive a slash command.

**Repos (8):** `AC_OSM`, `ac-repo-radar`, `ai-agent-kit`, `paperless-win-client` (2 sessions),
`tax_research`, `taxes` (2 sessions), `win_profiles`.

| session | repo | branch | invoked | gather Bash | outcome |
|---|---|---|---|---|---|
| `4150a02a-e5f` | AC_OSM | dev | start | 5 | accepted `/merge 285` |
| `9f35dd14-6b5` | ac-repo-radar | dev | **mid-session, ×2** | 5 (+5 re-inspect) | accepted `/prune` then `/release` |
| `39dc8450-709` | ai-agent-kit | dev | start | 6 | accepted `/merge #210 #199` |
| `1a620a5f-799` | paperless-win-client | dev | start | 4 | **declined / interrupted** |
| `b48d9415-b13` | paperless-win-client | feat/edit-mode-infra | start | 8 | accepted `/ship` |
| `16ea697d-396` | tax_research | dev | start | 8 | accepted `/prune` |
| `0f868571-346` | taxes | dev | start | 5 | accepted `/merge` → `/prune` → `/release` |
| `dd59140a-a65` | taxes | dev | start | 3 | accepted `/release` |
| `f0ae5e0a-ad6` | win_profiles | dev | start | 9 | accepted `/merge #9` |

---

## Usage patterns `[V]`

- **It is a session opener.** 8/9 invocations are the first operator turn of the session
  (record index 0–2) — "what's the state of this repo before I start / before I log off". The lone
  exception is `ac-repo-radar`, invoked mid-session (idx 67) and again at idx 81.
- **Almost always on `dev`.** 8/9 on `dev`; 1 on a feature branch (`b48d9415`, feat/edit-mode-infra).
- **The recommend → AskUserQuestion → launch flow works.** 9/9 reports ended with an
  `AskUserQuestion` offering the top recommendation; **8/9** users accepted and the recommended
  lifecycle op (`/merge`, `/prune`, `/release`, `/ship`) launched immediately. The one non-acceptance
  (`1a620a5f`) was an explicit user interrupt, not a bad recommendation.
- **No miscommunication.** In **0/9** episodes did the user express confusion or contradict the
  report ("report said X, I expected Y"). The report format (non-empty sections + a recommendation
  table) is landing cleanly. *This bounds the work: sharpen, do not gut.*

---

## Findings (ranked)

### F1 — The "I'll gather silently" preamble violates the contract it announces `[V] 4/9`

In 4 of 9 episodes the agent printed a first-person preamble **before the first gathering command**,
announcing that it would gather silently — which is itself the preamble the contract bans.

- `0f868571`: *"I'll gather repo state silently, then report."* (18:39:21, before Bash at 18:39:23)
- `16ea697d`: *"I'll gather the repo state silently."*
- `1a620a5f`: *"I'll gather repo state through the read-only probes."*
- `dd59140a`: *"I'll gather the repo state silently, then emit one report."*

The inspect Output Contract already says *"No preamble"*, *"stay silent"*, and bans *"narration of
your own reasoning or process ('let me verify', 'I'll check next')"*. The skeptic confirmed each
quote precedes the first tool call and is structurally identical to the banned examples. The ban
exists but the specific "I'll gather silently" meta-announcement slips past it 4/9 times — so it
needs to be a **named** banned example.

**Fix:** add the gather-preamble to the inlined Banned-output list as an explicit example.

### F2 — Gathering is two-phase and undocumented; `&&` chaining risks the degraded-section contract `[V]`

Every episode improvised the same shape: a **broad snapshot** (status, tracking, `fetch`, merges,
refs, worktrees, dev-vs-main, PRs) then **targeted drill-downs** informed by the snapshot
(per-branch merged status, per-worktree dirty, per-PR detail). The SKILL.md documents this as 7 flat
sequential `Step` blocks with no phase structure, so agents re-derive the ordering each time and the
gathering-phase round-trips vary **3–9 Bash calls (median 5)** `[V]`.

More importantly, **9/9 episodes chained probes with `&&`** `[V]`, e.g.
`git fetch origin --prune 2>&1 && echo "=== merges ===" && git log dev --merges …`. Under `&&`, a
single failed probe (a `git fetch` with no network) aborts the rest of the composite — which would
breach the contract's own rule: *"a failed probe degrades its own section, never the whole report."*
The skeptic confirmed the fragility is real and that `0f868571` partially mitigated it only by using
`;` in some calls. (The skeptic also noted round-trip variance is partly drill-down granularity, not
only separator choice — so the fix documents the two-phase shape **and** the separator rule.)

**Fix:** add a short "Gathering discipline" note above the steps — name the two phases, and require
sections be separated with `;` or individually guarded (`… 2>&1 || echo "section unavailable: …"`),
**never `&&`**, so one failed probe degrades only its own section.

### F3 — Per-PR mergeability drill-down is avoidable; CI/stat drill-downs are out of scope `[V] 3/9`

After the Step-5 `gh pr list`, 3 episodes (`0f868571`, `4150a02a`, `f0ae5e0a`) ran per-PR
`gh pr view <n> --json mergeable,…` to learn each open PR's mergeability — an N+1 round-trip. The
field **`mergeable` is available on `gh pr list --json`** (verified against `gh`'s field list), yet
Step 5 does not request it.

The skeptic's refinement: those drill-downs also fetched data **not** on `gh pr list` —
`4150a02a` ran `gh pr checks` (CI status) and `f0ae5e0a` fetched `additions/deletions/commits`.
Those belong to the `/merge` **preflight** or are simply out of scope for a read-only status report;
an inspect report recommends `/merge` from `state` + `mergeStateStatus` + `mergeable`, it does not
need CI or diff stats.

**Fix:** add `mergeable` to the Step-5 `gh pr list --json` query, and add a scope note: the single
list call yields everything the report needs — do **not** run per-PR `gh pr view` / `gh pr checks` /
commit-stat queries; CI-check gating is `/merge`'s job.

### F4 — Worktree probes fail "dubious ownership" on cross-user worktrees `[V] 2/9`

In `39dc8450` (ai-agent-kit) and `4150a02a` (AC_OSM), the Step-4 per-worktree probe
`git -C <path> status --porcelain` failed:

> `fatal: detected dubious ownership in repository at '.worktrees/spawn-terminal-scrub-session-env'`
> *(.git owned by `AC-AW4/erik26`, current user `OPBTA/erik`)*

The agent degraded the section ad-hoc ("clean\*" with a note). The skeptic confirmed the failures
come from Step 4's exact probe, and that `-c safe.directory='*'` is a **read-only-safe** remedy for a
`status --porcelain` read (it reads the index; it cannot mutate and masks no real repo-state problem).
The condition is workstation-specific (multi-profile / cross-SID worktrees) — generality `[?]` — but
the remedy is harmless everywhere.

**Fix:** run the worktree dirty probe as `git -C <path> -c safe.directory='*' status --porcelain`,
and name dubious-ownership as a recognised degraded path in Step 4.

### F5 — Redundant full re-inspect immediately after a launched mutation `[V] 1/9, generality [?]`

In `ac-repo-radar` the user ran `/repo-status`, accepted `/prune`, then **re-invoked `/repo-status`
~32s later**. The second invocation re-gathered ~90% identical state (merge log, local branches,
worktrees, `ls-remote`, `gh pr list`) although the only changes since the first report were the
local mutations `/prune` had just made. No intervening commit justified a full re-gather.

**Fix (guidance, low-risk):** note near the closing step that after the launched op completes, its
own summary already reflects post-state — do not auto re-invoke `/repo-status`; a re-inspect moments
after a mutation re-pays the full gather for no new information.

### F6 — What already works (scope guard) `[V]`

The core loop is healthy: **9/9** reports offered the follow-up via `AskUserQuestion`, **8/9** were
accepted and launched, **0/9** produced confusion. The recommendation-priority ordering
(land work > cleanup > release) matched what users chose. The changes above are additive sharpening;
none alter the report structure, the recommendation table, or the read-only guarantee.

---

## Coverage caps (logged, not hidden)

- **Episode extraction cap.** 4/9 episodes (`39dc8450`, `9f35dd14`, `b48d9415`, `f0ae5e0a`) hit the
  120-event slice cap, dropping 243 / 237 / 152 / 377 later records respectively. Each episode's
  first report lands at events 14–27 — well inside the cap — so the report and immediate follow-up
  were fully captured; only subsequent **unrelated** work was dropped. No episode's core was lost.
- **Main transcripts only.** 126 main transcripts scanned; subagent sidechain `.jsonl` were excluded
  by design (a slash command is never delivered to a subagent). This is why 126 < the prompt's ~268.
- **Typed invocations.** 0 typed `/repo-status` turns were found; if an operator ever buried the
  token mid-paragraph in a way the word-boundary regex missed, it would be uncounted. Confidence is
  high because the marker count (9) independently matches the prompt's sanity check.

---

## Changes applied (each traces to a finding)

| Change | File | Finding |
|---|---|---|
| Name the "I'll gather silently" preamble as a banned phrase | `sub-skills/inspect/SKILL.md` (Banned output) | F1 |
| Add "Gathering discipline": two-phase shape + `;`/guarded separators, never `&&` | `sub-skills/inspect/SKILL.md` (before Step 1) | F2 |
| Add `mergeable` to the Step-5 `gh pr list --json`; scope out per-PR drill-downs | `sub-skills/inspect/SKILL.md` (Step 5) | F3 |
| `-c safe.directory='*'` on the worktree dirty probe; name dubious-ownership degraded path | `sub-skills/inspect/SKILL.md` (Step 4) | F4 |
| Note: don't auto re-invoke `/repo-status` after a launched mutation | `sub-skills/inspect/SKILL.md` (Step 8) | F5 |
| Regression guard asserting the above invariants | `scripts/tests/test_inspect_skill.py` | F1–F4 |

The regression test is stdlib `unittest` (runs with plain `python`). It is **not** wired into the
`validate.ps1` pre-PR gate (which runs catalog/audit/changelog, not pytest/unittest); wiring the
`scripts/tests/` suite into the gate is a reasonable follow-up, noted here rather than bundled in.
