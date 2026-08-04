---
name: session-handoff
description: >
  Umbrella for two related but distinct session-lifecycle operations: handing off open work to a
  fresh Claude Code session, and auditing whether past session behavior actually followed a stated
  rule. Use this skill when the ask is about "session-handoff" without a clear sub-operation, or
  when unsure which of the two applies. Otherwise prefer invoking the specific sub-skill directly:
  `session-handoff:handoff` for continuing/dispatching work in a new terminal session ("continue in
  a new session", "hand this off", "spawn a new terminal and keep going", "/handoff",
  "/dispatch-session-prompt"), or `session-handoff:audit` for checking whether a stated policy was
  actually followed in past session transcripts ("did I actually follow rule X", "audit my last N
  hours for compliance", "/hand-off-audit"). Do not confuse the two: handoff moves work forward into
  a new session; audit looks backward at what already happened.
category: Foundations & Workflow
requires: []
---

# Session Handoff

This is a router, not a workflow — it exists so a request that names "session-handoff" without
specifying which half it means still finds the right place. The two sub-skills are independent and
you should almost always be able to route to one of them directly instead of stopping here.

## Which one do I want?

- **Moving work forward** — you have open decisions, unfinished tasks, or a scope that needs to run
  unattended in a fresh session with no conversation history. See
  [`sub-skills/handoff/SKILL.md`](sub-skills/handoff/SKILL.md) (skill: `session-handoff:handoff`).
  Commands: `/handoff`, `/dispatch-session-prompt`, `/repo-color`.

- **Looking backward** — you want to know whether a stated rule was actually followed by past agent
  behavior (this session or an earlier one), not whether code currently complies with a rule right
  now. See [`sub-skills/audit/SKILL.md`](sub-skills/audit/SKILL.md) (skill: `session-handoff:audit`).
  Command: `/hand-off-audit`.

If the request is genuinely ambiguous between the two, ask — don't guess. "Hand off this audit to a
new session" is a handoff *of* an audit task (`handoff`, with the audit as its scope), not an
invocation of `audit` itself.

## Scope

This file intentionally carries no procedural content of its own. All actual logic — entry modes,
steps, hard constraints, report formats — lives in the sub-skill it belongs to. Keep it that way:
if you find yourself adding a step here, it probably belongs in one of the two sub-skills instead.
