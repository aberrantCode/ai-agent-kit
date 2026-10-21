---
name: sm-resume
description: >
  Sub-skill of `session-manager`. Pick up where the operator left off — "what was I working on",
  "continue my last session", "resume work in this repo", "did I finish that", "what's next
  here", "I forgot where I left off". Scans this repo's recent Claude Code sessions (including
  git worktrees) newest-first, reconstructs what each expected next, reconciles against git
  state and approved plans, and proposes (or auto-runs) the single best thing to pick up.
  Commands: /work-resume, /work-resume-auto, /work-report, /work-scan.
---

# resume

Formerly the `work-resume` skill. You (or the operator) walked away mid-stream and came back.
The question is always: **what was in flight, did it finish, and what is the next move?**
Answer it by reading recent conversation history for *this* repo, working out what each session
expected next, and checking that against what git shows locally and on the remote. Trigger this
whenever the operator returns to a repo and asks where things stand, even without the word
"resume".

## Core principle: the funnel

`scripts/resume-scan.py` reduces the repo's transcript corpus (dozens of files, hundreds of MB)
to a few KB of **per-session digest**: initiating goal, last operator turn, last assistant turn,
and mechanical hints (ended mid-tool-call, files being edited, branch/worktree). Only that
digest enters context.

**The script extracts; you classify.** Whether a session is finished, finished-with-optional-next,
interrupted-mid-implementation, or waiting-on-the-operator is a reading task. The script never
guesses it; it hands you bounded evidence. Keyword rules would be brittle and wrong.

```
scan (script) -> classify each session   (references/transcript-forensics.md)
              -> reconcile top candidates (references/git-state-reconcile.md)
              -> decide -> propose (stop) OR auto-resume
                           \- nothing resumable -> references/plan-nextstep.md
```

## Step 1: scan

Run from the repo to resume (script path is relative to this sub-skill; resolve it from the
loaded bundle):

```bash
python scripts/resume-scan.py --repo . --format json
```

The script finds this repo's sessions across **all** worktrees (in-repo `.worktrees/`, sibling
`<repo>-wt/`, shared containers) by git identity, not directory names. Discovery details and the
one unrecoverable edge are in [references/transcript-forensics.md](references/transcript-forensics.md);
the shared transcript library is [../transcripts/SKILL.md](../transcripts/SKILL.md).

`--window` (default `smart`):

| value | meaning |
|---|---|
| `smart` | newest-first, last 21 days, clamped to 6-15 sessions |
| `14d` | sessions touched in the last 14 days |
| `10s` | the 10 most-recent sessions by mtime |
| `2026-07-01` | every session on/after that date |
| `all` | the whole corpus |

Output is `{meta, sessions[]}`, newest-first. Each session has `first_prompt`, `last_prompt`,
`last_assistant_tail`, `ended_mid_action`, `last_event_kind`, `last_tool`, `recent_edit_files`
(absolute), `branch`, `worktree_path`, `cwd`. Files beyond `--max-files` are dropped and
reported, never silently truncated. `--format md` is the human view used by `/work-scan`.

## Step 2: classify each session (newest to oldest)

Use the rubric in [references/transcript-forensics.md](references/transcript-forensics.md). Label
each session from its last assistant turn (and `first_prompt` if the tail is ambiguous):

- **completed**: work done, no next action promised. Skip it.
- **completed-with-optional-next**: done, but the agent recommended an optional follow-up. That
  follow-up is a candidate.
- **interrupted-mid-implementation**: `ended_mid_action` true and the tail shows work in
  progress. High-value candidate.
- **awaiting-operator**: the agent asked a question or proposed a plan and stopped. The next
  move is the operator's answer.

Stop early once you have a clear top candidate. **Do not** offer a session whose
`recent_edit_files` point into a *different* repo (cross-repo excursion).

## Step 3: reconcile with git

A last turn saying "done and pushed" is a *claim*. Follow
[references/git-state-reconcile.md](references/git-state-reconcile.md): uncommitted edits
matching `recent_edit_files`? Unpushed commits? Branch merged into `dev`? Open PR? Common cases:

