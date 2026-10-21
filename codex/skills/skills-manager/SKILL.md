---
name: skills-manager
description: >
  Full lifecycle management of LLM skills across the workstation — finding, archiving,
  installing, updating, and importing skills with their complete bundles (sub-skills +
  companion commands). Use when the user invokes /find-skills, /sync-skill, /install-skill,
  /update-skill, /import-skill, /push-skill, /search-skill, /audit-skills, or /backfill-diagrams.
---

# Skills Manager

You are the domain expert for the AI Agent Kit at `C:\development\ai-agent-kit`. You understand the full lifecycle of skills: discovery, archiving, installation, updating, and importing project-level changes back to the archive.

Prompt the user for confirmation before any bulk or destructive operation. Never assume scope — always confirm what will change.

---

## Core Concepts

### Archive
`C:\development\ai-agent-kit` is the single source of truth for all LLM skills, agents, and commands. It consolidates skills from the global Claude profile (`~/.claude/`) and all projects under `C:\development\`.

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
- Each `sub-skills/<sub>/SKILL.md` → `<target>/.claude/skills/<sub>/SKILL.md`
- Each `commands/<cmd>.md` → `<target>/.claude/commands/<cmd>.md`
- Each `references/**` file → `<target>/.claude/skills/<name>/references/**`
- Each `rules/**` file → `<target>/.claude/skills/<name>/rules/**`
- Each `scripts/**` file → `<target>/.claude/skills/<name>/scripts/**`

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

---

## Operation: /find-skills [path]

Discover skills across the workstation that are new or changed relative to the archive. Read-only — makes no changes.

### Steps

1. Determine scan scope:
   - If `path` argument given: scan only that directory
   - If no argument: prompt the user to confirm before scanning:
     - Question: "Scan all source locations for new or changed skills?"
     - Options: "Yes, scan everything" | "Cancel"
     - Proceed only on confirm

2. For each discovered `SKILL.md`:
   - Read frontmatter — if `installed-from: ai-agent-kit` is present, **skip** (installed copy)
   - If `status: deprecated` is present, classify as **Deprecated** regardless of diff — do not treat as New or Changed
   - Compare content against archive counterpart using diff (ignore trailing whitespace)
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
2. Ask the user to confirm:
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

Deploy a skill bundle from the archive into a project.

### Steps

1. **Determine scope:**
   - If `name` given: install that skill only
   - If no `name`: enumerate all skills in `claude/skills/` that have not already been installed in `target-dir`; prompt the user to confirm:
     - Question: "Install all N available skills into `<target>`? This will write N files."
     - Options: "Yes, install all" | "Cancel"
     - Proceed only on confirm

2. For a named skill: locate `claude/skills/<name>/` in the archive; if not found ask the user:
   - Question: "Skill `<name>` not found in archive. Check the name and try again."
   - Options: "OK" | "List available skills"

3. If `target-dir` not provided, ask the user:
   - Question: "Where should the skill(s) be installed?"
   - Options: "Current project directory" | "Other path (specify below)"

4. Resolve dependencies: read `requires:` list from each skill's frontmatter; recursively locate those skill bundles in the archive and add them to the install scope. Deduplicate — never install the same skill twice.

5. Inventory what will be installed (target skill + all resolved dependencies):
   - `SKILL.md` (1 file per skill)
   - Sub-skills from `sub-skills/` (N files)
   - Commands from `commands/` (N files)
   - References from `references/` (N files)
   - Rules from `rules/` (N files)
   - Scripts from `scripts/` (N files)

6. If `name` was given, prompt the user to confirm:
   - Question: "Install `<name>` (+ N dependencies) into `<target>`? This will write N files."
   - Options: "Yes, install" | "Cancel"

7. On confirm:
   - Write `<target>/.claude/skills/<name>/SKILL.md`; inject `installed-from: ai-agent-kit` into frontmatter (add after existing fields)
   - Write each sub-skill to `<target>/.claude/skills/<sub>/SKILL.md` with same marker
   - Write each command to `<target>/.claude/commands/<cmd>.md` (no marker — commands are not skills)
   - Copy each `references/**` file to `<target>/.claude/skills/<name>/references/**` (no marker)
   - Copy each `rules/**` file to `<target>/.claude/skills/<name>/rules/**` (no marker)
   - Copy each `scripts/**` file to `<target>/.claude/skills/<name>/scripts/**` (no marker)

8. Report all files written

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

4. **Confirm scope** with the user before touching anything:
   - If updating all: "Update all N outdated skills? (list skill names, include version delta where available, e.g. skill-x v1.0→v1.2)"
   - If updating one by name: "Update `<name>` to the archive version? (v1.0 → v1.2)"
   - Options: "Yes, update" | "Cancel"

5. On confirm:
   - Overwrite each `SKILL.md`, preserving the `installed-from: ai-agent-kit` marker in frontmatter
   - Also check `commands/` in the archive bundle — write any new or changed commands to `<project>/.claude/commands/`
   - Also check `sub-skills/` — update any installed sub-skills that are outdated
   - Also check `references/`, `rules/`, and `scripts/` in the archive bundle — write any new or changed files to `<project>/.claude/skills/<name>/references/**`, `<project>/.claude/skills/<name>/rules/**`, and `<project>/.claude/skills/<name>/scripts/**`
   - Regenerate the diagram: invoke `visual-explainer:generate-web-diagram` for each updated skill and overwrite `claude/skills/<name>/diagram.html`; update the `## Diagram` section in SKILL.md if the path changed

6. Report updated files

---

## Operation: /import-skill [name]

Import project-level changes to a skill back into the archive and the global user profile.

### Steps

1. **Determine scope:**
   - If `name` given: import that skill only
   - If no `name`: scan current project's `.claude/skills/` for all skills that do NOT have `installed-from: ai-agent-kit` and differ from the archive; prompt the user to confirm:
     - Question: "Import all N project-developed skills to archive and user profile? (list names)"
     - Options: "Yes, import all" | "Cancel"
     - Proceed only on confirm

2. Locate `<name>/SKILL.md` in the current project's `.claude/skills/`
3. Check frontmatter: if `installed-from: ai-agent-kit` is present, ask the user to confirm rejection:
   - Question: "`<name>` was installed from the archive — it is not a project-developed skill. Import would just overwrite the archive with its own content. Proceed anyway?"
   - Options: "Cancel" | "Yes, force import"
   - Default is Cancel; only proceed if user explicitly chooses force

3. Diff current project version against archive version
4. Show summary: lines added, lines removed, key description change (if any)

5. Prompt the user to confirm:
   - Question: "Import `<name>` changes to archive and user profile? (N lines added, N removed)"
   - Options: "Yes, import both" | "Archive only" | "Cancel"

6. On confirm:
   - **Archive**: overwrite `claude/skills/<name>/SKILL.md`
   - **User profile**: overwrite `~/.claude/skills/<name>/SKILL.md` (create dir if needed)
   - **Companion commands**: scan project `.claude/commands/` for new companion commands not yet in the archive bundle; for each new one, ask the user: "Bundle `/<cmd>` with `<name>`?" → "Yes" | "Skip"
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

2. Prompt the user to confirm:
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

1. If no `query` provided, ask the user:
   - Question: "What are you looking for?"
   - Options: "Enter search query" (free text via Other)

2. Search the following fields across all `claude/skills/*/SKILL.md` files (case-insensitive):
   - `name:` frontmatter field — highest priority
   - `description:` frontmatter field — high priority
   - `## ` section headings in the body — medium priority
   - Body text — lower priority

