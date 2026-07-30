---
name: work-resume-plan-nextstep
description: Sub-skill of `work-resume`. What to offer when nothing is mid-flight — the next APPROVED action. Gated on `pm-profile.yml` in the main checkout root: if present, read the project-manager task/plan state; if absent, fall back to the most actionable git signal. Read this when every recent session is completed or the operator picks "None".
---

# Plan next-step

Reached from `work-resume` Step 5 when there is nothing to *resume* — every recent
session is `completed`, or the operator declined the shortlist. The job now is to
offer the next **sanctioned** action, not to invent work. "Everything's shipped,
here's the next planned task" is a complete answer; so is "nothing is queued."

## The gate — pm-profile.yml decides the source

Check for `pm-profile.yml` in the **main checkout root** (the repo passed to
`work-resume`, not a worktree):

```bash
test -f "$REPO_ROOT/pm-profile.yml" && echo project-manager || echo git-signal
```

The main root matters because the project-manager layout (`docs/tasks/`,
`docs/plans/`, `docs/STATUS.md`) lives on the primary checkout; worktrees carry
feature branches, not the canonical PM state.

## Path A — project-manager repo (pm-profile.yml present)

This repo runs the `project-manager` workflow. Read its state rather than
guessing, in this order:

1. `docs/tasks/active/*.md` — any in-flight task files. An active task with an
   unfinished `## Completion` sentinel is the next thing to pick up; surface it
   and point the operator at `/continue-tasks` to drive it.
2. `docs/STATUS.md` — the orchestrator's snapshot of where the SDLC stands
   (next todo task, backlog).
3. `docs/plans/*.md` — approved plans whose tasks aren't all archived; the next
   unstarted step of the most advanced plan is the candidate.

Offer the single next approved action and name the command that executes it
(usually `/continue-tasks` for the full loop, or `/review-tasks` for a read-only
snapshot). Do not edit plan or task files here — plans are orchestrator-owned;
this sub-skill only *reads* to make a recommendation.

## Path B — no pm-profile.yml (git-signal fallback)

No project-manager state to consult, so recommend from git — the most actionable
signal, in priority order:

1. **Open PR awaiting action** (`gh pr list`) — review or merge it.
2. **Local branch with unpushed commits** and no PR — open the PR.
3. **Feature branch ahead of `dev`** not yet merged — finish/ship it.
4. **Behind the remote** (`git status -sb` shows behind) — pull to get current.
5. **A `dev`/`main` that is clean and synced** — genuinely nothing queued; say so
   and stop. Optionally point at any `TODO`/`FIXME` the operator has left, but do
   not manufacture a task.

## Framing the offer

Whichever path, present it the same baked-in way `work-resume` uses elsewhere —
recommend one action and pose it via `AskUserQuestion` so the operator can accept
with a click:

```
Nothing to resume — everything recent is complete.
Next approved action: <the one action> (source: <PM task | git signal>)
[AskUserQuestion] Proceed?
  • Do it now (Recommended)
  • Show me the details first
  • No, I'm done
```

Never pad the list to look busy. If the honest answer is "you're all caught up,"
that is the answer.
