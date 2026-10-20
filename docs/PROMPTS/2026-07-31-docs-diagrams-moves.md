# Follow-up: build denoted diagrams + execute orphan-doc moves

You are a fresh, unattended Claude Code session. This prompt is self-contained — everything you
need is below. Follow it exactly.

## Orientation

- Repo: `C:\development\ai-agent-kit`. Read and obey the repo's own `CLAUDE.md` and `AGENTS.md`
  exactly (branch/PR rules, project-manager flow, the `github` skill for git ops). Do not restate
  or reinterpret those conventions — follow them.
- **Your worktree and branch already exist. Work there. Do NOT create another.**
  - Worktree: `C:\development\ai-agent-kit\.worktrees\docs-diagrams-moves`
  - Branch: `docs/docs-diagrams-moves` (already branched from `origin/dev` @ `748c845`)
- Model pinned: **Sonnet 5** (`claude-sonnet-5`). Reason: the hardest work here is reviewing each
  drafted diagram for correctness against its source prose — that stays in your main loop. Draft
  work and lookups go to **Haiku** subagents (see Delegation). You may `/model` up to Opus only for
  a diagram whose logic you genuinely cannot verify at Sonnet; say so if you do.

## Hard constraints (unmissable — you run with permissions skipped; this is the only guardrail)

1. **Docs-only.** No changes to `manifest.json`, any `SKILL.md` behavior, or any script logic.
   You are moving/creating markdown and building `diagram.html` artifacts only.
2. **`scripts/validate.ps1` must exit 0 before you open any PR.** Run it from the worktree:
   `pwsh -NoProfile -File ./scripts/validate.ps1`. If it fails, fix the cause; never bypass it.
3. **Zero broken links, zero bad heading-anchors** across every file you touch. Reuse the checker
   in "Verification" below before every PR.
4. **Never append a bare code tag after a link.** E.g. never write `...policy](x.md) (§5)` or
   `...decision](x.md) (D8)`. The whole point of the prior effort was to remove those. Link OR
   gloss, never a dangling `D#/G#/N#/P#/T#/§#/F-KO` code.
5. **Do NOT touch the disposition-ledger data reconcile.** That is a separately-queued chore:
   `docs/tasks/active/chore-disposition-ledger-reconcile-2026-07-31.md`. Leave the ledger's row
   data and counts alone. You may still *build* the ledger's denoted Sankey diagram (Task 1).
6. **Never push to `dev`/`main` directly; never delete them.** Ship through a feature-branch PR via
   the `github` skill's `/ship`.
7. If any task appears to require a forbidden action, **stop and leave a note in your final report**
   rather than improvising.

## State already established (verified this session — do NOT redo)

- The documentation de-jargon effort is **DONE and merged**: PR **#141** → `dev`, merge commit
  **`748c845`**. `dev` == `origin/dev`. Do not re-de-jargon anything.
- 21 files were already cleaned (README cluster + governance cluster). `validate.ps1` was green
  (0 errors), and an automated pass confirmed **0 broken links / 0 bad anchors** at merge.
- The diagram callouts you must build were placed as literal lines:
  `> **▣ Diagram —** <description> *(type: flow|tree|sequence|state|decision|graph|timeline|sankey)*`
  There are roughly **17** of them. **Do not trust that number — grep for the exact set:**
  `git grep -n "▣ Diagram"` from the worktree root. Known host files: `README.md`,
  `scripts/README.md`, `claude/README.md`, `codex/README.md`, `gemini/README.md`,
  `shared/README.md`, `docs/reorg/charter.md`, `docs/reorg/disposition-ledger.md`,
  `docs/reorg/command-namespace-registry.md`, `docs/requirements/canonical-repo.md`,
  `docs/plans/canonical-repo-plan.md`, `docs/plans/template.md`, `docs/workflow/SDLC.md`,
  `docs/workflow/scope-manifest.md`.
- Orphan-doc facts (verified): `docs/rationalization.md` is historical AND contains a stale claim
  that `design-taste-frontend` was deleted (it still exists on disk). `claude/skills/project-manager/`
  holds two loose non-SKILL files — `AUDIT_REPORT.md`, `IMPLEMENTATION_PLAN.md` — that pollute the
  product bundle. `README.md`'s Governance list does not link `CHANGELOG.md` or `ROADMAP.md`.
  `shared/README.md` does not index its sub-READMEs (`shared/{configs,plugins,workflows,prompts}/README.md`).

## Tasks — do Task 2 first (it is small and independent), then Task 1

