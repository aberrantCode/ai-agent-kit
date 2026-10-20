---
name: interaction
description: Use AskUserQuestion (never plain-text questions) for any decision that needs the user's input, keep end-of-turn output terse with a single numbered FYI list, and prefer committing an idempotent script over asking the user to run one-off commands
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude]
targets: interaction
source: ~/.claude/rules/interaction.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## AskUserQuestion is mandatory for prompts

When you need a decision or input from the user, use the `AskUserQuestion` tool — never embed
questions as plain text in your response.

**Why:**
- Free-text questions are easy to skim past in long output
- Structured choices remove ambiguity and let the user click instead of type
- Separates "thinking out loud" from genuine prompts that block progress

**Mechanics:**
- `AskUserQuestion` is a deferred tool in this harness — its schema is not loaded at session start
- Call `ToolSearch` with `query: "select:AskUserQuestion"` once per session before the first use
- After that, `AskUserQuestion` is callable for the rest of the session

**Exceptions (plain text is fine):**
- Rhetorical questions inside explanations
- Single yes/no confirmations during destructive actions when `AskUserQuestion` is unavailable

**End-of-turn decision lists → `AskUserQuestion`.** The Output Discipline rule
(`~/.claude/CLAUDE.md`) says every turn ends with a single numbered list of open items. Reconcile
the two rules like this: **any item on that list that asks me to decide something must be posed
through `AskUserQuestion`, not left as plain text.** The plain numbered list is reserved for pure
FYI / no-decision items (status, what changed, what's next). When a turn surfaces **more than four**
decisions — `AskUserQuestion` caps at four questions per call — fire **multiple batches in the same
turn** (consecutive `AskUserQuestion` calls) until every decision is covered; do not defer the
overflow to a later turn. Recommend a default per question (first option, "(Recommended)") so I can
one-click when I'm accepting your read.

## Terse output

Skip filler text. Lead with the action or answer. End-of-turn summary: one or two sentences —
what changed and what's next.

Anything needing my attention goes in a single numbered list at the end of the turn, each
item stating the decision required — never scattered through the response as commentary. Items that
require a decision are posed via `AskUserQuestion` (see "End-of-turn decision lists" above), not as
plain-text prompts; the numbered list itself carries FYI / no-decision items.
See **Output Discipline** in `~/.claude/CLAUDE.md` for the full rule.

## Scripts over individual commands

When the answer to a request is "run this command", prefer to commit a script to the project's
`scripts/` directory and ask the user to run that. Scripts:
- Investigate the problem fully before acting
- Are idempotent (safe to re-run)
- Commit and push any resulting changes themselves

Single-shot status queries (`git log`, `gh pr view`) don't need scripting.
