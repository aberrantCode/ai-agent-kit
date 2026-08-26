---
name: statusline
category: Tooling & DevOps
status: active
version: 2026-08-26
description: >
  Use when the user wants to customize, fix, install, remove, inspect, or audit the Claude Code
  status line — the bottom-of-terminal line that can show token/context consumption, model,
  git branch, and cost. Triggers on "fix my status line", "my status line doesn't show tokens",
  "no token count in spawned/worktree tabs", "status line shows the wrong token number",
  "add context percentage to my status line", "install a status line", "remove my status line",
  "why is my status line blank", "audit my status line", "status line shows 100k on a fresh
  session", "statusline.sh", and any mention of the `statusLine` block in settings.json or the
  built-in `/statusline` command. This skill owns the canonical, worktree- and /handoff-safe
  status-line script and the install/remove/inspect/modify/audit operations around it. Prefer it
  over hand-editing settings.json or the script directly, because those ad-hoc edits are exactly
  what caused this to regress three times.
---

# Status line

Single entry point for **Claude Code status-line** lifecycle on this workstation. This skill is a
**thin orchestrator**: each command in `commands/` names one operation, and this skill runs that
operation's sub-skill under `sub-skills/` against the live config (`~/.claude/settings.json` +
the resolved script) and the canonical asset (`assets/statusline.sh`).

The status line is a shell script Claude Code runs on every render: it receives a JSON payload on
stdin and prints one line to stdout. Full schema and failure catalogue:
[`references/statusline-payload.md`](references/statusline-payload.md) — **read it before writing
or debugging any status-line script.**

---

## Output Contract — applies to EVERY operation in this skill

The user wants signal, not narration. Terminal output for any operation here is:

1. **During execution — stay silent.** Run commands through Bash. Do not announce steps, explain
   what a command does, or print a running play-by-play. No preamble.
2. **On error — surface only if it blocks you.** *Recoverable* (you know the fix — a missing
   dir, a stale copy): fix it quietly, fold one line into the summary. *Blocking* (needs a
   decision, credential, or judgment you can't make): print the failing command + stderr
   verbatim, then stop or ask via `AskUserQuestion`.
3. **At completion — one concise summary** (≤4 lines): what changed, where (path, PR #, commit),
   and any caveat the user must act on.
4. **If anything remains open — one compact table** (`| Item | Where | Action |`) after the
   summary, nothing else.

The `inspect` and `audit` operations are read-only reports: their deliverable **is** the report,
so for those two the "summary" is the report itself. All prompts to the user go through
`AskUserQuestion`, never inline "type yes/no". This overrides any conversational or explanatory
output style for the duration of the operation.

---

## Distilled history — why this keeps regressing

This complaint ("no token count shown") has recurred **three times with three different root
causes** under one surface symptom. Treat it as a class of bugs, not one bug — the `audit`
operation checks for all three.

| # | Root cause | Symptom | The fix this skill encodes |
|---|---|---|---|
| 1 | Script fell back to "newest `.jsonl` in the folder" | Fresh session shows a *prior* session's 150k+ context, uncorrelated with work | Resolve the transcript **only** by `session_id` exact filename; never by mtime |
| 2 | Worktree/`/handoff`-spawned sessions have **no flat `<session_id>.jsonl`** (only a `subagents/` dir) | Spawned tabs show **no token count at all** | Read the native `context_window` stdin object, which is present regardless of any transcript file |
| 3 | Script parsed the transcript instead of the native stdin fields the CLI now provides | Fragile everywhere; inherits #1 and #2 | `assets/statusline.sh` reads `context_window.*` **first**, transcript only as fallback |

Two supporting lessons, also baked in:
- **Sanitize every parsed number to digits** (`${v//[!0-9]/}`) — a stray `\r` from a CRLF stream
  silently breaks numeric comparisons on Git-Bash.
- **The archive copy drifts from the live copy** when edits are made ad-hoc. This skill's
  `install`/`modify` operations make `assets/statusline.sh` the **single source of truth** and
  deploy *from* it, so `~/.claude/statusline.sh` and the archive stay in sync by construction.

---

## The canonical asset

`assets/statusline.sh` is the source of truth. It renders:

```
<model>  <pct>% · <ctx> ctx · <out> out   |   <branch> <status>
```

- **`pct` / `ctx`** — from `context_window.used_percentage` / `total_input_tokens` (stdin), so
  they survive worktree and `/handoff` sessions. Colored by fill: green <50%, yellow 50–80%,
  red >80%.
- **`out`** — cumulative output tokens, enriched from the session transcript when resolvable;
  omitted otherwise.
- **`branch` / `status`** — git branch (≤25 chars), `*` dirty, `↑N`/`↓N` ahead/behind.
- Dependencies: `bash`, `jq`, `git`, `awk`. No node/ccusage/pwsh.

Degrades gracefully: missing token data → model + branch only (never a wrong number, never an
error). Wired into `~/.claude/settings.json` as
`{"statusLine":{"type":"command","command":"bash ~/.claude/statusline.sh"}}`.

---

## Operations

| Command | Operation | Sub-skill | Mutates? |
|---|---|---|---|
| `/install-statusline` | install | `sub-skills/install` | yes — deploys asset + writes settings.json |
| `/modify-statusline` | modify | `sub-skills/modify` | yes — edits the live script / display config |
| `/remove-statusline` | remove | `sub-skills/remove` | yes — unwires and optionally deletes the script |
| `/inspect-statusline` | inspect | `sub-skills/inspect` | no — read-only report of live state |
| `/audit-statusline` | audit | `sub-skills/audit` | no — checks for the 3 known root causes + drift |

**Lifecycle:** `inspect` (what's wired now?) → `audit` (is it correct / drifted?) → `install`
or `modify` (deploy/fix) → `remove` (tear down). `inspect` and `audit` are read-only and never
mutate; they recommend which mutating op to run and may offer to launch it via `AskUserQuestion`,
but never invoke one on their own.

Each sub-skill's `SKILL.md` restates the relevant Output Contract inline, because a command may
load a sub-skill without this parent file in context.

---

## Cross-operation principles

- **`assets/statusline.sh` is the single source of truth.** Deploy from it; when the live script
  differs, the archive wins unless the user asked to capture a live change back (then `modify`
  updates the asset first, then redeploys).
- **Prefer native `context_window` stdin fields over transcript parsing.** Transcript parsing is
  the source of every historical failure; use it only as a fallback or for cumulative totals, and
  only keyed on `session_id`.
- **Never render a wrong number.** When the true value is unavailable, show nothing for that
  segment. A blank token field is correct-and-transient; a stranger's 150k is a bug.
- **Windows paths use forward slashes** in both `settings.json` and inside the script.
- **A status-line change is verified by simulation**, not by eye: pipe a mock payload into the
  command and confirm stdout + exit 0 before declaring done. Include a worktree/handoff-shaped
  payload (native `context_window`, no transcript on disk) in every verification.
- **All user prompts go through `AskUserQuestion`.**

---

## Diagram

[View diagram](diagram.html)
