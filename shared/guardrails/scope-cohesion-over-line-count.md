---
name: scope-cohesion-over-line-count
description: Scope cohesion, not a line count, is the PR/file gate — never block, stop, or ask on size alone; split only when a change bundles unrelated concerns
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: git-workflow
source: mined from ~6 repos of session transcripts, 2026-08-09
status: active
version: 2026-08-09
---

## Scope, not size, is the gate

There is **no hard line-count cap** on a PR or a file. A change of any size is fine as long
as it is *cohesive* — one scope, all edits related, effort proportionate to the goal. Report
the diff line count in the summary for visibility, but **never block, stop, or raise a
decision item on line count alone.**

Split a PR **only** when it bundles **unrelated** concerns (two features, or a feature plus
an incidental refactor) — never merely because it is large.

When weighing whether a large diff is really "too much to review," count **reviewable** lines.
A diff that is mostly tests (added under the coverage rule), generated artifacts (diagrams,
dashboards, lockfiles, snapshots), byte-identical cross-vendor mirrors, or whitespace/reflow
adds no review burden and is **never** grounds for a split or a stop on its own.

> **Why:** a line cap is only ever a proxy for *review tractability*. Mining prior sessions
> showed every "over the cap" stop that was waved through was overage of exactly those
> zero-review-burden kinds — the cap interrupted work without protecting anything.

**Retires:** any prior "800-line hard cap / warn at 400" rule. If a repo's guardrail file
still cites a hard line cap, treat it as superseded by this one.
