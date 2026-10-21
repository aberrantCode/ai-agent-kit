---
name: skills-manager
category: Tooling & DevOps
install-target: global
description: >
  Full lifecycle management of LLM skills across the workstation — finding, archiving,
  installing, updating, and importing skills with their complete bundles (sub-skills +
  companion commands). Use when the user invokes /find-skills, /sync-skill, /install-skill,
  /update-skill, /push-skill, or /import-skill — AND whenever the user asks in plain language
  to install / deploy / push / add / set up a skill, especially phrased as "from
  aberrantcode/ai-agent-kit" (the GitHub slug for this archive), or asks to make a skill
  available globally or in a project. Triggers on prompts like "install the github skill from
  aberrantcode/ai-agent-kit", "push the project-manager skill to my profile", "add the
  security skill to this repo". Deployment is ALWAYS script-driven via scripts/push-to-profile.ps1
  — never hand-copy or hand-write bundle files. All user interaction MUST go through the
  AskUserQuestion tool — never free-form text, never inline markdown questions.
---

# Skills Manager

You are the domain expert for the AI Agent Kit at `C:\development\ai-agent-kit`. You understand the full lifecycle of skills: discovery, archiving, installation, updating, and importing project-level changes back to the archive.

**Critical constraint:** Every question or confirmation to the user MUST use the `AskUserQuestion` tool. Never prompt via free text, never write "Type yes/no", never use inline markdown questions.

---

## Core Concepts

### Archive
`C:\development\ai-agent-kit` is the single source of truth for all LLM skills, agents, and commands. It consolidates skills from the global Claude profile (`~/.claude/`) and all projects under `C:\development\`.

**`aberrantcode/ai-agent-kit` IS this archive.** When a user says "install the github skill from aberrantcode/ai-agent-kit" (or any variation — `aberrantCode/ai-agent-kit`, "the ai-agent-kit repo", "the archive"), they mean this archive. **Local-first:** if `C:\development\ai-agent-kit` exists, it is the source — deploy from it with the local scripts (it reflects the newest local edits). Only fall back to the remote GitHub bootstrap (`irm 'https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/main/install-skills.ps1' | iex`) when there is no local checkout. Before deploying from a local checkout, check whether it is in sync with its upstream (`git -C C:\development\ai-agent-kit status -sb`, or `git rev-list --left-right --count '@{u}...HEAD'`); if the local checkout is **ahead of** or **behind** `origin`, warn the user via `AskUserQuestion` (local is ahead → you may deploy unpushed work; local is behind → you may deploy stale work) and let them choose to continue, pull first, or abort.

### Deployment is script-driven (never hand-copy)
Every deployment of a bundle to a target — `/install-skill` (into a project or the profile), `/push-skill` (to the profile), and the write phase of `/update-skill` — MUST be performed by running `scripts/push-to-profile.ps1`, never by authoring files with the Write/Edit tools. The script does configuration work a manual copy silently skips: it stamps `installed-from: ai-agent-kit` provenance on every copied `SKILL.md`, keeps sub-skills **nested** inside the bundle (a loose top-level copy shadows the bundle's own sub-skill — `audit.ps1` Check 8 `profile-shadowing`), relocates companion commands to the discoverable top-level `commands/` dir, backs up any existing bundle before replacing it, and skips `status: draft` bundles. A hand-copy that misses any of these produces a subtly broken install. The script is preview-only by default; pass `-Force` to write.

### Skill Bundle
A skill directory may contain optional subdirectories that travel with it:

```
claude/skills/<name>/
├── SKILL.md              # Main skill
├── sub-skills/           # Thin delegate skills that extend this skill
│   └── <sub-name>/SKILL.md
└── commands/             # Slash-command dispatchers for this skill system
    └── <cmd>.md
