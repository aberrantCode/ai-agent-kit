---
name: github
category: Foundations & Workflow
description: >
  Use when the user wants to perform a git or GitHub repository operation from the terminal —
  merging a pull request, branch, or worktree into dev; shipping working changes through a
  feature-branch PR; cutting a dev→main release; provisioning or repairing a repo's release
  automation (changelog generator + tag-triggered workflow); committing and pushing; pruning
  stale branches and worktrees; bringing a repo's configuration up to standard (branch
  protection, merge policy, security settings, local hook gate); or creating, working in, and
  tearing down an isolated per-task worktree. Triggers on "merge 1209", "merge this branch",
  "merge the current worktree", "ship it", "release", "set up releases", "release init",
  "provision release workflow", "fix changelog automation", "commit", "clean up branches",
  "init the repo", "initialize this repo", "harden this repo", "set up branch protection",
  "why can I push straight to dev", "apply the repo standard", "create a
  worktree", "set up an isolated workspace", "remove the worktree", and similar
  phrasings — even
  when the word "git" is absent. This is a thin-command bundle: each command names one
  operation and this skill runs it against the current repo with minimal terminal output.
---

# GitHub

Single entry point for git and GitHub repository operations on this workstation. This skill is
a **thin orchestrator**: each command in `commands/` names one operation, and this skill runs
that operation's sub-skill under `sub-skills/` against the current repo.

---

## Output Contract — applies to EVERY operation in this skill

The user wants signal, not narration. Your terminal output for any operation here is exactly
these three things, and nothing else:

1. **During execution — stay silent.** Run the commands through the Bash tool. Do **not**
   announce steps ("Let me check…", "Now merging…"), do not explain what a command does, do
   not print per-command status or a running play-by-play. No preamble.
2. **On error — surface it the moment it happens.** When a command fails, print the failing
   command and its stderr verbatim, then stop or ask via `AskUserQuestion` as the operation
   prescribes. Errors are the only thing that breaks the silence mid-run.
