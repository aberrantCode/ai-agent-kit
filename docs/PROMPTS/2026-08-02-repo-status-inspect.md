# Handoff: add a `/repo-status` inspect operation to the `github` skill

You are a fresh Claude Code session. Your job is to add a **read-only repo-state inspection**
operation to the existing `github` skill bundle in this archive, ship it through a PR into `dev`,
and then push the updated bundle to the global profile so the command works machine-wide.

Your worktree and branch **already exist** — you are running inside them. Do **not** create
another worktree or branch.

- Worktree: `C:\development\ai-agent-kit\.worktrees\repo-status-inspect`
- Branch: `feat/repo-status-inspect` (based on `origin/dev @ 5905ffd`)
- Primary checkout (for the prompt file only, never edit code there): `C:\development\ai-agent-kit`

---

## Orientation — read these first, follow them exactly

- This repo's `CLAUDE.md` and `AGENTS.md` — the archive conventions (archive is source of truth;
  changes go through feature branch → PR → `dev`; every archived skill/command has a CATALOG row).
- The `github` skill you are extending: `claude/skills/github/SKILL.md` (the **Output Contract**
  and **Cross-Operation Principles** are binding on every operation, including the one you add).
- `docs/reorg/charter.md` and `docs/reorg/command-namespace-registry.md` — the **Generic-Verb
  Rule** and the binding command registry. Every new command name must be registered.

Do not restate these conventions in your own words inside the skill files — reference and follow
them. Getting them subtly wrong creates a conflicting second source of truth.

---

## Hard constraints (unmissable — this session may run with permissions skipped)

1. **The new operation is strictly READ-ONLY.** `/repo-status` inspects and reports. It must
   never stage, commit, push, merge, branch, delete, prune, or otherwise mutate repo state. Its
   only side effect is reading git/gh state and printing a report. If you ever find yourself
   writing a mutating git/gh command into the inspect sub-skill, stop — that belongs to
   `ship`/`merge`/`release`/`prune`, not here.
2. **`/repo-status` must not auto-run follow-up operations.** It ends by *recommending* which of
   `/ship` `/merge` `/release` `/prune` apply, and MAY offer to launch one via a single batched
   `AskUserQuestion` — but it never invokes them on its own.
3. **Never push directly to `dev` or `main`; never delete them.** Land your work via `/ship`
   (PR → `dev`, merge commit). Protected-branch rules in the github skill are binding.
4. **Do not delete this prompt file** (`docs/PROMPTS/2026-08-02-repo-status-inspect.md`). Its
   retirement is gated on a human confirmation you cannot give yourself.
5. **If a task appears to require a forbidden action, stop and ask** rather than improvising.

---

## State already established (verified this session — do not re-derive)

- **Naming decision (settled):** the command is **`/repo-status`**. No collision — it does not
  appear anywhere in `command-namespace-registry.md`. It is a specific noun-object compound, not
  a bare generic verb, so it satisfies the Generic-Verb Rule (siblings `/repo-color`, `/init-repo`
  already break verb-first). Do not rename it.
- **Rollout decision (settled):** archive → PR into `dev` → then push the updated `github` bundle
  to the global profile (`~/.claude`) so `/repo-status` is live machine-wide.
- **github bundle layout (verified):**
  - Sub-skills live in `claude/skills/github/sub-skills/<op>/SKILL.md`. Existing:
    `commit merge prune publish release release-init repo-init ship worktree-task-lifecycle`.
  - Thin commands live in `claude/skills/github/commands/<name>.md`. Existing:
    `commit init-repo merge prune publish release release-init ship`.
  - The parent `claude/skills/github/SKILL.md` has an **Operations** table (each row:
    `| /command | operation | sub-skills/<op> |`) — you add a row there.
  - `sub-skills/prune/SKILL.md` is the closest existing template for a read/audit-flavored op —
    read it for the house structure and the inlined Output Contract block. `sub-skills/ship`
    shows the full contract too.
- **The exact commit→registry→catalog→validate pattern was just used** in PR #145 (adding
  `/update-service`). Mirror it: a new command file + a registry row + a regenerated `CATALOG.md`,
  gated by `scripts/validate.ps1`.
- **Validate gate:** `pwsh -NoProfile -NonInteractive -File scripts/validate.ps1` — must exit 0
  before shipping. It checks catalog-staleness, changelog-staleness, and `audit.ps1`. Adding
  command files makes `CATALOG.md` stale; regenerate it with
  `pwsh -NoProfile -File scripts/generate-catalog.ps1 -Force` and stage the result (only the rows
  for your new command should change — verify the diff is scoped).

---

## Design of the inspect operation (this is the substance — get it right)

`/repo-status` answers, for the **current repo** (the cwd): *what work is in flight, and which
lifecycle command should I run next?* Detect and report each of these states (read-only commands
only — `git status`, `git rev-list`, `git for-each-ref`, `git worktree list --porcelain`,
`git ls-remote`, `gh pr list/view`, `git log`):

- **Working tree** — untracked files, unstaged modifications, staged-but-uncommitted changes
  (counts + a short list).
- **Current branch vs its remote** — commits ahead (unpushed) and behind (unpulled).
- **Local branches** — any feature branch not merged into `dev`; any local branch ahead of its
  upstream; branches with no upstream at all.
- **Worktrees** — for each entry in `git worktree list`: its branch, dirty/clean, ahead/behind
  its remote, whether the branch is pushed, and whether it is already merged into `dev`. Call out
  the important case explicitly: **pushed but not yet merged** (has an open PR or is simply
  unmerged) — a `/merge` or `/ship` candidate.
- **Open PRs** — `gh pr list` with state / draft / mergeable, so the user sees what is awaiting
  merge.
