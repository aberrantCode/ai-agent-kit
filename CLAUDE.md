# AI Agent Kit

Single source of truth for all AI agent extensions across the workstation — skills, agent instructions, slash commands (and status lines and prompts as they land).
Manages domain-specific knowledge modules for Claude Code, OpenAI Codex CLI, and Google Gemini CLI.

---

## Directory Structure

```
claude/
  instructions/                     — 15 agent instructions (invoked via Task tool)
  commands/                   — 27 global slash commands
  skills/<name>/
    SKILL.md                  — main skill content
    diagram.html              — visual diagram (generated)
    sub-skills/               — optional delegate sub-skills
    commands/                 — optional companion slash commands
codex/
  instructions/                     — agent instructions for Codex CLI
  skills/<name>/SKILL.md
gemini/
  instructions/                     — agent instructions for Gemini CLI
  skills/<name>/SKILL.md
.claude/commands/             — repo-local slash commands (skills-manager)
logs/timing.jsonl             — ship-to-dev timing log
```

---

## Key Conventions

- **Never delete** from archive — set `status: deprecated` instead
- **Flow direction** is always source → archive; only `/import-skill` reverses this
- **Installed copies** carry `installed-from: ai-agent-kit` frontmatter (legacy copies: `installed-from: llm_skills`) — skip either during scans
- **Skill bundles** may include optional `sub-skills/` and `commands/` subdirectories
- **All changes** go through feature branch → PR → `dev` (never commit directly to `dev` or `main`)
- **README parity** — every archived skill must have a README row; every row must point to a real file

---

## Skill Frontmatter Fields

| Field | Required | Notes |
|---|---|---|
| `name:` | yes | unique identifier |
| `description:` | yes | one-line summary |
| `status:` | no | `draft` \| `active` \| `deprecated` — defaults to `active` |
| `version:` | no | semver or ISO date |
| `requires:` | no | list of skill names this skill depends on |
| `installed-from:` | no | set to `ai-agent-kit` on installed copies only (legacy: `llm_skills`) |

---

## Management Commands

| Command | Purpose |
|---|---|
| `/audit-skills` | Full archive health check (read-only) |
| `/find-skills` | Discover new/changed skills on workstation |
| `/sync-skill <name>` | Archive a skill from its source location |
| `/install-skill <name> <dir>` | Deploy skill bundle to a project |
| `/update-skill` | Update installed skills to archive versions |
| `/import-skill <name>` | Pull project-level changes back to archive |
| `/push-skill <name>` | Push skill bundle to global `~/.claude/skills/` |
| `/search-skill <query>` | Keyword search across archive |
| `/backfill-diagrams` | Generate missing `diagram.html` files |

---

## Git Workflow

Always use `/ship-to-dev` to merge changes into `dev`, then `/release-to-main` for production releases.

Feature branches: `type/short-description` branching off `dev`, PR back to `dev`.
