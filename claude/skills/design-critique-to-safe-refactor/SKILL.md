---
name: design-critique-to-safe-refactor
description: Use when converting a design critique, redesign request, or UX audit finding into actual code changes on a tool or feature that's already working. Ensures the refactor can't silently break existing behavior by treating tests and client-side DOM hooks as the interface contract to preserve, and by gating auth/security-sensitive changes with explicit review before merge.
status: active
version: 2026-07-05
---

# Design Critique to Safe Refactor

## When to use

- Applying design critique findings (yours or a design-system audit's) as code changes to an existing, working tool or UI.
- Redesigning a user-facing feature or workflow that already has real usage, real client-side wiring, or an existing test suite.
- Any refactor touching auth, access control, or another core/security-sensitive path as a side effect of a design change.

## Method

1. **Read the test contracts before touching code.** Tests are the source-of-truth interface contract for what structural behavior must survive the refactor. Understand which assertions would break under each proposed change *before* making it, not after.

2. **Let snapshot tests tell you which DOM changes need deliberate regeneration.** A snapshot diff after a redesign isn't automatically a bug — it may be the intended new structure. Update snapshots only for changes you intended; if a snapshot changes somewhere you didn't touch, treat that as a signal to investigate, not to blindly regenerate.

3. **Distinguish "intentionally removed behavior" from "implementation bug" when a test fails.** Only update tests that assert behavior the critique explicitly says should go away. If a test fails and the critique didn't call for removing that behavior, it's a regression — fix the code, not the test.

4. **Before redesigning a tool with existing client-side JavaScript**, read that JS first to find every DOM hook it queries (class names, IDs, data attributes). Design the new structure to preserve those hooks exactly, and restructure everything else freely around them. Prefer CSS-only mechanisms (counters, `::after`, etc.) over JS changes when they achieve the same visual result — fewer moving parts means less to break. Test the redesign against the *existing* client to confirm every interaction still fires correctly. This makes it structurally impossible for the redesign to break the tool's behavior, because the hooks it depends on never moved.

5. **When redesigning a user-facing workflow (not just styling)**, first understand the current architectural context and pin down the specific pain points before proposing a replacement. Design the new surface as an orchestrator over existing, proven endpoints and data paths — not a parallel reimplementation — so it inherits existing write-path safety guarantees instead of re-deriving them. Validate the new design against existing patterns before implementation begins.

6. **When the refactor touches auth or another core path** (user revocation, access enforcement, etc.), establish the safety contract explicitly: run code-reviewer and security-reviewer gates before merge, identify the hardest part up front (e.g., a dual-path auth check), and verify the fix on *every* path (e.g., both forward-auth and OIDC), not just the one you changed. Test guard assertions directly (e.g., last-admin-cannot-be-deactivated, self-deactivation-blocked). Record any known tradeoffs (e.g., TOCTOU-class races) explicitly rather than silently accepting them, and note portable hardening ideas for future migrations.

7. **When auditing a design system against multiple implementations**, split the audit across parallel subagents by lens (code/token quality, documentation rigor, visual correctness) rather than one pass covering everything. Since agents can't see images, ground visual audits by first writing a plain-text inventory of the UI controls and layout patterns visible in screenshots, then hand that inventory (not the image) to the auditor. Synthesize findings into a priority-sequenced list where fixing lower-numbered items (e.g., token inconsistencies) unblocks higher-numbered ones (e.g., missing component styles depend on tokens existing first). Use a peer-review pass to catch derived-data drift (e.g., a scorecard whose references drifted from renumbered findings) before finalizing. Structure the action list as atomic sub-steps (5a, 5b, ...) so an automated loop can execute them sequentially without bundling unrelated fixes together.

## Gotchas

- A green test suite after a redesign doesn't prove nothing broke — check that the tests you expected to change actually changed, and nothing else did.
- Don't let "the design looks right" substitute for "the client-side hooks still resolve" — visually correct and functionally intact are different claims.
- Dual-path checks (e.g., two auth mechanisms) are the classic place a fix looks complete but only covers one path — enumerate every path explicitly.
- Image-blind subagents will fabricate visual detail if handed only a vague prompt; always ground them with a written inventory first.

## Diagram

[View diagram](diagram.html)
