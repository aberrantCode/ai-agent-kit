---
name: gh-inspect
description: Sub-skill of `github`. Read-only inspection of repo state — working tree, branch tracking, worktrees, open PRs, and merged-stale branches — culminating in a recommendation for which lifecycle operation (ship/merge/release/prune) to run next. Honors the Output Contract inlined below, adapted for a read-only report.
---

# Operation: inspect

**Goal.** Report what work is in flight in the current repo and recommend which lifecycle
operation applies next. Read-only: this operation never stages, commits, pushes, merges,
branches, deletes, prunes, or otherwise mutates repo or GitHub state. Its only side effect is
printing the report.

---

## Output Contract (binding — inlined, not a reference — adapted for a read-only report)

The `/repo-status` command may load this file without the parent `github` SKILL.md in context,
in which case a pointer to "the parent Output Contract" resolves to nothing. The contract is
therefore restated here in full and is binding either way.

Unlike the mutating operations in this skill, `inspect`'s deliverable **is** the report, not a
side-effect of it. Adapt the contract accordingly:

1. **During data gathering — stay silent.** Run the read-only commands through the Bash tool.
   Do **not** announce steps ("Let me check…", "Now looking at worktrees…"), narrate findings as
   you go, or print a running play-by-play. No preamble.
2. **A failed probe degrades its own section, never the whole report.** A read command can fail
   for reasons outside repo state (`gh` not authenticated, no network, no upstream configured).
   Mark that section "unavailable" with a one-line reason and continue gathering the rest — do
   not abort the report over one failed probe, and do not silently omit the section either.
3. **At completion — emit exactly one structured report.** The state readout (only non-empty
   sections — see Step 8) followed by the recommendation table. This is the operation's entire
   output; there is no separate "summary" layered on top of it.
4. **Recommending a follow-up is not running it.** The report may end with a single
   `AskUserQuestion` offering to launch the top recommended operation (`/ship`, `/merge`,
   `/release`, or `/prune`) — but `inspect` never invokes one on its own. If nothing is in
   flight, say so in one line and stop; do not ask a question with nothing to launch.