```

Deploying a bundle to a repo copies:
- `SKILL.md` → `<target>/.claude/skills/<name>/SKILL.md`
- Each `sub-skills/<sub>/**` → `<target>/.claude/skills/<name>/sub-skills/<sub>/**` (nested, never loose)
- Each `commands/<cmd>.md` → `<target>/.claude/commands/<cmd>.md`
- Every other bundle member (`references/`, `rules/`, `scripts/`, `assets/`, `templates/`, root
  files, …) → `<target>/.claude/skills/<name>/…` — only the archive-only `diagram.html` stays behind

### Installed Copy
A skill file is an installed copy when its YAML frontmatter carries an `installed-from:` marker pointing at this archive. New installs stamp `installed-from: ai-agent-kit`; copies installed before the repository was renamed carry the legacy value `installed-from: llm_skills`. **Treat either value as an installed copy** — throughout this document, `installed-from: ai-agent-kit` is shorthand for *either the current or the legacy marker*. The sync and find operations skip these — they are not project-developed skills.

### Source Priority (conflict resolution)
When the same skill name exists in multiple sources, the highest-priority source wins:
1. Global profile (`~/.claude/`)
2. This repo's `.claude/` folder
3. Other projects under `C:\development\` (alphabetical for determinism)

### Companion Command Detection
When scanning a project, a `.md` file in `.claude/commands/` is a companion to skill `X` if its body matches (case-insensitive):
```
Invoke the `[anything containing X]` skill
```
or uses `X:*` namespace notation.

### Sub-Skill Detection
A `SKILL.md` whose body is primarily a delegation (`Invoke the \`X\` skill and execute...`) is a sub-skill of `X`. It belongs in `X`'s `sub-skills/` bundle directory.

---

## Skill Metadata Standards

All `SKILL.md` files support these optional frontmatter fields beyond the required `name` and `description`:

- **`status`**: `draft` | `active` (default) | `deprecated`
  - `draft` — skill is in development; `/install-skill` skips unless forced
  - `active` — production-ready; normal install/sync behaviour
  - `deprecated` — superseded or obsolete, and **scheduled for deletion**; `/install-skill` skips and warns; `/find-skills` classifies as **Deprecated** rather than New/Changed

- **`version`**: semver string (e.g. `1.2.0`) or ISO date (e.g. `2026-04-05`) — displayed by `/update-skill` so the user sees the version delta before accepting an update

- **`requires`**: YAML list of skill names this skill depends on (e.g. `[project-manager, base]`) — `/install-skill` reads this and auto-installs all listed dependencies before installing the target skill

- **`install-target`**: `global` | `project` (optional) — the skill's preferred default deployment target when `/install-skill` is run without an explicit target. `global` → the user profile (`~/.claude/`), available in every project; `project` → the current project's `.claude/`. Workflow skills that must be available everywhere are stamped `global` (`github`, `project-manager`, `skills-manager`); content/implementation skills can opt into `project`.

### Install-target resolution

When `/install-skill` must decide where to deploy and the user did not name a target, resolve in this order (first match wins):

1. **Explicit user instruction** in the prompt ("…to my profile", "…into this repo") — honor it.
2. **The skill's `install-target:` frontmatter** — if set, use it.
3. **Not in a repo → `global`.** If Claude's working directory is not a git repository (`git rev-parse --is-inside-work-tree` is false/errors), deploy to the profile — there is no project to install into.
4. **Default → `global`.** With no field and no other signal, deploy to the profile.

A skill reaches the current project (not the profile) only when step 1 or step 2 selects `project` **and** step 3 found a repo. Always confirm the resolved target with `AskUserQuestion` before writing (see `/install-skill`).

---

## Operation: /find-skills [path]

Discover skills across the workstation that are new or changed relative to the archive. Read-only — makes no changes.

### Steps

1. Determine scan scope:
   - If `path` argument given: scan only that directory
   - If no argument: use `AskUserQuestion` to confirm before scanning:
     - Question: "Scan all source locations for new or changed skills?"
     - Options: "Yes, scan everything" | "Cancel"
     - Proceed only on confirm

2. For each discovered `SKILL.md`:
   - Read frontmatter — if `installed-from: ai-agent-kit` is present, **skip** (installed copy)
   - If `status: deprecated` is present, classify as **Deprecated** regardless of diff — do not treat as New or Changed
   - Compare content against archive counterpart using diff, **normalizing both sides
     first**: drop any `^category:\s` frontmatter line and truncate at the first
     `## Diagram` heading, then ignore trailing whitespace and CRLF/LF differences.
     `/sync-skill` appends a `category:` line and a `## Diagram` / `[View
     diagram](diagram.html)` footer to every archive copy that the live source lacks —
     an un-normalized diff reports every previously synced skill as Changed forever.
   - Classify: **New** | **Changed** | **Unchanged** | **Orphan** | **Deprecated**
   - If `version:` is present and archive has a different version, note the version delta in the report

3. For each New or Changed skill: also search the same project's `.claude/commands/` for companion commands using the detection heuristic.

4. Output a structured report:
   ```
   ┌─ Skills Manager: Find Report ──────────────────┐
   │ New (N):        skill-a, skill-b               │
   │ Changed (N):    skill-c  (v1.0 → v1.2)         │
   │ Deprecated (N): skill-d                        │
   │ Unchanged:      N skills skipped               │
   │ Orphans:        N archive-only skills          │
   └────────────────────────────────────────────────┘
   ```
   For each New/Changed skill, list any detected companion commands beneath it.

---

## Operation: /sync-skill [name]

Archive a specific skill (or all discovered skills) including its full bundle.

### With a skill name

1. Search all canonical source locations for a skill named `name` (match by leaf directory name)
2. Skip any match where `installed-from: ai-agent-kit` is in frontmatter
3. Apply conflict resolution if multiple sources found — take highest-priority source
4. Detect companion commands and sub-skills in the same project (see heuristics above)
5. Write to archive:
   - `SKILL.md` → `claude/skills/<name>/SKILL.md`
   - Companion commands → `claude/skills/<name>/commands/<cmd>.md`
   - Sub-skills → `claude/skills/<name>/sub-skills/<sub>/SKILL.md`
   - Any `scripts/**` helper files → `claude/skills/<name>/scripts/**` (a bundle whose SKILL.md invokes `<skill-dir>/scripts/…` is broken without them)
6. Generate a visual diagram for the skill:
   - Invoke the `visual-explainer:generate-web-diagram` skill
   - Instruct it to diagram: the skill's purpose (from `description` frontmatter), its key operations or phases (from section headings), significant inputs/outputs, and any decision points or branching paths
   - Save the resulting HTML to `claude/skills/<name>/diagram.html`
   - Add or update a `## Diagram` section at the bottom of `claude/skills/<name>/SKILL.md` (before any final horizontal rule) containing exactly: `[View diagram](diagram.html)`
7. Regenerate `manifest.json` and `CATALOG.md` (see Generated Catalog Update Rules).
8. Report what was written

### Without a skill name

1. Run the /find-skills scan internally (no user prompt for the scan itself) to enumerate scope
2. Use `AskUserQuestion` to confirm:
   - Question: "Sync all N new/changed skills? (list skill names)"
   - Options: "Yes, sync all" | "Cancel"
3. Proceed only on confirm; process each New and Changed skill in turn

### Generated Catalog Update Rules (sync)

- Author metadata in skill frontmatter; Claude `category:` is the source of category truth.
  Mirrors inherit the category from the Claude skill of the same name.
- Run `python scripts/generate-manifest.py`, then
  `pwsh -NoProfile -File scripts/generate-catalog.ps1 -Force` from the archive root.
- Never hand-edit `manifest.json`, `CATALOG.md`, or add asset tables/counts to root README.
- Bundled commands and sub-skills stay in their owning bundle; do not create global rows
  for them. Keep diagram links in each skill's `## Diagram` section; the catalog links to
  `SKILL.md` and does not currently emit separate diagram links.
- After additions, deletions, metadata changes, or diagram changes, regenerate and run
  `pwsh -NoProfile -File scripts/audit.ps1` to check parity.

---

## Operation: /install-skill [name] [target-dir]

Deploy a skill bundle from the archive to a target — the global profile or a specific project. This operation is the landing spot for natural-language requests such as *"install the github skill from aberrantcode/ai-agent-kit"*, *"push the project-manager skill to my profile"*, or *"add the security skill to this repo"*.

**Deployment is script-driven — do NOT hand-copy.** Every write goes through `scripts/push-to-profile.ps1` (see *Deployment is script-driven* under Core Concepts). The Write/Edit tools must never author bundle files into a target.

### Steps

1. **Determine scope:**
   - If `name` given: install that skill only
   - If no `name`: enumerate all skills in `claude/skills/` not already deployed to the resolved target; use `AskUserQuestion` to confirm "Install all N available skills into `<target>`?" → "Yes, install all" | "Cancel"

2. For a named skill: confirm `claude/skills/<name>/` exists in the archive; if not, use `AskUserQuestion`:
   - Question: "Skill `<name>` not found in archive. Check the name and try again."
   - Options: "OK" | "List available skills"

3. **Resolve the target** (see *Install-target resolution* under Skill Metadata Standards): honor an explicit user instruction → else the skill's `install-target:` frontmatter → else `global` if not in a repo → else `global`. Then confirm with `AskUserQuestion`:
   - Question: "Install `<name>` to `<resolved target>`? (global = `~/.claude/`, project = `<cwd>/.claude/`)"
   - Options: "Yes, <resolved> (Recommended)" | "The other target" | "Cancel"

4. **Local-first + sync check:** the source is the local archive at `C:\development\ai-agent-kit`. Before deploying, verify it is in sync with `origin` (`git -C C:\development\ai-agent-kit status -sb`); if ahead or behind, warn via `AskUserQuestion` and let the user continue / pull first / abort. If there is no local checkout, fall back to the remote bootstrap (`irm '…/install-skills.ps1' | iex`).

5. Resolve dependencies: read each skill's `requires:` frontmatter; recursively add those bundles to the install scope. Deduplicate.

6. **Preview** with the script (no `-Force`), once per bundle in scope:
   - Global target: `pwsh ./scripts/push-to-profile.ps1 -Name <name>`
   - Project target: `pwsh ./scripts/push-to-profile.ps1 -Name <name> -TargetDir "<project>/.claude/skills"` — the script writes the bundle under that skills root and relocates companion commands to the sibling `<project>/.claude/commands`, stamping provenance exactly as a profile push does.

   Show the previewed file list / member summary to the user.

7. On confirm, re-run each command **with `-Force`** to write. The script stamps `installed-from: ai-agent-kit`, nests sub-skills, relocates commands, and backs up any existing bundle automatically.

8. Report the script's output (files written, sub-skills nested, commands relocated, any backup taken) for the target skill and every dependency.

---

## Operation: /update-skill [name]

Update installed skills in the current project when the archive has newer versions.

### Steps

1. Scan current project's `.claude/skills/` for files with `installed-from: ai-agent-kit` in frontmatter
2. If `name` given: filter to that skill only

3. For each installed skill found:
   - Compare content against archive version
   - If identical: skip (no update needed)
   - If archive is newer: record as outdated

4. **Confirm scope** with `AskUserQuestion` before touching anything:
   - If updating all: "Update all N outdated skills? (list skill names, include version delta where available, e.g. skill-x v1.0→v1.2)"
   - If updating one by name: "Update `<name>` to the archive version? (v1.0 → v1.2)"
   - Options: "Yes, update" | "Cancel"

5. On confirm — **re-deploy via the script, do NOT hand-overwrite** (same engine as `/install-skill`; `sync-installed.ps1` remains a stub):
   - Profile copy: `pwsh ./scripts/push-to-profile.ps1 -Name <name> -Force`
   - Project copy: `pwsh ./scripts/push-to-profile.ps1 -Name <name> -TargetDir "<project>/.claude/skills" -Force`

   The script re-copies the whole bundle (every member except `commands/` and `diagram.html`), relocates companion commands, re-stamps `installed-from: ai-agent-kit`, and backs up the previous copy — so an update is just a push over the existing install.

6. Report the script's output for each updated skill

---

## Operation: /import-skill [name]

Import project-level changes to a skill back into the archive and the global user profile.

### Steps

1. **Determine scope:**
   - If `name` given: import that skill only
   - If no `name`: scan current project's `.claude/skills/` for all skills that do NOT have `installed-from: ai-agent-kit` and differ from the archive; use `AskUserQuestion` to confirm:
     - Question: "Import all N project-developed skills to archive and user profile? (list names)"
     - Options: "Yes, import all" | "Cancel"
     - Proceed only on confirm

2. Locate `<name>/SKILL.md` in the current project's `.claude/skills/`
3. Check frontmatter: if `installed-from: ai-agent-kit` is present, use `AskUserQuestion` to reject:
   - Question: "`<name>` was installed from the archive — it is not a project-developed skill. Import would just overwrite the archive with its own content. Proceed anyway?"
   - Options: "Cancel" | "Yes, force import"
   - Default is Cancel; only proceed if user explicitly chooses force

3. Diff current project version against archive version
4. Show summary: lines added, lines removed, key description change (if any)

5. Use `AskUserQuestion` to confirm:
   - Question: "Import `<name>` changes to archive and user profile? (N lines added, N removed)"
   - Options: "Yes, import both" | "Archive only" | "Cancel"

6. On confirm:
   - **Archive**: overwrite `claude/skills/<name>/SKILL.md`
   - **User profile**: overwrite `~/.claude/skills/<name>/SKILL.md` (create dir if needed)
   - **Companion commands**: scan project `.claude/commands/` for new companion commands not yet in the archive bundle; for each new one, use `AskUserQuestion`: "Bundle `/<cmd>` with `<name>`?" → "Yes" | "Skip"
   - **Helper scripts**: copy any new or changed `scripts/**` files from the project bundle to both `claude/skills/<name>/scripts/**` and `~/.claude/skills/<name>/scripts/**`
   - **Catalog**: regenerate `manifest.json` and `CATALOG.md` after the import

7. Report what was imported

---

## Operation: /backfill-diagrams [name]

Generate `diagram.html` for archived skills that don't have one, retroactively applying the diagram standard.

### Steps

1. **Determine scope:**
   - If `name` given: check only that skill
   - If no `name`: scan `claude/skills/*/` and collect every skill directory that lacks `diagram.html`

2. Use `AskUserQuestion` to confirm:
   - Question: "Generate diagrams for N skills that are missing one? (list skill names)"
   - Options: "Yes, backfill all" | "Cancel"
   - Proceed only on confirm

3. For each skill in scope:
   - Invoke `visual-explainer:generate-web-diagram` using the skill's purpose, operations, and key decision points as input
   - Save HTML to `claude/skills/<name>/diagram.html`
   - Add or update `## Diagram` section in `claude/skills/<name>/SKILL.md` with `[View diagram](diagram.html)`

