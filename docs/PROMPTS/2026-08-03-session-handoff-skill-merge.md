# Handoff — Consolidate `continue-new-session-prompt` + `compliance-audit` into one `session-handoff` skill

You are building a new skill by **merging two existing, already-working skills** into one
umbrella — not designing from scratch. Both source skills are mature and battle-tested; your
job is architecture/relocation/routing, not re-inventing either one's actual logic. Where this
prompt says "verbatim," it means it — the wording it points at was arrived at through real
iteration this session and rewriting it from memory will silently regress it.

Your worktree and branch **already exist**. Work in them, do **not** create another:

- **Worktree:** `C:\development\ai-agent-kit\.worktrees\session-handoff-skill-merge`
- **Branch:** `feat/session-handoff-skill-merge` (off `origin/dev`)

**Orientation.** Read this repo's own `CLAUDE.md`/`AGENTS.md` (root of the main checkout, not
the worktree) and follow its conventions exactly — branch naming, PR process, commit format,
whatever it specifies. Do not assume ac-repo-radar's conventions apply here; this is a
different repo with its own rules. If anything below conflicts with what you read there,
the repo's own file wins and you should flag the conflict in your final report.

---

## Hard constraints (read first)

1. **Do not touch `continue-new-session` (no `-prompt` suffix).** That is a different,
   separate skill — a lighter "generate a copy-paste prompt" flow, not the terminal-spawning
   mechanism. It is explicitly **out of scope**. Do not merge it, reference it, or modify its
   commands.
2. **Do not delete or modify the existing GLOBAL skills** at `~/.claude/skills/continue-new-session-prompt/`
   or `~/.claude/skills/compliance-audit/`, or their standalone commands, as part of this task.
   Build the new consolidated skill **alongside** them. Retiring the old ones is a **separate,
   not-yet-approved decision** — report it as an open item for the user, do not act on it
   unilaterally. (Rationale: `continue-new-session-prompt` is the exact mechanism that is
   currently running to deliver this very prompt to you — breaking it before the replacement is
   verified would be self-defeating, and it has real dependents you may not have full visibility
   into.)
3. **Do not merge the PR you open without explicit human confirmation.** Open it, leave it
   for review, per the repo's own PR workflow (see Orientation).
4. **Do not delete this prompt file.** The retirement gate in Step 7 (of the skill mechanism
   that produced you) requires a human confirmation you cannot evaluate on your own behalf.
5. If anything here appears to require a forbidden action, stop and say so in your final report
   rather than improvising around the constraint.

---

## State already established (verified this session — do not re-derive)

