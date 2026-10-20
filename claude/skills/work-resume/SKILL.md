---
name: work-resume
category: Foundations & Workflow
description: Use when the operator wants to pick up where they left off — "what was I working on", "continue my last session", "resume work in this repo", "did I finish that", "what's next here", "I forgot where I left off". Scans this repo's recent Claude Code sessions (including its git worktrees) newest-first, reads the last turn of each to reconstruct what was expected next, reconciles that against local/remote git state and approved plans, and proposes the single best thing to pick up — either stopping for approval or auto-resuming. Trigger this whenever the operator returns to a repo and asks where things stand or what to do next, even if they don't say the word "resume".
---

# Work Resume

## What this does

You (or the operator) walked away mid-stream and came back. The question is
always the same: **what was in flight, did it finish, and what's the next move?**
Answering it means reading recent conversation history for *this* repo, figuring
out what each session expected to happen next, and checking that expectation
against what git actually shows on disk and on the remote.

## Core principle — the funnel

A committed extractor (`references/resume-scan.py`) reduces the repo's transcript
corpus (dozens of files, hundreds of MB) to a few KB of **per-session digest**:
the initiating goal, the last operator turn, the last assistant turn, and
mechanical hints (did the session end mid-tool-call, which files were being
edited, which branch/worktree). Only that digest enters context.

**The script extracts; you classify.** Deciding whether a session is *finished*,
*finished-with-an-optional-next-step*, *interrupted-mid-implementation*, or
*waiting-on-the-operator* is a reading task — the script never guesses it. It
hands you bounded evidence; you make the call. This is the same discipline the
sibling `analyze-conversations` skill uses.

## The pipeline

```
scan (script)  →  classify each session (transcript-forensics)
              →  reconcile top candidates with git (git-state-reconcile)
              →  decide next action  →  propose (stop) OR auto-resume
                                     └─ if all complete → plan-nextstep
```

## Step 1 — scan

Run the extractor from the repo you want to resume. It finds this repo's sessions
across **all** its worktrees — in-repo `.worktrees/`, sibling `<repo>-wt/`, and
shared containers like `C:\development\github-repos-wt\` — by correlating on git
identity (each worktree's git-common-dir resolves to the main checkout), not on
directory names. So a session that ran in a worktree under a different path is
still found. See `sub-skills/transcript-forensics/SKILL.md` for the correlation
reasoning and its one unrecoverable edge (a pruned worktree in a shared container
whose directory is already deleted).

```bash
python references/resume-scan.py --repo . --format json
```

`--window` controls how far back to look (default `smart`):

| value | meaning |
|---|---|
| `smart` (default) | newest-first, last 21 days, clamped to 6–15 sessions |
| `14d` | sessions touched in the last 14 days |
| `10s` | the 10 most-recent sessions by mtime |
| `2026-07-01` | every session on/after that date |
| `all` | the whole corpus |

The JSON is `{meta, sessions[]}`, `sessions` newest-first. Each session carries
`first_prompt`, `last_prompt`, `last_assistant_tail`, `ended_mid_action`,
`last_tool`, `recent_edit_files` (absolute paths), `branch`, `worktree_path`.

## Step 2 — classify each session (newest → oldest)

Read `sub-skills/transcript-forensics/SKILL.md` for the classification rubric and
its edge cases. In short: walk the digests newest-first and label each session's
**resumption state** from its last assistant turn (and the initiating goal when
the last turn alone is ambiguous):

- **completed** — work done, no next action promised. Skip it.
- **completed-with-optional-next** — done, but the agent recommended an optional
  follow-up. That follow-up is a candidate.
- **interrupted-mid-implementation** — `ended_mid_action` is true and the tail
  shows work in progress; the session died mid-edit. High-value candidate.
- **awaiting-operator** — the agent asked a question or proposed a plan and
  stopped. The next move is the operator's answer.

Stop early once you have a clear top candidate — you rarely need to read past the
first completed thread. **Do not** offer a session whose `recent_edit_files` point
into a *different* repo; that session was launched here but did its work
elsewhere (see transcript-forensics for why this happens).

## Step 3 — reconcile the top candidate(s) with git

A last turn that says "done and pushed" is a *claim*, not proof. Read
`sub-skills/git-state-reconcile/SKILL.md` and confirm the expected-next against
reality: are there uncommitted edits matching `recent_edit_files`? Unpushed
commits? Is the branch merged into `dev` on the remote? The reconciliation turns
"the agent said X" into "X is actually true / half-true / stale."

The common cases the reconciliation resolves:

- Tail says "committed & pushed" **and** `git` agrees → genuinely complete.
- Tail says "done" but there are matching uncommitted edits → the session ended
  before it finished; resume by finishing/committing.
- `ended_mid_action` with dirty working tree → clearest resume: continue the edit.
- Tail proposed a next step and the tree is clean → offer the proposed step.

## Step 4 — present the shortlist and let the operator pick

Build a **ranked shortlist** of the recent sessions, newest-first, each collapsed
to a single line: a short label (derived from the goal), the resumption state,
and the reconciled one-line status. Reconcile git (Step 3) for at least the
candidate(s) you'd recommend — the completed ones only need enough of a check to
confirm they really are done.

Then **pose the choice with `AskUserQuestion`** (this is baked in — the skill
prompts rather than dumping prose the operator has to parse). Recommend the
strongest resumable thread as the first option, and always include an escape
option that routes to plan-nextstep:

```
Resumable threads — <repo>

