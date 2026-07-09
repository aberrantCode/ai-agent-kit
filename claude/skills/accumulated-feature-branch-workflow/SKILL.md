---
name: accumulated-feature-branch-workflow
description: Use when implementing multiple related enhancements, or a large feature that must be split across risk boundaries, and you need to decide branch/PR structure. Covers accumulating related work on one shared branch with atomic commits per enhancement, splitting risky multi-PR features along risk seams, and safely handling a branch that has both committed and dirty (uncommitted) work when shipping.
status: active
version: 2026-07-05
---

# Accumulated Feature Branch Workflow

## When to use

- Implementing several related, independent enhancements that belong together conceptually (e.g., a bundle of optimizer improvements).
- Splitting one large feature across multiple PRs where different parts carry different risk (reversible CPU-only change vs. change touching shared ingress/auth vs. a risky GPU/infra change).
- Running a ship-to-dev workflow on a branch that has a mix of already-committed work and uncommitted (dirty) files.

## Method

1. **Accumulate related enhancements on a single shared feature branch** (e.g., `feat/optimizer-enhancements-bundle`) rather than opening a PR per enhancement. Commit one atomic, conventional commit per enhancement as you go. Open a single combined PR only once all enhancements in the bundle are complete and passing tests. This groups genuinely related work for review while preserving per-enhancement commit history for future `git blame`/bisect.

2. **For a large feature that must span multiple PRs, split along risk seams, not arbitrary size.** Example seams: PR-1 = a CPU-only, fully reversible change; PR-2 = a change touching shared ingress/auth substrate; PR-3 = a GPU-risky change. Give each PR its own verification gate (e.g., two consecutive Ansible runs reporting `changed=0`). Never merge a PR without live-verify evidence attached — call out any missing gate explicitly in the reconciliation/summary rather than silently skipping it.

3. **When a feature is orchestrated across sessions**, use an iterate-tasks style pattern: advance exactly one PR per invocation, and let the next-session prompt carry forward the necessary context — don't let parent-session context bloat by trying to hold the whole multi-PR feature in one conversation.

4. **Enforce strict PR-only discipline for large multi-PR features**, rebasing on merge to avoid phantom-endpoint artifacts (stale references to code that no longer exists after a rebase). Give each sub-task its own contract doc and feature branch, and order dependencies correctly — typically backend-first when a frontend piece will consume the backend's new endpoints. Update plan status atomically within chore PRs, and archive completed task files with closure narratives per the repo's backlog-workflow rules.

5. **Before shipping, detect a mixed branch state early (Step 0).** Use `git status` and `git rev-list` to separately count commits-ahead-of-dev and dirty (uncommitted) files. If the branch has both pre-committed work and dirty files, explicitly ask the user whether to: (a) ship only the already-committed work and leave the dirty files behind, or (b) fold the dirty files into a new commit and ship both. Never resolve this ambiguity by guessing.

6. **In "pre-committed + dirty" mode, diff the committed set against the dirty set to confirm they're actually related** before staging anything together. Never blindly `git add --all` — flag throwaway files (e.g., a `mockup.html` dropped at repo root) as candidates for exclusion rather than silently including them. Stash any pre-existing, unrelated WIP (e.g., unrelated docs changes) separately so it is restored untouched after the PR merges, instead of getting swept into the feature commit.

## Gotchas

- A "bundle" branch only works when the enhancements are genuinely independent and reviewable together — don't use it to hide an oversized, poorly-scoped feature.
- Skipping the live-verify gate on any PR in a risk-seam split (even the "safe" reversible one) breaks the whole point of the split — the safety guarantee is per-PR, not just at the end.
- `git add --all` on a mixed dirty/committed branch is the most common way unrelated scratch files (mockups, local notes) end up shipped — always inspect dirty files individually first.
- Rebase-on-merge for multi-PR features prevents phantom endpoints, but only if every dependent PR actually rebases after each merge — a stale branch will silently reference deleted/renamed code.

## Diagram

[View diagram](diagram.html)
