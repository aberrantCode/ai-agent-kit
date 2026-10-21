---
name: sm-checkpoint
description: >
  Sub-skill of `session-manager`. Durable session state that survives context resets,
  compaction, /loop iterations and new sessions: one state-file convention (current state,
  decisions, tiered summaries), one step per turn with recorded evidence, and a copy-ready resume
  prompt. Use for "/checkpoint-session", "save progress", "checkpoint this", "update session
  state", "what's the current state?", "end session", "resume from last session", "make this
  resumable", "this task spans multiple sessions", "context preservation", "resume from the state
  file", or when a large task is run across many turns or `/loop` iterations.
---

# Checkpoint — durable session state

**Principle: write state down at natural breakpoints so any session — this one after `/clear`,
or a fresh one with no history — resumes from the file, not from memory.**

The state file is the single source of truth for "what's done and what's next". Conversation
history is not. Loop *composition* (writing a `/loop` or iteration prompt) is not this
sub-skill's job — that is `project-manager`. This sub-skill owns the state those loops read and
write.

## The convention (one layout, every project)

```
_project_specs/session/
  current-state.md     # live state — the file every turn reads first and updates last
  decisions.md         # append-only decision log; never delete entries
  code-landmarks.md    # optional: non-obvious code locations worth not re-discovering
  archive/
    YYYY-MM-DD[-topic].md   # one per finished session or milestone
```

This is the layout `base` and `/initialize-project` already scaffold, so existing projects need
no migration.

**Task-specific step lists.** When the work is driven by a list that already lives elsewhere — a
`project-manager` task file in `docs/tasks/active/`, a checklist the prompt names, or a
`docs/progress.md` — that file is the step list. Do not copy it. `current-state.md` links to it
under **Active Task** and records only what that file does not: status, context, evidence
pointers, and the resume prompt. One state file per session; never two competing ones.

### `current-state.md`

```markdown
<!-- CHECKPOINT RULES (session-manager checkpoint):
     quick update after each step; full checkpoint after a decision or ~20 tool calls;
     archive at session end, milestone, or context shift. -->
# Current Session State
*Last updated: YYYY-MM-DD HH:MM*

## Active Task
One sentence. Link the driving step list if one exists (task file / checklist path).

## Status
- Phase: exploring | planning | implementing | testing | debugging
- Progress: X of Y steps
- Blocking: none | <blocker>

## Steps
- [x] Step 1 — evidence: PR #123 / commit abc1234 / `pytest` 41 passed
- [ ] Step 2   ← NEXT
- [ ] Step 3

## Context to Preserve
Facts the next session would otherwise have to re-derive (constraints, chosen approaches,
gotchas hit). Link `decisions.md` entries instead of restating them.

## Files Being Modified
| File | Status | Notes |

## Resume Prompt
(see "End of turn" below — replace this block each checkpoint)
```

### `decisions.md`

Append one entry per architectural or implementation decision:
`## [YYYY-MM-DD] <title>` → **Decision**, **Context**, **Options considered**, **Choice +
reasoning**, **Trade-offs**, **References** (paths). Never edit or delete past entries; supersede
with a new one.

## Start of turn (every turn, before planning anything)

1. **Read the state file first.** `_project_specs/session/current-state.md` (and the step list it
   links), then `_project_specs/todos/active.md` if the project has one, then recent
   `decisions.md` entries if the next step depends on them.
2. **Verify the premise.** A prompt can be stale. Before committing effort, check:
   - the project's source of truth (`docs/features/`, `docs/plans/`) for whether the work is
     already planned or done;
   - `git log` (including `git log -S <term>`) for commits that already shipped it;
   - in-flight branches and PRs;
   - the repo's `CLAUDE.md` for its real conventions.
   Reconcile state file and git: the state file says what *should* be done; git is the
   tie-breaker for whether it actually landed.
3. **Handle leftovers.** Uncommitted working-tree state from a prior break is resolved
   (committed, stashed with a unique tag, or reported) before new work starts.
