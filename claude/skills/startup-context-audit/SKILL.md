---
name: startup-context-audit
category: Tooling & DevOps
description: Use when a newly launched Claude Code session already shows a token count greater than zero and you want to know why and how big — "why does a new session start with tokens", "what's in my context window at launch", "startup context cost", "per-repo baseline token audit", "why is this repo's fresh session so heavy", "what am I paying before I type anything". Measures the first-turn (pre-work) context each repo loads and decomposes it into readable on-disk instructions versus the non-visible harness. Complements usage-limit-reducer, which reports historical burn over time rather than the per-session baseline.
---

# Startup Context Audit

Every Claude Code session opens with a token count already above zero — before you
type a single instruction. This skill measures that number and shows what it is made
of, per repo.

**Core principle:** the "already > 0" count at launch is the **first-turn context** —
everything loaded before any real work: the harness (system prompt + tool schemas +
skill/agent/MCP inventory + injected hooks) plus your on-disk instruction stack (global
`~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, the project `CLAUDE.md`, and the memory
index). This skill reads the local session logs, reports that baseline for each repo,
and splits it into the part you can open on disk and the harness remainder you cannot.

**REQUIRED BACKGROUND:** none. **RELATED SKILL:** `usage-limit-reducer` diagnoses
*historical* token burn across days of sessions and applies rules to cut it; this skill
is its **startup / per-session-baseline** complement — use that one for "I'm burning
tokens over a long conversation", this one for "why does a *fresh* session already cost
so much". They read the same `~/.claude/projects/*/*.jsonl` logs from different angles.

## When to use

- A brand-new session shows a nonzero token count and you want the breakdown.
- One repo's fresh sessions feel heavier than another's and you want to know why.
- You're auditing whether your global `CLAUDE.md` / `rules/` stack has grown expensive.
- You want to attribute a repo's startup cost to project-local `.claude/` extensions or
  extra MCP servers.

**Not for:** trimming a long-running conversation's ongoing usage (that's
`usage-limit-reducer`), or changing any setting — this skill only measures.

## How to run

Run the bundled script with the absolute path to `scripts/startup-context.py` inside
this skill's directory. No arguments needed for the common case:

```bash
python <SKILL_DIR>/scripts/startup-context.py
```

It emits two parts:

- **Part 1 — current repo baseline decomposition.** Auto-detects the repo you're in
  (walks up from the working directory to the nearest `.git`), finds its session history,
  and breaks the leanest fresh baseline into readable on-disk buckets versus the harness
  remainder.
- **Part 2 — per-repo table.** The most-recently-modified sibling repos under the
  workspace root, each with its fresh baseline, latest baseline, and own `CLAUDE.md` size.

Flags:

| Flag | Default | Purpose |
|---|---|---|
| `--dev-root PATH` | `C:/development` | Workspace root scanned for sibling repos in Part 2 |
| `--top N` | `10` | How many recent repos to list in Part 2 |
| `--project SUBSTR` | (none) | Case-insensitive substring; only repos whose path matches |
| `--json` | off | Machine-readable output instead of the console tables |

## What the numbers mean

- **fresh baseline** = the *leanest* first-turn context seen across a repo's recent
  sessions — the closest proxy for "what a genuinely new session starts at."
- **latest baseline** = the first-turn context of the most recent session; higher when
  that session was resumed (it carries cache-read tokens from prior turns).
- **readable on-disk instructions** = the buckets you can open and edit: global
  `CLAUDE.md`, `rules/*.md`, project `CLAUDE.md`, `MEMORY.md`.
- **harness remainder** = fresh baseline minus readable = the system prompt, tool
  schemas, skill/agent/MCP inventory, and injected hooks. It is **not on disk**; it is
  reported as the difference, not measured directly.

## Worked example (ai-agent-kit, measured)

A fresh `ai-agent-kit` session starts at **~49K tokens**. Decomposed:

| Bucket | Tokens | On disk? |
|---|--:|---|
| `~/.claude/CLAUDE.md` (global) | ~1.2K | yes |
| `~/.claude/rules/*.md` (12 files) | ~6.5K | yes |
| project `CLAUDE.md` | ~1.5K | yes |
| `MEMORY.md` (auto-memory index) | ~0.9K | yes |
| **= readable on-disk instructions** | **~10K** | — |
| **= harness (sysprompt + tools + skills + MCP + hooks)** | **~39K (≈80%)** | **no** |
| **TOTAL fresh baseline** | **~49K** | — |

Across repos the fresh baseline clusters at **41K–49K** — the global stack is identical
everywhere. The outlier is **AC_OPBTA at ~79K**, because it carries a large
*project-local* `.claude/` surface (~30 slash commands + `agents/` + `rules/` + `skills/`)
plus extra MCP servers. **Takeaway:** the ~80% harness share is mostly fixed; the lever
you actually control per repo is the size of the project-local `.claude/` surface and the
number of MCP servers it enables.

## How it works (two facts worth preserving)

- **Token estimate is chars/4.** No `tiktoken` is assumed on the workstation, so on-disk
  bucket sizes use a `chars/4` estimate — the console header prints which tokenizer was
  used. If `tiktoken` *is* installed the script uses it automatically and says so. Session
  baselines are never estimated: they come straight from each JSONL's own `usage` records.
- **cwd is read, never decoded.** The `~/.claude/projects/<dir>` name encodes `_`, `:`,
  and `\` all as `-`, so it is lossy and ambiguous. The script never decodes a dir name;
  it inverts by reading the real `cwd` field the CLI writes into each session's JSONL.

## Common mistakes

- **Reading `latest baseline` as the startup cost.** A resumed session's latest turn
  includes cache-read from earlier work — use **fresh baseline** for "new session" cost.
- **Expecting Part 1 inside a git worktree.** A worktree is a distinct working directory
  with its own (often empty) session history; run from the repo's main checkout for the
  Part-1 decomposition, or read the repo's row in Part 2.
- **Treating the harness remainder as trimmable on disk.** It isn't a file — shrink it by
  reducing enabled skills/MCP servers, not by editing a document.

## Diagram

[View diagram](diagram.html)