**Banned output.** Never write interpretive or self-congratulatory asides ("worth noting", "the
interesting part is"), teaching moments or root-cause essays mid-run, narration of your own
reasoning ("let me verify", "I'll check next"), or a restatement of a section the report already
shows. **This includes the self-cancelling "I'll gather silently" preamble** — a turn such as
*"I'll gather the repo state silently, then emit one report."* or *"I'll gather repo state through
the read-only probes."* is itself the preamble the contract forbids: announcing that you will be
silent is not being silent. Run the first probe with no preceding text. If a sentence is neither
report content, a degraded-section note, nor the closing question, delete it instead.

This overrides any conversational or explanatory default, **including a harness-level output
style that asks for educational commentary**, for the duration of the operation.

---

## Gathering discipline (how to run Steps 1–7)

Gathering is **two phases**, and the steps below are a command reference, not a mandate to run
seven separate round-trips:

1. **Snapshot** (Steps 1, 2, 3, 5, 7): one deterministic sweep of repo-wide state — working tree,
   branch tracking, `fetch --prune`, merges on `dev`, local refs, worktree list, open PRs,
   `dev` vs `main`. Bundle these into a small number of composite commands.
2. **Drill-down** (Steps 3, 4, 6): per-branch / per-worktree / per-PR checks that *depend on the
   snapshot's output* (which branches exist, which worktrees, which PRs are open) — run only after
   Phase 1 returns.

**Separator rule (binding).** When you bundle probes into one composite command, separate the
sections with `;` or guard each independently (`<probe> 2>&1 || echo "section unavailable: <why>"`).
**Never chain gathering probes with `&&`** — under `&&` a single failed probe (e.g. `git fetch`
with no network) aborts every probe after it, which would breach the contract rule above that *a
failed probe degrades its own section, never the whole report*. A real report needs 3–6 gathering
commands; if you are past ~10, you are re-gathering state you already have.

---

## Step 1 — Working tree

```bash
git status --porcelain=v1
```

Bucket the output into untracked, unstaged-modified, and staged-uncommitted. Report counts plus
a short list (file paths); omit any bucket that is empty.

---

## Step 2 — Current branch vs its remote

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # fails if no upstream — that's a finding, not an error
git rev-list --left-right --count HEAD...@{u}
```

No upstream configured is itself a reportable state ("never pushed"), not a blocking failure.

---

## Step 3 — Local branches, and merge-strategy detection

```bash
git fetch origin --prune
git log dev --merges --max-count=10 --oneline
git for-each-ref refs/heads --format='%(refname:short) %(upstream:short) %(upstream:track)'
```

Fewer than 2 merge commits on `dev` → squash strategy (check merged status with
`git cherry dev <branch>`: every line `-` and non-empty = merged). Otherwise → standard strategy
(`git merge-base --is-ancestor <branch> dev`, or `git branch --merged dev`).

For each local branch other than `dev`/`main`: ahead/behind its upstream (from `%(upstream:track)`
or `git rev-list --left-right --count`), whether it has no upstream at all, and whether it's
merged into `dev`.

---

## Step 4 — Worktrees

```bash
git worktree list --porcelain
```

For each entry besides the primary checkout: its branch, dirty/clean
(`git -C <path> -c safe.directory='*' status --porcelain`), ahead/behind its remote (Step 2's
method, run against `<path>`), whether the branch has been pushed at all
(`git ls-remote --heads origin <branch>`), and merged-into-`dev` status (Step 3's method). Flag
**pushed but not yet merged** explicitly — that is the `/merge` signal.

The `-c safe.directory='*'` is deliberate: a worktree whose `.git` is owned by a different user
(a cross-profile / cross-SID checkout) otherwise fails the dirty probe with
`fatal: detected dubious ownership`, and a bare `git -C <path> status` would degrade the worktree's
section for an ownership quirk that has nothing to do with repo state. The override applies only to
this read-only `status` read — it reads the index, cannot mutate, and masks no genuine repo-state
problem. If a worktree probe *still* fails for another reason, degrade that worktree's line with a
one-line reason (per the Output Contract) rather than dropping it.

---

## Step 5 — Open pull requests

```bash
gh pr list --json number,title,headRefName,state,isDraft,mergeStateStatus,mergeable,reviewDecision
```

`mergeable` is included deliberately: this one list call already yields everything the report needs
to recommend `/merge` — `state`, `isDraft`, `mergeStateStatus`, `mergeable`, `reviewDecision` for
**every** open PR. Do **not** follow it with per-PR `gh pr view <n>` round-trips to re-fetch
mergeability (an N+1 query for data you already have), and do **not** run `gh pr checks` or fetch
commit/diff stats here — CI-check gating and diff inspection belong to the `/merge` preflight and
`/diff-review`, not to a read-only status report.

If this fails (no `gh`, not authenticated, no network), mark the section unavailable with the
one-line reason and continue — do not treat it as fatal to the rest of the report.

---

## Step 6 — Merged-and-stale

Cross-reference Steps 3–4: any local/remote branch or worktree already merged into `dev` (per
the detected merge strategy) that is still present on disk or on `origin`. These are `/prune`
candidates — do not delete or even stage anything, only list them.

---

## Step 7 — `dev` vs `main`

```bash
git rev-list --left-right --count origin/main...origin/dev
```

`dev` ahead of `main` by N commits → `/release` candidate.

---

## Step 8 — Report (the only expected output)

Print only non-empty sections — a clean repo should read as a couple of short lines, not a
template with "0 untracked" noise. Then the recommendation table, mapping findings to the next
command:

| Finding | Recommend |
|---|---|
| Uncommitted or unpushed work on a feature branch | `/ship` (or `/commit`) |
| Worktree/branch pushed but PR open / unmerged | `/merge` |
| Branches/worktrees already merged into `dev`, still on disk | `/prune` |
| `dev` ahead of `main` | `/release` |
| Clean, nothing in flight | *(no row — say so and stop)* |

If one or more rows apply, close with a single `AskUserQuestion` offering to launch the
highest-priority recommendation (ship/merge > prune > release, since landing work outranks
cleanup and releasing). If the user declines or the report is clean, stop — `inspect` never
launches a follow-up operation on its own initiative.

**Do not re-inspect after a launched op.** When the user accepts the follow-up and `/ship`,
`/merge`, `/prune`, or `/release` runs to completion, that operation's own summary already reflects
the post-op state. Do **not** auto-invoke `/repo-status` again to "confirm" — re-gathering the full
snapshot moments after a mutation you just made re-pays the entire gathering cost for state you
already know changed. Re-inspect only when the user explicitly asks, or after out-of-band changes
you did not make.