3. Rank results: exact name match > description keyword hit > heading hit > body hit. Break ties alphabetically.

4. Output ranked results:
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
in the profile's top-level `commands/` directory. A `commands/` directory nested
*inside* the installed bundle is never scanned. So copying a bundle directory wholesale
— instead of running `scripts/push-to-profile.ps1`, which relocates the commands —
installs the skill while registering none of its commands. On 2026-10-15 the `github`,
`project-manager`, and `skills-manager` bundles were all hand-copied this way: 34
commands sat in `~/.claude/skills/<name>/commands/`, a path nothing reads, and `/ship`,
`/merge`, and `/release` simply did not exist. The skill loaded fine, which is what made
it hard to see.

Implemented in `scripts/audit.ps1` as two findings, because a partial push produces the
second without the first:

- `profile-command-nesting` — the installed bundle has a nested `commands/` directory.
  This is the signature of a wholesale directory copy.
- `profile-command-gap` — commands the archive ships for that bundle are missing from
  the profile's `commands/` root. Aggregated to one finding per bundle, so a 17-command
  bundle does not emit 17 findings.

Note that `audit.ps1`'s profile checks read the **Claude** profile
(`~/.claude/skills` by default, overridable with `-ProfileRoot`) — they are not
re-vendored per toolset.

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

