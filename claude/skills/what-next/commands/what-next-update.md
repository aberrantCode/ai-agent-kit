---
description: Force a refresh of docs/what-next.md — re-scan the repo, reconcile the backlog against the current code (mark orphaned tasks as stale), and show a short diff of what changed before surfacing the new top-three. Use when the repo has shifted significantly since the last /what-next run.
---

Use the `what-next` skill in its Update Flow mode.

Arguments passed to this command (if any): $ARGUMENTS

Always re-run repo analysis. Do not trust existing fingerprints. Reconcile the backlog against
current file locations — any task whose referenced file no longer exists is marked `stale` (never
auto-closed; the user decides). After reconciliation, print a one-paragraph diff summary, then
proceed to prioritise + present top three via AskUserQuestion.
