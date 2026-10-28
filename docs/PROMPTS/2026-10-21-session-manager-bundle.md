# Handoff: build the `session-manager` master bundle (orchestrator session)

You are the **orchestrator**. You start this session with no conversation history, so everything
you need is in this file and in the checklist it references. Your job is to:

1. Turn the checklist into a task file and commit it.
2. Dispatch a specialist subagent for each checklist item, in dependency order.
3. Verify each subagent's result yourself.
4. Ship a single PR into `dev`.

## Model

This session is pinned to `claude-opus-5-5`. I chose it because the hardest items need
architectural judgment: the charter amendment (A1), the shared transcript-library refactor (C1)
that five scripts depend on, and merging two state-file conventions (C5). Keep design, sequencing
and verification in this main session.

## Orientation

- **Repo:** `C:\development\ai-agent-kit`.
- **Your worktree already exists:** `C:\development\ai-agent-kit\.worktrees\session-manager-bundle`
  on branch `refactor/session-manager-bundle`, branched from `origin/dev` @ `188ae87`.
  - You were launched inside it. Work only there.
  - Do **not** create another worktree or branch.
  - Subagents also work in this worktree. Give each one the absolute worktree path.
- Read the repo's `CLAUDE.md` and `AGENTS.md` and follow them exactly.
- Read `docs/reorg/charter.md`, which is binding for skill PRs. Item A1 amends it.
- **The work list** is
  `C:\development\ai-agent-kit\docs\PROMPTS\2026-10-21-session-manager-checklist.md`.
  - It is in the *main checkout*, not your worktree. Read it with that absolute path.
  - It is the scope authority for this run. Every item has a "Done when"; that is your
    acceptance test.

## Hard constraints (read these first)

This session runs with `--dangerously-skip-permissions`. These rules are the only guardrail.

- **Never push to `dev` or `main`, and never commit on them.** All changes reach `dev` only
  through one PR from `refactor/session-manager-bundle`, merged with the `/ship` flow (merge
  commit).
- **Never delete the `dev` or `main` branches.** Never force-push anything except your own
  feature branch, and only with `--force-with-lease` after rebasing.
- **Never write outside the worktree.** The one exception is the final fast-forward of the main
  checkout's `dev` (see Finishing).
  - Do not touch `~/.claude/` at all: no `/push-skill`, no `/install-skill`, no `/update-skill`,
    and no `push-to-profile.ps1 -Force`. Checklist item F1 is the human's job.
  - The only allowed write under `~/.claude/` is the delegation-ledger script, which appends to
    `~/.claude/telemetry/`.
- **Do not modify transcripts** under `~/.claude/projects/`. Read them only, for the before/after
  output checks.
- **Never hand-edit `manifest.json` or `CATALOG.md`.** Regenerate them.
- **Do not run `git commit --no-verify`.** If a hook fails, fix the cause.
- **Do not delete either prompt file** (this one or the checklist). The retirement gate does that
  after a human reviews the work.
- If any item seems to require a forbidden action, or would contradict the charter in a way A1
  does not cover, **stop and report**. Do not improvise.

## State already established (do not re-derive)

Tags: [V] = verified in the analysis session. [?] = recalled or unverified, so confirm it before
relying on it.

- [V] `session-handoff` has two sub-skills, `handoff` and `audit`. Commands: `/handoff`,
  `/dispatch-session-prompt`, `/hand-off-audit`.
  - The audit sub-skill's frontmatter says `name: compliance-audit`.
  - Neither sub-skill can be dispatched directly; this violates charter §1.
  - Handoff scripts: `complete-task-session.ps1`, `delegation-report.ps1`,
    `launch-claude-session.ps1`, `log-delegation-outcome.ps1`, `new-task-worktree.ps1`.
  - Audit files: `mine_dispatches.py`, `references/{report-template,transcript-data-model}.md`,
    `evals/evals.json`.
- [V] Five Python scripts each parse `.jsonl` transcripts on their own:
  - `session-handoff/sub-skills/audit/scripts/mine_dispatches.py`
  - `analyze-conversations/references/analyze-conversations.py`
  - `work-resume/references/resume-scan.py`
  - `usage-limit-reducer/scripts/usage-report.py`
  - `startup-context-audit/scripts/startup-context.py`
- [V] The ownership conflict that A1 resolves:
  - Charter §4 assigns session handoff to `project-manager` `session-handoff`, and session-JSONL
    parsing to `agent-manager` `session-jsonl-toolkit`.
  - `agent-manager` does not exist.
  - `command-namespace-registry.md` names a `/handoff` owner at lines ~83, ~95 and ~113.
- [V] `session-handoff`, `spawn-terminal` and `work-resume` have no rows in
  `disposition-ledger.md`.
- [V] `launch-claude-session.ps1` finds `spawn-terminal.ps1` with
  `$PSScriptRoot\..\..\..\..\spawn-terminal\scripts\spawn-terminal.ps1`. `spawn-terminal` is
  **not** installed in `~/.claude/skills`, which is why the analysis session launched you from the
  archive copy.
- [V] The only Codex/Gemini mirror in this cluster is `session-management`.
- [V] The user's decisions: Claude only (delete the session-management mirrors), include the
  `usage` sub-skill, amend the charter, keep a thin `session-handoff` alias for one release.
- [?] `scripts/guard-pm-flow.ps1` runs as a pre-commit guard that requires an active task file.
  Read it before your first commit.
- [?] `STANDARD_SKILLS` in `scripts/generate-manifest.py` may include `session-handoff`. Check it.

## Tasks, in order

