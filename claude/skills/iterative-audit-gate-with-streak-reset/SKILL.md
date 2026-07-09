---
name: iterative-audit-gate-with-streak-reset
description: Use when a deliverable, backlog closure, or shipped change must be verified against a spec/gate before being considered done, and a single clean pass isn't trustworthy enough. Runs independent auditors or verification gates repeatedly, resetting a "clean streak" to zero on any finding, until two consecutive rounds come back clean — forcing convergence instead of accepting the first green result.
status: active
version: 2026-07-05
---

# Iterative Audit Gate With Streak Reset

## When to use

- Reviewing a deliverable (design, feature, presentation) against a spec plus an evidence base, using independent auditors (e.g., design auditor + technical auditor).
- Enforcing verification gates (tests, lint, type-check) after each commit before something ships.
- Closing backlog items or knowledge-base entries where a structural invariant (e.g., a bijection between an index and its detail rows) must hold.

## Method

1. **Track a streak counter, not a single pass/fail.** Define the gate as: continue running audits/checks until **two consecutive rounds** both come back with zero findings. A single clean pass is not sufficient evidence of correctness — fresh eyes on a subsequent round routinely surface issues a prior pass missed.

2. **Reset the streak to 0 the moment any auditor or gate reports a finding**, no matter how minor. Fix it, then re-run the *entire* gate from round 1 — don't resume the count from where you left off. This is what forces genuine convergence instead of settling for "mostly clean."

3. **Use independent auditors per round** (e.g., a design auditor and a technical/code auditor running separately against the same spec + evidence base) so each round has a real chance of catching what the others missed, rather than one reviewer re-confirming their own prior judgment.

4. **Document resolved design/scope decisions in the audit brief itself**, not just in chat — e.g., "accepting a data-grid at data-label tier because task density forces the trade-off." This lets auditors ratify a deliberate compromise instead of re-flagging it as a fresh finding every round.

5. **For structural-invariant gates** (e.g., "every H2 entry must have a matching QV row," an index-count-equals-detail-file-count bijection), treat the gate's constraints as *design contracts*, not obstacles to route around. Gates commonly enforce removals strictly (you can't delete one side of a pair without the other) while allowing additions freely — use that asymmetry: if you find an orphaned/corrupted entry, restore its missing half first so the invariant holds, *then* remove both sides symmetrically. Use a dedicated checker script in `--strict` mode to validate (e.g., `check-backlog-closure.py --strict`); note that "no violations" typically emits zero output/pairs, not an explicit success message — don't mistake silence for a hang.

6. **Gate documentation/knowledge-base additions the same way**: bijection checks (index count == detail file count), cross-reference validation, and staleness warnings. Treat any gate failure here as a data-integrity issue, not an optional warning to dismiss — it's how duplicates, orphaned entries, and stale intake items get caught before they pollute the knowledge base.

7. **For code-quality gates (tests/lint/type-check), require two consecutive passing runs before shipping**, not one. When a run fails, first diagnose whether it's a test-isolation bug or a real defect — fix the actual cause atomically, then restart the streak at 0. Treat the gate's pass/fail as the system of record; don't let a manual "looks fine to me" substitute for the gate rerunning clean.

## Gotchas

- Don't resume a partially-built streak after a fix — restart from 0. A fix that "should" only affect the flagged item can have side effects the next full pass would catch.
- A gate that emits nothing on success (e.g., zero violation pairs) can look identical to a hung or misconfigured run — verify the script's actual success contract before trusting silence.
- Recurring stale-task classes (e.g., "fixed in a follow-up PR but the backlog row was never closed") indicate a verify-before-promote discipline gap — treat repeat occurrences as a process signal, not just a one-off cleanup.
- Independent auditors lose their value if they're given the same framing/bias each round — vary the review lens or angle slightly, or the second "independent" pass just re-confirms the first.

## Diagram

[View diagram](diagram.html)
