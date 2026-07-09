---
name: project-plan-task-reconciliation
description: Use when reconciling a completed worker task against the project plan and backlog — appending a parseable completion block, updating plan status and archives, verifying subagent claims against actual git/repo state, and auditing for features that shipped without a formal plan/task trail.
status: active
version: 2026-07-05
---

# Project Plan / Task Reconciliation

## When to use

In any project-management framework where feature specs define scope, plans break features into phased tasks, and active task files capture in-progress work — after a worker/subagent finishes a task, before advancing to the next one, or when auditing overall project status.

## Method

1. **Append a parseable `## Completion` block to the task file** as soon as a worker finishes, containing: `Status:` (`success` / `failure` / `blocked`), `Summary`, `Artifacts`, `Tests`, `Notes`. This is the contract the reconciliation step reads — don't skip fields even if they seem obvious from context.
2. **Verify the claims before trusting them.** When a subagent's completion block or hand-off prompt claims something ("already merged", "endpoint returns 200"), check it against actual git/repo state — `git status`, `git log`, a live curl — before propagating the claim forward. A branch reported as merged but actually left in a CONFLICTING state is a real failure mode; catch it here, not three sessions later.
3. **On `Status: success` with passing tests**: mark the corresponding plan task `done`, move the completed task file to the archive, and update the plan frontmatter (`failures` count, `last_updated`).
4. **On `Status: failure`**: diagnose the root cause, increment the plan's failure count, and insert corrective tasks *before* the failed one in the sequence — then re-run from the corrective task, not from scratch.
5. **On `Status: blocked`**: do not archive; surface the blocker in `FOCUS.md` (or equivalent next-action doc) so the next session picks it up first instead of silently skipping it.
6. **Refresh the "what's next" doc every reconciliation** — next action plus current blockers — so a fresh session or fresh subagent can resume without re-deriving state from scratch.
7. **Respect the dependency graph.** Use each feature's `depends_on` field to sequence work — never start a downstream feature's tasks before its declared dependencies show `done`.
8. **Reconcile plan/bookkeeping changes via their own PR**, never direct-to-main-integration-branch — this forces the same review discipline on backlog bookkeeping as on code.
9. **When a backlog row's target file is itself under a freeze protocol** (e.g. the row lives in a directory frozen for structural changes), split into two separate PRs: one for the substantive change (migration script, lint rule, SoT mirror updates), one purely for the backlog-closure edit (narrative move to archive, formatting validation, removal from the quick-view table). This avoids racing the freeze and keeps it intact.
10. **Track durable cross-cutting discoveries** (facts that will matter to future tasks, not just this one) in a project-wide index doc, separate from the task-local completion block.
11. **Periodically audit for pipeline-bypass**: cross-reference the feature list against the task-count matrix. A feature that shipped with zero recorded tasks bypassed the formal pipeline entirely — this is process debt, not a delivery gap, and should be flagged for either retroactive documentation (write a summary plan after the fact) or a prospective fix (enforce the pipeline for all new features going forward). Distinguish this explicitly from "unimplemented with a plan," which is real remaining work, not process debt.

## Gotchas

- A subagent's self-reported hand-off prompt is a claim, not a fact — always cross-check against git/repo state before re-emitting it to the next session.
- Architectural drift can creep into hand-off prompts too (e.g. a subagent proposing an approach the plan explicitly rejected) — catch and downgrade this during reconciliation, not after the next session has already acted on it.
- "Implemented but missing a plan" and "unimplemented with a plan" look similar in a status report but require completely different responses — conflating them misdirects remediation effort.
- Freeze protocols on backlog directories are easy to violate accidentally by bundling the closure edit into the substance PR — always check whether the target directory is frozen before deciding PR boundaries.

## Diagram

[View diagram](diagram.html)