3. **At completion — emit one concise summary.** A single short block (target ≤ 4 lines):
   what was merged / shipped / released / cleaned, where it landed (PR #, commit SHA, tag,
   branch), and any caveat the user must act on (e.g. "worktree dir left on disk — locked
   handle; delete manually").

This contract overrides any conversational or explanatory default for the duration of the
operation. If you are about to write a sentence that is neither an error nor the final
summary, delete it instead.

---

## Parameter Contract

Every command accepts an **optional free-text message** naming what to act on. Interpret it
against the current repo; never block on it when a sensible default exists.

| Token in the message | Interpreted as |
|---|---|
| All digits (`1209`) | a pull-request number |
| Matches a local or remote branch name | a branch |
| An existing path, or a path in `git worktree list` | a worktree (resolve to its branch/PR) |
| Several of the above, space/comma separated | a **set** of targets — process each in turn |
| *(empty)* | the **current context** — the current branch's open PR, or the worktree you are standing in |

When a required target cannot be resolved (e.g. `/merge` with no argument and no open PR on
the current branch), use `AskUserQuestion` to elicit it — never inline-print a free-text
question.

---

## Operations

| Command | Operation | Sub-skill |
|---|---|---|
| `/publish` | publish | `sub-skills/publish` |
| `/init-repo` | repo-init | `sub-skills/repo-init` |
| `/commit` | commit | `sub-skills/commit` |
| `/ship` | ship | `sub-skills/ship` |
| `/merge [targets]` | merge | `sub-skills/merge` |
| `/release` | release | `sub-skills/release` |
| `/release-init` | release-init | `sub-skills/release-init` |
| `/prune` | prune | `sub-skills/prune` |

One sub-skill has **no command of its own** and triggers directly on worktree phrasings:

| *(no command — triggers directly)* | worktree lifecycle | `sub-skills/worktree-task-lifecycle` |
|---|---|---|

`worktree-task-lifecycle` is the **single lifecycle authority** for per-task worktrees —
creation under `<repo>-wt/.worktrees/`, post-merge idempotent removal, Windows file-lock
recovery, and credential rules. `merge` and `prune` delegate their worktree handling to it;
so do multi-agent harnesses (agent-manager) that run one worktree per agent.

The operations form one repo lifecycle: **publish → commit → ship → merge → release → prune**.

Two `*-init` operations sit beside that lifecycle. Both are idempotent provisioning passes
that own one standard each, are safe to re-run forever, and never commit — they leave files
in the working tree for `/ship` to land:

| Operation | Owns | Standard |
|---|---|---|
| `repo-init` | repository **configuration** | Repo-Configuration Standard — ruleset-protected `main`/`dev`, immutable `v*` tags, merge-commit-only, push protection, an active local hook gate, the standard artifact set |
| `release-init` | release **automation** | Release-Automation Standard — notes derived from git at tag time |

`release` verifies release conformance and warns; only `release-init` fixes. `repo-init` and
`publish` are two entry points onto the same configuration standard: **`publish` owns repo
creation, `repo-init` owns repo configuration.** `publish` hands off to `repo-init` once the
repo exists; `repo-init` invokes `publish` when there is no remote yet. Either path converges
on the same configured repo, and neither duplicates the other's logic.

**Local-first CI.** Repository checks run on this workstation through versioned git hooks,
not GitHub Actions. Actions are reserved for tag-triggered release automation. The single
server-side exception is secret-scanning push protection, because a pushed secret is the one
failure in this model that cannot be undone. `repo-init` owns and enforces that policy.
When a new thin command is added, append a row here and a sub-skill under `sub-skills/`.

### Companion commands (not part of this bundle)

These live elsewhere but pair naturally with the operations above — reference them, do not
re-implement:

- **`/code-review`** — an optional pre-PR quality/security gate. `ship` may suggest it
  before opening the PR.
- **`/diff-review`** — a visual HTML diff of a branch, commit, or PR. Point users to it to
  inspect a PR before `/merge`.

---

## Cross-Operation Principles

These hold for every operation, present or future:

- **Protected branches.** Never push directly to `dev` or `main`; never delete them. Feature
  work merges into `dev` via PR; `dev` merges into `main` only for releases. Enforcement is
  a **ruleset** per branch (`repo-init` provisions them) — rulesets are used over the legacy
  branch-protection API because they work on private repos without a paid plan and can also
  protect tags.
- **Merge strategy is a merge commit.** Use `--merge` / `--no-ff` to preserve feature-branch
  history. Never squash a feature branch into `dev`. `repo-init` disables squash and rebase
  merges at the repo level so the GitHub UI cannot violate this either.
- **Release tags are immutable.** A `v*` tag ruleset blocks deletion and force-update. Fix a
  bad release by publishing a new version, never by repointing a published tag.
- **Default merge base is `dev`.** `/merge` targets `dev` unless told otherwise.
- **Run destructive git/gh from the repo root**, never from inside a secondary worktree —
  `cd "$(git rev-parse --show-toplevel)"` first, and if you are in a worktree, resolve the
  primary root before merging.
- **Cleanup order is worktree → local branch → remote.** Removing a worktree does not delete
  its backing branch; delete that separately.
- **Worktree create/remove goes through `sub-skills/worktree-task-lifecycle`.** It owns the
  canonical location (`<repo>-wt/.worktrees/`), the Windows lock-recovery sequence
  (`git worktree prune` + force-remove; if the directory still resists, leave it and say so
  in the summary rather than looping), and the credentials-stay-in-primary-checkout rule.
- **Commit conventions.** Conventional-commit format `<type>: <description>` with types
  `feat|fix|refactor|docs|test|chore|perf|ci`; one logical change per commit (atomic — if the
  message needs "and", split it); never leave `WIP` commits on a branch that reaches a PR;
  commit at every stable point rather than waiting for "done".
- **Verify remembered refs against live state before anything destructive.** A cached pointer
  — `git symbolic-ref refs/remotes/origin/HEAD`, a remembered default branch, a memory-file
  note — is a hypothesis, not a fact: branches get deleted and renamed after the cache was
  written. Before a release, force-push, or bulk delete, confirm the target actually exists
  remotely (`git ls-remote --heads origin <branch>`); if the cached ref is wrong, repair it at
  the source (`git remote set-head origin -a`) rather than working around it, and never
  guess-continue past a failed verification.
- **All user prompts go through `AskUserQuestion`.** Never write "type yes/no".
- **Never force-push `dev` or `main` blind, never skip failing CI gates.** Surface the failure
  and stop.

---

## Diagram

[View diagram](diagram.html)
