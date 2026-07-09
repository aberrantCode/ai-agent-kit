---
name: diagnostics-probe-design
description: Use when investigating a service or infrastructure failure and before proposing any fix — verify the premise, then write a read-only, multi-hypothesis probe that combines recorded metrics with live state to pinpoint the broken component and avoid redoing already-completed or destructive work.
status: active
version: 2026-07-05
---

# Diagnostics Probe Design

## When to use
- A service, monitor, or integration is reported down/broken and you're about to investigate root cause.
- A prompt claims infrastructure "needs to be retired" or "needs to be built" — before acting.
- The failure spans multiple components (e.g., API → bridge/integration → automation, or media server → transcoder → capture → storage).
- You're about to write PromQL/LogQL against metrics you haven't confirmed still exist under the same names/labels.
- A previously "fixed" issue recurs, or triage keeps reinventing the same diagnostic steps from scratch.

## Method
1. **Verify the premise first.** Spend 30 seconds checking whether the claimed problem is real and unaddressed: read `docs/progress.md` for a dated entry describing the exact work, glob for the artifact in question (e.g., `deployments/<service>/`) to see if it exists or is already gone, and run `git log --oneline --all` for recent related commits. Only proceed if the premise is stale or unconfirmed — this prevents redoing destructive work (e.g., deleting a live Cloudflare Worker a second time).
2. **Map component boundaries.** For multi-component systems (e.g., Wyze API → bridge integration → Home Assistant automation; media server → transcoder → capture → storage), enumerate each hop and note what data enters and exits it. The break is almost always at a boundary, not inside a single component.
3. **Write the probe before drafting conclusions.** The probe must be read-only and multi-hypothesis: structure it as numbered sections, each testing exactly one hypothesis, ending in a decision tree that routes evidence to a root cause. Never propose a fix before the probe runs.
4. **Gather two classes of evidence per hypothesis:**
   - *Recorded metrics* — Prometheus/Loki time-series scoped to the incident window. Immutable and reproducible; use these to establish what actually happened.
   - *Live state* — cgroup files, process state, API queries (e.g., Authentik API, DNS resolution). Use these to confirm whether the capability still exists right now.
5. **Pre-validate the substrate before writing queries.** Run a small live probe against the Prometheus/Loki scraper to confirm exact metric names and label cardinality before authoring PromQL/LogQL. Exporter versions drift silently; skipping this step is reported to cause roughly 60% of follow-up fixes.
6. **Capture error messages and timestamps verbatim** (e.g., cron's literal "bad minute" message), not paraphrased — the exact string is often the diagnostic signal.
7. **If the probe doesn't isolate a single cause, bisect.** Build targeted, throwaway tests that change one variable at a time (e.g., isolated `cron.d` files) to pin the exact trigger.
8. **Register the probe by symptom, not internals.** Add it to a diagnostic registry indexed by what the operator observes as broken (e.g., "push monitor shows down in Kuma"), not by script name or internal structure. Store the exact cross-host invocation in the registry row (e.g., a double-hop SSH string), not a bare script path, so triage goes symptom → invocation without requiring repo knowledge.
9. **Document the decision tree and any false-positive misdiagnosis** in the probe or registry entry so the next investigator lands on root cause directly instead of repeating a wrong turn.

## Gotchas
- Don't skip the reproduction step or assume root cause before evidence pinpoints the failing boundary.
- Don't act on a prompt's claim that something "needs" retiring/building without checking progress logs and git history — duplicate destructive actions (deleting a live resource twice) are a real failure mode.
- Don't index a probe registry by probe/script internals — operators search by symptom.
- Don't store bare script paths for cross-host checks; multi-hop SSH invocations get lost and each triage reinvents them.
- Don't write PromQL/LogQL against assumed metric names — exporter drift silently breaks queries; pre-validate against the live scraper first.
- Don't paraphrase captured error messages — verbatim text (timestamps included) preserves the signal needed for bisection.
- Recorded metrics and live state answer different questions (what happened vs. what's true now) — use both, not one as a substitute for the other.

## Diagram

[View diagram](diagram.html)
