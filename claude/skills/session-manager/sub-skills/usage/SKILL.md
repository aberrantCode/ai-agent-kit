---
name: sm-usage
description: >
  Sub-skill of `session-manager`. Token cost, in two modes. Historical burn — "hit my limit",
  "running out of tokens", "usage limit", "save tokens", "reduce usage", "am I wasting tokens",
  "this chat is getting long", "which model should I use": diagnoses the current session, runs a
  real token-usage report from local JSONL logs, and applies the 11 rules for reducing usage
  (/token-report). Startup baseline — "why does a new session start with tokens", "what's in my
  context window at launch", "startup context cost", "per-repo baseline token audit", "why is
  this repo's fresh session so heavy", "what am I paying before I type anything": measures the
  first-turn context each repo loads and splits it into on-disk instructions versus the
  non-visible harness (/startup-cost).
---

# usage

Token cost, in two modes that read the same `~/.claude/projects/*/*.jsonl` logs from different angles:

| Mode | Question it answers | Command | Script |
|---|---|---|---|
| **Historical burn** | "I'm burning tokens over long conversations / days of sessions." | `/token-report` | `scripts/usage-report.py` |
| **Startup baseline** | "Why does a *fresh* session already cost so much?" | `/startup-cost` | `scripts/startup-context.py` |

Pick the mode from the request (or the command that loaded this file). The two complement each other: historical burn reports usage over time and applies rules to cut it; startup baseline reports the per-session pre-work baseline. If a user's fresh sessions are heavy, run startup baseline; if long conversations are heavy, run historical burn. Both share the transcripts library ([`../transcripts/SKILL.md`](../transcripts/SKILL.md)). Formerly the `usage-limit-reducer` and `startup-context-audit` skills.

---

## Mode A — Historical burn (`/token-report`)

Apply Dubi's 11 rules for cutting Claude token usage. Claude re-reads the entire conversation every turn, so 98.5% of tokens often go to re-reading history instead of generating responses. This mode diagnoses where the user's tokens are going and applies the rules that actually move the needle.

Do the steps in order. Skip any step that clearly doesn't apply, but don't skip all of them — the value is in matching rules to what the user is actually doing.

### Step 1 — Run the real token-usage report

Rule #4: "you can't fix what you can't measure." Claude Code already writes every token, model, and timestamp to `~/.claude/projects/<project>/<session>.jsonl`. Run the bundled script to show the breakdown (use the absolute path to `scripts/usage-report.py` inside this sub-skill's directory):

```bash
python3 <USAGE_DIR>/scripts/usage-report.py --days 7
```

Flags: `--days N` (default 7), `--project <substring>` to scope by cwd, `--json` for machine-readable output. Share the headline numbers with the user — cache-hit % and model mix are the two that matter most. A low cache-hit % (under ~60%) means too many fresh chats or cache-busting edits; high Opus share for routine work means Rule #8 applies.

### Step 2 — Diagnose the current session

Before advising, check three things:

1. **Conversation length.** If this session already has many turns, rule #2 applies directly. Suggest `/compact` (summarize in place) or `/clear` then paste a one-paragraph summary as the first message of the new chat.
2. **CLAUDE.md presence.** Check the project root for `CLAUDE.md` and `~/.claude/CLAUDE.md`. If missing, rule #6 applies — offer to create one with the user's role, style, and project conventions so every new session doesn't burn 3–5 messages on setup.
3. **Model in use.** If the user is on Opus for trivial tasks (grammar, formatting, short answers, quick renames), rule #8 applies — recommend `/model claude-haiku-4-5` for those and keep Opus for deep work.

### Step 3 — Apply the rules that match

Pick the 2–4 rules most relevant to what the user is doing right now. Don't dump all 11 on them. For each rule you pick, say (a) what to do, (b) why it works, (c) the concrete next action.

| # | Rule | Claude Code action |
|---|------|--------------------|
| 1 | Don't follow up to correct — restart with a fixed prompt | When Claude misunderstands, `/clear` and re-prompt instead of piling on corrections |
| 2 | Fresh chat every 15–20 turns | `/compact` to summarize in place, or `/clear` + paste summary |
| 3 | Batch questions into one message | Combine related asks into one prompt; Claude often answers better with full picture |
| 4 | Track actual token usage | Run the script in Step 1 |
| 5 | Reuse recurring context | Put it in `CLAUDE.md`, a skill, or `.context/` — not re-pasted each session |
| 6 | Set up memory / user preferences | Create or update `CLAUDE.md`; use the memory system under `~/.claude/projects/*/memory/` |
| 7 | Turn off features you don't use | Audit `~/.claude/settings.json` for unused MCP servers, hooks, permissions |
| 8 | Use Haiku for simple tasks | `/model claude-haiku-4-5` for grammar, drafts, formatting, quick lookups |
| 9 | Spread work across the day | 5-hour rolling window — split into 2–3 sessions instead of one marathon |
| 10 | Work off-peak | Peak is 5–11am PT / 8am–2pm ET weekdays; evenings and weekends stretch your plan |
| 11 | Enable Overage as a safety net | Settings → Usage on Pro/Max plans — pay-as-you-go kicks in at the limit |

### Step 4 — Offer concrete next actions

End with a short, ordered list of what to do *now*, based on the diagnosis. Examples:

- "Run `/compact` — this conversation is 40+ turns."
- "I can create a `CLAUDE.md` with your preferences — want me to?"
- "Switch to Haiku for this rename: `/model claude-haiku-4-5`."

Don't recite every rule. Don't lecture. Match the advice to what the session actually shows.

### Rules not implementable in Claude Code

- Rule #1 ("Edit your prompt") is a claude.ai web UI feature — in Claude Code the equivalent is `/clear` + restart.
- Rule #5 ("Upload to Projects") is also web-only — use `CLAUDE.md`, skills, and `.context/` instead.
- Rule #11 (Overage) is plan-level — mention it, don't implement it.

### What this mode does NOT do

- It does not silently change the user's model or settings. Recommend, then act only on confirmation.
- It does not summarize-and-clear without asking — the user may have unsaved context in the conversation.
- It does not send data anywhere. The usage report is strictly local.

---

## Mode B — Startup baseline (`/startup-cost`)

Every Claude Code session opens with a token count already above zero — before you type a single instruction. This mode measures that number and shows what it is made of, per repo.

**Core principle:** the "already > 0" count at launch is the **first-turn context** — everything loaded before any real work: the harness (system prompt + tool schemas + skill/agent/MCP inventory + injected hooks) plus your on-disk instruction stack (global `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, the project `CLAUDE.md`, and the memory index). The script reads the local session logs, reports that baseline for each repo, and splits it into the part you can open on disk and the harness remainder you cannot.

### When to use

- A brand-new session shows a nonzero token count and you want the breakdown.
- One repo's fresh sessions feel heavier than another's and you want to know why.
- You're auditing whether your global `CLAUDE.md` / `rules/` stack has grown expensive.
- You want to attribute a repo's startup cost to project-local `.claude/` extensions or extra MCP servers.

**Not for:** trimming a long-running conversation's ongoing usage (that is Mode A), or changing any setting — this mode only measures.

### How to run

Run the bundled script with the absolute path to `scripts/startup-context.py` inside this sub-skill's directory. No arguments needed for the common case:

```bash
python <USAGE_DIR>/scripts/startup-context.py
```

It emits two parts:

- **Part 1 — current repo baseline decomposition.** Auto-detects the repo you're in (walks up from the working directory to the nearest `.git`), finds its session history, and breaks the leanest fresh baseline into readable on-disk buckets versus the harness remainder.
- **Part 2 — per-repo table.** The most-recently-modified sibling repos under the workspace root, each with its fresh baseline, latest baseline, and own `CLAUDE.md` size.

| Flag | Default | Purpose |
|---|---|---|
| `--dev-root PATH` | `C:/development` | Workspace root scanned for sibling repos in Part 2 |
| `--top N` | `10` | How many recent repos to list in Part 2 |
| `--project SUBSTR` | (none) | Case-insensitive substring; only repos whose path matches |
| `--json` | off | Machine-readable output instead of the console tables |

Presentation: lead with the headline — the repo's fresh baseline and how much of it is the on-disk instruction stack versus the harness remainder — then the per-repo table.

### What the numbers mean

- **fresh baseline** = the *leanest* first-turn context seen across a repo's recent sessions — the closest proxy for "what a genuinely new session starts at."
- **latest baseline** = the first-turn context of the most recent session; higher when that session was resumed (it carries cache-read tokens from prior turns).
- **readable on-disk instructions** = the buckets you can open and edit: global `CLAUDE.md`, `rules/*.md`, project `CLAUDE.md`, `MEMORY.md`.
- **harness remainder** = fresh baseline minus readable = the system prompt, tool schemas, skill/agent/MCP inventory, and injected hooks. It is **not on disk**; it is reported as the difference, not measured directly.

### Worked example (ai-agent-kit, measured)

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

Across repos the fresh baseline clusters at **41K–49K** — the global stack is identical everywhere. The outlier is **AC_OPBTA at ~79K**, because it carries a large *project-local* `.claude/` surface (~30 slash commands + `agents/` + `rules/` + `skills/`) plus extra MCP servers. **Takeaway:** the ~80% harness share is mostly fixed; the lever you actually control per repo is the size of the project-local `.claude/` surface and the number of MCP servers it enables.

### How it works (two facts worth preserving)

- **Token estimate is chars/4.** No `tiktoken` is assumed on the workstation, so on-disk bucket sizes use a `chars/4` estimate — the console header prints which tokenizer was used. If `tiktoken` *is* installed the script uses it automatically and says so. Session baselines are never estimated: they come straight from each JSONL's own `usage` records.
- **cwd is read, never decoded.** The `~/.claude/projects/<dir>` name encodes `_`, `:`, and `\` all as `-`, so it is lossy and ambiguous. The script never decodes a dir name; it inverts by reading the real `cwd` field the CLI writes into each session's JSONL.

### Common mistakes

- **Reading `latest baseline` as the startup cost.** A resumed session's latest turn includes cache-read from earlier work — use **fresh baseline** for "new session" cost.
- **Expecting Part 1 inside a git worktree.** A worktree is a distinct working directory with its own (often empty) session history; run from the repo's main checkout for the Part-1 decomposition, or read the repo's row in Part 2.
- **Treating the harness remainder as trimmable on disk.** It isn't a file — shrink it by reducing enabled skills/MCP servers, not by editing a document.
