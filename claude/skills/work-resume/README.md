# work-resume

Pick up where you left off. `work-resume` scans a repo's recent Claude Code
sessions (across all of its git worktrees), reconstructs what each session
expected to happen next, reconciles that against real git state and approved
plans, and proposes the single best thing to resume — either stopping for your
approval or auto-continuing.

This README documents the bundle for maintainers. The runtime instructions live
in `SKILL.md` and the three sub-skills; this file explains **why** the pieces are
shaped the way they are and how to extend them (including porting to other
agent runtimes).

---

## The problem it solves

You walk away mid-task and come back — maybe hours later, maybe in a fresh
terminal, maybe the last real work happened inside a throwaway worktree. The
questions are always: *what was in flight, did it finish, and what's next?*
Answering by hand means trawling JSONL transcripts and cross-checking git. This
skill automates the trawl and leaves the judgment to the agent.

## Architecture — the funnel

The design mirrors the sibling `analyze-conversations` skill: a committed script
does only the **mechanical** reduction, and the agent does the **judgment**.

```
references/resume-scan.py        →  SKILL.md (orchestrator)
  locate transcripts                classify each session's resumption state
  (git-authoritative, all              (completed / optional-next / interrupted
   worktree conventions)               / awaiting-operator)
  stream + digest each             →  reconcile top candidate(s) with git
  (bounded, a few KB)                 (claim vs proof)
                                   →  ranked shortlist + AskUserQuestion pick
                                   →  resume brief (stop) OR auto-resume
                                      └─ nothing to resume → plan-nextstep
```

**Why split this way:** "what was expected next" is a reading task — a script
that tried to classify it with keyword rules would be brittle and wrong. So the
script never classifies; it surfaces bounded evidence (last assistant turn,
initiating goal, mid-action flags, edited files) and the agent reads it. Only a
few KB per run enters context, never the raw hundreds of MB of JSONL.

## Components

### `references/resume-scan.py` (the mechanical core)

Read-only. Prints JSON (default, for the skill) or Markdown (for `/work-scan`).

