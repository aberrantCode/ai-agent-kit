---
handoff_id: d2-tuner-26a
title: Build the self-improving handoff-tuner sub-skill, and run it once (analysis + handoff enhancements)
model: opus
base_branch: dev
branch: feat/handoff-tuner-subskill
repo: C:\development\ai-agent-kit
depends_on: d1-corr-26a
---

# Handoff — Build the self-improving `handoff-tuner` sub-skill (D2), then run it once

You are a fresh session. Everything below is the task. Your worktree and branch
(`feat/handoff-tuner-subskill`, from `dev`) **already exist** — work there; do not create another.

**This depends on D1 (`feat/handoff-correlation-backbone`) having merged to `dev`.** Task 0 verifies
it; if it has not merged, stop and report.

## 1. Orientation

- Read `C:\development\ai-agent-kit\CLAUDE.md` and `AGENTS.md` and follow them exactly.
- You are adding a new sub-skill to the **`session-manager`** bundle and then executing it once. The
  one-time execution *is* the handoff-efficiency analysis the owner asked for; its output is a
  findings report plus a reviewed PR of enhancements to the `handoff` sub-skill.

## 2. Hard constraints (first and unmissable)

Running under `--dangerously-skip-permissions`; this section is the only guardrail.

- Transcript and registry reads are **read-only**. Never write under `~/.claude/projects/`; never
  mutate existing records in `delegation-outcomes.jsonl` or `handoffs.jsonl`.
- **No autonomous self-rewriting.** "Self-improvement" here means the sub-skill, on each run, emits a
  **versioned rubric/metrics update and a tuning-log entry as proposed diffs that land through a
  normal reviewed PR**. It must **never** rewrite its own SKILL.md control flow, or apply its own
  changes outside the worktree/PR, without human review.
- Enhancements to the `handoff/SKILL.md` must **preserve its existing structure and intent** — add
  or sharpen rules, justify each with evidence from the report; do not gut it.
- Never state a churn/token metric you did not compute; tag every claim `[V]`/`[?]`. A wrong number
  here poisons every future tuning cycle.
- If a task seems to require violating the above, stop and ask.

## 3. State already established (do not redo)

- [V] Live bundle: `claude/skills/session-manager/`. New sub-skill goes at
  `claude/skills/session-manager/sub-skills/handoff-tuner/`.
- [V] Read-only transcript library: `…/sub-skills/transcripts/scripts/cc_transcripts.py` — import it;
  do **not** re-derive discovery/iteration/counting. Prior art to mirror:
  `…/sub-skills/audit/scripts/mine_dispatches.py` (meta.json dispatch mining, both counting bugs
  already fixed).
- [V] Correlation source (from D1): `~/.claude/telemetry/handoffs.jsonl` registry (fields
  `handoff_id, ts, parent_sid, child_sid, prompt, branch, repo, source, confidence`) +
  `delegation-outcomes.jsonl` now carrying `handoff_id`. Schema doc:
  `…/sub-skills/handoff/references/handoff-registry.md`.
- [V] The handoff prompt's **required-sections rubric** is defined in `…/sub-skills/handoff/SKILL.md`
  (Orientation; Hard constraints; State w/ `[V]`/`[?]`; What we tried / dead ends; Tasks in order;
  Finishing; Delegation; Delegation logging; Polling; Reporting; Model note). That rubric is the
  basis of the STATIC score.
- [V] Child-session join: a child's first non-injected user turn is the launcher opener
  `Read and follow the instructions in the file at <path> …`. Registry-first; fall back to this
  forensic join for anything not in the registry.
- [V] Corpus: 48 project dirs / 267 jsonl / ~174 MB; ~96 main-checkout prompt files; 235 ledger
  records (57 branches). Enough to analyze.
- [?] Exact join precision — read it from the D1 PR's reported number; re-verify if stale.

## 4. What we tried / dead ends

- Title/slug opener join = 0% (window-asymmetry bug + wrong signal). Use registry first, launcher
  opener as fallback. See the D1 prompt's dead-ends section for the full story.
- Do not rebuild a transcript reader — `cc_transcripts` already solves the `**`-zero-dir double
  count, the `resumeFromRunId` multi-count, missing-parent-jsonl, and the Windows path-translation
  traps. Reintroducing any of these yields plausible-but-wrong counts.

## 5. Tasks, in order

Ordering rationale: scaffold + mining (1–2) before measurement (3–4) before the first run (6) before
enhancements derived from it (7) before self-tuning on that run's evidence (8). Each step consumes
the prior's output; reordering wastes it.