- Tail says committed and pushed **and** git agrees: genuinely complete.
- Tail says done but matching uncommitted edits exist: ended early; resume by finishing.
- `ended_mid_action` with a dirty tree: clearest resume, continue the edit.
- Tail proposed a next step and the tree is clean: offer the proposed step.

Also check durable state written by [../checkpoint/SKILL.md](../checkpoint/SKILL.md): the
newest `_project_specs/session/current-state.md` and any handoff prompt under `docs/PROMPTS/`
are first-class evidence of what the last session expected next (see the optional hook in
[references/session-start-hook.md](references/session-start-hook.md)).

## Step 4: ranked shortlist, operator picks

Build a **ranked shortlist**, newest-first, one line each: short label, resumption state,
reconciled git status. Reconcile git for at least the candidates you would recommend. Rank:
`interrupted-mid-implementation` (dirty tree) > `awaiting-operator` >
`completed-with-optional-next` > `completed`; ties by recency. Then pose the choice with
`AskUserQuestion`, recommended thread first, always with an escape option:

```
Resumable threads - <repo>
1. <label>   <state>   <one-line git-reconciled status>
2. ...
-> Recommend resuming #1.
[AskUserQuestion] Resume which?
  - #1 <label> (Recommended)
  - #2 / #3
  - None / show next approved action  -> references/plan-nextstep.md
```

## Step 5: act on the pick (modes)

- **propose-and-stop** (`/work-resume`, default): after the pick, present the **resume brief**
  (reconstructed goal and acceptance criteria, git evidence, one recommended next action) and
  STOP for approval before touching anything.
- **auto-resume** (`/work-resume-auto`): skip the picker, take the top candidate and start its
  next action immediately, no confirmation gate. Still obey git rules (never push to
  `dev`/`main`; branch and PR as normal). Only when the operator asked for it.
- **read-only report** (`/work-report`): classify, reconcile enough git to label honestly,
  report the ranked shortlist with one-line statuses plus the next approved action from
  `references/plan-nextstep.md`. No execution, no `AskUserQuestion`, no git or file mutation.
- **scan** (`/work-scan [window]`): run `python scripts/resume-scan.py --repo . --format md`
  (add `--window <value>` if given), show the output largely as-is; no classification or action.

If the operator picks **None**, or **every** recent session is `completed`, fall through to
[references/plan-nextstep.md](references/plan-nextstep.md) (project-manager tasks/plans when
`pm-profile.yml` is in the main checkout root, else a git-signal suggestion).

## The resume brief

```
**Resuming:** <one-line goal>  .  <branch/worktree>  .  <state>
**Where it stopped:** <what the last turn expected next>
**Git says:** <committed/unpushed/merged/dirty>
**Next action:** <the single concrete step>
```

When nothing is resumable, say so plainly and offer the plan-nextstep suggestion. Do not
manufacture a candidate: "everything is shipped, here is the next planned task" is a complete
answer. If the last turn is thin, reconstruct the goal from `first_prompt` and pull a few extra
turns from the session `path` (technique in transcript-forensics).

## Maintainer notes

- Design decisions: ranked shortlist plus `AskUserQuestion` (operator sees what was skipped);
  the prompting is deliberate so installed copies behave consistently (relax to markdown for a
  team without that convention); git identity over name matching for worktrees; never invent a
  candidate.
- Dependencies: Python 3 stdlib, `git`; `gh` for PR reconciliation. The locator reads
  `~/.claude/projects/<slug>/*.jsonl`, so this is Claude-Code-specific.
- Porting to Codex/Gemini: only the locator and digest layer (`slugify`, `worktree_slugs`,
  `_session_cwd`, `digest_session`, injected-content filter) is runtime-specific. Rewrite those
  for the other runtime's transcript store keeping the `{meta, sessions[]}` contract and field
  names; keep git correlation, rubric, reconcile table and the `pm-profile.yml` gate unchanged;
  prove on two real repos (one with worktrees) first.
- The optional SessionStart hook is documented only, never installed:
  [references/session-start-hook.md](references/session-start-hook.md).
