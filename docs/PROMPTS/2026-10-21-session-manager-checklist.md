# Checklist: replace `session-handoff` with the `session-manager` master bundle

Source: analysis session of 2026-10-21. The user accepted every recommendation and settled these
open questions:

- **Codex/Gemini mirrors: Claude only.** Delete the `codex/` and `gemini/` `session-management`
  mirrors because the new bundle absorbs them. Write no new mirrors.
- **Optional `usage` sub-skill: include it.** Absorb `usage-limit-reducer` and
  `startup-context-audit` now.
- **Charter §4 amendment: yes.** `session-manager` becomes the single owner of session handoff
  and of session-JSONL parsing.
- **Retiring `session-handoff`:** keep a thin `session-handoff` alias bundle for one release. It
  only routes to `session-manager`. Delete it in a later release.

All paths are relative to the repo root (inside the worktree). Every item ends with **Done when**.
Tick a box only after you have checked its Done-when condition.

---

## Phase A: Governance (land first; every later item depends on it)

- [ ] **A1. Amend `docs/reorg/charter.md`.**
  - In §4 Single Owners, set the owner of "Session handoff / 'give me a prompt for the next
    session'" to `session-manager` `handoff`. Set the owner of "Session-JSONL parsing +
    token-efficiency page" to `session-manager` `transcripts` (parser) and `usage` (token page).
  - Reword §3 boundary sentence 1 so `project-manager` keeps single-agent loop composition and
    `agent-manager` keeps multi-agent dispatch and recovery. Session handoff, durable session
    state, and session-JSONL infrastructure move to `session-manager`.
  - Reword sentence 2's "project-manager owns session-plane resumption" to name
    `session-manager`.
  - Add a dated note that says why: handoff already lived outside `project-manager`, and
    `agent-manager` does not exist yet.
  - Charter §3 requires each boundary sentence verbatim in *both* SKILL.md files of its pair.
    Write the reworded sentence into `session-manager/SKILL.md` and `project-manager/SKILL.md`.
    Do not edit `agent-manager`, which does not exist.
  - **Done when:** grep shows each new sentence verbatim in every file the charter names for it,
    and nothing in §4 still names `project-manager` `session-handoff` or `agent-manager`
    `session-jsonl-toolkit`.

- [ ] **A2. Update `docs/reorg/disposition-ledger.md`.**
  - Add or replace rows for `session-handoff`, `spawn-terminal` (standalone, unchanged) and
    `work-resume`. None of these three has a row today.
  - Repoint `analyze-conversations`, `conversation-history-mining-for-domain-knowledge`,
    `recursive-batch-handoff`, `session-management`, `state-file-driven-multi-turn-resumption`
    and `usage-limit-reducer` to `session-manager / <sub-skill>`.
  - Change `startup-context-audit` from standalone to absorb-delete → `session-manager / usage`.
  - Leave `self-paced-loop-iteration`, `iterative-development` and `team-coordination` routed as
    they are.
  - **Done when:** every source skill in Phase C has exactly one ledger row naming its
    `session-manager` destination, and the rows you completed say `done`.

- [ ] **A3. Update `docs/reorg/command-namespace-registry.md`.**
  - Add one row per command in the table in Phase B.
  - Mark `/hand-off-audit`, `/dispatch-session-prompt` and `/continue-new-session` as
    back-compat **aliases**.
  - Change the `/handoff` owner from `project-manager` (lines ~83 and ~113) and from
    `session-handoff` (line ~95) to `session-manager`.
  - **Done when:** each command resolves to exactly one owner, and no alias collides with
    another bundle's command.

## Phase B: Bundle skeleton

- [ ] **B1. Create `claude/skills/session-manager/SKILL.md`.**
  - This master file is a router. Set `category: Foundations & Workflow`, `requires:
    [spawn-terminal]` and `install-target: global`.
  - It states what the bundle owns: the session lifecycle (start: resume; during: checkpoint;
    end: handoff, dispatch, retire; after: audit, mine, delegation-ledger, usage) plus the shared
    transcript parser.
  - It routes to each sub-skill, includes the A1 boundary sentences verbatim, and points to
    `spawn-terminal`, which stays a separate standalone skill.
  - The description must carry the trigger phrases of every absorbed skill so plain-language
    requests still route here. Keep these verbatim from `usage-limit-reducer`: 'hit my limit',
    'running out of tokens', 'which model should I use'. The ledger requires them.
  - **Done when:** the frontmatter parses and the description contains every trigger phrase
    listed in the absorbed skills' descriptions.

