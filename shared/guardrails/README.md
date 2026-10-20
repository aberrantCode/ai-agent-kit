# guardrails/

Vendor-neutral **agent guardrail content** — the reusable rules, snippets, and whole-file
captures that populate a project's `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or a profile's
`~/.claude/rules/*.md`. One concern per file. This is where a rule authored (or *mined*) in
one repo is archived so every other repo and profile can adopt it.

> The same guardrail deploys into a Claude project as `CLAUDE.md` content, into a Codex
> project as `AGENTS.md`, and into a Gemini project as `GEMINI.md`. The **content** is
> vendor-neutral; only the destination *filename* differs — which is exactly why this class
> lives in `shared/` (see the vendor-neutral test below), the same way `prompts/` does.

## The vendor-neutral test, as applied here

A guardrail belongs in `shared/guardrails/` only if its body is plain markdown any vendor's
agent can read verbatim — no vendor-specific frontmatter contract, tool-invocation syntax, or
hard-coded install path *in the content*. The per-vendor destination file is chosen at install
time (`applies-to` frontmatter below), not baked into the text. A rule that only makes sense
for one CLI's tool syntax is not a guardrail — it belongs in that vendor's tree.

## What qualifies

- **A rule / snippet** — a self-contained policy you want dropped into `CLAUDE.md`/`AGENTS.md`
  (e.g. "scope cohesion, not line count, is the PR gate"). `kind: snippet`.
- **A whole-file capture** — an entire `CLAUDE.md` / `AGENTS.md` archived as a reusable
  starting point for a new repo of the same shape. `kind: file`.

## Frontmatter contract

Each guardrail is a single markdown file with YAML frontmatter, then the drop-in body:

```yaml
---
name: scope-cohesion-over-line-count   # MUST equal the filename (without .md)
description: One-line, trigger-rich summary of the rule
category: Foundations & Workflow       # reuse the skill CATEGORY_ORDER values for consistency
kind: snippet                          # snippet | file
scope: global                          # global (~/.claude/rules or profile) | repo (a repo's CLAUDE.md)
applies-to: [claude, codex, gemini]    # destination map: claude→CLAUDE.md, codex→AGENTS.md, gemini→GEMINI.md
targets: git-workflow                  # optional — the rules file / section this belongs under
source: mined from session transcripts, 2026-08-09   # optional — provenance
status: active                         # active | draft | deprecated   (optional)
version: 2026-08-09                    # semver or ISO date            (optional)
---
```

Everything **below** the frontmatter is the verbatim content installed into the destination
file — write it so it reads correctly when pasted straight into a `CLAUDE.md`.

## Lifecycle

Managed by the **`guardrails-manager`** skill (profile-install it once, then the commands are
available everywhere):

| Command | Purpose |
|---|---|
| `/archive-guardrail` | Capture a `CLAUDE.md`/`AGENTS.md` file, a section, or pasted content into this directory as a new guardrail (with frontmatter). |
| `/install-guardrail <name> [dir]` | Deploy a guardrail into a project's `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` (or a profile rules file), per its `applies-to`/`scope`. |

Flow is always **source → archive** (`/archive-guardrail`); `/install-guardrail` is the only
reverse direction, mirroring the skill lifecycle.

## Conventions

- **One concern per file** — a guardrail is atomic, like a `~/.claude/rules/*.md` module.
- **Delete superseded guardrails** — git history is the archive of record; `deprecated` is a
  transient "scheduled for removal" marker, not a tombstone.
- **No secrets** — `audit.ps1` scans everything under `shared/` for secret-shaped content and
  fails the build on a hit. Pointers only.
- **Retirement note** — when a guardrail supersedes a prior rule, say so in the body so an
  installing agent knows what it replaces (see `scope-cohesion-over-line-count.md`).