Rationale: Task 2 is a handful of fast, low-risk file moves + links; Task 1 is the larger
iterative build. Doing Task 2 first banks a clean, quickly-reviewable change and cannot invalidate
Task 1 (the moved files carry no diagram callouts). Single branch is fine. **If the Task 1 diagram
diff grows past the repo's PR-size guidance (see `CLAUDE.md`), split Task 1 into its own second PR**
off `origin/dev` and ship each separately.

### Task 2 — orphan-doc placement moves
1. `git mv docs/rationalization.md docs/reports/archive/rationalization.md`. (Do NOT fix its stale
   `design-taste-frontend` claim — that is a data question outside this docs-only pass; leave a
   one-line note at the top marking it archived/historical if the repo's archive convention wants
   one — check how existing `docs/reports/archive/` files are marked first.)
2. Inspect `claude/skills/project-manager/AUDIT_REPORT.md` and `IMPLEMENTATION_PLAN.md`. If
   superseded/obsolete, delete them; otherwise `git mv` both into `docs/reports/archive/`. Decide
   per their content — state your call in the report.
3. In `README.md`'s Governance list, add links to `CHANGELOG.md` and `ROADMAP.md`.
4. In `shared/README.md`, index the four sub-READMEs (`configs/`, `plugins/`, `workflows/`,
   `prompts/`) as links.
5. **Before moving anything, grep for inbound references** (`git grep -n "rationalization"`,
   `git grep -n "AUDIT_REPORT"`, `git grep -n "IMPLEMENTATION_PLAN"`) and update every link that
   points at a moved file.
- **Done =** files relocated, all inbound links updated, `README`/`shared` links added, checker
  clean, `validate.ps1` exit 0.

### Task 1 — build the denoted diagrams
1. Grep the exact callout set (above). For each, read the surrounding prose so the diagram is
   *correct*, not decorative.
2. Build each as a `diagram.html` artifact following the repo's existing convention — study a few
   existing `diagram.html` files and the `/backfill-diagrams` command before authoring. Match their
   structure/styling; self-contained HTML.
3. Decide the artifact location per the repo convention (a diagram beside its doc, or the standard
   diagram location — follow what `/backfill-diagrams` and existing artifacts do). Update each
   `▣ Diagram —` callout to reference/link its rendered artifact (keep the callout's description).
4. **Draft → review loop:** a Haiku subagent drafts each diagram from the callout + prose; you (the
   Sonnet main loop) review each against the source for correctness and only accept when it matches.
   Iterate. Escalate a single stubborn diagram to Opus only if needed.
- **Done =** every denoted callout has a correct, accepted artifact; checker clean; `validate.ps1`
  exit 0.

## Finishing

- Ship via the `github` skill's `/ship` (feature-branch PR → merge-commit into `dev`), per repo
  rules. If you split into two PRs, ship each. Reference the CAP-IDs / PR template as `CLAUDE.md`
  requires.
- After merge, sync local `dev` to `origin/dev`. **Do not delete this prompt file** — a human
  retirement gate handles that.
- Report and stop.

## Delegation

- Spawn subagents for mechanical work with **`model: "haiku"` passed explicitly** (an unset model
  silently inherits Sonnet). Good candidates here: grepping the callout set and inbound references;
  reading a doc and extracting the prose a diagram must encode; drafting each `diagram.html`;
  cross-checking a built diagram's node/edge labels against the source text; drafting the PR body.
- Keep in your main loop: diagram-correctness review, the move/delete judgment for the two PM
  files, sequencing, and the PR decision. Do not fan out judgment.
- Dispatch independent lookups in parallel in one message.

## Delegation logging (required — this is the ledger's denominator)

Record outcomes with:
`pwsh -NoProfile -File "C:\Users\erik.OPBTA\.claude\skills\continue-new-session-prompt\scripts\log-delegation-outcome.ps1"`

- Whenever you escalate a subagent to a stronger model, redo a subagent's work yourself, or drop a
  task it couldn't finish: log it with `-Category`, a `-FailureMode` from the fixed vocabulary, and
  one line of concrete `-Evidence`. Log even instantly-recovered failures.
- **Required final step, before you report finished:** log the totals — one `-Outcome ok
  -Dispatches N` row per category, each tagged
  `-PromptPath "C:\development\ai-agent-kit\docs\PROMPTS\2026-07-31-docs-diagrams-moves.md"`. Do
  this even if nothing was escalated. Without this denominator the escalation rows are
  uninterpretable, and the retirement gate will refuse to clean up.

## Polling

Only if you watch external state (e.g. a PR merge that isn't immediate), use `/loop 5m <task>`.
Do not wrap already-notifying backgrounded commands in a loop.

## Reporting

Terse. End every turn with a single numbered list of items needing a decision; put nothing that
needs attention anywhere else. Verify counts before stating them. Correct any earlier wrong claim
of your own in one line and move on.