0. **Verify D1 landed.** Confirm `~/.claude/telemetry/handoffs.jsonl` exists with the documented
   schema and `dev` contains the D1 merge. If not, stop and report — do not proceed on a missing
   backbone.
1. **Scaffold the sub-skill.** `handoff-tuner/SKILL.md` describing the loop:
   **mine → measure (static + dynamic) → report → propose+apply handoff enhancements → self-tune
   (versioned rubric/metrics + tuning-log)**. Add companion command(s) if the bundle's convention
   wants them (e.g. `/tune-handoff`). Register in manifest per repo convention.
2. **Mining script** (`scripts/`, on `cc_transcripts`): enumerate handoffs registry-first, forensic
   fallback; resolve each to (prompt file, child session, ledger rows, token usage).
3. **Static rubric scorer** (`scripts/` + versioned `references/rubric.v1.md` / `rubric.json`): score
   each prompt against the required-sections rubric — missing/empty sections, untagged state claims,
   bare `scripts/…` paths (should be absolute), missing "already exists" worktree warning, absent
   dead-ends section, model-note presence.
4. **Dynamic churn/token measurement** (`scripts/`): per joined child session — early-turn
   re-derivation of facts the prompt already stated `[V]` (wasted work), duplicate-worktree creation,
   user-questions an unattended session could not answer, escalations/redos/dropped tasks from the
   ledger, and first-turn-context + total token deltas. Each metric tagged `[V]`/`[?]`.
5. **`references/report-template.md`** + **`evals/evals.json`** (trigger-phrase + behavior evals for
   the sub-skill, mirroring the handoff/audit eval style).
6. **First run (validate → expand).** Phase A: last ~90 days, main checkouts — confirm join ≥ ~70%
   reliable and metrics sane. Phase B: expand to the full corpus incl. worktrees. Write
   `docs/reports/handoff-efficiency-analysis.md`: ranked, evidence-tagged findings on token
   efficiency, cost, and new-session churn, each tied to concrete prompts/sessions. **Log, don't hide,
   any coverage cap** (unjoined prompts, pruned transcripts).
7. **Handoff enhancements (the deliverable).** From the report, propose + apply edits to
   `handoff/SKILL.md` and its `evals/evals.json` — each change justified by a report finding (e.g. a
   recurring untagged-count failure → a sharper `[V]`/`[?]` rule + a regression eval). This is the
   "Report + ready PR" the owner approved.
8. **Self-tune.** Write `rubric.v2` (or bump `rubric.json` version) with threshold/metric refinements
   justified by what discriminated signal from noise this run, and append a newest-on-top entry to
   `references/tuning-log.md` recording: metrics used, findings, what changed in `handoff/SKILL.md`,
   and what changed in the tuner's own rubric/metrics — with rationale. This is the recursive step,
   and it is a **reviewed diff**, not an autonomous edit.

## 6. Finishing

Rebase onto `origin/dev`, pass `pwsh ./scripts/validate.ps1`. Open PR(s) to `dev` — keep the
sub-skill addition and the handoff-enhancements cohesive (one scope: handoff self-tuning). Reference
this prompt and the report. Sync local to `origin/dev` after merge. **Do not delete this prompt
file.** Report and stop.

## 7. Delegation

`model: "haiku"` subagents (explicit) for mechanical fan-out, dispatched in parallel: per-repo
transcript mining, per-prompt static scoring passes, ledger extraction, token tallies. Keep in the
main loop (Opus): the metric/rubric **design**, the enhancement **synthesis** (which findings become
which rule changes), and any adversarial judgement of whether a finding is real. Spawn an adversarial
verifier subagent to refute each top finding before it reaches the report.

## 8. Delegation logging

Use
`~/.claude/skills/session-manager/sub-skills/delegation-ledger/scripts/log-delegation-outcome.ps1`:
log each escalation/redo/dropped task with `-Category`/`-FailureMode`/`-Evidence` and `-HandoffId
d2-tuner-26a`; **once at the end before finishing**, log per-category totals (`-Outcome ok
-Dispatches N`) tagged `-PromptPath <this file>` and `-Branch feat/handoff-tuner-subskill`. The tuner
eating its own dogfood: its first run's delegation outcomes are themselves data for the next run.

## 9. Reporting

Terse; single numbered decision list per turn; verify counts; one-line corrections.

## 10. Model note

Pinned **Opus** — this is reasoning-heavy meta-work: designing discriminating metrics, synthesizing
evidence into skill-rule changes, and judging a recursive self-modification boundary. Delegate the
mechanical mining/scoring to `model: "haiku"` subagents rather than underpowering the main loop.