1. <label>   <state>      <one-line git-reconciled status>
2. <label>   <state>      <...>
3. <label>   <state>      <...>

→ Recommend resuming #1.
[AskUserQuestion] Resume which?
  • #1 <label> (Recommended)
  • #2  • #3
  • None / show next approved action  → plan-nextstep
```

Rank so the most resumable state floats up: `interrupted-mid-implementation`
(dirty tree) > `awaiting-operator` > `completed-with-optional-next` >
`completed`. Break ties by recency. Never list a session whose work targeted a
*different* repo (see transcript-forensics).

## Step 5 — act on the pick

- **`/work-resume` (propose-and-stop, default):** once the operator picks a
  thread, present that thread's full **resume brief** — reconstructed goal +
  acceptance criteria (walk back through earlier turns if the last turn is thin —
  transcript-forensics explains how), the git evidence, and the single
  recommended next action — then STOP for approval before touching anything.
  This matches the repo's propose-then-confirm git workflow.
- **`/work-resume-auto` (auto-resume):** skip the picker entirely. Take the
  top-ranked candidate and begin executing its next action immediately, no
  confirmation gate. Use only when the operator explicitly asked to auto-resume.

If the operator picks **None**, or **every** recent session is `completed`, fall
through to `sub-skills/plan-nextstep/SKILL.md`, which offers the next *approved*
action (project-manager tasks/plans when `pm-profile.yml` is present in the main
checkout root; otherwise a git-signal-based suggestion).

## The resume brief (shown after a pick, or by /work-resume-auto)

```
**Resuming:** <one-line goal>  ·  <branch/worktree>  ·  <state>
**Where it stopped:** <what the last turn expected next>
**Git says:** <reconciliation — committed/unpushed/merged/dirty>
**Next action:** <the single concrete step>
```

When nothing is resumable, say so plainly and offer the plan-nextstep suggestion.
Do not manufacture a candidate to look busy — "everything's shipped, here's the
next planned task" is a complete, correct answer.

## Reading more context when the last turn is thin

Sometimes the last assistant turn is a terse "done" and you need the goal and
acceptance criteria to resume intelligently. The digest's `first_prompt` is the
seed; if you need more, read the transcript directly — the digest carries the
session `path`. transcript-forensics explains how to pull specific turns without
loading the whole file into context.