4. Verify each generated diagram is linked from its owning `SKILL.md`; leave the root
   README and generated catalog tables unedited.

5. Report how many diagrams were generated

---

## Operation: /search-skill [query]

Search the archive for skills matching a keyword or phrase. Read-only — no changes made.

### Steps

1. If no `query` provided: use `AskUserQuestion`:
   - Question: "What are you looking for?"
   - Options: "Enter search query" (free text via Other)

2. Search the following fields across all `claude/skills/*/SKILL.md` files (case-insensitive):
   - `name:` frontmatter field — highest priority
   - `description:` frontmatter field — high priority
   - `## ` section headings in the body — medium priority
   - Body text — lower priority

3. Rank results: exact name match > description keyword hit > heading hit > body hit. Break ties alphabetically.

4. Output ranked results (no `AskUserQuestion` needed):
   ```
   ┌─ Skills Manager: Search Results for "auth" ────┐
   │ 1. security          (Security & Credentials)   │
   │    "OWASP security patterns, secrets..."        │
   │    [diagram](claude/skills/security/diagram.html)│
   │ 2. credentials       (Security & Credentials)   │
   │    "Centralized API key management..."          │
   │ 3. supabase          (Databases & Storage)      │
   │    "...Auth, Storage, real-time..."             │
   └────────────────────────────────────────────────┘
   ```
   Include diagram link on result lines where `diagram.html` exists.

