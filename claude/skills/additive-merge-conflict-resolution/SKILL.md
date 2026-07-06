---
name: additive-merge-conflict-resolution
description: Use when a rebase or merge reports conflicts on a file where both branches only appended or inserted new content (append-only logs, registries, holding-pen documents) rather than editing the same lines. Recognizes the conflict as a false signal and resolves it as a union-keep-both operation instead of a real semantic merge.
status: active
version: 2026-07-05
---

# Additive Merge Conflict Resolution

## When to use

- Two feature branches both extend the same file with new, independent entries at the same anchor point(s) — e.g., both register a new scanner/probe/handler at the same insertion point in a registry file.
- A `git stash pop` or rebase conflicts on an append-only document (progress logs, learnings intake files, backlog notes) where each side added a distinct, valid entry.
- Any file whose edit pattern is strictly additive (new blocks appended or inserted), never in-place modification of existing content.

## Method

1. **Diagnose before resolving: is this conflict additive or substantive?** Read both sides of the conflict. If each side inserts brand-new, logically independent content near the same anchor point (not editing the same existing line), this is a false-positive conflict — git's line-based diff can't recognize that adjacent insertions are independent, even though the correct resolution is obvious to a human.

2. **Resolve by keeping both sides — never drop one to "win."** Remove the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) and retain both hunks. For registry-style code (e.g., both branches add setup calls at the same two anchor points), preserve each hunk's original internal order.

3. **For append-only logs** (e.g., `docs/progress.md`, `docs/learnings/_intake.md`), keep both appended blocks, separated by a blank line, and order them by recency — newest entry first (reverse-chronological) — matching the file's established convention. This exact pattern repeats constantly in append-only logs; once recognized, resolve it in seconds rather than treating it as a complex merge.

4. **For stash-pop conflicts on a holding-pen/intake document**, recognize that both the stashed version and the current HEAD version represent distinct, valid entries. Keep both, drop only your own session's stash reference once merged, and leave the file in the state a curator would expect (i.e., don't leave your session's scratch artifacts behind).

5. **Verify the union is correct after resolving.** Run the test suite (for code registries) or visually confirm both entries are present and well-formed (for logs/docs) before committing the resolution.

6. **Document the merge logic in the commit message** — state explicitly that this was an additive/false-positive conflict and both sides were kept, so future readers (and `git blame`/bisect) understand the resolution wasn't arbitrary.

## Gotchas

- Don't reach for a merge tool's "ours"/"theirs" shortcut on additive conflicts — both are correct; picking one silently loses data.
- Order matters for logs with a chronological convention — if the file is newest-first, appending the older entry at the top instead of below the newer one silently breaks the convention even though no content was lost.
- This pattern recurs constantly on shared append-only files (backlog/progress/intake docs) touched by multiple concurrent sessions or PRs — recognizing the shape quickly (rather than re-deriving it each time) is the actual point of this skill.
- Always re-run tests after resolving registry-style additive conflicts — "both blocks are present" doesn't guarantee the combined registration is still syntactically/semantically valid (e.g., duplicate keys).
