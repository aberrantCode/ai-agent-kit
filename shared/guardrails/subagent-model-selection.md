---
name: subagent-model-selection
description: Default every background/fan-out subagent to the cheapest capable model (Haiku by default) instead of silently inheriting the parent session's Opus/Sonnet model — tiering guide for Agent tool and Workflow agent() stages
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude]
targets: subagent-model-selection
source: ~/.claude/rules/subagent-model-selection.md, archived 2026-08-09
status: active
version: 2026-08-09
---

Applies whenever you dispatch a subagent — the `Agent`/`Task` tool, `Workflow`
`agent()` stages, or any fan-out of delegated work.

## The rule

**Delegate to the cheapest capable model. Default background/fan-out subagents
to Haiku — never let them silently inherit the session's Opus/Sonnet model.**

The parent session already carries the expensive reasoning. Most delegated work
is mechanical and does not need a frontier model:

- registry / version / release lookups
- grep / glob / codebase search and file-location sweeps
- reading a page or file and extracting a value
- structured-output extraction against a schema
- running a command and reporting the result

Running those on Opus burns tokens and wall-clock for no quality gain.

## How to apply

- **`Agent` tool:** pass `model: "haiku"` on the call. Use `"sonnet"` only when
  the task needs more than Haiku but not Opus.
- **`Workflow` `agent()`:** pass `{model: 'haiku'}`, and `effort: 'low'` for
  cheap mechanical stages. Reserve higher tiers for the hardest verify/judge
  stages only.
- **Omit the override (inherit the session model) ONLY** when the subagent's
  task is genuinely reasoning-heavy: architecture/design, adversarial
  verification, hard multi-file debugging, or synthesis that needs the frontier
  model's judgment.

## Tiering guide

| Model | Use for |
|-------|---------|
| **Haiku** (default) | search, lookup, extraction, mechanical edits, worker agents in a fleet |
| **Sonnet** | multi-step tasks with moderate reasoning; the middle default |
| **Opus** | architecture, adversarial review, deep debugging, final synthesis |

## Why this is a rule, not a preference

A subagent with no `model` set inherits the caller's model. When the caller is
on Opus, an unset `model` silently makes every worker an Opus worker — the
expensive default is the *invisible* one. Making Haiku the explicit default
inverts that: you opt UP to Opus for the few tasks that earn it, instead of
opting DOWN for the many that don't.

Aligns with `~/.claude/rules/performance.md` ("Haiku 4.5 … Worker agents in
multi-agent systems") and `~/.claude/rules/agents.md` (parallel Task execution).