- **Archive convention, confirmed by direct inspection:** skills live at
  `claude/skills/<name>/` in this repo (no leading dot — that's the archive copy; `.claude/skills/`
  is this *repo's own* operative skills, a different, much smaller set). Each skill bundle
  carries its own `commands/*.md` subdirectory (thin commands travel with the skill, not in a
  separate top-level location) and optionally `scripts/`, `references/`, `diagram.html`.
- **`continue-new-session-prompt` already has a canonical archive copy** at
  `claude/skills/continue-new-session-prompt/` (SKILL.md + `commands/continue-new-session-prompt.md`
  + `commands/dispatch-session-prompt.md` + `commands/repo-color.md` + `scripts/*.ps1` +
  `diagram.html`). This is the **source of truth** to pull from — not the deployed global copy
  (they should be identical, but the archive is canonical per this repo's own stated purpose).
- **`compliance-audit` has NO archive copy** — it was authored directly into the global profile
  this session (`~/.claude/skills/compliance-audit/`: `SKILL.md`, `scripts/mine_dispatches.py`,
  `references/transcript-data-model.md`, `references/report-template.md`) and never synced. Pull
  from the global copy directly.
- **`compliance-audit`'s frontmatter `description` went through 4 rounds of adversarial subagent
  review this session** to fix real triggering bugs (a missing scope boundary vs. codebase
  audits, a collision with `usage-limit-reducer`, a collision with `security-review`, missing
  live-session coverage, redundant examples). **Copy it verbatim into the new sub-skill's
  frontmatter. Do not paraphrase, shorten, or "clean up" this text** — every clause in it is
  there because a specific realistic phrasing broke without it.
- **This harness supports directly-addressable sub-skills** via `parent:child` naming (confirmed
  present in the live skill list this session, e.g. `interface-design:audit`,
  `visual-explainer:diff-review`) — each with its own independently-loaded description. This is
  the mechanism to use, not a single monolithic SKILL.md.
- **`dispatch-session-prompt` is not a separate skill** — it's an alternate *entry mode* of
  `continue-new-session-prompt` itself (see that skill's own "Entry modes" section: continue
  mode vs. scope mode, identical from Step 2 onward). It moves together with the handoff
  sub-skill; do not treat it as independent.

---

## Target structure

```
claude/skills/session-handoff/
├── SKILL.md                       # lightweight router: what this umbrella covers, the two
│                                   # sub-skills, and a one-paragraph "which one do I want"
│                                   # disambiguator. Keep this short — it is not where the
│                                   # actual logic lives.
├── sub-skills/
│   ├── handoff/
│   │   ├── SKILL.md               # = continue-new-session-prompt's SKILL.md content, moved
│   │   │                          #   verbatim (adjust only internal path references, see
│   │   │                          #   Task 3 below)
│   │   ├── scripts/*.ps1          # all scripts from the source skill, moved as-is
│   │   └── diagram.html           # moved as-is
│   └── audit/
│       ├── SKILL.md               # = compliance-audit's SKILL.md content, moved verbatim
│       ├── scripts/mine_dispatches.py
│       └── references/
│           ├── transcript-data-model.md
│           └── report-template.md
├── commands/
│   ├── continue-new-session-prompt.md   # repointed: "Invoke the `session-handoff:handoff`
│   │                                    #  skill and follow it exactly." (continue mode)
│   ├── dispatch-session-prompt.md       # repointed, scope mode — same pattern
│   ├── repo-color.md                    # repointed (still describes the tab-coloring feature,
│   │                                    #  which belongs to the handoff sub-skill)
│   └── hand-off-audit.md                # repointed: "Invoke the `session-handoff:audit` skill..."
```

Naming is your one open design call if something clearly better emerges while building — but
default to `session-handoff` as the umbrella name and `handoff`/`audit` as the two sub-skill
names unless you find a concrete reason not to (this session cannot approve a rename mid-flight
since it is not attended).

---

## Tasks, in order

**Task 1 — Read the source material.**
Read `claude/skills/continue-new-session-prompt/SKILL.md` (archive copy) in full, and
`~/.claude/skills/compliance-audit/SKILL.md` + its two reference files in full. Do not
paraphrase from a partial read — both are dense and the details matter (e.g.
`continue-new-session-prompt`'s retirement-gate five conditions, `compliance-audit`'s
three mining-strategy branches).

**Task 2 — Scaffold the target structure** exactly as shown above, under
`claude/skills/session-handoff/` in this worktree.

**Task 3 — Move `continue-new-session-prompt`'s content into `sub-skills/handoff/`.**
Copy `SKILL.md` verbatim, then fix only what must change because the path moved:
- Any place the source SKILL.md says `<skill-dir>` should still resolve correctly — the
  convention ("this bundle's own directory... when installed to the global profile") already
  handles this correctly as long as `<skill-dir>` continues to mean "wherever this skill
  bundle ends up" (i.e. after `push-skill`, `~/.claude/skills/session-handoff/sub-skills/handoff`).
  Update the worked example paths (the `pwsh -File <skill-dir>/scripts/...` lines) to show the
  new nested path shape so a future reader isn't confused by the extra `sub-skills/handoff`
  segment.
- Move `commands/continue-new-session-prompt.md`, `commands/dispatch-session-prompt.md`, and
  `commands/repo-color.md` into the new skill's top-level `commands/` (per the target
  structure — commands live at the `session-handoff` bundle level, not nested under
  `sub-skills/handoff/commands/`), and change their body text from "Invoke the
  `continue-new-session-prompt` skill" to "Invoke the `session-handoff:handoff` skill."
- Move `scripts/*.ps1` and `diagram.html` as-is into `sub-skills/handoff/`.

**Task 4 — Move `compliance-audit`'s content into `sub-skills/audit/`.**
Copy `SKILL.md` verbatim — **frontmatter description included, unedited** (see State
Established above). Move `scripts/mine_dispatches.py` and both `references/*.md` files as-is.
Update the one internal reference in `SKILL.md` that points at `~/.claude/skills/compliance-audit/`
paths (the "Reference files" section at the bottom) to the new nested location. Create/move
`commands/hand-off-audit.md` (currently at the global `~/.claude/commands/hand-off-audit.md` —
read it, it's short) into the new skill's top-level `commands/`, changing its body to
"Invoke the `session-handoff:audit` skill."

**Task 5 — Write the router `SKILL.md`.**
One short frontmatter description covering both sub-skills at a high level (so an unscoped
mention of "session-handoff" or a phrasing that doesn't clearly indicate one sub-operation
still finds this), plus a body that briefly explains the two sub-skills and points to each —
"if the ask is about spawning/continuing work in a new session, see `sub-skills/handoff/`; if
the ask is about auditing whether a stated rule was actually followed, see `sub-skills/audit/`."
Keep this file short (well under 100 lines) — it is a router, not a duplicate of either
sub-skill's content.

**Task 6 — Regenerate `CATALOG.md`.**
This repo's `CATALOG.md` is stated (in the ac-repo-radar CLAUDE.md excerpt available to your
orchestrator, and likely restated in this repo's own docs) to be a **generated** file, not
hand-maintained. Find and run whatever script/skill regenerates it (check for a
`scripts/`-level generator or a `skills-manager` operation before hand-editing) rather than
manually adding a `session-handoff` row.

**Task 7 — Light structural validation (not a full functional test).**
Given the launcher runs unattended, do not spawn further terminals or run a real compliance
audit / real handoff as a test — that's expensive, recursive, and not what this step needs.
Instead confirm, mechanically:
- Every file this task moved exists at its new path and is non-empty.
- Every `commands/*.md` file's body references the correct new skill/sub-skill name (grep for
  stale references to `continue-new-session-prompt` or `compliance-audit` as bare skill names
  inside the new bundle — a leftover reference means a path or invocation was missed).
- The three frontmatter blocks (router, handoff, audit) each parse as valid YAML with `name`
  and `description` present.
- `mine_dispatches.py` still runs (`python3 <path> --since "<any recent timestamp>"` — a syntax
  check, not a full audit).

**Task 8 — Open the PR.**
Follow this repo's own PR conventions (Orientation, above) — branch `feat/session-handoff-skill-merge`
already exists and is where you're working; push it and open the PR against whatever base
branch this repo's conventions specify (confirmed `dev` when the worktree was created, but
re-confirm against the repo's own docs rather than trusting that blindly). **Leave it
unmerged** per the hard constraints above.

**Task 9 — Deploy to the global profile.**
Once the PR is open, run `/push-skill session-handoff` (the `skills-manager` operation) to
deploy the new bundle to `~/.claude/skills/session-handoff/` and its commands to
`~/.claude/commands/`. If `push-skill` doesn't handle nested `sub-skills/` correctly (verify
this — it may have been built before this repo had any skill using that layout), fall back to
a direct, careful copy and say so explicitly in your report rather than silently patching
`push-skill` itself (that's out of scope for this task).

---

## Delegation

Spawn `model: "haiku"` subagents (stated explicitly — an unset model silently inherits this
session's pinned model) for mechanical work, dispatched in parallel where independent: the
Task 7 file-existence/grep sweep, confirming YAML frontmatter parses, diffing moved files
against their sources to confirm byte-for-byte fidelity where "verbatim" was required. Keep in
the main session: the router `SKILL.md`'s actual routing text (Task 5 — this is synthesis, not
extraction), the retirement-timing judgment (hard constraint 2), and the PR-conventions
reconciliation in Orientation.

**Delegation logging (required).** Log escalations/redos/drops with
`C:\Users\erik.OPBTA\.claude\skills\continue-new-session-prompt\scripts\log-delegation-outcome.ps1`
(`-Category`, `-FailureMode`, one-line `-Evidence` — this is the *currently deployed* global
script, stable regardless of what you're building, since hard constraint 2 keeps it untouched).
**As the final step before reporting finished**, log totals `-Outcome ok -Dispatches N` per
category, each tagged
**`-PromptPath 'C:\development\ai-agent-kit\docs\PROMPTS\2026-08-03-session-handoff-skill-merge.md'`**.

## Finishing

Report: the new skill's structure as built, the PR URL (opened, unmerged), confirmation that
the two old global skills were left untouched, confirmation `continue-new-session` (no suffix)
was not touched, and the delegation tally. End with a single numbered decision list — at
minimum it must include "retire the two old global skills now that the replacement is live?"
as an explicit item, since hard constraint 2 defers that decision to the user. Do not delete
this prompt file — that happens only via the normal retirement gate, later, with human
confirmation.