---

## Operation: /audit-skills

Run a comprehensive read-only health check across the entire archive. No changes made, no confirmation needed.

### Checks

1. **Missing diagrams**: skills in `claude/skills/*/` that lack `diagram.html`
2. **Catalog drift — broken links**: generated `CATALOG.md` rows whose targets no longer exist
3. **Catalog drift — missing rows**: archived skills absent from generated `CATALOG.md`
4. **Malformed frontmatter**: `SKILL.md` files missing required `name:` or `description:` fields
5. **Deprecated installs**: scan all projects under `C:\development\` for installed skills (`installed-from: ai-agent-kit`) where the archive copy has `status: deprecated` — list project and skill name
6. **Codex/Gemini parity gaps**: compare platform skill names in `manifest.json`; report gaps informationally per the reorg charter (Codex on demand, Gemini frozen)
7. **Profile skill shadowing**: loose top-level skills in `~/.claude/skills/<name>/` whose name matches a **sub-skill of an installed bundle**
8. **Profile companion-command placement**: installed bundles whose companion commands are not registered in `~/.claude/commands/` — either because a `commands/` directory sits nested inside the bundle, or because the archive ships commands the profile lacks

### Check 7 — profile skill shadowing

A loose top-level skill wins name resolution over a bundle's sub-skill of the same
name. `/<name>` then runs the loose copy, and the bundle's maintained sub-skill never
loads — silently, with no error. This is not hypothetical: six standalone skills
(`ship`, `merge`, `release`, `prune`, `commit`, `publish`) shadowed the `github`
bundle's sub-skills until 2026-07-19, so `/merge` and `/release` had been resolving
to stale copies. Four more (`continue-tasks`, `reinit`, `review-tasks`,
`update-tasks`) shadowed `project-manager` sub-skills and were removed the same day.

Implemented in `scripts/audit.ps1` as check `profile-shadowing`. It builds a
sub-skill-name → owning-bundle map from every installed bundle, then flags any
top-level directory whose name appears in it. A bundle is never treated as a shadow
of its own sub-skill namespace.

**Severity is `warn`, never `error`.** `validate.ps1` gates pull requests on
`audit.ps1`'s exit code, and an archive PR must not fail because of state in one
developer's profile. The check no-ops when the profile directory is absent (CI,
fresh clones) and can be disabled with `-SkipProfile`; `-ProfileRoot` overrides the
default `~/.claude/skills`.

**Resolution order is mandatory — never delete first.** For each finding: diff the
loose copy against the bundle sub-skill; if it holds anything unique, `/import-skill`
that content into the archive *before* removing anything. Only a copy that is a
strict subset of the bundle version is safe to delete outright.

### Check 8 — profile companion-command placement

The mirror image of Check 7, and the same silent failure. A bundle's companion
commands are its top-level slash-command entry points, and they are discovered **only**
in `~/.claude/commands/`. A `commands/` directory nested *inside* the installed bundle
is never scanned. So copying a bundle directory wholesale — instead of running
`scripts/push-to-profile.ps1`, which relocates the commands — installs the skill while
registering none of its commands. On 2026-10-15 the `github`, `project-manager`, and
`skills-manager` bundles were all hand-copied this way: 34 commands sat in
`~/.claude/skills/<name>/commands/`, a path nothing reads, and `/ship`, `/merge`, and
`/release` simply did not exist. The skill loaded fine, which is what made it hard to see.

Implemented in `scripts/audit.ps1` as two findings, because a partial push produces the
second without the first:

- `profile-command-nesting` — the installed bundle has a nested `commands/` directory.
  This is the signature of a wholesale directory copy.
- `profile-command-gap` — commands the archive ships for that bundle are missing from
  `~/.claude/commands/`. Aggregated to one finding per bundle, so a 17-command bundle
  does not emit 17 findings.

Both are keyed off the archive shipping `claude/skills/<name>/commands/*.md` for a
bundle that is installed in the profile; bundles with no companion commands are skipped.
The commands root is resolved as the sibling `commands/` of `-ProfileRoot`, matching
where `push-to-profile.ps1` writes.

**Severity is `warn`, never `error`**, for the same reason as Check 7 — profile state must
not fail an archive PR. Same guards: no-ops when the profile is absent, disabled by
`-SkipProfile`.

**Resolution:** re-run `/push-skill <name>` (or
`scripts/push-to-profile.ps1 -Name <name> -Force`). It relocates the commands and drops
the nested copy. Nothing needs to be hand-moved, and nothing unique is ever lost — a
nested `commands/` dir is by construction a verbatim copy of the archive's.

### Output format

```
┌─ Skills Manager: Audit Report ─────────────────────────────────┐
│ Missing diagrams (N):   skill-a, skill-b, ...                  │
│ Catalog broken links (N): row-name → path/does/not/exist     │
│ Catalog missing rows (N): skill-dir has no catalog entry     │
│ Bad frontmatter (N):    skill-c (missing description)          │
│ Deprecated installs (N): project-x uses deprecated skill-d     │
│ Profile shadowing (N):  merge shadows github/sub-skills/merge  │
│ Profile command gaps (N): github — 8 commands unregistered     │
│ Parity gaps — Claude only (N skills, top candidates):          │
│   - security (Security & Credentials)                          │
│   - typescript (Languages & Runtimes)                          │
│   ...                                                           │
└────────────────────────────────────────────────────────────────┘
```

---

## Operation: /push-skill [name]

Push a skill bundle from the archive to the global user profile (`~/.claude/`) so it is available across all projects. `/push-skill <name>` is exactly `/install-skill <name>` with the target fixed to `global`.

**Deployment is script-driven — do NOT hand-copy.** `scripts/push-to-profile.ps1` is the implementation; it stamps provenance, nests sub-skills, relocates companion commands to the top-level `~/.claude/commands/`, backs up any existing bundle, and skips drafts. The Write/Edit tools must never author profile files.

### Steps

1. **Determine scope:**
   - If `name` given: push that skill bundle only
   - If no `name`: enumerate all skills in `claude/skills/`; use `AskUserQuestion` to confirm:
     - Question: "Push all N archive skills to the global profile (~/.claude/)?"
     - Options: "Yes, push all" | "Cancel"
     - Proceed only on confirm

2. **Local-first + sync check** (see *aberrantcode/ai-agent-kit* under Core Concepts): the source is the local archive; warn via `AskUserQuestion` if it is ahead of or behind `origin` before deploying.

3. **Preview** each bundle with no `-Force`: `pwsh ./scripts/push-to-profile.ps1 -Name <name>`. The script reports the members it would copy; `status: draft` bundles report as skipped. If a destination bundle already exists it will be backed up to a sibling `<skillsRoot>-backups/<name>.bak-<ts>` (not a silent clobber), so no separate overwrite prompt is needed — but show the preview and confirm with `AskUserQuestion` before writing.

   **The script is the deployment path, not a suggestion.** The bundle layout has two traps that are easy to fall into by hand, and the script handles both:

   - **Never copy the bundle directory wholesale.** A plain recursive copy leaves `commands/` nested *inside* the installed bundle, and that path is never scanned for slash commands — the skill installs while every one of its commands stays unregistered. This is how `/ship`, `/merge`, and `/release` silently went missing on 2026-10-15. Caught by `audit.ps1` as `profile-command-nesting` + `profile-command-gap`.
   - **Never write a sub-skill to a loose top-level `~/.claude/skills/<sub>/` directory.** That shadows the bundle's own sub-skill and breaks the parent's delegation — each sub-skill stays *inside* the bundle and is reached through the parent's relative `sub-skills/<sub>` path. Caught by `audit.ps1` as `profile-shadowing`.

   The parent skill plus its companion commands are the only top-level entry points. The layout the script writes — verify against this, never hand-build it:
   - `SKILL.md` → `~/.claude/skills/<name>/SKILL.md`, stamped `installed-from: ai-agent-kit` (after existing fields).
   - Each sub-skill → `~/.claude/skills/<name>/sub-skills/<sub>/SKILL.md` (nested; preserve any `templates/` and other sub-skill files), each stamped with the same `installed-from: ai-agent-kit` marker.
   - Each companion command → `~/.claude/commands/<cmd>.md` (no marker — commands are not skills; they are the top-level entry points that dispatch into the bundle).
   - Every other bundle member — `references/`, `rules/`, `scripts/`, `assets/`, `templates/`,
     root files — → `~/.claude/skills/<name>/…` (no marker). Only `diagram.html` is left behind.

4. On confirm, re-run **with `-Force`**: `pwsh ./scripts/push-to-profile.ps1 -Name <name> -Force`.

5. Report the script's output. (A pushed bundle is a downstream **copy** — stamped `installed-from: ai-agent-kit` so `/find-skills` and `/sync-skill` skip it and it can never masquerade as a profile-authored source and clobber the archive it came from. Hand-authored profile skills stay unmarked and remain valid sources; to pull in-place edits to a pushed copy back to the archive, use `/import-skill`.)

For a non-default vendor or skills root, pass `-Vendor claude|codex|gemini` and/or `-TargetDir`; see the script's comment-based help.

---

## Source Discovery Table

| Source | Path Pattern | Toolset | Archive Destination |
|--------|-------------|---------|---------------------|
| Global profile | `~/.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Global profile | `~/.claude/agents/*.md` | Claude | `claude/instructions/<name>.md` |
| Global profile | `~/.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| This repo | `.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| This repo | `.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| Other projects | `.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Other projects | `.claude/agents/*.md` | Claude | `claude/instructions/<name>.md` |
| Other projects | `.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| Other projects | `skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Other projects | `codex/skills/*/SKILL.md` | Codex | `codex/skills/<name>/SKILL.md` |
| Other projects | `gemini/skills/*/SKILL.md` | Gemini | `gemini/skills/<name>/SKILL.md` |

**Nested paths**: The skill `<name>` is always the leaf directory containing `SKILL.md`. Intermediate path segments (e.g. `homeradar/` in `skills/homeradar/feature-start/SKILL.md`) are discarded.

**Installed-copy filter**: Apply before any classification. Skip any file with `installed-from: ai-agent-kit` in frontmatter.

**`ai-agent-kit` itself**: Only scan `.claude/` — never recurse into `claude/` (the archive destination). Scanning the archive as a source would create circular copies.

**Directories to skip**: `nul`, `emby-opbta.p12`, `fullchain.pem`, `privkey.pem`, `recovery_app`, and any loose files (not directories) at the `C:\development\` root.

---

## Category Assignment

Choose an existing category from `CATEGORY_ORDER` in `scripts/generate-manifest.py` and
write it to the canonical Claude skill's `category:` frontmatter. Do not derive catalog
categories or ordering from description keywords, and do not write a separate category to
Codex/Gemini mirrors. The generators resolve and render the category; `audit.ps1` flags
missing canonical categories.

---

## Archive Invariants — Never Violate

1. **Sync never auto-deletes; curators do.** The automated flow won't remove an archive copy just because its source file vanished — but superseded skills/commands are *intentionally* deleted (folded-in or obsolete → removed; git history is the record), never kept as permanent `deprecated` tombstones.
2. **Capture is source → archive** (`/sync-skill`, `/import-skill`); deployment is archive → consumer (`/install-skill`, `/push-skill`, `/update-skill`).
3. **The generated catalog is the asset index.** Every archived skill must appear in `CATALOG.md`; regenerate it and `manifest.json` rather than hand-editing rows or README counts.
4. **Toolset is determined by directory, not content.**
5. **Installed copies are not project-developed skills.** The `installed-from: ai-agent-kit` marker gates this distinction.
6. **Deployment is script-driven — never hand-copy.** `/install-skill`, `/push-skill`, and the write phase of `/update-skill` deploy a bundle ONLY by running `scripts/push-to-profile.ps1` (preview, then `-Force`). Authoring bundle files into a target with the Write/Edit tools is prohibited — it skips provenance stamping, sub-skill nesting, command relocation, backups, and draft gating, producing a subtly broken install.

## Diagram

[View diagram](diagram.html)
