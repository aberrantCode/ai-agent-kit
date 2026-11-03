---
handoff_id: rs-usage-26a
title: Mine all logs for /repo-status usage; find patterns & inefficiencies; propose meaningful skill improvements
model: opus
base_branch: dev
branch: feat/repo-status-usage-analysis
repo: C:\development\ai-agent-kit
---

# Handoff — Analyze `/repo-status` usage across all logs and improve the skill

You are a fresh session. Everything below is the task; treat it as your first message. Your worktree
and branch (`feat/repo-status-usage-analysis`, from `dev`) **already exist** — work there; do not
create another worktree.

## 1. Orientation

- Read `C:\development\ai-agent-kit\CLAUDE.md` and `AGENTS.md` and follow them exactly.
- Target skill: the **`github`** skill's `repo-status` command → the **`inspect`** operation.
  - Command entry: `claude/skills/github/commands/repo-status.md` (thin; delegates to the op).
  - **Primary improvement target:** `claude/skills/github/sub-skills/inspect/SKILL.md` — the actual
    read-only report logic (working tree, tracking, worktrees, open PRs, stale branches → a
    next-command recommendation).
  - Output Contract it inherits: `claude/skills/github/SKILL.md`.
- Goal: mine **all** conversation logs for real `/repo-status` usage, characterize how it actually
  behaves in the wild, and propose + apply meaningful improvements as a reviewed PR.

## 2. Hard constraints (first and unmissable)

Running under `--dangerously-skip-permissions`; this section is the only guardrail.

- Transcript access is **strictly read-only**. Never write, move, or delete anything under
  `~/.claude/projects/`.
- Changes land **only** in the `github` skill, via a reviewed PR to `dev`. Preserve the skill's
  existing structure, the read-only guarantee of `inspect`, and its Output Contract — sharpen and
  add, do not gut.
- Never state a usage count, "N sessions", or "happens every time" claim you did not compute from
  the logs. Tag every finding `[V]` (measured) / `[?]` (inferred). A fabricated frequency sends the
  improvement effort at a non-problem.
- Work only inside the provided worktree. If a task seems to require violating the above, stop and
  report.

## 3. State already established (do not redo)

- [V] Read-only transcript library (stdlib-only, Python 3.10+):
  `claude/skills/session-manager/sub-skills/transcripts/scripts/cc_transcripts.py` — import it; do
  **not** re-derive discovery/iteration/counting. Prior art for mining:
  `claude/skills/session-manager/sub-skills/audit/scripts/mine_dispatches.py`.
- [V] Corpus: 48 project dirs / ~268 `.jsonl` / ~174 MB under `~/.claude/projects/`.
- [V] Usage signal counts (starting sanity check, **not** the final number):
  34 `.jsonl` files reference `/repo-status`; 9 carry a `<command-name>`-style invocation marker;
  211 reference the loose string `repo-status` — **the 211 is inflated** by the skill/command
  *definitions*, descriptions, catalog, and planning chatter. Do not treat loose mentions as usage.
- [V] The command is read-only and delegates: `commands/repo-status.md` → load `Skill(github)` →
  read `sub-skills/inspect/SKILL.md` (a file to read, not `Skill(github:inspect)`).

## 4. What we tried / dead ends (apply these, learned the hard way)

- **`cc_transcripts.is_injected()` will hide command invocations.** Its `INJECTED_PREFIXES`
  includes `<command-name>`, so a `/repo-status` invocation turn is classified as "injected". To
  **detect** invocations you must look for the `<command-name>`/`repo-status` signal explicitly —
  do **not** filter user turns through `is_injected` and expect invocations to survive. (Use
  `is_injected` only to strip reminders/hooks when reading the *surrounding* human turns.)
- **Loose-string counting over-reports.** Join real usage from the invocation marker + the
  `/repo-status` token in an actual user turn; exclude files that only contain the skill/command
  definition text.
- Do not rebuild a transcript reader — `cc_transcripts` already fixes the `**`-zero-dir double
  count, `resumeFromRunId` multi-count, missing-parent-jsonl, `isSidechain` subagent turns, and the
  Windows path-translation trap. Reintroducing any yields plausible-but-wrong counts.

