---
name: parallel-subagent-fanout
description: Use when a task splits into independent lenses or disjoint-file subtasks — multi-layer system audits, large documentation backfills (10+ specs), batch state-transition decisions, or code/security review of a feature branch — to dispatch multiple subagents concurrently and reconcile their results into one verdict.
status: active
version: 2026-07-05
---

# Parallel Subagent Fanout

## When to use

- Analyzing a complex multi-layer system where each layer needs distinct domain expertise (e.g., node inventory, model research, topology, domain practices, extension patterns for a ComfyUI-style pipeline).
- Backfilling large documentation sets (10+ specs) that can be grounded independently in source code.
- Making many similar state-transition or classification decisions in a batch, where most cases are unambiguous but some need human judgment.
- Reviewing a feature branch: running code-reviewer and security-reviewer concurrently against the same diff.
- Deploying a feature with multiple independent subtasks that touch disjoint files.
- Auditing a spec/implementation across several axes at once (e.g., code correctness, documentation consistency, visual fidelity) instead of one agent doing all axes sequentially.

## Method

1. **Partition the work by lens, not by chunk.** Give each subagent a distinct domain angle (one node type, one doc topic, one review discipline, one audit axis) rather than splitting an undifferentiated pile of work evenly — this is what produces fresh, specialized findings instead of N copies of the same shallow pass.
2. **Re-baseline before dispatching.** Sync to the latest `origin/dev` (or equivalent) immediately before fanning out. Stale local state is the single biggest cause of subagents duplicating work that already landed elsewhere.
3. **Brief each subagent with everything it needs and nothing it can't use.** Subagents run blind to each other and cannot see images — if the task depends on screenshots or diagrams, translate them into precise written summaries (control inventories, layout descriptions) before handing them off.
4. **Scope diffs precisely.** When dispatching reviewers against a branch, specify the diff target explicitly (e.g., `origin/dev...HEAD`) so agents evaluate only the delta, not pre-existing code. Treat concurrent code-reviewer + security-reviewer dispatch as mandatory for any PR that adds admin, auth, or mutation surfaces.
5. **Respect the dependency graph.** True fanout only applies to disjoint-file work. When two subtasks touch the same file or role, sequence them (PR-A merges before PR-B starts) instead of parallelizing — parallel edits to shared surfaces cause conflicts, not speedups.
6. **Collect and cross-validate, don't just concatenate.** Verify every claimed issue against the actual source of truth (the real JSON/config/type, not an assumption). Drop any claim that can't be traced to a specific node, value, or line.
7. **Reconcile disagreements by root cause.** When two subagents disagree (e.g., one flags a missing endpoint as CRITICAL while another assumes it exists), trace back to why — often the answer is a timing issue (the endpoint exists on an unmerged branch) rather than a real conflict.
8. **Apply a consensus threshold for batch decisions.** When subagents are independently judging many similar items, auto-apply verdicts with ~80%+ agreement and surface only the ambiguous minority for user judgment.
9. **Own the integrative synthesis yourself.** The main session (not a subagent) merges findings, makes any call requiring visual judgment, and produces the final unified report — subagents are used for scoped generation, not for that synthesis.
10. **Verify cross-artifact consistency afterward.** For documentation backfills or multi-file writes, do a final pass checking frontmatter uniformity and cross-file consistency once all subagents finish.

## Gotchas

- Skipping the re-baseline step is the most common failure mode — stale state makes subagents "discover" and redo work that already exists.
- A subagent reporting "this work already exists" is a valid and valuable result, not a wasted dispatch — it surfaces deduplication problems the dispatcher would otherwise miss.
- Never hand a subagent raw claims to trust blindly; unverified findings that don't trace to a concrete source value should be dropped, not merged in.
- Fanning out edits to files/roles that overlap between subtasks causes merge conflicts — check the dependency graph before assuming everything is parallelizable.
- Subagents can't see screenshots or other images; omitting a written translation of visual context silently degrades their output.