- **Merged-and-stale** — local/remote branches and worktrees already merged into `dev` (a
  `/prune` candidate).
- **`dev` vs `main`** — is `dev` ahead of `main`? (a `/release` candidate).

Then emit a **recommendation block** mapping findings to the next command:

| Finding | Recommend |
|---|---|
| Uncommitted or unpushed work on a feature branch | `/ship` (or `/commit`) |
| Worktree/branch pushed but PR open / unmerged | `/merge` |
| Branches/worktrees already merged into `dev`, still on disk | `/prune` |
| `dev` ahead of `main` | `/release` |
| Clean, nothing in flight | nothing — say so |

**Output Contract nuance — important.** For every *other* github op the deliverable is the
action and the contract says "stay silent". For `inspect` the deliverable **is the report**:
stay silent during the read commands (no play-by-play), then emit exactly one structured report
(the state readout + the recommendation table) and, only if warranted, one `AskUserQuestion`
offering to launch a recommended follow-up. Inline the Output Contract block in the sub-skill the
same way the other sub-skills do, adapted for a read-only op whose output is the report itself.

Keep the report terse and scannable. Prefer showing only non-empty sections (don't print "0
untracked" noise); when everything is clean, say so in one line.

---

## Tasks, in dependency order

Do them on the one branch you are already on (`feat/repo-status-inspect`). The order matters:
the skill content must exist before the registry/catalog reference it, and validate must pass
before you ship.

1. **Author `claude/skills/github/sub-skills/inspect/SKILL.md`** — the read-only inspect
   operation per the Design section above, with an inlined (read-adapted) Output Contract.
2. **Author `claude/skills/github/commands/repo-status.md`** — a thin command in the house style
   (see `commands/prune.md`): frontmatter `description:` + a body that says "Apply the `github`
   skill and execute its `inspect` operation (`sub-skills/inspect`)", notes the cwd is the repo
   under inspection, and that it is read-only and ends with a recommendation.
3. **Add an Operations-table row** to `claude/skills/github/SKILL.md`
   (`| /repo-status | inspect | sub-skills/inspect |`), placed sensibly in the lifecycle order,
   and mention the read-only inspect op wherever the lifecycle sentence lists the operations.
4. **Register `/repo-status`** in `docs/reorg/command-namespace-registry.md` — add a row to
   *Current Bundle Commands* (owner `github`), with a one-line note that it is a read-only
   state-inspection op that recommends ship/merge/release/prune. Follow the format of the
   `/update-service` row added in PR #145.
5. **Regenerate + validate:** run `generate-catalog.ps1 -Force`, confirm the `CATALOG.md` diff is
   scoped to your new command, then run `validate.ps1` and confirm **exit 0**. Fix any failure
   before proceeding.
6. **Ship** via the `/ship` operation (you are already on a conforming `feat/` branch with the
   work committed — so this is ship's *pre-committed* path: commit your changes first with a
   conventional message, then ship → PR into `dev` → merge commit → branch cleanup). Do not
   hand-roll `gh pr create`/`merge`; route through `/ship`.
7. **Push to global** (rollout): after the PR merges and local `dev` is synced, push the updated
   `github` bundle to `~/.claude` via the `/push-skill github` operation so `/repo-status` is live
   machine-wide. Confirm the command file and the `sub-skills/inspect/SKILL.md` landed under
   `~/.claude/skills/github/` (and the command is resolvable). If `/push-skill` is unavailable or
   errors, stop and report — do not hand-copy files blindly.

---

## Delegation

Pin: this session is on **Sonnet** (`claude-sonnet-5`) — good for authoring skill content against
existing templates. Escalate to Opus with `/model` only if the Output-Contract/read-only design
turns genuinely subtle. Keep in the **main session**: the inspect operation's design (which states
to detect, the recommendation mapping, the read-adapted contract), the registry wording, and the
ship/merge sequencing.

Delegate **mechanical** work to `model: "haiku"` subagents (pass `model: "haiku"` explicitly — an
unset model silently inherits Sonnet). Good candidates here:
- reading `sub-skills/prune/SKILL.md` + `sub-skills/ship/SKILL.md` and extracting the exact
  inlined Output-Contract block to adapt;
- grepping `command-namespace-registry.md` to re-confirm no `/repo-status` collision and to copy
  the `/update-service` row format;
- drafting the list of read-only git/gh commands for each detection in the Design section;
- checking the regenerated `CATALOG.md` diff is scoped to the new command.
Dispatch independent lookups in parallel in one message.

**Delegation logging** (required — the ledger's denominator is the step tired sessions drop):
- Log any escalation / redo / dropped subagent task immediately with
  `pwsh -File C:\Users\erik.OPBTA\.claude\skills\continue-new-session-prompt\scripts\log-delegation-outcome.ps1`
  using a `-Category`, a `-FailureMode`, and one line of concrete `-Evidence` — even if you
  recovered in seconds.
- **As a required final step before reporting finished**, log the totals per category:
  `... log-delegation-outcome.ps1 -Outcome ok -Dispatches N -Category <cat> -PromptPath 'C:\development\ai-agent-kit\docs\PROMPTS\2026-08-02-repo-status-inspect.md'`.
  If you delegated nothing, you must still declare that (the retirement gate refuses to run
  without either a correlated tally or an explicit no-delegation declaration).

---

## Finishing

Merge into `dev` (via `/ship`), sync local `dev` to `origin/dev`, complete the global push, then
**report and stop**. Do **not** delete this prompt file — its retirement is a separate,
human-confirmed gate.

## Reporting discipline

Terse. Lead with the result. End every turn with a single numbered list of items that need a
decision; put nothing needing attention anywhere else. Verify any count before you state it. If
you contradict an earlier claim of your own, correct it in one line and move on.