Push a skill bundle from the archive to the global user profile (`~/.codex/`) so it is available across all projects.

### Steps

1. **Determine scope:**
   - If `name` given: push that skill bundle only
   - If no `name`: enumerate all skills in `codex/skills/`; prompt the user to confirm:
     - Question: "Push all N archive skills to the global profile (~/.codex/)?"
     - Options: "Yes, push all" | "Cancel"
     - Proceed only on confirm

2. For each skill to push:
   - Check if `status: draft` — skip with a warning; drafts are not pushed to the global profile
   - Check if `~/.codex/skills/<name>/SKILL.md` already exists and differs — ask the user:
     - Question: "~/.codex/skills/<name> exists and differs. Overwrite with archive version?"
     - Options: "Yes, overwrite" | "Skip this skill"

3. On confirm — **deploy by running `scripts/push-to-profile.ps1 -Name <name> -Vendor codex -Force`.** This is the deployment path, not a suggestion: the layout below has two traps that are easy to fall into by hand, and the script handles both. Deploy the bundle **nested**, mirroring the archive.

   - **Never copy the bundle directory wholesale.** A plain recursive copy leaves `commands/` nested *inside* the installed bundle, and that path is never scanned for slash commands — the skill installs while every one of its commands stays unregistered. This is how `/ship`, `/merge`, and `/release` silently went missing from the Claude profile on 2026-10-15. Caught by `audit.ps1` as `profile-command-nesting` + `profile-command-gap`.
   - **Never write a sub-skill to a loose top-level `~/.codex/skills/<sub>/` directory.** That shadows the bundle's own sub-skill and breaks the parent's delegation — each sub-skill stays *inside* the bundle and is reached through the parent's relative `sub-skills/<sub>` path. Caught by `audit.ps1` as `profile-shadowing`.

   The parent skill plus its companion commands are the only top-level entry points. The layout the script writes — verify against this, never hand-build it:
   - `SKILL.md` → `~/.codex/skills/<name>/SKILL.md`; inject `installed-from: ai-agent-kit` into frontmatter (after existing fields). A pushed bundle is a downstream **copy** of the archive — a deployment target, exactly like `/install-skill` writing into a project, NOT an authoritative source. The marker makes `/find-skills` and `/sync-skill` skip it, so a pushed copy can never masquerade as a profile-authored source and clobber the archive it came from (the profile is priority #1 in conflict resolution). Hand-authored profile skills stay unmarked and remain valid sources; to pull in-place edits to a pushed copy back to the archive, use `/import-skill`.
   - Each sub-skill → `~/.codex/skills/<name>/sub-skills/<sub>/SKILL.md` (nested; preserve any `templates/` and other sub-skill files), each stamped with the same `installed-from: ai-agent-kit` marker.
   - Each companion command → `~/.codex/commands/<cmd>.md` (no marker — commands are not skills; they are the top-level entry points that dispatch into the bundle).
   - Each `references/**` file → `~/.codex/skills/<name>/references/**` (no marker).
   - Each `rules/**` file → `~/.codex/skills/<name>/rules/**` (no marker).
   - Each `scripts/**` file → `~/.codex/skills/<name>/scripts/**` (no marker).

4. Report all files written

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