- [ ] **B2. Give each sub-skill frontmatter that lets it trigger on its own** (charter §1).
  - Use `claude/skills/session-manager/sub-skills/<name>/SKILL.md`, where `name:` equals the
    directory name.
  - Each description opens with ``Sub-skill of `session-manager`.`` followed by trigger-rich
    text.
  - Follow the `github` bundle's dispatchable sub-skill layout. The old `session-handoff`
    pattern of "read the file, don't dispatch" is the defect being fixed. Check how
    `scripts/push-to-profile.ps1` nests sub-skills and copy the shipped precedent.
  - **Done when:** every sub-skill passes `validate.ps1` and each can be reached directly.

The commands and the sub-skill that owns each one. Every command is a thin file under
`claude/skills/session-manager/commands/`.

| Sub-skill | Commands |
|---|---|
| handoff | `/handoff`; aliases `/dispatch-session-prompt` (scope mode), `/continue-new-session` (copy mode) |
| dispatch | `/dispatch` |
| retire | `/retire-session` |
| checkpoint | `/checkpoint` |
| resume | `/work-resume`, `/work-resume-auto`, `/work-report`, `/work-scan` (names unchanged) |
| audit | `/session-audit`; alias `/hand-off-audit` |
| mine | `/analyze-conversations`, `/mine-sessions` |
| delegation-ledger | `/delegation-report` |
| usage | `/token-report`, `/startup-cost` (name unchanged) |

## Phase C: Sub-skills (each item is one specialist subagent's job)

- [ ] **C1. `transcripts`: shared JSONL library.** Build this first; C6, C7, C8 and C9 depend on it.
  - Create `sub-skills/transcripts/` with a `SKILL.md` aimed at skill authors, not end users.
  - Add `scripts/cc_transcripts.py`, a stdlib-only Python module that provides:
    - project-directory discovery, including worktree path encodings
    - session iteration with `--since` and project-substring filters
    - message and tool_use iteration
    - `subagents/**/*.meta.json` loading
    - the Windows/git-bash path-translation fix
  - Move `references/transcript-data-model.md` here from the audit sub-skill.
  - Bring over every documented gotcha, including the two counting bugs described in
    `mine_dispatches.py`'s docstring.
  - Rewire `mine_dispatches.py`, `analyze-conversations.py`, `resume-scan.py`, `usage-report.py`
    and `startup-context.py` to import it. Each script locates the module with a path relative to
    its own file; do not depend on `PYTHONPATH`.
  - **Done when:**
    - For each rewired script, output on a fixed `--since` window is identical before and after.
      Capture both runs and diff them.
    - The module has unit tests under `scripts/tests/` (or the repo's existing Python test
      location), and they pass.

- [ ] **C2. `handoff`: write the prompt for the next session.**
  - Move the writing steps from `session-handoff/sub-skills/handoff/SKILL.md`: entry modes, item
    recovery, dependency order, prompt sections, delegation instructions and model choice.
  - Add these modes:
    - **launch** (default): hands off to `dispatch`.
    - **scope**: replaces `/dispatch-session-prompt`.
    - **copy**: absorbs `project-manager/sub-skills/continue-new-session`. Prints a copy-ready
      prompt for Claude, Codex or Gemini and launches nothing.
    - **chain**: absorbs `recursive-batch-handoff`. The prompt repeats its own structure: a
      discovery command, one chunk of work, the next handoff, and a sequence number.
  - Adopt these ideas from the web survey:
    - Tag every state claim `[V]` (verified this session) or `[?]` (recalled), following the
      `claim-discipline` skill.
    - Add a required "What we tried / dead ends" section.
    - When context is getting heavy, offer a handoff in one sentence and do not start one
      automatically.
  - **Done when:** the evals in `evals/evals.json` cover all four modes, and a dry-run of each
    mode against a sample scope produces a well-formed prompt file.

