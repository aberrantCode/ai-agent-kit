---
name: iterate-tasks
description: >
  Self-perpetuating, subagent-driven iteration of the project pipeline. One invocation:
  (1) merges any pending PR left by the previous turn, (2) dispatches the recap-recommended
  next action as a fresh subagent so each unit of work gets a clean context, then
  (3) emits a copy-ready prompt for the action that comes AFTER the one just completed.
  Designed to pair with /loop for unattended runs and to minimize parent-context growth.
---

# Iterate Tasks

Run one atomic iteration of the project pipeline: optionally merge a pending PR, dispatch
the next recommended action as a fresh subagent, then emit the next-next prompt so the
user (or `/loop`) can immediately keep going. Each unit of real work runs in its own
subagent context — the parent session only sees returned summaries, which keeps context
growth bounded across many iterations.

## Operating Principle

This command is the recursion-clause primitive expressed as a skill. It assumes the
previous assistant turn (the recap) is the source of truth for "what's next." It does
NOT re-derive a next action from project state when the recap already named one.

Each invocation handles exactly **one** atomic unit: at most one PR merge and one
dispatched subagent. The output is always either:

1. A fenced markdown code block containing the next-session prompt (so the next
   invocation can pick up immediately), OR
2. An explicit terminal message: "No eligible next action — pipeline is idle."

Never end the turn ambiguously. Either there is a next prompt, or the loop is done.

## Required Inputs

None. The command derives everything from session state and the repo:

- Previous assistant turn (read from your own conversation history)
- `docs/workflow/FOCUS.md` and `docs/workflow/INDEX.md` (fallback signals)
- `references/scripts/pm-next.ps1` (deterministic next-task helper if present)
- `gh pr list` (only when a pending PR is suspected)

## Step 1 — Read the recap for the recommended next action

Mirror `project-manager:continue-new-session` Step 1 exactly. Scan your own most recent
assistant turn for:

