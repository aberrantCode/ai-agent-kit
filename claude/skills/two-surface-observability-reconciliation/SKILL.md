---
name: two-surface-observability-reconciliation
category: DevOps & Tooling
description: Use when a system's true state can only be seen by combining two observability surfaces that can't see each other (an API/tool-level view and a backend/infra-level view), or when two candidate sources of truth (a formal tracking framework and a living backlog, or two metrics pipelines) disagree about what's actually going on. Reconciles them into one verdict instead of trusting either alone.
status: active
version: 2026-07-05
---

# Two-Surface Observability Reconciliation

## When to use

- A service has split observability — e.g., an in-session API/tool view and a backend server view that don't see each other — and you need a single verdict on system health.
- A repo has both a formal project-management framework (specs → plans → tasks) and a parallel living backlog document, and you need to know what's *actually* open.
- A service "appears offline" per one signal (container healthcheck) but you're not sure if that signal is live or stale.
- Two systems both partially cover a metrics/throughput gap and you need to pick (or derive) the authoritative signal rather than build new collection.

## Method

1. **Build a diagnostic probe that reads each surface in its native format, separately, then compares them.** Don't trust a single surface's self-report. Example: an MCP tool layer shows conclusions as recent and coherent, but a direct SSH query against the backend Postgres database reveals the processing queue is actually stuck. Compare concrete, comparable signals across both surfaces — e.g., latest-derivation timestamp on each side, or error count vs. throughput — to surface gaps neither surface exposes alone (a silent backlog the API side never reports).

2. **When a repo has two competing sources of truth for "what's open"** (a formal docs/features → docs/plans → docs/tasks/active framework, and a living docs/tasks/backlog.md), audit both but explicitly choose which one is authoritative for the question being asked. The formal framework fits greenfield initiatives with a defined completion state; the backlog fits living infrastructure repos where work is perpetual and "% complete" is the wrong metric because nearly everything eventually ships. Report status by priority (HIGH/MEDIUM/LOW) and theme, not by feature-completion percentage, when the backlog is authoritative. Call out the 2-3 HIGH items separately as immediate operational risk; group MEDIUM items by concern area (observability, security, cluster, etc.) to aid prioritization.

3. **When a service appears offline, separate the host-level health signal from real-time application state before declaring it down.** A `docker ps` "unhealthy" status can be stale (frozen during a resource-starvation wedge) rather than reflecting current reality. Confirm true failure by: tailing the process log for fresh activity (not a frozen healthcheck), confirming the daemon actually restarts, and watching live metrics (memory, load, io.pressure) recover once the starvation condition ends. Log "stale healthcheck frozen during a wedge" explicitly as a known footgun so it's recognized faster next time.

4. **When a metrics/coverage gap spans two systems** (e.g., an API poller and a log-scraper), prefer deriving the signal from whichever system already collects cleaner, closer-to-source data over standing up new infrastructure. Example: if an exporter already polls coverage every 15 minutes, derive throughput as `increase(metric_name[1h])` from that existing series rather than adding a separate log-scraper. Point alert rules and dashboard panels at the chosen surface once decided. Validate idempotency of any backfill/reconciliation job (e.g., a second pass reports `changed=0`) before calling the work done.

## Gotchas

- A surface that looks "recent and coherent" can still be blind to a stuck downstream stage — recency of the last successful item says nothing about queue depth behind it.
- Don't average or merge two disagreeing surfaces' numbers — pick the authoritative one deliberately and state why, or the reconciliation itself becomes a new source of confusion.
- Container/process healthchecks can freeze mid-wedge and report a stale "healthy" or "unhealthy" state well past when it stopped being accurate — always cross-check with a live log tail or fresh metric sample before trusting it.
- Building new collection infrastructure to fill a metrics gap is a last resort — check first whether an existing poller/exporter already has the data, just not surfaced correctly.

## Diagram

[View diagram](diagram.html)
