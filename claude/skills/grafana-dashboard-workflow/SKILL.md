---
name: grafana-dashboard-workflow
category: DevOps & Tooling
description: Use when authoring, retrofitting, or verifying Grafana service-monitoring dashboards — enforces probing live metrics before writing PromQL, a standard four-row health baseline, and a four-rung verification ladder before declaring a dashboard done.
status: active
version: 2026-07-05
---

# Grafana Dashboard Workflow

## When to use
- Authoring a new Grafana dashboard for a service, container, or LXC substrate.
- Retrofitting existing dashboards onto a standard health baseline.
- A dashboard's panels are broken, empty, or failed to alert on a real incident.
- Any time PromQL/LogQL is about to be written against an exporter or Loki.

## Method

1. **Probe before you design.** Never trust an exporter's README or an old design doc — metric names drift silently between versions. Hit the live endpoint first:
   `curl http://exporter:port/metrics | grep '^[a-z_]+'`
   Also check Prometheus targets to confirm instance labels and scrape availability. Write PromQL only against what you actually observe.

2. **Author against the standard four-row baseline** (applies across both LXC and container substrates):
   - Row 1 — Health: uptime, container restarts, Kuma monitoring state.
   - Row 2 — USE: CPU, memory-vs-limit, disk, network + saturation, via cadvisor/node-exporter.
   - Row 3 — Logs: Loki scoped to per-container/per-host labels, plus error-rate aggregation.
   - Row 4 — RED: `traefik_service_*` metrics keyed by service label.

   Query conventions: use `vector(0)` fallbacks so zero-series panels still render; use `$__interval` for cache-aware `rate()` windows; prefer `rate()` over raw counters. MUST rules: double-quote all label matchers (Grafana JSON silently strips single quotes), use pre-baked datasource UIDs (`prometheus`/`loki` — never re-resolve by name), and jq-validate the dashboard JSON before provisioning.

3. **Register the dashboard in provisioning config**, e.g. `roles/grafana/defaults/main.yml`. Dropping a JSON file into the dashboards directory alone does nothing — it must be registered or it will never be provisioned.

4. **Run the verification ladder, in this exact order, before declaring done:**
   - **Rung 1 (static):** jq parse + the 8 MUST-rule greps + UID-collision check + diff-shape review.
   - **Rung 4 (live query):** run the actual PromQL/LogQL against real datasources, substituting `$__interval` → `5m`, to catch metric-name mismatches and label typos *before* apply.
   - **Rung 2 (idempotent apply):** apply twice — first pass `changed=1`, second pass `changed=0` — to prove the provisioning is idempotent.
   - **Rung 3 (delivery):** query the Grafana API by UID (admin basic-auth; from inside the container via `docker exec`, not the external URL if it sits behind Authentik) to confirm the served panel set matches what was committed.

5. **When retrofitting existing dashboards onto the baseline:** inventory dashboards by type (hand-authored single-service vs. community imports vs. analysis/diagnostic/fleet-aggregate). Apply an eligibility rubric — only single-service *health* dashboards are retrofit targets; analysis dashboards (e.g. internet-latency, flow analysis, sni-console) are exempt because the baseline's four rows don't map to their shape. Tier eligible dashboards by effort (how many rows are already compliant vs. need rework), then draft a per-tier PR sequence with a migration contract per dashboard (which rows to add, which metrics exist, known gaps). Treat the baseline as routine only once it's proven stable against at least two real reference dashboards.

## Gotchas
- **Config in tree ≠ applied to host.** Always validate both the committed dashboard JSON and the live served state — a dashboard can look correct in the repo while the host still serves an older version.
- **Skipping ladder rungs causes the "60%-follow-up-fix trap"** — dashboards that pass a shallow check (JSON parses) still ship with broken queries discovered only after merge.
- **Scene-load parser quirk:** large line-filter unions in a Loki query can defeat Grafana's metric-vs-log classification, forcing a range query even though the panel has a stored instant-query flag. Workaround: apply a `reduce` + `seriesToRows` transform to collapse the per-series matrix into a single table row.
- **A dashboard can correctly measure the wrong thing.** If a dashboard fails to alert on a real outage, don't assume instrumentation is broken — audit whether the chosen metric is blind to the actual failure mode (e.g. `MemAvailable` reads "available" even while page-cache holding a mmap'd model is thrashing). Add the signals that would have caught the incident (memory current-vs-max, swap usage, PSI pressure) rather than just re-trusting the existing metric.

## Diagram

[View diagram](diagram.html)