- An explicit "next step" / "next" / "follow-up" recommendation
- A trailing bullet or "Next: …" line
- A fenced "Next-session prompt:" block (the contract this command's subagents emit)

Capture:

1. **Action verb + object** — what to do next
2. **Identifier(s)** — feature slug, plan path, CAP-ID, task ID, branch name
3. **Follow-on guidance** — TDD, security-first, worktree, etc.
4. **Pending PR signal** — any PR URL, `gh pr` reference, or "open PR" phrasing left
   from the previous iteration

If the previous turn had no recap-recommended action, use the **Fallback** section
from `project-manager:continue-new-session` (FOCUS.md → `pm-next.ps1` → highest-priority
unblocked todo). Prefix the action with `(derived from {source})`.

## Step 2 — Handle any pending PR

Pending-PR detection signals, in priority order:

1. The recap explicitly names a PR URL or PR number
2. `gh pr list --search "author:@me state:open" --json number,url,headRefName,mergeable,mergeStateStatus,statusCheckRollup`
   returns an open PR whose `headRefName` matches a feature branch the previous turn
   was working on

If no pending PR: skip to Step 3.

If a pending PR exists, classify it:

| Condition | Action |
|---|---|
| Mergeable, checks green, approvals satisfied | Eligible for merge (proceed below) |
| Checks failing or pending | Surface the failing checks via `gh pr checks`; do NOT merge; treat as the next action ("fix CI on PR #N") |
| Has conflicts | Surface the conflict; do NOT merge; treat as the next action ("rebase PR #N onto dev") |
| Awaiting required review | Surface; stop the loop; require user decision |

**Before merging an eligible PR**, use `AskUserQuestion` to confirm. This is a
destructive action under the global git-workflow rules — one-time skill invocation
does not authorize unattended merges. Offer the choices:

- "Merge now via /ship-to-dev" (Recommended)
- "Skip merge, just continue with the next action"
- "Stop iteration here"

If confirmed: invoke the global `ship-to-dev` skill rather than calling `gh pr merge`
directly. `/ship-to-dev` enforces rebase-onto-dev, runs CI checks, performs the merge,
deletes the feature branch, and syncs local `dev`. Composing it preserves every gate
in the user's git-workflow rules.

After merge: pull latest `dev` and continue.

## Step 3 — Resolve the next action into a subagent brief

Convert the action captured in Step 1 into a self-contained brief suitable for a fresh
subagent that has zero conversation history. The brief MUST include:

- **Goal** — the action verb + object, restated imperatively
- **Pointers** — file paths to feature spec, plan, active task (or task to create), and
  workflow focus. Reference-style only; do not embed full file contents.
- **Constraints** — the project-manager skill conventions (one active task at a time,
  `## Completion` sentinel required, no silent spec edits, runner discovery via
  `docs/workflow/runners.md`)
- **Workflow** — if `.claude/rules/agent-concurrency.md` exists in the project, instruct
  the subagent to set up a worktree per that file. Otherwise work on the current branch.
- **PR handling** — when the subagent opens a PR, it stops there. The merge happens in
  the NEXT iteration of `/iterate-tasks` (via Step 2). Do not instruct the subagent
  to self-merge.
- **RECURSION CLAUSE** — append this exact instruction verbatim:

  > After completing your task and (when applicable) opening a PR against `dev`,
  > end your final message with a fenced markdown code block under the heading
  > `## Next-session prompt`. The block must contain a self-contained prompt for the
  > NEXT action that comes after this one — same shape as the prompt you received:
  > Goal / Pointers / Constraints / Workflow / PR handling / RECURSION CLAUSE
  > (including this clause itself, so the chain continues). Pick the next action from
  > `docs/tasks/backlog.md`, `docs/workflow/FOCUS.md`, or `pm-next.ps1` output —
  > whichever the project uses. If multiple plausible candidates exist, list them in
  > the prompt and instruct the next session to use `AskUserQuestion` to pick.

This contract is what makes the loop self-perpetuating without parent context growth.

## Step 4 — Dispatch as a fresh subagent

Use the `Agent` tool with one subagent. Pick `subagent_type` from the recap-supplied
role hint and the existing project-manager role mapping:

| Role hint | subagent_type |
|---|---|
| `architecture`, `design`, `planning` | `planner` |
| `feature`, `implementation`, `api` | `tdd-guide` |
| `review`, `quality` | `code-reviewer` |
| `security` | `security-reviewer` |
| `build`, `types`, `errors` | `build-error-resolver` |
| `e2e`, `testing` | `e2e-runner` |
| `docs`, `documentation` | `doc-updater` |
| `cleanup`, `refactor` | `refactor-cleaner` |
| anything else / multi-role | `general-purpose` |

Most `/iterate-tasks` invocations span multiple roles (implement + commit + push + PR)
and should default to `general-purpose`.

Do NOT set `isolation: "worktree"` on the `Agent` call. Let the subagent set up its own
worktree per the project's `agent-concurrency.md` script — that's the project's
convention, not this skill's to override.

Use the default foreground dispatch (not `run_in_background`). The parent must wait for
the subagent to finish before Step 5.

## Step 5 — Reconcile after the subagent returns

Run `project-manager:update-tasks` synchronously. It is idempotent: it parses any
`## Completion` sentinel the subagent wrote into `docs/tasks/active/`, archives the
task, updates plan status, and reports anything that needs operator attention.

If `update-tasks` reports failures, malformed sentinels, or blocked work, surface
those in the parent output and use them to shape the next-next prompt rather than
papering over them.

## Step 6 — Emit the next-next prompt

Look for a `## Next-session prompt` fenced block in the subagent's returned summary.

**If present**: re-emit that block verbatim as this command's final output, inside its
own fenced markdown code block so the user can copy it as one unit.

**If absent**: derive a substitute using the `/continue-new-session` fallback chain
(FOCUS.md → `pm-next.ps1` → highest-priority unblocked todo) and emit it in the same
shape as the contract in Step 3. Prefix the recommended-action line with
`(derived from {source})` so the next session understands the provenance.

**If nothing eligible remains** (all plans complete, no backlog, no FOCUS next-action):
do NOT emit a prompt block. Print this exact terminal message:

> No eligible next action — pipeline is idle. Run `/review-tasks` for a project
> snapshot, `/add-feature` to capture a new spec, or `/init-features` if specs are
> missing.

## Step 7 — Offer to continue

After emitting the next prompt (or the terminal message), use `AskUserQuestion` to ask:

- "Run `/iterate-tasks` again now" (Recommended for interactive use)
- "Stop here — I'll paste the prompt into a fresh session"
- "Pair with `/loop` for unattended cadence"

Document `/loop /iterate-tasks` as the canonical pairing for unattended runs.

## Constraints

- **One subagent per invocation.** Parallel dispatch belongs to
  `superpowers:dispatching-parallel-agents`, not here.
- **Never merge without `AskUserQuestion` confirmation.** Per global
  `git-workflow.md`: a one-time skill invocation does not authorize ongoing
  destructive operations.
- **Never push directly to `dev` or `main`.** All merges go through `/ship-to-dev`
  (feature → dev) or `/release-to-main` (dev → main).
- **Context clearing is the user's responsibility.** This command minimizes parent
  context growth by dispatching subagents, but cannot wipe the parent. For long
  unattended runs, recommend the user pair `/iterate-tasks` with `/clear` between
  invocations, or use the emit-and-paste workflow with a fresh session each time.
- **The next-next prompt is the contract.** Every invocation MUST end with either
  a copy-ready next prompt or the explicit "pipeline is idle" terminal message.
  Never end the turn ambiguously.
- **Do not modify feature specs.** Spec authority rule from the parent skill applies.
- **Do not skip verification.** The Verification Gate from `/continue-tasks` applies
  to any code-changing subagent dispatched here.

## Output Contract

- Exactly one fenced markdown code block at the end containing the next-session
  prompt (unless the terminal "pipeline is idle" message is printed instead).
- A short summary of what this iteration did: PR merged (if any), subagent role
  and outcome, reconciliation result.
- Never claim a file exists when it doesn't. Never embed full spec/plan/task
  contents in the emitted prompt — only file paths and short excerpts.

## Related Commands

- `/continue-tasks` — the synchronous orchestration loop a dispatched subagent
  may invoke when its action is "run one full pipeline turn"
- `/continue-new-session` — the recap-reading primitive this command reuses for
  Steps 1 and 6 fallbacks
- `/update-tasks` — invoked in Step 5 for reconciliation
- `/ship-to-dev` — invoked in Step 2 for PR merge
- `/loop` — pair with `/iterate-tasks` for unattended cadence:
  `/loop /iterate-tasks` lets the model self-pace iterations
