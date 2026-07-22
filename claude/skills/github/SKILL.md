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
  worktree", "set up an isolated workspace", "remove the worktree",
  "merge PR 76", "merge these PRs", "land this branch", "open a PR for this",
  "cut a release", "clean these branches" — route these through the named
  operation rather than a raw gh/git sequence — and similar
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
2. **On error — surface it only if it blocks you.** Split every failure in two:
   - **Recoverable** (you know the fix and can apply it now — a gate that wants a file
     regenerated, a stale ref needing a fetch, a cleanup step that raced): **just fix it.**
     Say nothing mid-run. Fold it into the final summary as one line.
   - **Blocking** (needs a decision, a credential, a human, or a judgment you cannot make):
     print the failing command and its stderr verbatim, then stop or ask via
     `AskUserQuestion`. This is the only thing that breaks the silence mid-run.

   A recovered error is not an event worth reporting in real time. Fixing it quietly *is*
   the job.
3. **At completion — emit one concise summary.** A single short block (target ≤ 4 lines):
   what was merged / shipped / released / cleaned, where it landed (PR #, commit SHA, tag,
   branch), and any caveat the user must act on (e.g. "worktree dir left on disk — locked
   handle; delete manually").

4. **If anything remains open — one compact table, and nothing else.** Unresolved issues,
   follow-up work, or recommended changes to a skill/command/instruction go in a single table
   after the summary: `| Item | Where | Action |`. No table when there is nothing outstanding.

### Banned output

The contract is violated by *commentary*, not just by length. Never write:

- **Interpretive or self-congratulatory asides** — "the gate earned its keep", "exactly as
  predicted", "this is the honest outcome", "worth noting", "the interesting part is".
- **Teaching moments, insights, or root-cause essays** mid-run. If a finding is genuinely
  reusable, it belongs in one row of the follow-up table, not a paragraph.
- **Narration of your own reasoning or process** — "I deliberately chose", "my prediction was",
  "let me verify". Do the work; report the result.
- **Restating what a step did** when the summary already covers it.

This contract overrides any conversational or explanatory default — including a harness-level
output style that asks for educational commentary — for the duration of the operation. If you
are about to write a sentence that is neither a blocking error, the final summary, nor a
follow-up table row, delete it instead.

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

## Prefer the named operation over hand-rolling git/gh

When you are about to run `gh pr create`, `gh pr merge`, a `git push` that opens or lands a
PR, or to replicate init/release/prune logic by hand — **route through the matching operation
instead of reimplementing it in Bash.** `/ship`, `/merge`, `/release`, `/init-repo`, `/prune`
carry the preflight, cleanup, ref-hygiene, and Output-Contract guarantees; a hand-rolled
`gh`/`git` sequence silently drops all of them. This applies most in autonomous, `/loop`, and
background runs, where the temptation to inline a quick `gh pr merge` is highest.

When a **batch** of PRs is left pending, surface the merge decision through `AskUserQuestion`
(a multi-select of PRs to merge) — never a prose paragraph asking the user what to do.

---

## Cross-Operation Principles

These hold for every operation, present or future:

- **Route repository actions through the named operation.** Opening/landing a PR, cutting a
  release, or pruning branches goes through `/ship` `/merge` `/release` `/prune` — not an
  ad-hoc `gh`/`git` sequence that skips their guarantees. See "Prefer the named operation".
- **Never merge before a preflight passes.** Before any `gh pr merge`, read
  `gh pr view <n> --json state,isDraft,mergeable,mergeStateStatus,reviewDecision` and
  `gh pr checks <n>`. A `mergeable == "UNKNOWN"` right after a push is transient — poll, don't
  fail. `isDraft` is its own gate (ask: mark-ready or skip). Required checks / `BLOCKED` mean
  either `--auto` (only if the repo has auto-merge enabled) or watch-to-green — never bypass.
  `merge` and `ship` carry the executable preflight; see their steps.
- **Refresh remote refs before reasoning; treat an already-gone remote delete as success.**
  Any op that decides "merged?" or "still needs deleting?" from local refs runs
  `git fetch --prune origin` first — `deleteBranchOnMerge` (which `repo-init` enables) removes
  branches server-side, so unpruned `origin/*` refs are phantoms. Before deleting a remote
  branch, `git ls-remote --heads origin <b>`; absent → record "already removed", not a failure.
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
