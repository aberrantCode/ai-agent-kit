---
name: skills-manager
description: >
  Full lifecycle management of LLM skills across the workstation — finding, archiving,
  installing, updating, and importing skills with their complete bundles (sub-skills +
  companion commands). Use when the user invokes /find-skills, /sync-skill, /install-skill,
  /update-skill, or /import-skill. All user interaction MUST go through the AskUserQuestion
  tool — never free-form text, never inline markdown questions.
---

# Skills Manager

You are the domain expert for the LLM Skills Archive at `C:\development\llm_skills`. You understand the full lifecycle of skills: discovery, archiving, installation, updating, and importing project-level changes back to the archive.

**Critical constraint:** Every question or confirmation to the user MUST use the `AskUserQuestion` tool. Never prompt via free text, never write "Type yes/no", never use inline markdown questions.

---

## Core Concepts

### Archive
`C:\development\llm_skills` is the single source of truth for all LLM skills, agents, and commands. It consolidates skills from the global Claude profile (`~/.claude/`) and all projects under `C:\development\`.

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

### Installed Copy
A skill file with `installed-from: llm_skills` in its YAML frontmatter is an installed copy from the archive. The sync and find operations skip these — they are not project-developed skills.

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
  - `deprecated` — superseded or obsolete; `/install-skill` skips and warns; `/find-skills` classifies as **Deprecated** rather than New/Changed

- **`version`**: semver string (e.g. `1.2.0`) or ISO date (e.g. `2026-04-05`) — displayed by `/update-skill` so the user sees the version delta before accepting an update

- **`requires`**: YAML list of skill names this skill depends on (e.g. `[project-manager, base]`) — `/install-skill` reads this and auto-installs all listed dependencies before installing the target skill

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
   - Read frontmatter — if `installed-from: llm_skills` is present, **skip** (installed copy)
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
2. Skip any match where `installed-from: llm_skills` is in frontmatter
3. Apply conflict resolution if multiple sources found — take highest-priority source
4. Detect companion commands and sub-skills in the same project (see heuristics above)
5. Write to archive:
   - `SKILL.md` → `claude/skills/<name>/SKILL.md`
   - Companion commands → `claude/skills/<name>/commands/<cmd>.md`
   - Sub-skills → `claude/skills/<name>/sub-skills/<sub>/SKILL.md`
6. Generate a visual diagram for the skill:
   - Invoke the `visual-explainer:generate-web-diagram` skill
   - Instruct it to diagram: the skill's purpose (from `description` frontmatter), its key operations or phases (from section headings), significant inputs/outputs, and any decision points or branching paths
   - Save the resulting HTML to `claude/skills/<name>/diagram.html`
   - Add or update a `## Diagram` section at the bottom of `claude/skills/<name>/SKILL.md` (before any final horizontal rule) containing exactly: `[View diagram](diagram.html)`
7. Update README: add row if new, update description if `description` frontmatter changed; include diagram link (see README Update Rules)
8. Report what was written

### Without a skill name

1. Run the /find-skills scan internally (no user prompt for the scan itself) to enumerate scope
2. Use `AskUserQuestion` to confirm:
   - Question: "Sync all N new/changed skills? (list skill names)"
   - Options: "Yes, sync all" | "Cancel"
3. Proceed only on confirm; process each New and Changed skill in turn

### README Update Rules (sync)
- New skill: extract `description` from frontmatter, classify subsection (see heuristics), insert alphabetically within subsection, mark `✓` in correct toolset column, increment counts
- Changed skill: update Description cell only if frontmatter `description` changed; do not move the row
- Bundled commands: document on the skill's row as `— ships with /cmd1, /cmd2`; do NOT add standalone rows for them in the Commands table
- Sub-skills in bundles: do NOT list as standalone rows; implied by parent skill row
- **Diagram link**: every skill row that has a `diagram.html` in its archive directory must include a diagram link in the Skill column cell, formatted as: `` [`<name>`](claude/skills/<name>/) [(diagram)](claude/skills/<name>/diagram.html) ``
- Never delete from archive; never remove rows

---

## Operation: /install-skill [name] [target-dir]

Deploy a skill bundle from the archive into a project.

### Steps

1. **Determine scope:**
   - If `name` given: install that skill only
   - If no `name`: enumerate all skills in `claude/skills/` that have not already been installed in `target-dir`; use `AskUserQuestion` to confirm:
     - Question: "Install all N available skills into `<target>`? This will write N files."
     - Options: "Yes, install all" | "Cancel"
     - Proceed only on confirm

2. For a named skill: locate `claude/skills/<name>/` in the archive; if not found use `AskUserQuestion`:
   - Question: "Skill `<name>` not found in archive. Check the name and try again."
   - Options: "OK" | "List available skills"

