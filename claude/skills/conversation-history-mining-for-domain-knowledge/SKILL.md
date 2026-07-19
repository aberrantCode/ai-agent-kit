---
name: conversation-history-mining-for-domain-knowledge
category: Foundations & Workflow
description: Use when building a skill, doc, or knowledge base for an existing internal service or codebase, or when asked to audit past sessions for recurring failures and gaps — mine prior Claude conversation transcripts instead of reverse-engineering from logs or current code alone.
status: active
version: 2026-07-05
---

# Conversation History Mining for Domain Knowledge

## When to use

Any time you need load-bearing domain knowledge about a service, system, or process
that has been discussed before but isn't written down anywhere authoritative:
building a new skill for an internal tool, onboarding onto a legacy system, or
auditing "what keeps going wrong" across a fleet of repos. Also use when explicitly
asked to analyze recent conversations for patterns (e.g. "find and analyze all Claude
conversations over the past 14 days"). Transcripts capture failure modes, workarounds,
and decisions that current code and logs alone won't reveal — they encode the "why,"
not just the "what."

## Method

1. **Mine transcripts, not just logs or current state.** Prior conversations with
   Claude about a service accumulate incidents, constraints, and workarounds that
   never made it into docs. Example: a Honcho skill was built by pulling
   `DERIVER_FLUSH_ENABLED` behavior, a `claude→claude` conclusion-pollution incident,
   and a 6-day silent auth-key failure directly out of conversation history — faster
   and more accurate than reconstructing them from logs after the fact.

2. **Dispatch a search agent over the transcript corpus** rather than reading
   everything serially. Have it search for symptom descriptions, workaround
   phrasing, and decision language ("we changed X because Y", "the actual cause was").

3. **Parse transcripts as structured data, not prose.** JSONL-format session logs
   carry tool calls and their results as first-class fields — use a read-only funnel
   script to extract them, then cluster errors by a normalized signature (strip
   timestamps/IDs, group by error shape) to surface recurring failure classes across
   many sessions.

4. **Treat the transcript as the arbiter of what happened, not current git/system
   state.** Current state gets masked by later manual remediation — someone fixes
   the symptom outside the session and the repo no longer shows the bug. The
   transcript is the only record of what the agent actually did and claimed at the
   time, and session-end wrap-ups are where the *intended* outcome is stated even
   if it wasn't fully realized.

5. **Convert one-off discoveries into durable memory via a capture-then-curate
   workflow:**
   - Agents/operators append diagnostic insights, failure modes, and architectural
     decisions to a lightweight intake file as they're discovered — no ceremony,
     just append.
   - A designated curator agent periodically sweeps the intake file: dedups entries,
     allocates stable IDs, links related items to existing knowledge, and writes the
     result into a permanent index.
   - This keeps CLAUDE.md (or the main context doc) from ballooning while still
     making discoveries retrievable and linkable by issue ID later.

## Gotchas

- Don't treat current repo/system state as ground truth for "did this bug get
  fixed" — silent manual remediation outside the session will make a real recurring
  bug look resolved. Cross-check against the transcript record of what actually
  happened.
- Clustering needs normalization (strip volatile fields like timestamps/paths/IDs)
  or every error looks unique and no pattern emerges.
- An intake file that's never curated just becomes a second, messier CLAUDE.md —
  the curator pass (dedup + ID allocation + linking) is what makes it durable memory
  rather than a growing pile of notes.
- Measuring "session completion vs. actual delivery" requires reading both the
  wrap-up (stated intent) and the tool-call trace (actual actions) — either alone
  overstates or understates what was really delivered.

## Diagram

[View diagram](diagram.html)
