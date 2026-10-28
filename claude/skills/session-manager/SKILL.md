---
name: session-manager
category: Foundations & Workflow
install-target: global
requires: [spawn-terminal]
description: >
  Owns the whole Claude Code session lifecycle plus the shared transcript (JSONL) parser.
  Start: resume where you left off — "what was I working on", "continue my last session",
  "resume work in this repo", "did I finish that", "what's next here", "I forgot where I left
  off". During: checkpoint durable state so work survives context resets, /loop iterations and
  multi-session tasks (tiered summaries, one step per turn, a copy-ready resume prompt). End:
  hand off open work — "continue in a new session", "spawn a new terminal and keep going", "hand
  this off", "open a new window and work through those items", "go do all that in a new
  session", "/handoff", "/dispatch-session-prompt" — as a launched session, a scope prompt, a copy-ready prompt for Claude,
  Codex or Gemini, or a self-similar chain for a large migration split across many sessions;
  dispatch any prompt file into a new worktree and terminal tab; retire it after merge. After:
  audit past sessions against a stated rule — "did I actually follow rule X", "did we already
  follow rule X", "did I actually follow the haiku-delegation rule", "audit my last N
  hours/days of sessions for X compliance", "audit my last N hours for compliance", "were any
  subagents spawned without the required isolation", "check whether we've been using
  AskUserQuestion instead of inline questions", "did you actually use AskUserQuestion just now
  instead of asking inline?", "did any session push directly to dev/main despite the PR-only
  rule", "was CHANGELOG.md actually regenerated before that release, or hand-edited", "mine my
  transcripts for violations of Z", "/hand-off-audit", compliance audit; mine history — "what keeps going wrong",
  "find issues we've hit more than once", "audit our conversation history", "what should we
  change so this stops happening", or mine prior transcripts for domain knowledge when building
  a skill or doc for an existing service; tune handoffs — "tune the handoff skill", "how efficient
  are our handoffs", "analyze handoff token cost / new-session churn", "score our handoff prompts",
  "/tune-handoff": measure past handoffs and propose evidence-backed handoff enhancements plus a
  versioned rubric refinement; report delegated-subagent outcomes; and token cost —
  "hit my limit", "running out of tokens", "usage limit", "save tokens", "reduce usage", "am I
  wasting tokens", "how do I use fewer tokens", "this chat is getting long", "which model should
  I use", "why does a new session start with tokens", "what's in my context window at launch",
  "startup context cost", "per-repo baseline token audit", "why is this repo's fresh session so
  heavy", "what am I paying before I type anything". Routes to one sub-skill per stage; replaces the
  retired "session-handoff" umbrella.
---

# Session Manager

This is an ownership and routing head, not a runtime gate. Each sub-skill under `sub-skills/`
triggers on its own frontmatter description and each command loads one sub-skill directly — you
should rarely need to stop here. Read this file when a request names the session lifecycle
without saying which stage, or when you are authoring a new session tool and need to know where
it belongs.

## What this bundle owns

The session lifecycle, end to end, plus the one parser every stage shares:

