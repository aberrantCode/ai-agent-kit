---
name: multi-perspective-dns-diagnostic-ladder
description: Use when DNS resolution is failing, inconsistent, or NXDOMAIN, or when any "mysterious" networked-service failure needs root-causing — apply a layered probing ladder (multiple resolver perspectives, or dependency-chain tracing) to pinpoint which layer broke, and always verify a fix by re-checking logs after applying it.
status: active
version: 2026-07-05
---

# Multi-Perspective DNS Diagnostic Ladder

## When to use

- DNS queries return NXDOMAIN or give inconsistent answers depending on where they're issued from.
- A device fails to fully join/authenticate on a network (e.g. DHCP/association issues) and the cause could be client, AP, or server-side.
- A monitored service shows as "down" for an unclear reason spanning multiple dependent systems (cron, scripts, secrets, network, monitoring API).

## Method

**1. DNS: test from three perspectives to localize the failing layer.**
- **P1 — workstation recursive resolver**: query using the normal local/OS resolver.
- **P2 — public recursive via DoH** (e.g. Cloudflare DNS-over-HTTPS): bypasses local resolver and cache entirely.
- **P3 — direct-to-authoritative**, e.g. `curl --resolve` or `dig @<authoritative-ns>`: bypasses all recursive resolvers.

Interpret the pattern of failures:
- P1 fails, P3 succeeds → local resolver cache poisoning or stale cache.
- P2 fails, P1 succeeds → split-brain DNS (internal vs external views disagree).
- All three fail → zone propagation lag or the record genuinely isn't published yet.

This ladder separates "TTL/cache problem" from "replication problem" from "network interception problem" without guessing.

**2. Network/association issues: layer probes from server outward to client.**
- Start with static, server-side verification: firewall rules, service health, expected listening ports.
- If server side is healthy, move to live packet captures on the suspect interface(s), comparing expected vs. actual traffic patterns.
- Use MAC-address signatures in the capture to positively identify which device's traffic you're looking at.
- If the server side is confirmed healthy end-to-end, the failure is upstream of it — client association, VLAN tagging, or AP misconfiguration — so stop looking server-side and pivot the investigation there.

**3. "Mysterious" service-down failures: trace the full dependency chain in one pass.**
Build a single diagnostic probe/script that walks every link in the chain end-to-end (example chain: cron → script → secret-decrypt → network → monitoring API), with one check per dependency so you can isolate exactly which link broke via systematic elimination.

**4. Verify-after-apply — never declare victory on a plausible fix alone.**
When a fix looks plausible, re-apply it and then re-read the system logs/output to confirm the failure signature is actually gone. If logs still show the same error after the "fix," the hypothesis is falsified — don't stop there, bisect further into the chain rather than assuming the first plausible cause was correct.

## Gotchas

- Testing DNS from only one vantage point (e.g. just the workstation) can't distinguish cache/TTL problems from replication problems from network interception — always run the three-perspective ladder before concluding root cause.
- Don't stop the network investigation at "server looks fine" without stating that conclusion explicitly and then continuing upstream — otherwise the investigation stalls exactly where it should pivot to client/AP-side capture.
- A fix that "looks right" (e.g. restarting a service, editing a secret) is not confirmed until logs are re-read post-apply; treat an unverified fix as still-open.
- Building a single-dependency probe (checking only the network, only the secret) instead of the full chain risks fixing a step that wasn't actually the broken one.

## Diagram

[View diagram](diagram.html)