4. **Announce** "Resuming from: <last state>, next: <step>" and, if the step is ambiguous or
   risky, confirm before proceeding.

## During the turn

- **Advance exactly one step.** One step, one evidence entry. Batching steps defeats the audit
  trail.
- **Respect workflow constraints.** Feature branches only, never direct commits to `dev`/`main`;
  preserve any queue of pending operations.
- **Record evidence inline** when the step completes: PR number, commit hash, command output
  excerpt, API response, or gate result. A checkbox without evidence is a claim, not a record.
- **Mark completion with an unambiguous sentinel** (`[x]` + evidence, or the task file's
  `## Completion` block) so a fresh agent can parse "what's next" mechanically.

## Tiered checkpoints

| After… | Tier | Action |
|---|---|---|
| any small step / todo | 1 — quick update | Update Status, Steps, and Resume Prompt in `current-state.md` |
| a decision, a finished feature or significant change, ~20 tool calls, or switching codebase area | 2 — full checkpoint | Tier 1 + rewrite Context and Files tables + append to `decisions.md` |
| end of session, a milestone, a context shift, or ~50 tool calls / context feels heavy | 3 — archive | Tier 2 + write `archive/YYYY-MM-DD[-topic].md` + trim `current-state.md` + update `code-landmarks.md` if new patterns appeared |

Self-check after every task: decision made → log it; more than ~10 tool calls → full checkpoint;
feature done → archive; ending or switching context → archive + resume prompt; otherwise →
quick update.

### What to keep vs archive

Keep in `current-state.md`: the current task and next steps, the active file list, blockers,
and decisions that affect current work. Move to the archive, keeping only the conclusion:
exploration paths that didn't work, debugging traces (keep the root cause), verbose errors, and
research notes (keep the recommendation).

### Archive entry

`# Session Archive: <date> — <topic>` with: **Summary** (one paragraph), **Completed** (steps or
todos, with evidence), **Decisions** (links into `decisions.md`), **Code changes** (file → change
table), **Tests added**, **Dead ends** (what was tried and why it failed), **Carried forward**
(open items, now in the step list).

## End of turn: the resume prompt

Every checkpointed turn ends by replacing **Resume Prompt** in `current-state.md` and, when the
turn is the last in this session, printing it verbatim as the final output. It contains:

- what is done (with evidence pointers) and the specific next step;
- the verification discipline the next step needs (tests, CI gates, manual checks);
- recurring failure modes this session hit, as explicit warnings;
- the exact workflow to repeat: worktree setup, branch naming, PR target, merge sequence,
  cleanup — so the next session runs the same playbook instead of inventing variance;
- a self-perpetuating shape: the next session can follow it without re-reading project history.

For a full standalone prompt in a new session or another CLI, hand off instead:
[`handoff`](../handoff/SKILL.md) copy mode prints one, and chain mode builds the self-similar
version for a migration split across many sessions.

**`/loop` and unattended runs:** pause around ~200k tokens of context, write a Tier 3 checkpoint,
and emit the resume prompt under a `RESUME PROMPT` heading as the literal last output so the
operator can `/clear` and paste it with zero state loss. In an interactive session, do not
start a handoff yourself — offer one in one sentence and let the operator decide.

## Gotchas

- Acting on a prompt's premise without checking the source of truth, git log, and state file —
  the leading cause of redoing shipped work.
- Trusting git log alone, or the state file alone. Reconcile both.
- Stale state files are worse than none. If you touched the work, you update the file.
- Overly verbose state — keep `current-state.md` scannable; archive the detail.
- Skipping the checkpoint after a decision — the reason is the first thing lost.
- Running past heavy context without a resume prompt loses everything not yet written down.
- Forgetting to carry recurring failure modes into the resume prompt — the next session repeats
  them.
- Ignoring leftover uncommitted state from a prior break can silently clobber or duplicate work.
