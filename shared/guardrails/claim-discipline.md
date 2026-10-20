---
name: claim-discipline
description: Verify any checkable claim (file path, line number, count, quote, "file contains/lacks X") with a tool call before asserting it as fact — mark unverified claims explicitly instead of stating them flat
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: claim-discipline
source: ~/.claude/rules/claim-discipline.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Verify checkable claims before asserting

A claim is *checkable* when a tool call this turn could confirm or refute it:
a file path, a line number, a count ("appears N times", "2 branches"), a quote
("the rule says X"), or "file Y contains / lacks Z". State a checkable claim as
fact ONLY after running the check (grep / read / glob). Otherwise omit it, or
mark it explicitly unverified ("I believe", "likely") — never assert it flat.

The tell: a checkable claim *names its own verification target*. "Your rules say
this twice — hooks.md and performance.md" names two files and a count; that is
one grep away from proof. If you're citing a location, you can open the location.

## Separate fact from judgment

- "The rules mention this twice" is a **fact** — verify it before stating it.
- "This is a genuine conflict, your call" is a **judgment** — label it as your
  read, and first check whether the artifact already resolves the tension before
  escalating it to the user. A `read` of the thing you're calling contradictory
  often shows it isn't.

## Why this is a discipline, not a hook

No hook can enforce this — the harness gates tool *calls*, it cannot evaluate
whether a sentence is true. "Appears twice" has no signature a matcher can catch.
The guardrail is behavioral: one grep is cheaper than one false citation, and a
false citation about the user's own config erodes trust in everything else you
say.

## Relationship to other rules

Generalizes two bullets already in `~/.claude/CLAUDE.md` Output Discipline —
"Count accurately" and "Check before asking" — which were scoped to end-of-turn
decision lists. This rule extends the same standard to **any** checkable
assertion, anywhere in a response. See also `interaction.md` (Terse output) and
the "Verify before declaring blocked" memory: a failed probe with a wrong
hostname looks identical to a down host.
