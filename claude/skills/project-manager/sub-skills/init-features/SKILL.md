---
name: init-features
description: Run the Feature Interview to capture initial feature specs from docs/INITIAL_PROMPT.md — extracts functional areas, interviews the user one area at a time, and writes one feature spec per area to docs/features/
---

# Init Features

Run the **Feature Interview** to seed `docs/features/` from `docs/INITIAL_PROMPT.md`. This is Step 1 of the orchestration pipeline. Without feature specs, plans cannot be generated and tasks cannot be spawned.

**Prerequisite:** `docs/INITIAL_PROMPT.md` must exist. If it does not, stop and tell the user to run `/init-project` first (or create the file manually).

---

## Step 1 — Extract feature areas

Read `docs/INITIAL_PROMPT.md` in full. Group the implied features into 3-6 functional areas (e.g. "Data Models & Engine", "Onboarding & Profiles", "Dashboard & Logging", "Planner & Visualization", "Recovery & Reminders").

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
- Constraints or non-obvious requirements not captured in `INITIAL_PROMPT.md`
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

- **Never invent requirements.** If the user did not state it and it is not derivable from `INITIAL_PROMPT.md`, ask via `AskUserQuestion` — do not infer silently.
- **One spec per area.** Do not produce a single mega-spec; the orchestrator processes specs independently.
- **Specs are authority.** Once `status: approved`, only the user (or an agent with explicit `AskUserQuestion` confirmation) may change the spec.
