---
name: state-file-driven-multi-turn-resumption
description: Use when a task spans multiple sessions, context resets, or `/loop` iterations and progress must survive them — a durable state file (e.g. docs/progress.md) becomes the single source of truth, each turn advances one step, records evidence, and ends with a copy-ready resume prompt.
status: active
version: 2026-07-05
---

# State-File-Driven Multi-Turn Resumption

## When to use
- A task is too large for one context window, or is explicitly run via `/loop` / recursive re-invocation across fresh sessions.
- Work must survive session breaks, `/clear`, or context resets without re-deriving progress from chat history.
- A prompt asks you to "continue," "resume," "pick the next unit of work," or "complete all remaining work" on a repo you may not have full history for.
- Multi-session feature work needs atomic, CI-verified turns, each advancing to a named next action.

## Method
1. **Read the state file first, before planning anything.** Use a durable, repo-committed file (e.g. `docs/progress.md`, a checklist, or deployment logs under `evidence/`) as the single source of truth — not conversation history, not assumptions from the prompt. Trust this file over `git log` alone for "what's already done."
2. **Verify the premise before committing effort.** A prompt can be stale (e.g. describing initial-brief work when the project is actually on phase 3). Before starting:
   - Check the project SoT (`docs/features/`, `docs/plans/`) for whether the requested work is already listed/planned.
   - Check `git log` (including `git log -S <term>`) for commits that already shipped it.
   - Check for an in-flight branch or PR.
   - Check `progress.md` / the state file for prior work notes.
   - Read `CLAUDE.md` to learn the repo's actual conventions (backlog-driven vs. project-manager vs. freestyle) — don't assume.
   This 5-minute diagnosis prevents redoing completed work and pays for itself many times over.
3. **Advance exactly one step per turn.** Do not batch multiple state-file steps in a single turn. After completing the step, record evidence inline in the file: PR number, command output, API response excerpt, applied commit hash, or verification-gate result. Checkboxes become an auditable, forensic record, not just a to-do list.
4. **Respect workflow constraints while advancing.** Route edits through feature branches, never direct commits to `dev`/`main`. Preserve any queue of pending operations. Handle uncommitted working-tree state left over from a prior session break before starting new work.
5. **Use explicit completion sentinels.** Mark a step done with an unambiguous sentinel (not just prose) so the next turn — possibly a fresh agent — can parse "what's next" mechanically.
6. **End every turn with a copy-ready handoff/resume prompt**, emitted verbatim as the last output, containing:
   - What's done, what's next (the specific next candidate item).
   - Verification discipline required (tests, CI gates, manual checks).
   - Recurring failure modes this session surfaced, as explicit warnings (e.g. "verify-before-promote: N stale backlog rows found; run `git log -S` before starting any concrete-file item").
   - The exact workflow to repeat: worktree setup, branch naming, PR target, merge sequence, cleanup — so the next session runs the same playbook instead of inventing variance.
   - Structure it as a self-perpetuating template: the next session can fork from it without re-reading full project context.
7. **For `/loop` automation**, pause proactively around ~200k tokens of context and emit a "RESUME PROMPT" block as the literal last output, so the user can `/clear` and paste it into a fresh session with zero state loss.

## Gotchas
- Acting on a prompt's stated premise without checking the SoT/git log/progress file first — this causes redundant work on already-shipped features.
- Trusting `git log` alone instead of the state file (or vice versa) — reconcile both; the state file should reflect reality, but git is the tie-breaker for "did this actually land."
- Batching multiple checklist steps per turn defeats the auditability purpose — one step, one evidence entry.
- Committing directly to `dev`/`main` instead of routing through a feature branch breaks workflow compliance and audit trail.
- Letting context run past ~200k tokens without emitting a resume prompt loses state that isn't yet written to the file.
- Omitting evidence (PR#, output, commit hash) turns checkboxes into unverifiable claims — future turns can't distinguish "done" from "claimed done."
- Forgetting to surface recurring failure modes in the handoff prompt causes the same mistake to repeat across sessions.
- Ignoring leftover uncommitted working-tree state from a prior session break can silently clobber or duplicate work.