## 5. Tasks, in order

Ordering rationale: lock the invocation set (1) before extracting episodes (2) before cross-episode
synthesis (3) before the report (4) and the improvements derived from it (5). Each step consumes the
prior's output; reordering wastes it.

1. **Detect invocations.** Build a detector (on `cc_transcripts`) that finds every session with a
   real `/repo-status` invocation (command-name marker and/or the token in a genuine user turn),
   deduped to sessions. Report the count and the session list.
2. **Extract each episode.** For every invocation, capture the *episode*: the invocation turn; the
   agent's information-gathering tool calls (the `git`/`gh`/Bash `tool_use` blocks it ran to build
   the report) with counts and a sense of duplication; the report text returned to the user; and all
   subsequent **related** turns — follow-up questions, clarifications the agent asked, corrections,
   and whether the user acted on the recommended next command. Delegate per-session extraction to
   parallel `model: "haiku"` subagents.
3. **Synthesize across episodes.** Identify: patterns of use (when/why invoked, which repos);
   recurring issues; areas of confusion or miscommunication (report said X, user expected Y);
   repetitive or excessive tool use (same `git`/`gh` call repeated, info gathered then re-gathered,
   avoidable round-trips); token inefficiencies (oversized output, re-reading state the harness
   already had); and anything else useful to improving the skill. Adversarially verify each
   candidate finding (a skeptic subagent that tries to refute it) before it enters the report.
4. **Write the report:** `docs/reports/repo-status-usage-analysis.md` — ranked, `[V]`/`[?]`-tagged
   findings, each tied to concrete sessions/turns (session id + quoted evidence), with the measured
   frequency. **Log, don't hide, any coverage cap** (sessions you couldn't parse, ambiguous
   episodes).
5. **Propose + apply meaningful improvements** to `sub-skills/inspect/SKILL.md` (and
   `commands/repo-status.md` / the parent Output Contract where a finding points there), each change
   justified by a report finding. Likely levers, pending what the data shows: collapse redundant
   state-gathering into fewer deterministic commands; make the output contract pre-empt the most
   common follow-up questions; tighten the next-command recommendation logic; trim token-heavy
   output. Keep it read-only. Add/adjust any eval the skill carries so a regression is caught.

## 6. Finishing

Rebase onto `origin/dev`, pass `pwsh ./scripts/validate.ps1`, open a PR to `dev` (via `/ship` or the
`github` skill) referencing this prompt and the report. The PR **is** the proposal — nothing is
"meaningfully changed" until a human merges it. Sync local to `origin/dev` after merge. **Do not
delete this prompt file.** Report and stop.

## 7. Delegation

`model: "haiku"` subagents (explicit), dispatched in parallel in one message, for the mechanical
fan-out: per-session episode extraction, counting duplicate tool calls, token tallies, pulling the
report text out of a transcript. Keep in the main loop (Opus): the detector's correctness, the
cross-episode synthesis, the adversarial verification, and the improvement design — these need
judgement, not throughput.

## 8. Delegation logging

Use
`~/.claude/skills/session-manager/sub-skills/delegation-ledger/scripts/log-delegation-outcome.ps1`:
log each escalation/redo/dropped subagent task with `-Category`/`-FailureMode`/`-Evidence` and
`-HandoffId rs-usage-26a`; **once at the end before finishing**, log per-category totals
(`-Outcome ok -Dispatches N`) tagged `-PromptPath <this file>` and `-Branch
feat/repo-status-usage-analysis`. If you dispatched nothing, declare `-NoDelegation`.

## 9. Reporting

Terse; single numbered decision list per turn; verify counts before stating them; one-line
corrections to any earlier wrong claim.

## 10. Model note

Pinned **Opus** — reasoning-heavy: correct invocation detection against the `is_injected` trap,
cross-episode pattern synthesis, adversarial verification, and designing skill changes that improve
experience without breaking the read-only contract. Delegate the mechanical mining to
`model: "haiku"` subagents rather than underpowering the main loop.
