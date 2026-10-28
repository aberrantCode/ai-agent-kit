---
name: sm-retire
description: >
  Sub-skill of `session-manager`. Post-merge cleanup gate for a dispatched session: five checks
  (branch merged into origin base, local base synced to origin, tests pass, human confirmed via
  -Confirmed, delegation tally logged for the prompt) — reports every check and deletes nothing
  unless all pass. Then retires the prompt file, worktree and branch. Use for "/retire-session",
  "clean up that handoff", "retire the session", "remove the worktree now the PR merged".
---

# retire

Formerly Step 7 ("Retire the session, only once it has earned it") of the `session-handoff`
handoff skill. It is the last step of a dispatched session's life, after
[`dispatch`](../dispatch/SKILL.md) launched it and it reported finished.

## When to retire

When the spawned session reports finished, run the gate rather than cleaning up by hand. Scripts
live in `scripts/` beside this file.

```powershell
pwsh -NoProfile -File <skill-dir>/scripts/complete-task-session.ps1 `
    -RepoPath 'C:\repo' -PromptPath 'C:\repo\docs\PROMPTS\2026-07-21-thing.md' `
    -Branch 'refactor/reset-move-queue' -Confirmed
```

Run it first WITHOUT `-Confirmed`: the mechanical checks still all report and nothing is deleted.

## The five gates

It refuses to delete anything unless all five hold:

1. the branch is an ancestor of `origin/<base>` (`-BaseBranch`, default `dev`) — actually merged, not just PR'd;
2. local `<base>` matches `origin/<base>` exactly — no unpushed or unpulled commits;
3. the repo's tests pass (auto-detected, or `-TestCommand`, or `-SkipTests` with the reason
   printed so a skip is never silent);
4. `-Confirmed` is present;
5. the delegation ledger holds an `ok` tally correlated to this session — matched by the prompt
   filename, the branch, or a `-Task` tagged with the prompt slug — or `-NoDelegation` is passed to
   declare, out loud, that nothing was delegated.

## `-Confirmed` is human-only

The fourth gate cannot be automated, and it is deliberately not a formality. A merged branch with
green tests can still be the wrong solution — that is exactly what a human review catches and what
no repo state can tell you. So **an agent may pass `-Confirmed` only after the user has actually
looked at the work and said it is right.** Asking them is the point of the gate; inferring it
defeats it. If they have not responded yet, run without the flag.

## The delegation gate

The end-of-session tally is the step a tired session drops, and once retirement has run nothing is
left to notice. Tying deletion to a correlated tally means the session must either log its dispatch
totals (tagged with `-PromptPath`) using the
[`delegation-ledger`](../delegation-ledger/SKILL.md) script `log-delegation-outcome.ps1` — the gate
locates it at `../../delegation-ledger/scripts/` relative to its own directory and names that path
in its failure message — or say `-NoDelegation` explicitly. `-LedgerPath` overrides the default
`~/.claude/telemetry/delegation-outcomes.jsonl`.

## Options

- `-SkipTests` — record the test gate as skipped (tests already run this session); the reason prints.
- `-NoDelegation` — satisfy gate 5 because nothing was delegated; printed, never silent.
- `-KeepWorktree` — delete the prompt but leave the worktree and branch.

## What gets deleted

Only when all five pass: the prompt file, the worktree (removed unforced, so it refuses on
uncommitted changes rather than discarding them), and the local branch. On any failure it prints
the per-check verdict and exits non-zero, leaving everything intact — a failed gate is always
recoverable by fixing the cause and re-running.
