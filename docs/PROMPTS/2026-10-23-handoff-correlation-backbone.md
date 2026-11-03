---
handoff_id: d1-corr-26a
title: Handoff correlation backbone — handoff_id + handoffs.jsonl registry (forward + tagged backfill)
model: sonnet
base_branch: dev
branch: feat/handoff-correlation-backbone
repo: C:\development\ai-agent-kit
---

# Handoff — Build the handoff↔child correlation backbone (D1)

You are a fresh session. Everything below is the task; treat it as your first message. Your
worktree and branch **already exist** (`feat/handoff-correlation-backbone`, created from `dev`) —
work there, do **not** create another worktree.

## 1. Orientation

- Read `C:\development\ai-agent-kit\CLAUDE.md` and the repo's `AGENTS.md`, and follow them exactly.
  Do not restate their conventions here or invent new ones.
- The skill you are editing is **`session-manager`** (the live bundle). `session-handoff` is a
  deprecated alias — ignore it. [V] Verified: `claude/skills/session-handoff/SKILL.md` has
  `status: deprecated`, `requires: [session-manager]`.
- All edits are to the **archive source** under `claude/skills/session-manager/…` in your worktree.
  Deploying the edited skill to `~/.claude/skills/` is a **separate** `/push-skill` step and is
  **out of scope** for this PR.

## 2. Hard constraints (first and unmissable)

You are likely running under `--dangerously-skip-permissions`. This section is the only guardrail.

- **Never modify or delete** existing transcript files under `~/.claude/projects/`. All transcript
  access is **read-only**. The backfill reads them; it never writes there.
- **Never modify or delete** existing records in `~/.claude/telemetry/delegation-outcomes.jsonl`
  or any existing `docs/PROMPTS/*.md` file. Backfill only **appends** to the *new*
  `~/.claude/telemetry/handoffs.jsonl`.
- **Never fabricate** a parent/child session id, a handoff_id, or a confidence score. If a historical
  handoff cannot be joined to a child with high confidence, write the row with `child_sid: null` and
  a low confidence — never guess an id.
- Work only inside the provided worktree. Do not touch the primary checkout's branch.
- If any task appears to require one of the above, **stop and report** rather than improvise.

## 3. State already established (do not redo)

- [V] Live handoff sub-skill: `claude/skills/session-manager/sub-skills/handoff/SKILL.md`
  (required-sections rubric for the prompt it writes is in that file; read it before editing).
- [V] The launcher `claude/skills/session-manager/sub-skills/dispatch/scripts/launch-claude-session.ps1`
  makes the child's **first message** the exact string (lines ~189–191):
  `Read and follow the instructions in the file at <absolute PromptPath> exactly. Its full contents
  are your task; treat them as your first message.` — this exact opener is the high-precision join
  key between a prompt file and the child session it launched.
- [V] The parent session id is available to the launcher as `$env:CLAUDE_CODE_SESSION_ID` **before**
  it is cleared for the child (see `$script:InheritedSessionVariables` in the launcher). Capture it
  there to populate the registry's `parent_sid`.
- [V] Worktree creator: `…/dispatch/scripts/new-task-worktree.ps1`.
- [V] Delegation ledger: `~/.claude/telemetry/delegation-outcomes.jsonl` — 235 records; fields:
  `timestamp, category, model, outcome, dispatches, failure_mode, escalated_to, evidence, task,
  repo, branch, prompt`. 223/235 have a non-empty `prompt`. Writer:
  `…/sub-skills/delegation-ledger/scripts/log-delegation-outcome.ps1`; reporter: `delegation-report.ps1`.
- [V] Read-only transcript library (stdlib-only, Python 3.10+):
  `claude/skills/session-manager/sub-skills/transcripts/scripts/cc_transcripts.py` — import it, do
  not re-derive discovery/iteration/counting. Its docstring lists every gotcha; `is_injected`,
  `iter_messages(role="user", skip_sidechains=True)`, and `first_text` are what you need for the join.
- [V] Corpus: 96 handoff-style prompt files in main checkouts; 71 (73%) appear in ≥1 transcript —
  this is the backfill supply ceiling.
- [?] The *precision* of the launcher-opener join has not been measured, only its 73% supply. It is
  expected to be high **because the opener is an exact, launcher-generated string**, but you must
  measure it (sample + manual spot-check) and record the number in the PR.

## 4. What we tried / dead ends

- **Opener join by title heading / filename slug → 0% match.** The authoring session's first probe
  matched the prompt's first `#` heading (and the de-dated slug) against session openers and got
  zero joins, for two reasons: (a) a window-asymmetry bug (prompts and child sessions filtered by the
  *same* 90-day mtime cutoff, so July children fell outside the window while their recently-touched
  prompt files stayed in), and (b) the child opener does **not** contain the prompt's title — it
  contains the **launcher's fixed "Read and follow the instructions in the file at <path>" string**.
  **Do not join on title/slug. Join on the launcher opener containing the prompt's absolute path or
  basename, keyed to that exact launcher phrasing.**
