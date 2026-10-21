---
name: sm-audit
description: >
  Sub-skill of `session-manager`. Compliance audit: check Claude Code session history for
  whether a stated rule was actually followed in practice — "did I actually follow rule X", "did
  we already follow rule X", "did I actually follow the haiku-delegation rule", "audit my last N
  hours/days of sessions for X compliance", "were any subagents spawned without the required
  isolation", "check whether we've been using AskUserQuestion instead of inline questions", "did
  any session push directly to dev/main despite the PR-only rule", "mine my transcripts for
  violations of Z". Read-only; produces an evidence-backed report proposing (never applying)
  fixes. Commands: /session-audit, /hand-off-audit.
---

# audit

_Stub — authored by the session-manager build (checklist item for `audit`)._
