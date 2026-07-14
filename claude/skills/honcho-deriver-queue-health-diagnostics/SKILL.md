---
name: honcho-deriver-queue-health-diagnostics
category: Infrastructure & Ops
description: Use when a Honcho memory backend (or any background derivation/processing queue) seems stuck, slow, or is reporting suspicious pending/error counts — check both the MCP-visible layer and the server-side queue table directly, distinguish "broken" from "contended," and audit stored conclusions for pollution.
status: active
version: 2026-07-05
---

# Honcho Deriver Queue Health Diagnostics

## When to use

A Honcho instance (or structurally similar background-processing queue — ffmpeg extraction pipelines, refresh jobs, any worker draining a Postgres-backed queue) appears stalled, has an unexplained pending count, or you need to confirm stored memory/derivations aren't polluted by hallucinated or misattributed entries. Use this before assuming "the pipeline is broken" — most stalls are contention, not failure.

## Method

1. **Check both layers, not just one.** The MCP-visible layer (`get_representation`, `get_context`, conclusions) only shows the *output* of derivation. The real health signal is the server-side queue — Postgres rows on the backing host (e.g., `ac-docker1`), visible only via SSH, not through the API.
2. **A queue can look healthy and still be hiding history.** `pending=0` with recent successful derivations does NOT mean everything is fine — there can be 68+ historically errored rows from past blips (network timeouts, LLM endpoint unreachable). Query directly:
   ```sql
   SELECT processed, error, created_at FROM queue WHERE error > 0;
   ```
   Group by error cause to separate one-off historical blips from an ongoing active failure.
3. **For active/ongoing errors**, check the deriver process itself: is it running (container logs, `systemctl status`), what's its memory/CPU, and what do its error logs say right now.
4. **For historical/resolved errors**, reset them safely — but only after acquiring the coordination lock — with:
   ```sql
   UPDATE queue SET error = 0 WHERE error > 0 AND error NOT IN ('reconciler', 'dream');
   ```
   Excluding `reconciler`/`dream` error types preserves categories that need separate handling rather than blind reset.
5. **When "pending count is static," diagnose in this order:**
   a. Is any deriver process actually running (container logs, systemd status)?
   b. Do the pending items even have users with preference vectors configured (check config)?
   c. Are analyses actually being enqueued (trace the scheduler path)?
   The queue only drains if an active deriver is running — a static count with zero active deriver is the single most common root cause.
6. **If an always-on container deployment is expected, check `inProgressWorkUnits`** — it should be > 0 while the queue is actively draining. Zero in-progress units alongside a nonzero pending count confirms the deriver isn't picking up work.
7. **Verify against live state, not memory of how it was set up.** Stale assumptions like "we run it locally" are common; always check current container/process state and `origin/dev` config, not local docs or memory of a prior session.
8. **For background pipelines that share resources with interactive workloads** (e.g., ffmpeg extraction competing with playback transcoding), define falsifiable "broken" criteria up front:
   a. task state ≠ failed
   b. recent activity in logs (extraction timestamps within the expected quiet window)
   c. disk/permissions OK
   Only conclude "broken" if (a) or (b) actually fail — if all three pass but throughput looks low, it's contention (e.g., a competing transcode job), not a defect. Build a single diagnostic script that checks all signals in one pass so you don't chase false alarms.
9. **To audit for pollution in stored conclusions:** enumerate every peer-scope (erik→erik, claude→claude, cross-peer), count raw conclusions per scope, and inspect samples for hallucination, truncation, or misattribution. Trace each pollution source to its origin (e.g., unified-mode self-observation, a derive-assistant flag, model quality issues) so cleanup can target the actual source rather than deleting indiscriminately.

## Gotchas

- Don't stop at the MCP layer when diagnosing a stall — the actual queue state lives in Postgres and requires SSH access to inspect.
- A flat pending count is ambiguous by itself — it can mean "broken" (no deriver running) or "healthy but blocked upstream" (no preference vectors, scheduler not enqueuing). Check all three causes before concluding.
- Never bulk-reset queue errors without excluding special categories (`reconciler`, `dream`) and without holding the coordination lock — a concurrent reset can race an active deriver.
- Resource contention (playback transcoding starving an extraction pipeline) looks identical to "broken" from throughput alone — always check the three falsifiable criteria before declaring a pipeline dead.
- Pollution cleanup should be targeted (trace to origin) not wholesale — indiscriminate deletion risks removing legitimate operator-approved memory alongside noise.

## Diagram

[View diagram](diagram.html)
