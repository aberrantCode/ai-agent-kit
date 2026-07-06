---
name: deploy-idempotency-two-pass-gate
description: Use when running any live infrastructure apply (Ansible playbook, Terraform, Docker Compose stack, or similar) — before declaring a deployment successful or moving on to smoke tests, run the apply twice and require the second pass to report zero changes, so latent non-idempotent tasks are caught before they corrupt future deploys.
status: active
version: 2026-07-05
---

# Deploy Idempotency Two-Pass Gate

## When to use
- Before declaring any live infrastructure apply "done" — Ansible playbook, Terraform plan/apply, Docker Compose stack, or any tool that should converge to a stable state.
- Especially critical when deploying from an unmerged feature branch to live infra: the two-pass run is the only chance to catch idempotency bugs before the code reaches `dev`.
- As a hard-stop gate before running smoke tests, so convergence bugs are caught early rather than masked by "it looks like it worked."

## Method
1. **Acquire a coordination lock** before pass 1 if other agents/processes might apply concurrently — shared rendering tasks (dashboards, compose stacks) will falsely appear non-idempotent if two applies race.
2. **Run pass 1.** Expect `changed > 0` — this is normal on first deploy or after a real change. Capture the full PLAY RECAP (or equivalent apply summary) in the evidence log.
3. **Run pass 2 immediately after**, same playbook/command, same scope. Require `changed = 0` for the gate to pass. Capture this PLAY RECAP too — both recaps go in the evidence log together, not just the final one.
4. **Isolate the signal if pass 2 is not clean.** Don't treat any nonzero `changed` in pass 2 as an automatic hard fail:
   - Filter to your target tasks (via tags or resource names) and verify only those went quiet.
   - If unrelated tasks are churning (e.g., a different dashboard's `emby.json` re-copying, or an unrelated catalog re-rendering), document it as a pre-existing flap so it doesn't mask a real bug in your own changes.
5. **On first-time service deploys**, a one-time "settle" pass is expected and not a bug: cross-service artifacts (e.g., an Authentik app binding, a dashboard catalog hash) can only reconcile once the container/resource exists, so pass 2 may still show `changed > 0` even though the underlying tasks are deterministic.
   - Run a third, diagnostic pass to distinguish a genuine settle from broken non-determinism. A monotonic decline (e.g., 6 → 2 → 0 changed) proves convergence. Changes that persist or fluctuate across passes prove a broken/non-deterministic template — root-cause it, don't skip it.
6. **Distinguish expected slowness from errors.** First-run install latency, Docker image pulls, etc. are expected on pass 1 and should not be treated as failures. Stop and escalate only on a non-zero return code in pass 2, or on changes that don't converge per step 5.
7. **Treat the gate as non-negotiable and cost-bearing.** A failing pass 2 demands a root-cause fix in the underlying task/template — not a skip-and-retry, and not silencing the check.

## Gotchas
- Common sources of false non-idempotency: `pipx inject` heuristics, lingering handler side effects (handlers firing on every run instead of only on real change), and dashboard/catalog render tasks that hash inconsistently.
- Concurrent agents or processes touching shared rendering tasks (dashboard configs, compose stacks) can make an otherwise-idempotent task look broken — this is why a coordination lock matters, and why isolating unrelated churn (step 4) is necessary before blaming your own change.
- Don't confuse a legitimate one-time settle (step 5) with a real bug — the distinguishing signal is monotonic convergence across a third pass, not just "pass 2 wasn't zero."
- Skipping the second pass or accepting `changed > 0` on faith defeats the entire point of the gate; every exception must be documented as a known pre-existing flap, not silently ignored.