- A loose basename grep across all transcripts also matches the *authoring* session and *subagent*
  transcripts, not just the child. Disambiguate: the child is the session whose **first non-injected
  user turn** is the launcher opener — not any session that merely mentions the basename.

## 5. Tasks, in order

Ordering rationale: the registry **schema** must be fixed before anything writes to it (2 before
3/4/5); the live writer (3) and backfill (5) must agree on one schema; docs/tests (6/7) describe
what already exists. Do the schema first or every later task churns.

1. **Define the `handoffs.jsonl` registry schema.** New reference doc
   `claude/skills/session-manager/sub-skills/handoff/references/handoff-registry.md`. Fields (one
   JSON object per line, append-only, at `~/.claude/telemetry/handoffs.jsonl`):
   `handoff_id, ts, parent_sid, child_sid, prompt (absolute path), branch, repo, source
   ("live"|"forensic"), confidence (1.0 for live; 0.0–1.0 for forensic)`. Document that `child_sid`
   is `null` until the child's first turn fills it (live) or until a confident forensic match exists.
2. **Edit the handoff sub-skill** (`handoff/SKILL.md`): (a) add `handoff_id` to the required prompt
   **frontmatter** the skill writes; (b) add a short **Correlation** required section instructing the
   generated prompt to tell the child to, on its first turn, record the handoff via the registry
   (and carry `handoff_id` into any `log-delegation-outcome.ps1` call). Keep the existing structure
   and tone; add, don't rewrite.
3. **Thread `handoff_id` through dispatch.** In `launch-claude-session.ps1`: accept/generate a
   `handoff_id`, capture `parent_sid` from `$env:CLAUDE_CODE_SESSION_ID` before the env is cleared,
   and **append a live registry row** (`source: live, confidence: 1.0, child_sid: null`) at launch.
   Update `new-task-worktree.ps1` only if it needs to pass the id through. Keep the "short pointer,
   never inline the prompt" behaviour intact (it exists to dodge Defender/AMSI — see the launcher
   header).
4. **Extend the ledger** with `handoff_id`: add the field to `log-delegation-outcome.ps1` (optional
   param, written when present) and surface it in `delegation-report.ps1`. Do not break existing
   callers or rewrite existing records.
5. **Build + run the backfill.** A new script (import `cc_transcripts`) that, for each main-checkout
   `docs/PROMPTS/*.md`, finds the child whose first non-injected user turn is the launcher opener
   referencing that prompt, and **appends** a `source: forensic` row with a confidence derived from
   match strength (exact-path opener = high; basename-only = lower; multiple candidates = lower +
   keep best, log the ambiguity). Report: candidates, joined, precision spot-check, confidence
   distribution. Idempotent (re-running must not duplicate rows — key on `(prompt, child_sid)`).
6. **Docs:** update the registry reference and add a short note to
   `…/sub-skills/transcripts/references/transcript-data-model.md` pointing at the registry + the
   title-match dead end above.
7. **Tests:** follow the repo's test + `scripts/validate.ps1` conventions. Add coverage for the
   registry writer (live row shape) and the backfill join (a fixture transcript with a launcher
   opener joins; a basename-only mention does not become a high-confidence row).

## 6. Finishing

Rebase onto latest `origin/dev`, ensure `pwsh ./scripts/validate.ps1` passes, then open a PR to
`dev` (use `/ship` or the `github` skill). Reference this prompt. Sync local to `origin/dev` after
merge. **Do not delete this prompt file** — that gate needs a human. Report and stop.

## 7. Delegation

Spawn subagents with `model: "haiku"` passed explicitly for mechanical work; dispatch independent
lookups in parallel in one message:
- grepping `~/.claude/projects` for launcher-opener signatures / basenames (read-only);
- extracting current param lists from the three PowerShell scripts;
- counting registry rows / confidence buckets after a backfill run.
Keep in the main loop: the registry schema, the backfill disambiguation logic (precision matters —
these rows become persisted "ground truth"), and the ledger/launcher edits.

## 8. Delegation logging

Record outcomes with
`~/.claude/skills/session-manager/sub-skills/delegation-ledger/scripts/log-delegation-outcome.ps1`:
on every escalation/redo/dropped subagent task, log `-Category`, a `-FailureMode`, one line of
`-Evidence`; **once at the end before reporting finished**, log per-category totals
(`-Outcome ok -Dispatches N`) each tagged `-PromptPath <this file>` and `-Branch
feat/handoff-correlation-backbone`. If you dispatched nothing, declare `-NoDelegation`.

## 9. Reporting

Terse. End each turn with a single numbered list of items needing a decision. Verify counts before
stating them. Correct any earlier wrong claim in one line.

## 10. Model note

Pinned **Sonnet** — implementation-heavy and well-specified (PowerShell + markdown edits, one
careful forensic join). If the backfill disambiguation turns subtle (many ambiguous multi-candidate
prompts), `/model` up to Opus for that step, then back down.
