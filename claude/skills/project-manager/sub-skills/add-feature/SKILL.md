---
name: add-feature
description: Create a new feature spec — interviews user, detects overlap with existing specs, populates the canonical template, generates a diagram, and updates the feature index
---

# Add Feature

Creates a complete, approval-ready feature specification in `docs/features/`. Covers requirement gathering, overlap detection, template population, optional diagram generation, and feature-index updates.

**Prerequisite:** The project must have been initialized with `/init-project` (or equivalent manual scaffolding). Specifically, this skill assumes the following exist:

- `docs/features/template.md` — canonical feature spec template
- `docs/features/README.md` — feature index
- `docs/workflow/SDLC.md` — contains the Feature Abbreviation Registry table used for CAP-ID prefixes

If any are missing, stop and tell the user to run `/init-project` first.

---

## Phase 1 — Gather Feature Requirements

Check whether the user's invocation contains a meaningful feature description.

If **no description** was provided, use `AskUserQuestion` to ask:
> "Tell me about the feature you want to add. What does it do, who uses it, and what problem does it solve?"

After receiving a description, summarize it back to the user and use `AskUserQuestion` to clarify anything unclear — at minimum:

- The **must-have capabilities** (P0 items that block launch)
- What is **explicitly out of scope** for this iteration

Do not proceed to Phase 2 until you have enough to draft a meaningful spec.

---

## Phase 2 — Overlap Detection

Read every `.md` file in `docs/features/` except `template.md` and `README.md`. For each, note the items under `## Capabilities`.

Compare those against the proposed feature. Look for:

- **Full overlap** — another spec already covers the entire proposed feature
- **Partial overlap** — some capabilities already exist elsewhere
- **Adjacent** — a related spec that could be extended vs. a separate spec warranting its own file

**If no overlap exists:** proceed to Phase 3.

**If overlap exists:** use `AskUserQuestion` to present the situation clearly:

- List the overlapping capabilities and which existing spec(s) contain them
- Offer options:
  - (a) Narrow the new spec to exclude overlapping capabilities (leave them where they are)
  - (b) Move overlapping capabilities from the existing spec into the new one (and edit the existing spec)
  - (c) Extend the existing spec instead of creating a new file

**Do not proceed until every capability in the planned feature exists in exactly one spec file.** If capabilities must be removed from an existing spec, edit that file now, before creating the new one.

---

## Phase 3 — Create the Spec File

1. **Choose a filename:** `docs/features/<feature-slug>.md` — kebab-case, descriptive (e.g. `notification-center.md`, `bulk-import.md`). Derive from the feature's primary capability. If ambiguous, use `AskUserQuestion`.

2. **Choose a CAP-ID abbreviation:**
   - Open `docs/workflow/SDLC.md` and locate the **Feature Abbreviation Registry** table
   - Pick a 2-letter abbreviation not already in that table
   - Note it — you will reference it throughout, and you will add a row to the registry in Phase 6

3. **Copy the template:** Read `docs/features/template.md` in full, then write its content to the new file path.

---

## Phase 4 — Populate the Template

Fill in every required section following these rules:

- **Delete every instruction blockquote** (`> ...` lines) after populating the section — never leave template instructions in the finished spec
- Use `AskUserQuestion` for any **REQUIRED** section where you lack enough information to write confidently
- Make reasonable inferences for optional sections; record assumptions as Open Questions
- Never leave `[placeholder]` text — either fill it in or mark it `TBD` with a note

### Section-by-Section Guidance

**Metadata.** Set `Status: Draft`, `Last Updated:` today's date, `Owner:` ask via `AskUserQuestion` if not obvious from context, `Version: 1.0`.

**Executive Overview.** 2-4 sentences of prose (no bullets): what it does, why it exists, who it serves, what success looks like.

**Problem Statement.** Who is affected, what the current workaround is, why it falls short.

**Use Cases.** Generate at least three: one primary (happy path), one power-user, one admin. Use `AskUserQuestion` if the admin scenario is unclear.

**Capabilities.**
- Use `[XX-CAP-NN]` with the chosen 2-letter prefix
- Include priority tags `[P0]`, `[P1]`, `[P2]`
- Draft the list, then use `AskUserQuestion` to confirm the P0 items with the user before finalizing — these define launch-blocking scope

**Acceptance Criteria.** Given/When/Then for every P0 capability and any P1 items with clear testable outcomes.

**Out of Scope.** Items deferred during the requirements conversation and any capabilities removed from existing specs during overlap resolution.

**Edge Cases.** Generate plausible boundary conditions from the capabilities. Reference each affected capability ID.

**Known Issues & Limitations.** Deferred items, known performance limits, third-party constraints. Write `_none_` if there are none.

**Open Questions.** Unresolved decisions go here as table rows with `Status: Open`. Write `None.` only when everything is resolved.

**Change History.** Single row: `{{TODAY}} | {{author}} | Initial draft`.

---

## Phase 5 — Generate the Diagram (optional)

If the `visual-explainer:generate-web-diagram` skill is installed, invoke it to generate an HTML diagram for this feature.

Ask it to illustrate:

- The primary user flow (entry point → key actions → outcome)
- System components involved (infer from project — API, database, UI, worker, etc.)
- Data flows between components
- Key decision points or branching conditions

**Save location:** `docs/features/diagrams/<feature-slug>.html`

After generating, add a `## Diagram` section to the spec, inserted just before the `## Change History` section:

```markdown
## Diagram

[Feature flow diagram](diagrams/<feature-slug>.html)
```

Open the diagram in the browser for the user to review.

If `visual-explainer` is not installed, skip Phase 5 silently.

---

## Phase 6 — Update the Feature Index and Registry

1. **Feature index.** Open `docs/features/README.md` and add the new feature to the most appropriate category table. If no category fits, use `AskUserQuestion` to choose between (a) adding a new category or (b) using the closest existing one.

   Match the existing row format exactly:

   ```markdown
   | [Feature Name](feature-slug.md) | One-line description | Key capabilities summary |
   ```

2. **CAP-ID registry.** Open `docs/workflow/SDLC.md`, find the **Feature Abbreviation Registry** table, and append a row mapping your chosen 2-letter prefix to the new feature slug:

   ```markdown
   | XX | feature-slug | Short description of the feature |
   ```

---

## Completion Checklist

Verify before reporting done:

- [ ] `docs/features/<feature-slug>.md` exists with all required sections populated and no instruction blockquotes remaining
- [ ] `docs/features/README.md` includes the new feature entry with a working link
- [ ] `docs/workflow/SDLC.md` has the new CAP-ID prefix in the registry
- [ ] Diagram exists at `docs/features/diagrams/<feature-slug>.html` (if `visual-explainer` was available)

Tell the user:

> "The spec is ready for review at `docs/features/<feature-slug>.md`. When you're satisfied with the content, set `Status: approved` in the frontmatter — that's the signal for `/continue-tasks` to begin plan generation."
