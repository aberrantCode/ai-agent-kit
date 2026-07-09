---
name: analyze-conversations
description: Use when the operator wants to review recent Claude Code sessions for recurring mistakes, repeated friction, or patterns the agent keeps hitting — "what keeps going wrong", "find issues we've hit more than once", "audit our conversation history", "what should we change so this stops happening". Mines the JSONL transcripts for repeated tool errors, rejections, and operator corrections, then proposes concrete prevention patches.
---

# Analyze Conversations

## Overview

Claude Code stores every session as a JSONL transcript. Over months that is
hundreds of files and hundreds of MB. The job here is to find issues the agent
hit **more than once** and propose changes that stop them recurring — without
loading the raw transcripts into context.

**Core principle — the funnel.** A committed extractor reduces ~400 MB of JSONL
to a few KB of structured signal (clustered error signatures + bounded
correction excerpts). Only that distilled report enters context. The script
clusters what normalises mechanically (errors); you cluster what needs judgment
(free-text corrections).

**The recurrence axis is distinct sessions, not raw count.** An error that
fires 50 times in one session is one incident. The same error in 8 sessions is
systemic. Always rank by session spread.

## When to use

- "What mistakes do I keep making in these sessions?"
- "Find problems we've hit more than once and how to prevent them."
- "Audit the last two weeks of conversations."
- Periodic self-review before a sprint, or after a frustrating stretch.

Not for: debugging one live failure (use `diagnostics-first` + the probe
table), or reviewing a single transcript you already have in context.

## Step 1 — run the extractor

```bash
python .claude/skills/analyze-conversations/references/analyze-conversations.py --window 7d
```

> The extractor script ships bundled with this skill under `references/`. Run it
> from the repo whose sessions you want to analyze — it auto-detects that repo's
> Claude Code project slug from the current directory.

`--window` is flexible; the script adapts its strategy to the value:

| value | meaning |
|---|---|
| `7d`, `30d` | calendar window — sessions touched in the last N days |
| `20s` | session window — the N most-recent sessions by mtime (use for quiet stretches a date window would miss) |
| `2026-05-01` | every session touched on/after that date |
| `all` | the full corpus |

Other flags: `--max-files N` (cap on sessions scanned; oldest past the cap are
**dropped and reported**, never silently truncated), `--min-recurrence N`
(error-signature threshold, default 2), `--max-corrections N`,
`--include-sidechains` (subagent turns, off by default), `--project-dir`
(auto-derived from the current directory's Claude Code project slug under
`~/.claude/projects/`; pass explicitly to analyze a different repo). Run with
`--help` for the full list.

The script is read-only — it mutates nothing and prints a bounded Markdown
report to stdout. Read that report; do **not** read the transcripts yourself.

## Step 2 — read the report

Three sections:

1. **Recurring tool errors** — already clustered by normalised signature,
   ranked by distinct sessions then count. Each row: `sessions | count | tool |
   signature`. These are mechanical findings you can trust as-is.
2. **Operator rejections / interrupts** — counts of times the operator rejected
   a tool call or interrupted. Plus a separate count of parallel-batch
   cancellations (downstream noise, excluded from the error ranking).
3. **Operator corrections** — bounded excerpts of genuine human re-steers, for
   **you** to cluster semantically. Group excerpts that push back on the *same*
   behaviour. A theme across ≥2 distinct sessions is a recurring issue.

## Step 3 — cluster and define "recurring"

An issue counts as recurring when **either**:
- an error signature appears in ≥2 distinct sessions, **or**
- ≥2 correction excerpts (different sessions) re-steer the same behaviour.

Merge mechanical errors with the corrections that describe the same root cause
(e.g. the `Permission denied (publickey)` error rows + a correction like "the
command you gave me threw an error" may be the same SSH-key-drift story).

## Step 4 — map each issue to a prevention surface

This repo already has homes for "this should not happen again". Pick the
narrowest one that actually prevents recurrence:

| Issue shape | Prevention surface |
|---|---|
| Technical failure mode (tool/command/API breaks the same way) | New `docs/learnings.md` `ISSUE-NNN` entry (Mistake/Root cause/Fix/Lesson) |
| Mechanically detectable + preventable (file pattern, forbidden command, missing flag) | A **hook** in `.claude/settings.json` (PreToolUse guard) or a pre-commit check under `.githooks/` |
| A hard "never do X" the agent keeps violating | `docs/negative-constraints.md` |
| How the agent should *work* (process/behaviour correction) | A `.claude/rules/*.md` rule, or a `memory/feedback_*.md` file + `MEMORY.md` pointer |
| Recurring diagnostic ("doesn't work on host X" again) | A read-only probe/diagnostic script + a documented runbook entry |
| Operator preference / settled decision being re-litigated | A `memory/project_*.md` or `feedback_*.md` file |

Prefer a **hook or check** when the issue is mechanically enforceable — a
guard beats a paragraph the next agent might skim past. Reserve prose
(learnings/rules) for judgment calls.

## Step 5 — deliver the list, then draft patches

Output is two-stage — a concise list first, then drafted patches:

**First, the concise list** — one line per recurring issue:

```
1. <issue> — <N sessions / M hits> — <proposed resolution + target surface>
```

Keep it scannable. Lead with the highest session-spread items.

**Then, draft the concrete patches** for the issues worth acting on — the exact
`ISSUE-NNN` text, the rule paragraph, the hook JSON, the memory file — and
present them for approval. **Do not write them until the operator approves** —
don't spawn busywork or trivial follow-ups.

## Reading-the-data gotchas (encoded so you don't re-derive them)

- **`type:user` is overloaded.** It carries genuine human turns, `tool_result`
  blocks, AND harness injections (skill bodies that open with `Base directory
  for this skill:`, `<local-command-caveat>` blocks from `! ` commands,
  `<system-reminder>`, Honcho memory, compaction summaries). The extractor
  filters these; if you ever parse transcripts by hand, replicate that filter
  or injections drown real corrections ~80:1.
- **Trust `is_error`, not content-sniffing.** A successful verifier that prints
  `errors: 0` is not a failure. The harness sets `is_error: true` on genuine
  tool failures — key off that.
- **`Cancelled: parallel tool call` is downstream noise.** When one tool in a
  parallel batch fails, the harness cancels its siblings. Those cancellations
  are consequences, not causes — the extractor counts them separately and
  excludes them from the ranking.
- **Long baton prompts ≠ corrections.** A session-kickoff brief embeds
  `NEVER`/`don't` directives mid-paragraph. A real correction *leads* with the
  re-steer, so the extractor only trusts a lead-in match for long turns.

## Limits

- Correction clustering is yours to do — the script only extracts candidates.
- Heavy windows (`all`) plus a high `--max-files` will scan slowly (streaming,
  so memory stays flat). Narrow the window for routine reviews.
- Sub-agent transcripts are excluded by default; add `--include-sidechains`
  only when auditing agent-dispatched work specifically.

## Real signal this surfaces (validated against the live corpus)

A 7-day run over 76 sessions found, among others: `Edit "File has not been read
yet"` across 30 sessions; `'dev' is already used by worktree` across ~9;
`ssh ...Permission denied (publickey)` across 3 (the opbta-deploy vs
opbta-ansible key drift); `Blocked: sleep N` (reaching for a forbidden
`sleep`); and a correction cluster of "the command you gave me threw an error" /
"don't see that it ran" — the agent claiming completion it hadn't verified.
Each maps cleanly to a surface in Step 4.

## Diagram

[View diagram](diagram.html)
