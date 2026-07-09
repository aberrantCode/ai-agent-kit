---
name: firewall-alias-as-indirection
description: Use when designing or editing firewall rules for a group of devices (e.g. cameras, IoT clusters) — reference a named alias instead of hardcoded IPs so device-set changes never require rule edits, and use config-tracing (not assumption) to decide whether a public endpoint is actually load-bearing before retiring it.
status: active
version: 2026-07-05
---

# Firewall Alias as Indirection

## When to use

You're writing or modifying firewall rules for a set of devices that share a control policy (e.g., "block all Wyze cameras," "allow all NAS backup hosts"), or you're deciding whether an existing rule/endpoint can be safely retired. Use this pattern whenever a rule's *target* (which devices it applies to) is likely to change independently of the rule's *intent* (what action to take).

## Method

1. **Define an alias, not an inline IP list.** Create a named alias (e.g., `wyze_cams`) that maps to the actual device IPs. Write firewall rules against the alias name, never against raw IPs or an inline list.
2. **Prefer contiguous IP ranges over per-host aliases** when multiple devices share one control policy: `wyze_cams = 192.168.40.30-36` as a single range, not five separate per-camera aliases. This means "block all Wyze cameras" is one rule referencing one alias — not five rules.
3. **Size the range for future growth.** Convert a multi-device list to a stable contiguous range sized larger than the current device count, so adding a new device of the same class never requires a rule or range edit — only, at most, an alias membership update.
4. **Decouple rule lifecycle from inventory lifecycle.** When promoting a device from dynamic DHCP to a static reservation, update only the alias definition (or DHCP reservation pinning to keep the alias range stable) — the rule itself stays untouched. This is the entire point of the indirection: rule count and rule content stay stable while device membership churns.
5. **Before retiring a rule or public endpoint, trace actual consumers in config — don't rely on operator assumption or recap wording.** Search configs for explicit references (e.g., `endpoint.baseUrl = 'honcho-api.opbta.com'`) or client connection strings that name the alias/endpoint. If something explicitly depends on it, it's load-bearing even if it "seems unused."
6. **Never retire before repointing.** If a config explicitly names an endpoint or alias target, don't remove the underlying resource until the config has been repointed to a replacement path and that new path has been verified to work end-to-end.

## Gotchas

- Table-group / range aliases are the source of truth for a *managed device set* — treat alias membership edits as the only sanctioned way to add/remove devices from a policy, don't special-case one device with its own rule "just this once."
- Config is the source of truth for "is this used," not memory of the deployment's intended design or a written recap — grep the actual config for references before deciding something is dead.
- Range-based aliases still need enough headroom: sizing `192.168.40.30-36` for 4 current devices leaves room for roaming/DHCP additions without triggering a range resize later.
- This pattern generalizes beyond firewalls: any indirection where "the identity of the target set" and "the policy applied to it" change on different timelines benefits from a named alias/group layer instead of inline enumeration.

## Diagram

[View diagram](diagram.html)