- [ ] **C3. `dispatch`: worktree, launch and verification.**
  - Move `new-task-worktree.ps1` and `launch-claude-session.ps1`. Move the steps for worktree
    creation, launch, environment variables, `-SetEnv` model pinning, tab colour, the WT-absent
    fallback and PID verification.
  - The launcher resolves `spawn-terminal.ps1` with a `$PSScriptRoot`-relative path. Recompute
    it for the new nesting depth and keep the clear error when the skill is missing.
  - `/dispatch <prompt-file>` launches any prompt file, not only ones `handoff` wrote.
  - **Done when:** `launch-claude-session.ps1 -DryRun` succeeds from the new location against
    the archive layout, and the "spawn-terminal not found" error still fires when the skill is
    absent.

- [ ] **C4. `retire`: cleanup gate.**
  - Move `complete-task-session.ps1` and its five gate checks.
  - Keep `-Confirmed` as a human-only gate.
  - It must find the delegation ledger script through the C8 sub-skill's new path.
  - **Done when:** running it without `-Confirmed` against a throwaway merged branch prints all
    five checks and deletes nothing.

- [ ] **C5. `checkpoint`: durable session state.**
  - Absorb `session-management` (tiered summaries and the current-state.md/decisions.md layout)
    and `state-file-driven-multi-turn-resumption` (one step per turn, recorded evidence, a resume
    prompt).
  - Merge them into one state-file convention. Do not keep two.
  - Cut `session-management`'s 531 lines down to the procedure and remove the generic filler.
  - Leave loop composition alone. `self-paced-loop-iteration` and `iterative-development` stay
    routed to `project-manager` `loop-prompt-composer`.
  - **Done when:** the sub-skill is under about 200 lines, and every rule from both sources is
    either kept or listed as deliberately dropped in the PR description.