- **Worktree correlation is git-authoritative, not name-based.** This workstation
  uses three worktree conventions — in-repo `<repo>/.worktrees/<name>`, sibling
  `<repo>-wt/<name>`, and shared containers (`C:\development\.worktrees\`,
  `C:\development\github-repos-wt\`) that hold *several* repos' worktrees. Because
  the shared containers don't embed the origin repo in their path, the script
  correlates on **git-common-dir** (every worktree of a repo shares the main
  checkout's `.git`). Sources unioned: the main checkout, `git worktree list`
  (live + prunable, any location), and a pruned-recovery pass that attributes
  leftover worktree-shaped project dirs by identity. See
  `sub-skills/transcript-forensics/SKILL.md` for the full reasoning and the one
  unrecoverable edge (pruned + shared-container + directory deleted).
- **Windows** (recall window), reused from `analyze-conversations`: `smart`
  (default — newest-first, last 21 days, clamped to 6–15 sessions), `Nd`, `Ns`,
  `YYYY-MM-DD`, `all`. Oldest past `--max-files` are dropped and reported, never
  silently truncated.
- **Per-session digest fields:** `first_prompt`, `last_prompt`,
  `last_assistant_tail`, `ended_mid_action`, `last_event_kind`, `last_tool`,
  `recent_edit_files` (absolute — reveals cross-repo excursions), `branch`,
  `worktree_path`, `cwd`.

### `SKILL.md` (the orchestrator)

Routes the pipeline and owns the **interaction model**: a ranked shortlist, a
recommended thread, and the choice posed via `AskUserQuestion` (baked in by
design — see below). Ranking floats the most resumable state up
(`interrupted-mid-implementation` > `awaiting-operator` >
`completed-with-optional-next` > `completed`), ties broken by recency.

### Sub-skills (isolated domain expertise)

| Sub-skill | Domain |
|---|---|
| `transcript-forensics` | Locating transcripts across worktree conventions; the digest fields; the 4-state classification rubric; cross-repo-excursion and continued-session traps; reading extra turns without loading a whole file. |
| `git-state-reconcile` | Turning a last-turn *claim* into ground truth: local/staged/committed/pushed/merged classification, the reconciliation decision table, and the source-vs-artifact distinction (a dirty tree of generated files is not unfinished work). |
| `plan-nextstep` | What to offer when nothing is mid-flight: gated on `pm-profile.yml` in the main checkout root → project-manager tasks/plans, else the most actionable git signal. |

Each is a delegate reference module the orchestrator points into as needed, so
the SKILL.md body stays under ~200 lines and each domain can evolve
independently.

### Commands (thin wrappers)

| Command | Mode | Behavior |
|---|---|---|
| `/work-resume` | propose-and-stop (default) | Full pipeline → shortlist → pick → resume brief → **stop for approval**. |
| `/work-resume-auto` | auto | Skip the picker; take the top candidate and start executing immediately. |
| `/work-report` | read-only | Ranked snapshot + next approved action; no execution, no git mutation, no prompt. |
| `/work-scan [window]` | inspection | Dumps `resume-scan.py --format md`; optional recall window. Transparent debug view. |

## Key design decisions (and why)

1. **Ranked shortlist → AskUserQuestion pick**, not a single auto-chosen thread.
   The operator sees what was skipped and why, and picks with a click. A "None /
   show next approved action" option always routes to `plan-nextstep`.
2. **AskUserQuestion prompting is baked into the skill** (not left to the host).
   Chosen deliberately so an installed copy prompts consistently. If you port
   this for a team that doesn't share that convention, relax it to neutral
   markdown output.
3. **Git identity over name matching** for worktrees — the only correct way to
   attribute shared-container worktrees without cross-contamination.
4. **Never manufacture a candidate.** "Everything's shipped, here's the next
   planned task" is a complete answer; so is "you're caught up."

## Business logic reference

- **Resumption states:** completed · completed-with-optional-next ·
  interrupted-mid-implementation · awaiting-operator. (`transcript-forensics`.)
- **Reconciliation table:** maps `last-turn claim × git reality` → verdict + next
  action. (`git-state-reconcile`.)
- **Plan gate:** `pm-profile.yml` in the main checkout root selects
  project-manager mode vs git-signal mode. (`plan-nextstep`.)

## Compatibility / dependencies

- Python 3 (standard library only) and `git` on PATH; `gh` for PR reconciliation.
- Reads `~/.claude/projects/<slug>/*.jsonl` — the Claude Code transcript layout.
  **This locator is Claude-Code-specific**, which is why the bundle currently
  ships for Claude only.

---

## Porting to another runtime (Codex / Gemini) — re-prompt

The skill is Claude-only today because `resume-scan.py`'s transcript locator is
hard-wired to Claude Code's `~/.claude/projects/<slug>/*.jsonl` layout and event
schema. Only the **locator + digest** layer is runtime-specific; the
orchestration, classification, reconciliation, and plan logic are runtime-neutral.

To produce a `codex/skills/work-resume` (or `gemini/…`) variant later, hand an
agent this prompt:

> Port the `work-resume` skill (`claude/skills/work-resume/`) to the **Codex CLI**
> runtime as `codex/skills/work-resume/`. Only the transcript-locator layer is
> runtime-specific — keep the funnel architecture, the four resumption states,
> the git-authoritative worktree correlation, the reconciliation decision table,
> the `pm-profile.yml` plan gate, and the four commands unchanged.
>
> 1. Determine where Codex CLI stores its conversation transcripts on this
>    workstation, their on-disk layout (per-session file? directory-per-repo?
>    how is the repo/cwd encoded in the path?), and their record schema (how a
>    turn's role, text, tool calls, timestamp, cwd, and git branch are
>    represented). Verify by inspecting real files, not assumption.
> 2. Rewrite `references/resume-scan.py`'s locator + digest functions
>    (`slugify`/project-dir derivation, `worktree_slugs`, `_session_cwd`,
>    `digest_session`, the injected-content filter) to that schema, preserving
>    the exact output contract (`{meta, sessions[]}` with the same field names)
>    so the SKILL.md and sub-skills need no changes.
> 3. Keep git worktree correlation identical — it depends on git, not the runtime.
> 4. Update this README's Compatibility section and add the runtime to
>    `manifest.json` via the generate scripts.
> 5. Prove it on two real repos (one with worktrees) before archiving, then run
>    `python scripts/generate-manifest.py` + `pwsh ./scripts/generate-catalog.ps1
>    -Force` + `pwsh ./scripts/audit.ps1`.

The same prompt works for Gemini CLI — substitute the runtime name and its
transcript store.

## Regenerating archive metadata after any change

```bash
python scripts/generate-manifest.py
pwsh ./scripts/generate-catalog.ps1 -Force
pwsh ./scripts/audit.ps1          # read-only health check
```

`CATALOG.md` and `manifest.json` are generated — never hand-edit them.
