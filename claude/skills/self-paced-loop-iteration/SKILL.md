---
name: self-paced-loop-iteration
description: Use when draining a multi-task backlog, feature plan, or long-running operational workload via Claude Code's /loop command without a fixed interval — each iteration completes one bounded unit of work, verifies it, commits, and schedules the next wakeup based on what just happened rather than wall-clock time.
status: active
version: 2026-07-05
---

# Self-Paced Loop Iteration

## When to use

For any multi-iteration workload — a phased feature plan, a backlog of 5-50 small tasks, an operational batch job (poster backfill, retry sweep, cleanup pass), or an open-ended exploration where scope emerges as you go. Use `/loop` with **no fixed interval** so the model self-paces: each iteration's duration is determined by the work, not the clock, which matters when some tasks take 30 minutes and others take 2 hours.

## Method

1. **Re-establish ground truth at the start of every iteration** — never rely on memory from a prior turn. Re-read the source-of-truth progress document (plan file, `docs/REMAINING_WORK.md`, backlog), and confirm git state via `git fetch` + reflog rather than assuming the last iteration's summary is still accurate.
2. **Scope each iteration to exactly one shippable unit** — one task, one enhancement, one phase item. Do not bundle multiple backlog rows into a single iteration even if they look related.
3. **If the task is a code change, apply TDD inside the iteration**: write the failing test (RED), implement minimally (GREEN), refactor. Then run the full gate suite before committing — backend (`ruff`, `mypy --strict`, `pytest`) and/or frontend (`tsc`, lint, `vitest`) as applicable. All gates must be green before commit.
4. **Run code review inside the iteration**, not deferred to the end: invoke a code-reviewer pass on touched files, address CRITICAL/HIGH findings immediately, apply tactical fixes for MEDIUM. Route through a security-review pass specifically when the touched files involve auth, admin surfaces, or backup/restore logic.
5. **Enforce size discipline per iteration**: warn at 400 changed LOC, hard-cap at 800 — split the unit further if it's larger, rather than shipping an oversized change.
6. **Sync the progress document in the same commit/PR as the work**, not as a follow-up: mark the completed item with a checkmark and a `YYYY-MM-DD` + one-line resolution note. Documentation drift between the plan and reality is the most common way loop-driven work becomes untrustworthy.
7. **Merge with a regular merge commit** (not squash) to preserve full per-iteration history on the integration branch, when doing feature-branch-per-iteration work.
8. **Decide the next wakeup dynamically**: emit the iteration's result into context, use it to pick the next task (the next backlog row, the next phase-gated item now that its predecessor is done, or a newly-discovered task from exploration), and schedule a short wakeup rather than a fixed timer.
9. **For fresh-context iterations**, dispatch each iteration as a fresh subagent that receives full codebase/task context via the prompt but not the accumulated conversation history of prior iterations — this avoids context-window exhaustion on long-running loops while still allowing parallel-friendly tracking.
10. **Checkpoint with the user before large or risky phases** (e.g., a multi-hour re-skin, an irreversible migration) even mid-loop — a self-paced loop is not a license to skip approval gates on big-ticket phases.

## Gotchas

- The pattern must tolerate multi-session resumption: if a loop is interrupted or restarted, it should re-read the progress doc and re-confirm `origin/<integration-branch>` state rather than resuming from stale in-context assumptions — it's safe to pause after any merged unit.
- Phase gating matters: don't start a downstream task before its documented predecessor phase is actually complete, even if the loop "has time."
- Self-pacing is about cadence, not about skipping verification — every iteration still needs its own gate-to-green and review step; the fixed-interval-vs-self-paced choice only affects when the next iteration starts.

## Diagram

[View diagram](diagram.html)
