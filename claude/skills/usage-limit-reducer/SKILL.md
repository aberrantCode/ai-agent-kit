---
name: usage-limit-reducer
description: Use when the user is hitting Claude usage limits, burning through tokens fast, running a long conversation, or asks how to use Claude Code more efficiently. Triggers on phrases like "hit my limit", "running out of tokens", "usage limit", "save tokens", "reduce usage", "am I wasting tokens", "this chat is getting long", "which model should I use". Diagnoses the current session, runs a real token-usage report from local JSONL logs, and applies Dubi's 11 rules for reducing Claude usage.
---

# Usage Limit Reducer

Apply Dubi's 11 rules for cutting Claude token usage. Claude re-reads the entire conversation every turn, so 98.5% of tokens often go to re-reading history instead of generating responses. This skill diagnoses where the user's tokens are going and applies the rules that actually move the needle.

## How to run this skill

Do the steps in order. Skip any step that clearly doesn't apply, but don't skip all of them — the value is in matching rules to what the user is actually doing.

### Step 1 — Run the real token-usage report

Rule #4: "you can't fix what you can't measure." Claude Code already writes every token, model, and timestamp to `~/.claude/projects/<project>/<session>.jsonl`. Run the bundled script to show the breakdown (use the absolute path to `scripts/usage-report.py` inside this skill's directory):

```bash
python3 <SKILL_DIR>/scripts/usage-report.py --days 7
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

## Rules not implementable in Claude Code

- Rule #1 ("Edit your prompt") is a claude.ai web UI feature — in Claude Code the equivalent is `/clear` + restart.
- Rule #5 ("Upload to Projects") is also web-only — use `CLAUDE.md`, skills, and `.context/` instead.
- Rule #11 (Overage) is plan-level — mention it, don't implement it.

## What this skill does NOT do

- It does not silently change the user's model or settings. Recommend, then act only on confirmation.
- It does not summarize-and-clear without asking — the user may have unsaved context in the conversation.
- It does not send data anywhere. The usage report is strictly local.
