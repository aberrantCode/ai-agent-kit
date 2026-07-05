---
name: recursive-batch-handoff
description: Use when a large migration, refactor, or long-running batch operation must be split across many sessions or iterations — each batch runs a discovery command to find what's left, executes one coherent chunk, and emits a self-similar handoff prompt so the next session (or run) continues without a central master plan.
status: active
version: 2026-07-05
---

# Recursive Batch Handoff

## When to use
- Migrating or refactoring a large number of homogeneous targets (dozens to hundreds of files, e.g. ~200 scripts) that cannot fit in one session or one PR.
- Long-running batch operations on a live system (ffmpeg jobs, DB migrations, staged deployments) that must proceed in controlled increments across many iterations.
- Multi-phase infrastructure remediation or feature work spanning many sessions, where maintaining a centralized master plan would go stale, block progress, or cause state drift.

## Method
1. Define a discovery command (grep/query/count) that is the single source of truth for "what's left." Re-run it at the start of every session — never trust a stale summary or narrative of remaining scope.
2. From the discovery output, select the next batch using a coherent grouping heuristic: pick the next largest prefix group, subdirectory, or name-glob. Cap batch size (e.g. ~20-30 files) so the resulting PR stays under an ~800-line diff limit.
3. Execute the batch with judgment-per-file analysis, not blind sed/find-replace — files in the same "coherent group" can still differ enough to need individual handling. Apply normal TDD discipline while implementing.
4. Commit the batch as one PR/change.
5. Update a running progress log (e.g. `docs/progress.md`), prepending a new entry per batch. Prepending keeps the most recent state at the top so the whole sequence can be surveyed at a glance and any stalled batch spotted immediately.
6. Log any recurring failure mode discovered in this batch at the top of the handoff (e.g., "already-fixed-in-code stale backlog rows") so the next session doesn't waste time rediscovering it.
7. Emit a self-similar handoff prompt — the same template, updated only with current state — for the next session or iteration to run verbatim. It must embed: the discovery command, the batch-selection heuristic, the execution recipe, and an explicit instruction to repeat this whole process and re-emit itself at the end.
8. For live/queued batch operations rather than file refactors (ffmpeg, DB migrations, deployments): each iteration first verifies the prior batch is draining (its count is falling) before increasing batch size, and only increases size once the prior batch has fully cleared — this prevents orphaning a giant queue across a service restart.

## Gotchas
- Skipping the discovery command and trusting a prior session's written summary instead lets scope drift out of sync with reality — always re-run discovery fresh.
- Blind scripted replacement (sed, mass find/replace) across a "coherent" batch causes regressions because files that look similar often differ in ways that require per-file judgment.
- Omitting the recurring-failure-mode note at the top of the handoff means every future session rediscovers the same gotcha independently (e.g., stale backlog rows for work that was already fixed in code but never removed from tracking).
- Batches larger than the size/line cap (roughly 20-30 files, 800 lines) block review and reintroduce the exact master-plan bottleneck this pattern exists to avoid.
- For live/queued operations, increasing batch size before confirming the previous batch fully drained risks orphaning in-flight work (e.g., a service restart abandoning a queue that was still processing).
- The pattern has scaled to ~200 files across 15+ sessions without state drift, but only because the progress log and discovery command remained the sole source of truth — don't also run a separate master plan that can fall out of sync with them.
- Multi-phase feature/infra chains benefit from the same recursive copy-ready-prompt structure with explicit recursion clauses and decision gates, even when the "batch" is a follow-on task rather than a file group.