3. If `target-dir` not provided, use `AskUserQuestion`:
   - Question: "Where should the skill(s) be installed?"
   - Options: "Current project directory" | "Other path (specify below)"

4. Resolve dependencies: read `requires:` list from each skill's frontmatter; recursively locate those skill bundles in the archive and add them to the install scope. Deduplicate — never install the same skill twice.

5. Inventory what will be installed (target skill + all resolved dependencies):
   - `SKILL.md` (1 file per skill)
   - Sub-skills from `sub-skills/` (N files)
   - Commands from `commands/` (N files)

6. If `name` was given, use `AskUserQuestion` to confirm:
   - Question: "Install `<name>` (+ N dependencies) into `<target>`? This will write N files."
   - Options: "Yes, install" | "Cancel"

7. On confirm:
   - Write `<target>/.claude/skills/<name>/SKILL.md`; inject `installed-from: llm_skills` into frontmatter (add after existing fields)
   - Write each sub-skill to `<target>/.claude/skills/<sub>/SKILL.md` with same marker
   - Write each command to `<target>/.claude/commands/<cmd>.md` (no marker — commands are not skills)

8. Report all files written

---

## Operation: /update-skill [name]

Update installed skills in the current project when the archive has newer versions.

### Steps

1. Scan current project's `.claude/skills/` for files with `installed-from: llm_skills` in frontmatter
2. If `name` given: filter to that skill only

3. For each installed skill found:
   - Compare content against archive version
   - If identical: skip (no update needed)
   - If archive is newer: record as outdated

4. **Confirm scope** with `AskUserQuestion` before touching anything:
   - If updating all: "Update all N outdated skills? (list skill names, include version delta where available, e.g. skill-x v1.0→v1.2)"
   - If updating one by name: "Update `<name>` to the archive version? (v1.0 → v1.2)"
   - Options: "Yes, update" | "Cancel"

5. On confirm:
   - Overwrite each `SKILL.md`, preserving the `installed-from: llm_skills` marker in frontmatter
   - Also check `commands/` in the archive bundle — write any new or changed commands to `<project>/.claude/commands/`
   - Also check `sub-skills/` — update any installed sub-skills that are outdated
   - Regenerate the diagram: invoke `visual-explainer:generate-web-diagram` for each updated skill and overwrite `claude/skills/<name>/diagram.html`; update the `## Diagram` section in SKILL.md if the path changed

6. Report updated files

---

## Operation: /import-skill [name]

Import project-level changes to a skill back into the archive and the global user profile.

### Steps

1. **Determine scope:**
   - If `name` given: import that skill only
   - If no `name`: scan current project's `.claude/skills/` for all skills that do NOT have `installed-from: llm_skills` and differ from the archive; use `AskUserQuestion` to confirm:
     - Question: "Import all N project-developed skills to archive and user profile? (list names)"
     - Options: "Yes, import all" | "Cancel"
     - Proceed only on confirm

2. Locate `<name>/SKILL.md` in the current project's `.claude/skills/`
3. Check frontmatter: if `installed-from: llm_skills` is present, use `AskUserQuestion` to reject:
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
   - **README**: update Description cell if frontmatter `description` changed

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

