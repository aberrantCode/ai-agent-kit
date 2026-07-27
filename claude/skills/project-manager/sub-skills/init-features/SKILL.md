---
name: init-features
description: Run the Feature Interview to capture initial feature specs from docs/REQUIREMENTS.md — extracts functional areas, interviews the user one area at a time, and writes one feature spec per area to docs/features/
---

# Init Features

Run the **Feature Interview** to seed `docs/features/` from `docs/REQUIREMENTS.md`. This is Step 1 of the orchestration pipeline. Without feature specs, plans cannot be generated and tasks cannot be spawned.

---

## Step 0 — Prerequisite Gate (fail-closed)

**Run this before anything else. Do not proceed past it on a partial scaffold.**

Verify every required artifact exists (e.g. `test -f <path>`):

- `docs/REQUIREMENTS.md` — source material for the interview
- `docs/features/template.md` — canonical spec template each area is written from (Step 2)
- `docs/workflow/SDLC.md` — must exist **and** contain a `## Feature Abbreviation Registry` heading, where you append a CAP-ID prefix row per spec (Step 2)

**Verify existence *and* the registry**, e.g. `test -f docs/workflow/SDLC.md && grep -q "Feature Abbreviation Registry" docs/workflow/SDLC.md`. A present-but-registry-less `SDLC.md` is incomplete — **treat it as missing**.

**If all exist and `SDLC.md` has the registry, continue to Step 1.**

**If any are missing (or `SDLC.md` lacks the registry), STOP.** A repo without these was not initialized by `/init-project`; do not improvise a substitute. Use `AskUserQuestion` to offer:

- (a) **Run `/init-project` now** (Recommended) — scaffold the missing artifacts, then re-run this gate and continue.
- (b) **Cancel** — stop; report exactly which artifacts were missing.

If the user picks (a): invoke `project-manager:init-project`, wait for it to finish, **re-verify the paths**, and only then continue. If any are still missing after init, stop and report.

> **Red flag — STOP.** Writing specs into a repo with no `SDLC.md` leaves you nowhere to register CAP-ID prefixes. Do not invent a per-repo convention to route around the missing registry — halt and offer init.

---

## Step 1 — Extract feature areas

Read `docs/REQUIREMENTS.md` in full. Group the implied features into 3-6 functional areas (e.g. "Data Models & Engine", "Onboarding & Profiles", "Dashboard & Logging", "Planner & Visualization", "Recovery & Reminders").

Use `AskUserQuestion` to confirm the grouping before proceeding. Allow the user to:

- (a) Accept the grouping as proposed
- (b) Merge or split specific areas
- (c) Add a missed area
- (d) Drop an area for later

Iterate until the user accepts.

---

## Step 2 — Interview one area at a time

For each accepted area, use `AskUserQuestion` to collect:

- Which capabilities in this area are must-have (P0) vs. nice-to-have (P1/P2)
- Constraints or non-obvious requirements not captured in the requirements doc
- Acceptance criteria: what does "done" look like for this area?
- Known dependencies on other areas

After each area interview, **immediately** write the feature spec to `docs/features/<area-slug>.md` using the canonical template (`docs/features/template.md`). Do not batch writes — specs are useful the moment they exist, and the user may stop at any time.

For each spec, also append a CAP-ID prefix row to `docs/workflow/SDLC.md` Feature Abbreviation Registry. Pick a unique 2-letter prefix per spec.

---

## Step 3 — Final pass

After all areas have specs:

1. Read every newly created spec back.
2. Use `AskUserQuestion` to confirm priorities, P0 capabilities, and out-of-scope items per spec.
3. Update each spec's `status:` frontmatter — `approved` if the user is satisfied, otherwise leave as `draft`.

Report a summary table:

| Spec | CAP prefix | P0 count | Status   |
|------|------------|----------|----------|
| ...  | XX         | N        | approved |

Next: tell the user to run `/continue-tasks` to begin plan generation.

---

## Constraints

- **Never invent requirements.** If the user did not state it and it is not derivable from the requirements doc, ask via `AskUserQuestion` — do not infer silently.
- **One spec per area.** Do not produce a single mega-spec; the orchestrator processes specs independently.
- **Specs are authority.** Once `status: approved`, only the user (or an agent with explicit `AskUserQuestion` confirmation) may change the spec.
