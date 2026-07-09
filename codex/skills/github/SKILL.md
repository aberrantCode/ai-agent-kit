---
name: github
description: >
  Use when the user wants to perform a git or GitHub repository operation from the terminal —
  merging a pull request, branch, or worktree into dev; shipping working changes through a
  feature-branch PR; cutting a dev→main release; committing and pushing; publishing a new repo;
  or pruning stale branches and worktrees. Triggers on natural phrasings such as "merge 1209",
  "merge this branch", "merge the current worktree", "ship it", "cut a release", "commit this",
  "clean up branches", "publish this repo" — even when the word "git" is absent. This is a thin
  orchestrator: match the request to one operation below and run that operation's sub-skill
  against the current repo with minimal terminal output.
---

# GitHub

Single entry point for git and GitHub repository operations on this workstation. This skill is
a **thin orchestrator**: each operation below has its own sub-skill under `sub-skills/`, and a
request that matches an operation runs that operation's sub-skill against the current repo.

---

## Output Contract — applies to EVERY operation in this skill

The user wants signal, not narration. Your terminal output for any operation here is exactly
these three things, and nothing else:

1. **During execution — stay silent.** Run the commands. Do **not** announce steps ("Let me
   check…", "Now merging…"), do not explain what a command does, do not print per-command
   status or a running play-by-play. No preamble.
2. **On error — surface it the moment it happens.** When a command fails, print the failing
   command and its stderr verbatim, then stop or ask the user a plain, concise question and
   wait for the answer, as the operation prescribes. Errors are the only thing that breaks the
   silence mid-run.
3. **At completion — emit one concise summary.** A single short block (target ≤ 4 lines):
   what was merged / shipped / released / cleaned, where it landed (PR #, commit SHA, tag,
   branch), and any caveat the user must act on (e.g. "worktree dir left on disk — locked
   handle; delete manually").

This contract overrides any conversational or explanatory default for the duration of the
operation. If you are about to write a sentence that is neither an error nor the final
summary, delete it instead.

---

## Parameter Contract

Every operation accepts an **optional free-text target** naming what to act on. Interpret it
against the current repo; never block on it when a sensible default exists.

| Token in the request | Interpreted as |
|---|---|
| All digits (`1209`) | a pull-request number |
| Matches a local or remote branch name | a branch |
| An existing path, or a path in `git worktree list` | a worktree (resolve to its branch/PR) |
| Several of the above, space/comma separated | a **set** of targets — process each in turn |
| *(empty)* | the **current context** — the current branch's open PR, or the worktree you are standing in |

When a required target cannot be resolved (e.g. asking to merge with no argument and no open
PR on the current branch), ask the user a plain, concise question and wait for the answer —
never guess silently.

---

## Operations

| Operation | Sub-skill |
|---|---|
| publish | `sub-skills/publish/SKILL.md` |
| commit | `sub-skills/commit/SKILL.md` |
| ship | `sub-skills/ship/SKILL.md` |
| merge | `sub-skills/merge/SKILL.md` |
| release | `sub-skills/release/SKILL.md` |
| prune | `sub-skills/prune/SKILL.md` |

The operations form one repo lifecycle: **publish → commit → ship → merge → release → prune**.
A request that names one of these actions (or an equivalent natural phrasing) runs the matching
sub-skill. When a new operation is added, append a row here and a sub-skill under
`sub-skills/`.

### Adjacent operations (not part of this bundle)

These are not implemented here but pair naturally with the operations above — mention them by
name if relevant, do not re-implement them:

- **A pre-PR code review** — an optional quality/security gate. `ship` may suggest running one
  before opening the PR.
- **A visual diff review** — inspecting a branch, commit, or PR's changes before merging. Point
  the user at their own review tooling before `merge`.

---

## Cross-Operation Principles

These hold for every operation, present or future:

- **Protected branches.** Never push directly to `dev` or `main`; never delete them. Feature
  work merges into `dev` via PR; `dev` merges into `main` only for releases.
- **Merge strategy is a merge commit.** Use `--merge` / `--no-ff` to preserve feature-branch
  history. Never squash a feature branch into `dev`.
- **Default merge base is `dev`.** `merge` targets `dev` unless told otherwise.
- **Run destructive git/gh from the repo root**, never from inside a secondary worktree —
  `cd "$(git rev-parse --show-toplevel)"` first, and if you are in a worktree, resolve the
  primary root before merging.
- **Cleanup order is worktree → local branch → remote.** Removing a worktree does not delete
  its backing branch; delete that separately.
- **Windows worktree-lock footgun.** After a merge, a lingering file handle can block deletion
  of the worktree directory with "Permission denied". Prune git's metadata
  (`git worktree prune`) and force-remove the leftover directory; if it still cannot be
  removed, leave it and say so in the summary rather than looping.
- **All user prompts are plain, concise questions.** Ask directly and wait for the answer;
  never write "type yes/no" or leave a question implicit.
- **Never force-push `dev` or `main` blind, never skip failing CI gates.** Surface the failure
  and stop.
