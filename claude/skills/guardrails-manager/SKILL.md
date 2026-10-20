---
name: guardrails-manager
category: Tooling & DevOps
description: >
  Lifecycle management of vendor-neutral agent guardrails — the reusable CLAUDE.md / AGENTS.md
  / GEMINI.md rules, snippets, and whole-file captures archived under shared/guardrails/. Use
  when the user invokes /archive-guardrail or /install-guardrail, or says "archive this
  CLAUDE.md rule", "capture this guardrail", "save this to the archive as a rule", "install
  that rule into this repo's CLAUDE.md", or "mine my CLAUDE.md rules into the archive". All
  user interaction MUST go through the AskUserQuestion tool — never free-form text, never
  inline markdown questions.
---

# Guardrails Manager

You manage the **`shared/guardrails/`** asset class in the AI Agent Kit at
`C:\development\ai-agent-kit` — vendor-neutral agent guardrail content: the rules, snippets,
and whole-file captures that populate a project's `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or a
profile's `~/.claude/rules/*.md`.

**Critical constraint:** Every question or confirmation to the user MUST use the
`AskUserQuestion` tool. Never prompt via free text, never write "Type yes/no", never use inline
markdown questions.

Read `shared/guardrails/README.md` first — it holds the frontmatter contract and conventions
this skill enforces.

---

## Core concepts

### Guardrail
A single markdown file under `shared/guardrails/<name>.md` with YAML frontmatter (contract in
`shared/guardrails/README.md`) followed by the verbatim drop-in body. `kind: snippet` is a
self-contained rule; `kind: file` is a whole `CLAUDE.md`/`AGENTS.md` captured as a starting
point.

### Vendor mapping (`applies-to`)
| token | destination file |
|---|---|
| `claude` | `CLAUDE.md` |
| `codex`  | `AGENTS.md` |
| `gemini` | `GEMINI.md` |

### Scope
- `scope: global` → belongs in a profile (`~/.claude/rules/*.md` or the profile-level
  `CLAUDE.md`), applies to every project.
- `scope: repo` → belongs in a single repository's `CLAUDE.md`/`AGENTS.md`/`GEMINI.md`.

### Flow direction
Always **source → archive** (`/archive-guardrail`). `/install-guardrail` is the only reverse
direction, mirroring the skill lifecycle.

---

## Operations

### /archive-guardrail
Capture guardrail content into `shared/guardrails/`.

1. Determine the source via `AskUserQuestion`: a file path (a `CLAUDE.md`/`AGENTS.md`/rules
   file), a section of one, or pasted content.
2. If capturing a **section**, isolate just that concern — one guardrail is one concern. Offer
   to split a multi-concern file into several guardrails.
3. Derive `name` (kebab-case, unique under `shared/guardrails/`), draft a trigger-rich
   `description`, and infer `kind`, `scope`, `applies-to`, `category`, `targets`, `source`.
   Confirm the derived frontmatter with `AskUserQuestion` before writing.
4. Strip any vendor-specific tool syntax / hard-coded install path from the **body** (the
   vendor-neutral test) — the destination is chosen at install time, not baked in. If the
   content can't pass the test, tell the user it belongs in a vendor tree, not `shared/`.
5. Write `shared/guardrails/<name>.md` (frontmatter + verbatim body). If it supersedes an
   existing rule, add a **Retires:** line to the body.
6. Do NOT touch `manifest.json`/`CATALOG.md` — `shared/` classes are not manifest-tracked.
   Run `pwsh ./scripts/audit.ps1` (it scans `shared/` for secrets) and report the result.
7. All changes land via a feature branch → PR to `dev` (never commit to `dev`/`main`).

### /install-guardrail <name> [target-dir]
Deploy a guardrail into a consumer.

1. Resolve `<name>` under `shared/guardrails/`. If ambiguous/missing, search and offer matches
   via `AskUserQuestion`.
2. Read its `scope` and `applies-to`. Confirm the target with `AskUserQuestion`:
   - `scope: repo` → the target repo's `CLAUDE.md` (and/or `AGENTS.md`/`GEMINI.md` per
     `applies-to`), defaulting to `[target-dir]` or the current repo.
   - `scope: global` → the matching profile file (`~/.claude/rules/<name>.md`, or the profile
     `CLAUDE.md`/`AGENTS.md`).
3. Insert the **body** (below the frontmatter) into the destination — append under the right
   heading, or replace a prior version if the guardrail's **Retires:** line names one already
   present. Never duplicate a rule already there; show a diff-style summary of what will change
   and confirm before writing.
4. Do not carry the archive frontmatter into the destination file — it is archive metadata, not
   guardrail content.

---

## Guardrail search
When the user asks "is there a rule for X" or "what guardrails exist", grep
`shared/guardrails/*.md` frontmatter (`name`, `description`, `category`) and return ranked
matches via a short list — offer `/install-guardrail` on the pick.
