---
name: work-resume-git-state-reconcile
description: Sub-skill of `work-resume`. How to reconcile what a session's last turn CLAIMED against what git actually shows — local working-tree state, unpushed commits, remote branch status, and open PRs — so "the agent said it's done" becomes "it is / isn't / is half done." Read this for the reconciliation decision table and the source-vs-artifact distinction.
---

# Git state reconcile

Step 3 of `work-resume`. A last assistant turn that says "committed and pushed"
is a **claim**, not proof — the session may have died before it ran the commit,
or the operator may have changed things since. This sub-skill turns the claim
into ground truth by asking git, so the resume brief rests on reality.

## The signals to gather

Run these from the candidate's checkout (its worktree, if the session ran in
one — use `worktree_path` from the digest):

```bash
git status -sb                 # branch + ahead/behind + dirty summary
git status --porcelain         # exact per-file state (staged/modified/untracked)
git log --oneline @{u}..HEAD   # commits made but NOT pushed
git rev-parse --abbrev-ref @{u} 2>/dev/null   # upstream; error/"gone" = no live remote branch
gh pr list --state open        # is there an open PR carrying this work?
```

Interpretation:

- **Dirty working tree** — `--porcelain` non-empty. Match the changed paths
  against the digest's `recent_edit_files`: if the files the session was editing
  are still modified/untracked, the work was **not** finished, regardless of what
  the tail said.
- **Committed but unpushed** — `@{u}..HEAD` non-empty. The work exists locally
  only; resuming may just mean pushing / opening a PR.
- **Upstream `gone`** — the remote branch was deleted, which on this workstation's
  merge-commit workflow almost always means the branch was **merged and cleaned
  up**. Combined with the work appearing in `dev`'s history, that is "done."
- **Open PR exists** — the work is in review; the next action is review/merge, not
  re-implement. Never re-do work that is sitting in an open PR.

## Source vs artifact — do not cry "unfinished" over generated files

A dirty tree is not automatically unfinished work. Many repos leave generated
outputs uncommitted by design — `data/*.csv` run artifacts, build outputs,
`.mcp.json`, backups. If **every** dirty path is a generated/ignored artifact and
no *source* file is touched, the source work is complete even though `git status`
is noisy. Judge by what the paths are, not by the count. (Real example:
dropbox_audit's 31 dirty paths were all `data/*.csv` + backups — zero source, so
the thread was genuinely done.)

Cross-check with `.gitignore` and the repo's conventions when unsure; a path the
repo ignores is a strong "artifact, not unfinished source" signal.

## Reconciliation decision table

Map the tail's claim × git reality to a resume state and next action:

| last turn claims | git shows | → verdict | next action |
|---|---|---|---|
| "done & pushed" | clean, upstream gone / in `dev` | genuinely complete | none — skip / offer plan-nextstep |
| "done" | source files still dirty | ended before finishing | finish + commit those files |
| "done & pushed" | unpushed commits | committed, not pushed | push / open PR |
| mid-edit (ended_mid_action) | dirty tree | interrupted | continue the in-flight edit |
| proposed next step | clean | ready for the step | do the proposed step |
| "opened PR #N" | PR open | in review | review/merge, don't re-implement |
| "done" | only artifacts dirty | complete | none — the noise is by design |

## Timing sanity check

Compare the session's `last_ts` against the mtime of the files it claims to have
changed and against `git log` dates. A commit timestamped *after* the session's
last turn means someone (or a later session) finished the job — treat the older
session as superseded. A working-tree file modified *after* the session ended
means the operator kept editing by hand; ask before clobbering it.

## Output of this step

A single reconciled line per candidate for the shortlist, e.g.
`audit committed & merged (#68); dev behind 2; no source dirty`, plus — for the
thread the operator ultimately picks — the fuller **Git says:** block in the
resume brief.