**Step 0: Task file, committed first.**
- Read one existing task file in `docs/tasks/active/` to learn the frontmatter format.
- Create `docs/tasks/active/refactor-session-manager-bundle.md` in the worktree. Its body is the
  full checklist.
- Commit it as `chore: add session-manager bundle task`, so every later commit traces to an
  active task.
- Tick boxes in this file as items pass their Done-when checks.
- At the end, append the `## Completion` sentinel and move the file to `docs/tasks/archive/` as
  the repo's project-manager flow requires.

**Phase A (A1 → A2 → A3): governance.**
- Do this in the main session or with one Sonnet subagent, then review the diff yourself.
- It goes first because every later item cites the ownership it sets. If you author sub-skills
  before the boundary sentences are fixed, you will have to edit all of them again.

**Phase B (B1, B2): skeleton.** Create the bundle directory, the master SKILL.md, empty sub-skill
directories, and the command table. It goes before C because every C-item subagent needs to know
where its files belong.

**Phase C: one specialist subagent per item.**
- **C1 (`transcripts`) must merge into the branch first.** C6, C7, C8 and C10 rewire their
  scripts onto it; if they run before it exists, each one builds its own parser.
- Before C1, capture "before" output of all five scripts on one fixed `--since` window and save
  it under the session scratch directory. Do this with a Haiku subagent.
- After C1, dispatch **C2–C10 in parallel in a single message**. They write to separate
  sub-skill directories.
  - Exceptions: C3 must finish before C4, because C4 resolves scripts through it. C9 must finish
    before C4's gate check.
  - So run C4 after C3 and C9.
- Give each specialist:
  - the worktree path
  - its checklist item, quoted in full
  - the B2 frontmatter rule
  - its allowed file paths: its own sub-skill directory, plus the source directories it absorbs
    (read only; deletion happens in D2)
  - the instruction to report the files it changed and the results of its Done-when checks
- **Specialists do not commit.** You review each result against its Done-when, then commit it
  atomically, for example `refactor: add session-manager transcripts library`.

**Phase D (D1 → D2 → D3 → D4 → D5 → D6).**
- Deletions and reference rewrites run after every sub-skill exists, so nothing points at a gap.
- The manifest and catalog are regenerated last, because each earlier step changes what they
  list.

**Phase E.**
- Run `pwsh ./scripts/validate.ps1` and the test suites. Every Done-when must hold.
- Run `git fetch origin && git rebase origin/dev`, then `/ship` (PR to `dev`, merge commit).
- PR body: `## Summary` and `## Test Plan`. Reference the task file and the reorg CAP-IDs, if
  the PR template asks for them. List the rules deliberately dropped in C5. Under "Follow-ups
  (human)", list checklist items F1 and F2.

## Delegation

Specialist agents implement and the main session judges.

**Sonnet** (`model: "sonnet"`, passed explicitly every time) for authoring:
- the C2–C10 sub-skills
- reference rewrites that need judgment (D3)

**Haiku** (`model: "haiku"`, passed explicitly; a subagent with no model inherits Opus) for
mechanical work:
- capturing and diffing the before/after script output
- grep sweeps for leftover references
- regenerating the manifest and catalog
- running `validate.ps1` and reporting failures
- checking frontmatter prefixes across sub-skills
- confirming that deleted paths are gone

**Keep in the main session:**
- the A1 charter wording
- the C1 API design (review it before fan-out)
- the C5 merge of the two state-file conventions (decide what to drop)
- resolving any conflict between specialists
- final review of every diff before you commit it

Run independent lookups and specialists in parallel, in one message.

**Delegation logging** is required. Use the *installed* script. The archive copy is deleted by
this very PR and disappears from the main checkout when `dev` syncs.

```
pwsh -File C:\Users\erik30\.claude\skills\session-handoff\sub-skills\handoff\scripts\log-delegation-outcome.ps1 ...
```

- **Log every failure:** an escalation to a stronger model, work you redo yourself, or a dropped
  subagent task. Pass `-Category` (`search|extract|summarize|edit|test-run|verify|docs|other`),
  `-Model`, `-Outcome escalated|redone-by-parent|failed`, a `-FailureMode`, and one line of
  concrete `-Evidence`. Log it even if you recovered in seconds.
- **Required final step**, the last thing before you report finished: one totals row per category
  and model, `-Outcome ok -Dispatches N`, **each tagged**
  `-PromptPath 'C:\development\ai-agent-kit\docs\PROMPTS\2026-10-21-session-manager-bundle.md'`.
  Without these tagged totals, the retirement gate refuses to clean up.

## Polling

None of this work waits on external state, so do not use `/loop`. Background commands notify you
when they finish.

## Finishing

1. Once `/ship` has merged the PR into `dev`, fast-forward the main checkout:
   `git -C C:\development\ai-agent-kit pull --ff-only` (it is on `dev`).
   - Its untracked `docs/PROMPTS/2026-10-21-*` files are expected. Leave them alone.
   - If the fast-forward fails, stop and report. Do not reset.
2. Log the delegation totals (see above).
3. Report briefly:
   - PR number and URL, and the merge commit
   - the final checklist with a pass/fail for each item
   - the line count of the diff
   - rules dropped in C5
   - anything deferred, with the reason
   - follow-ups F1 and F2
   Then stop.
4. Do **not** delete the worktree, the branch, or either prompt file. The human runs the
   retirement gate after reviewing.

## Reporting style

- Keep it short. Check every count before you state it.
- If an earlier claim turns out wrong, correct it in one line.
- End each turn with one numbered list of items that need a human decision. If there are none,
  say "none".