| Stage | Sub-skill | Owns |
|---|---|---|
| start | [`resume`](sub-skills/resume/SKILL.md) | Reconstruct where the operator left off from recent transcripts + git state; propose (or auto-run) the next action |
| during | [`checkpoint`](sub-skills/checkpoint/SKILL.md) | The single durable state-file convention: tiered summaries, one step per turn, recorded evidence, a resume prompt |
| end | [`handoff`](sub-skills/handoff/SKILL.md) | Write the prompt for the next session — launch, scope, copy, and chain modes |
| end | [`dispatch`](sub-skills/dispatch/SKILL.md) | Create a per-task worktree and launch any prompt file in a new terminal tab; verify the launch |
| end | [`retire`](sub-skills/retire/SKILL.md) | Post-merge cleanup gate (five checks; `-Confirmed` is human-only) |
| after | [`audit`](sub-skills/audit/SKILL.md) | Read-only check of past sessions against a stated rule |
| after | [`handoff-tuner`](sub-skills/handoff-tuner/SKILL.md) | Measure past handoffs (join coverage, prompt-rubric score, child-session churn, token cost) and propose evidence-backed `handoff` enhancements + a versioned rubric refinement, as a reviewed PR |
| after | [`mine`](sub-skills/mine/SKILL.md) | Friction mode (recurring mistakes → proposed patches) and knowledge mode (domain knowledge from history) |
| after | [`delegation-ledger`](sub-skills/delegation-ledger/SKILL.md) | Record and report delegated-subagent outcomes (`~/.claude/telemetry/delegation-outcomes.jsonl`) |
| after | [`usage`](sub-skills/usage/SKILL.md) | Token cost: historical burn and the per-session startup baseline |
| shared | [`transcripts`](sub-skills/transcripts/SKILL.md) | `cc_transcripts.py` — the one stdlib JSONL library every script above imports (for skill authors) |

## Ownership boundary

Verbatim per the ai-agent-kit reorg charter §3 (`docs/reorg/charter.md`):

> project-manager owns single-agent multi-turn loop composition; agent-manager owns multi-agent dispatch and recovery; session-manager owns session handoff, durable session state, and session-JSONL infrastructure.

> gated-batch owns per-item data-plane state; session-manager owns session-plane resumption.

Not here: composing a `/loop` or iteration prompt (`project-manager`), feature specs, plans and
task files (`project-manager`), and opening a terminal tab for an arbitrary command
([`spawn-terminal`](../spawn-terminal/SKILL.md), a separate standalone skill this bundle
`requires:` — `dispatch` delegates tab spawning to it).

## Commands

Every command is a thin file in `commands/` that loads exactly one sub-skill.

| Command | Sub-skill | Notes |
|---|---|---|
| `/handoff` | handoff | launch mode (default) |
| `/dispatch-session-prompt` | handoff | alias — scope mode |
| `/continue-new-session` | handoff | alias — copy mode |
| `/dispatch-session` | dispatch | launch any prompt file |
| `/retire-session` | retire | |
| `/checkpoint-session` | checkpoint | |
| `/work-resume` `/work-resume-auto` `/work-report` `/work-scan` | resume | |
| `/session-audit` | audit | |
| `/hand-off-audit` | audit | alias |
| `/tune-handoff` | handoff-tuner | measure handoffs → propose handoff enhancements + self-tune (reviewed PR) |
| `/analyze-conversations` | mine | friction mode |
| `/mine-sessions` | mine | knowledge mode |
| `/delegation-report` | delegation-ledger | |
| `/token-report` | usage | historical burn |
| `/startup-cost` | usage | startup baseline |

The three aliases were kept for one release after the `session-handoff` retirement (2026-10-21);
that release was v0.16.0, so they are now due for removal. The `session-handoff` alias bundle
itself was removed after v0.16.0.

## Routing

- **Forward vs backward.** "Hand this audit off to a new session" is a `handoff` *of* an audit
  task, not an invocation of `audit`. Handoff moves work forward; audit, mine, delegation-ledger
  and usage look backward.
- **Audit vs mine.** A named rule ("did we follow X") → `audit`. No rule, just "what keeps going
  wrong" or "what does history know about service Y" → `mine`. The built-in `/insights` gives a
  general history summary; `mine` covers rule-free friction patterns and domain-knowledge
  extraction that `/insights` does not.
- **Resume vs checkpoint.** `checkpoint` writes durable state during work; `resume` reads it (and
  the transcripts) when the operator comes back.
- **Handoff vs dispatch.** `handoff` writes the prompt; `dispatch` launches a prompt file — any
  prompt file, including one a human wrote.
- If a request is genuinely ambiguous between two stages, ask — don't guess.

## Diagram

[View diagram](diagram.html)