- [ ] **C6. `resume`: pick up where the user left off.**
  - Absorb the whole `work-resume` bundle: its SKILL.md, README, four commands and
    `resume-scan.py`, rewired onto C1.
  - Add an optional SessionStart hook snippet that injects the newest handoff/checkpoint file.
    Document it only; do not install it.
  - **Done when:** `resume-scan.py` output is unchanged (C1's check) and all four commands load
    this sub-skill.

- [ ] **C7. `audit`: check past sessions against a stated rule.**
  - Move `session-handoff/sub-skills/audit`: SKILL.md, evals, `report-template.md` and
    `mine_dispatches.py` rewired onto C1.
  - Rename frontmatter `name: compliance-audit` to `audit`. Keep "compliance audit" as a
    trigger phrase.
  - Keep it read-only.
  - **Done when:** the evals still pass their assertions, and `/session-audit` and
    `/hand-off-audit` both load it.

- [ ] **C8. `mine`: find patterns in session history.**
  - Absorb `analyze-conversations` as friction mode and
    `conversation-history-mining-for-domain-knowledge` as knowledge mode.
  - Add an option that turns repeated corrections into proposed (never applied) CLAUDE.md or
    rule patches, in the style of claude-reflect.
  - Mention the built-in `/insights` command. This sub-skill covers what `/insights` does not:
    checking against a specific rule (hand that to `audit`) and extracting domain knowledge.
  - **Done when:** friction mode reproduces the original extractor's report on a fixed window.

- [ ] **C9. `delegation-ledger`: record and report delegated work.**
  - Move `log-delegation-outcome.ps1` and `delegation-report.ps1`, plus the "Delegation logging"
    rationale from the handoff SKILL.md.
  - The ledger path `~/.claude/telemetry/delegation-outcomes.jsonl` does not change.
  - **Done when:** `delegation-report.ps1` produces the same report from the new path, and the C4
    retire gate still credits a tally tagged with `-PromptPath`.

- [ ] **C10. `usage`: token cost.**
  - Absorb `usage-limit-reducer` (historical burn, `usage-report.py`, the 11 rules) and
    `startup-context-audit` (startup baseline, `startup-context.py`, `/startup-cost`).
  - Rewire both scripts onto C1.
  - Keep the verbatim trigger phrases (see B1).
  - **Done when:** both scripts' output is unchanged on a fixed window, and `/token-report` and
    `/startup-cost` both load this sub-skill.

## Phase D: Retire, rewire, regenerate

- [ ] **D1. `session-handoff` alias bundle.**
  - Shrink `claude/skills/session-handoff/` to a router SKILL.md with `status: deprecated` and a
    note to remove it next release.
  - It routes to `session-manager` and contains no sub-skills, scripts or commands. The commands
    have moved.
  - **Done when:** the directory holds only SKILL.md (plus a regenerated diagram, if the
    generator requires one).

- [ ] **D2. Delete the absorbed skill directories** (git history is the archive):
  - `analyze-conversations`
  - `conversation-history-mining-for-domain-knowledge`
  - `recursive-batch-handoff`
  - `session-management`
  - `state-file-driven-multi-turn-resumption`
  - `work-resume`
  - `usage-limit-reducer`
  - `startup-context-audit`
  - `project-manager/sub-skills/continue-new-session` and its command file. The command moves to
    a `session-manager` alias.
  - the Codex and Gemini `session-management` mirrors
  - **Done when:** none of these paths exist and nothing in the repo still links to them.

- [ ] **D3. Rewrite references across the repo.**
  - Grep the whole repo (skills, commands, instructions, `shared/guardrails`, docs, scripts,
    `README.md`, `CLAUDE.md`, `AGENTS.md`) for every deleted name and old script path.
  - Rewrite each to its `session-manager` equivalent. This includes `spawn-terminal`'s
    references to `session-handoff:handoff`, and `project-manager/SKILL.md`'s references to
    `continue-new-session`.
  - Do not edit `docs/tasks/archive/**`, `docs/PROMPTS/**`, `docs/reports/**` or
    `CHANGELOG.md`. They are historical records.
  - **Done when:** the grep finds no live references outside those historical paths.

- [ ] **D4. `STANDARD_SKILLS` in `scripts/generate-manifest.py`.**
  - If `session-handoff` or any absorbed skill is in `STANDARD_SKILLS`, replace it with
    `session-manager`. Make sure `spawn-terminal` comes along through `requires:`.
  - **Done when:** `bootstrap-profile.ps1` (preview mode) lists `session-manager` and
    `spawn-terminal`.

- [ ] **D5. Diagrams.** Generate a `diagram.html` for the master bundle and each sub-skill that
  needs one, following the repo's diagram standard (see `/backfill-diagrams`).
  - **Done when:** `/audit-skills` reports no missing diagrams for `session-manager`.

- [ ] **D6. Regenerate generated files.** Run `scripts/generate-manifest.py` and
  `scripts/generate-catalog.ps1`. Never hand-edit `manifest.json` or `CATALOG.md`.
  - **Done when:** both are regenerated and the diff contains only the expected rows.

## Phase E: Verify and ship

- [ ] **E1.** `pwsh ./scripts/validate.ps1` exits 0. Run the repo's Python and Pester tests,
  plus every Done-when check above.
- [ ] **E2.** A read-only `/audit-skills` run shows no new findings for the bundles you touched.
- [ ] **E3.** Rebase onto `origin/dev`, then use `/ship` to open a PR to `dev` and merge it with
  a merge commit.
  - The PR description has a Summary and a Test Plan, cites the task file, and lists the rules
    deliberately dropped in C5.
  - The PR does **not** carry follow-up work outside this repo (F1).

## F: Follow-ups (outside this repo; never done by the orchestrator)

- [ ] **F1.** Update the installed copies, to be run by a human after merge:
  - `/push-skill session-manager` and `/push-skill spawn-terminal`. `spawn-terminal` is
    currently **not** installed globally, and the installed `session-handoff` launcher fails
    without it.
  - Then `/update-skill` across the projects that have absorbed skills installed. This is the
    sweep charter §2.2 requires.
- [ ] **F2.** Next release: delete the `session-handoff` alias bundle and the three command
  aliases.