4. Update README: for each skill now having a diagram, add the diagram link to its Skill column cell (see README Update Rules)

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
2. **README drift — broken links**: rows in the README Skills table whose link target directory does not exist in `claude/skills/`
3. **README drift — missing rows**: skill directories in `claude/skills/*/` that have no corresponding row in the README Skills table (match by link text)
4. **Malformed frontmatter**: `SKILL.md` files missing required `name:` or `description:` fields
5. **Deprecated installs**: scan all projects under `C:\development\` for installed skills (`installed-from: llm_skills`) where the archive copy has `status: deprecated` — list project and skill name
6. **Codex/Gemini parity gaps**: README rows with `✓` only in the Claude column — grouped by subsection, sorted by description length as a proxy for skill complexity (longer = more porting value)

### Output format

```
┌─ Skills Manager: Audit Report ─────────────────────────────────┐
│ Missing diagrams (N):   skill-a, skill-b, ...                  │
│ README broken links (N): row-name → path/does/not/exist        │
│ README missing rows (N): skill-dir has no README entry         │
│ Bad frontmatter (N):    skill-c (missing description)          │
│ Deprecated installs (N): project-x uses deprecated skill-d     │
│ Parity gaps — Claude only (N skills, top candidates):          │
│   - security (Security & Credentials)                          │
│   - typescript (Languages & Runtimes)                          │
│   ...                                                           │
└────────────────────────────────────────────────────────────────┘
```

---

## Operation: /push-skill [name]

Push a skill bundle from the archive to the global user profile (`~/.claude/`) so it is available across all projects.

### Steps

1. **Determine scope:**
   - If `name` given: push that skill bundle only
   - If no `name`: enumerate all skills in `claude/skills/`; use `AskUserQuestion` to confirm:
     - Question: "Push all N archive skills to the global profile (~/.claude/)?"
     - Options: "Yes, push all" | "Cancel"
     - Proceed only on confirm

2. For each skill to push:
   - Check if `status: draft` — skip with a warning; drafts are not pushed to the global profile
   - Check if `~/.claude/skills/<name>/SKILL.md` already exists and differs — use `AskUserQuestion`:
     - Question: "~/.claude/skills/<name> exists and differs. Overwrite with archive version?"
     - Options: "Yes, overwrite" | "Skip this skill"

3. On confirm:
   - Write `SKILL.md` to `~/.claude/skills/<name>/SKILL.md` (do NOT add `installed-from` marker — the global profile is a source, not a deployment target)
   - Write each sub-skill from `sub-skills/` to `~/.claude/skills/<sub>/SKILL.md`
   - Write each companion command from `commands/` to `~/.claude/commands/<cmd>.md`

4. Report all files written

---

## Source Discovery Table

| Source | Path Pattern | Toolset | Archive Destination |
|--------|-------------|---------|---------------------|
| Global profile | `~/.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Global profile | `~/.claude/agents/*.md` | Claude | `claude/agents/<name>.md` |
| Global profile | `~/.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| This repo | `.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| This repo | `.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| Other projects | `.claude/skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Other projects | `.claude/agents/*.md` | Claude | `claude/agents/<name>.md` |
| Other projects | `.claude/commands/*.md` | Claude | `claude/commands/<name>.md` |
| Other projects | `skills/*/SKILL.md` | Claude | `claude/skills/<name>/SKILL.md` |
| Other projects | `codex/skills/*/SKILL.md` | Codex | `codex/skills/<name>/SKILL.md` |
| Other projects | `gemini/skills/*/SKILL.md` | Gemini | `gemini/skills/<name>/SKILL.md` |

**Nested paths**: The skill `<name>` is always the leaf directory containing `SKILL.md`. Intermediate path segments (e.g. `homeradar/` in `skills/homeradar/feature-start/SKILL.md`) are discarded.

**Installed-copy filter**: Apply before any classification. Skip any file with `installed-from: llm_skills` in frontmatter.

**`llm_skills` itself**: Only scan `.claude/` — never recurse into `claude/` (the archive destination). Scanning the archive as a source would create circular copies.

**Directories to skip**: `nul`, `emby-opbta.p12`, `fullchain.pem`, `privkey.pem`, `recovery_app`, and any loose files (not directories) at the `C:\development\` root.

---

## README Classification Heuristics

Infer subsection from keywords in the skill's `description` field:

| Keywords | Subsection |
|----------|-----------|
| git, branch, commit, PR, merge, workflow, session, team, coordination, repo | Foundations & Workflow |
| TypeScript, Python, Node.js, runtime, language | Languages & Runtimes |
| React, Vue, Next.js, frontend framework, PWA, Flutter | Frontend Frameworks |
| Android, iOS, mobile native, Kotlin, Swift | Mobile (Native) |
| UI, UX, design, Tailwind, accessibility, visual, diagram, explainer | UI & Design |
| database, SQL, Supabase, Firebase, DynamoDB, Aurora, Cosmos, D1, schema | Databases & Storage |
| code review, testing, quality, lint, coverage, Playwright, duplication | Code Quality |
| security, credentials, auth, OWASP, secrets, vulnerability | Security & Credentials |
| AI, LLM, agent, prompt, model, Anthropic, OpenAI, Gemini | AI & LLM |
| commerce, Shopify, WooCommerce, Medusa, Stripe, payment | Commerce & Payments |
| Klaviyo, Reddit, Teams, PostHog, third-party, integration | Third-Party Integrations |
| SEO, sitemap, robots, web presence, content, GEO | SEO & Web Presence |
| tooling, DevOps, CLI, deploy, Vercel, render, CI/CD | Tooling & DevOps |
| OSINT, research, intelligence, GEOINT, worldview, forensics | Research & OSINT |

If no keywords match: **Uncategorized**. Multiple matches: most keyword hits wins; break ties with more specific subsection.

---

## Archive Invariants — Never Violate

1. **Never delete from archive.** Even if a source file no longer exists, the archive copy stays. Deletions are manual curatorial decisions.
2. **Flow is always source → archive** — except `/import-skill`, which explicitly reverses this.
3. **The archive README is the authoritative index.** Every archived skill must have a row; every row must point to a real file.
4. **Toolset is determined by directory, not content.**
5. **Installed copies are not project-developed skills.** The `installed-from: llm_skills` marker gates this distinction.
