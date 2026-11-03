---
name: analyze-features
description: Audit all feature specs in docs/features/ against the current template, CAP-ID standards, open questions, logical gaps, and plan coverage — then request user authorization before making any changes
---

# Analyze Features

Perform a structured audit of every feature spec in `docs/features/`. **Do not modify any files
until the user has explicitly authorized each class of change.**

---

## Phase 1 — Load Reference Artifacts

Before reading any specs, load the reference material you will audit against:

1. Read `docs/features/template.md` — this is the authoritative template. Note every required
   section and every required frontmatter field.
2. Glob `docs/plans/*.md` — build an index of existing plan files (filename → path).
3. Glob `docs/features/*.md` — collect all spec files, excluding `README.md` and `template.md`.

---

## Phase 2 — Audit Each Feature Spec

For every spec file, perform all five checks below. Accumulate findings in an internal report
structure — **do not write anything to disk yet**.

### Check 1 — Template Alignment

Compare the spec against `docs/features/template.md`. Flag if any of the following are missing
or structurally non-conforming:

**Required frontmatter / Metadata table fields:**
- Feature Name, Status, Owner / Author, Last Updated, Version, Related PRs / Issues

**Required sections (must be present and non-empty):**
- `## Metadata`
- `## Executive Overview`
- `## Problem Statement`
- `## Use Cases`
- `## Capabilities`
- `## Acceptance Criteria`
- `## Out of Scope`
- `## Edge Cases`
- `## Known Issues & Limitations`
- `## Open Questions`
- `## Change History`

Flag: "missing sections" or "missing metadata fields" per spec.

### Check 2 — Capabilities Quality

Read the `## Capabilities` section. For each capability item, verify:

- **Numbered with a CAP-ID** in the format `[XX-CAP-NN]` (2-letter prefix, zero-padded integer)
- **Priority label** present: `[P0]`, `[P1]`, or `[P2]`
- **Imperative voice**: starts with "User can…", "System automatically…", "Admin may…", or
  equivalent agent-subject phrasing
- **Single-sentence, testable**: not vague ("improve performance"), not compound
  (two capabilities in one bullet)
- **Logical coherence**: capability makes sense in the context of the feature and the overall
  HomeRadar solution (a property tracking / alerts / extension tool)

Flag each deficient capability with a specific, actionable improvement suggestion.
Also flag if the capability set has **obvious gaps** — e.g., a data model feature with no
read/list capability, an alert feature with no disable/delete capability, a UI feature with
no error state capability.

### Check 3 — Open Questions

Read the `## Open Questions` table. A spec has unresolved open questions if:
- The table is missing entirely
- Any row has `Status: Open` (case-insensitive)
- The section body contains placeholder text like `[Question text]` or `TBD`

If "None" is written and the table is absent, that is acceptable — mark as resolved.

Flag: list each open question verbatim so it can be presented to the user.

### Check 4 — Logical Gaps and Fallacies

Review the spec holistically for:

- **Logical fallacies**: an AC that cannot be tested as written; a capability that contradicts
  another capability in the same spec; a requirement that conflicts with a stated out-of-scope item
- **Capability gaps**: a flow described in Use Cases or UX Flows that has no corresponding
  capability; a data model with fields referenced in ACs but not listed in the data model table;
  an API endpoint referenced in ACs but not listed in the endpoints table
- **Inconsistencies**: version numbers or field names that differ between sections

Flag each gap with a specific proposed fix.

### Check 5 — Plan Coverage

Look up whether a plan file exists for this spec:
- Expected filename: `docs/plans/{spec-slug}-plan.md`
  (derive slug from the spec filename, stripping `.md`)
- Also accept: `docs/plans/{spec-slug}.md`

If a plan exists, read it and check:
- Every CAP-ID from the spec's `## Capabilities` section appears in at least one task in the plan
- Flag any CAP-IDs present in the spec but absent from the plan

If no plan exists, flag: "no plan file found".

---

## Phase 3 — Compile the Audit Report

After processing all specs, build a structured summary:

```
AUDIT SUMMARY
=============
Specs analyzed: N
Specs with template gaps: N (list filenames)
Specs with capability deficiencies: N (list filenames)
Specs with open questions: N (list filenames)
Specs with logical gaps: N (list filenames)
Specs missing a plan: N (list filenames)
Specs with plan coverage gaps: N (list filenames)
```

Then for each spec that has any finding, produce a detail block:

```
--- docs/features/{filename}.md ---
Template gaps:      [list or "none"]
Capability issues:  [list each with proposed fix, or "none"]
Open questions:     [list verbatim, or "none"]
Logical gaps:       [list each with proposed fix, or "none"]
Plan status:        [ok | no plan | missing CAP-IDs: XX-CAP-NN, ...]
```

---

## Phase 4 — Request Authorization via AskUserQuestion

Use the `AskUserQuestion` tool **once** with a consolidated prompt covering all five categories.
Structure the question exactly as follows (fill in the findings):

```
I've audited all {N} feature specs. Here is what I found and what I'd like your authorization to fix:

**1. Template Alignment**
The following specs are missing required sections or metadata and should be updated to match
the current template:
{list each spec and what is missing — or "None found"}

Can I update these specs to align with the template? (yes / no / select specific files)

---

**2. Capability Improvements**
The following capabilities should be improved for clarity, CAP-ID format, or coverage gaps:
{list each spec + each deficient capability + proposed fix — or "None found"}

Can I apply these capability improvements? (yes / no / select specific items)

---

**3. Open Questions**
The following specs have unresolved open questions. Please answer them one at a time after
this prompt and I will record your answers in the spec:
{list each spec + each open question verbatim — or "None found"}

---

**4. Logical Gaps and Fixes**
The following logical issues were found:
{list each spec + each issue + proposed fix — or "None found"}

Can I apply these logical fixes? (yes / no / select specific items)

---

**5. Plan Generation**
The following specs have no plan file or have capabilities not covered by their plan:
{list each spec + what is missing — or "None found"}

Can I generate or update plan files to cover all capabilities? (yes / no / select specific files)
```

---

## Phase 5 — Execute Authorized Changes

After the user responds, apply only the authorized changes:

### If template alignment is authorized:
- Rewrite non-conforming specs to match the template structure
- Never discard content — map every sentence to the nearest section; use `## Notes` if no section fits
- Update `Last Updated` field to today's date

### If capability improvements are authorized:
- Apply only the specifically authorized items
- Preserve all other content in the spec verbatim
- If a new capability is added, assign the next available CAP-ID in sequence

### For open questions:
- After the user answers each question in the AskUserQuestion response, update the corresponding
  `## Open Questions` row: set `Status: Resolved` and append the answer as a note
- If no questions were open, skip

### If logical fixes are authorized:
- Apply only the specifically authorized fixes
- For each fix that modifies a capability, AC, or data model field, note the change in `## Change History`

### If plan generation is authorized:
- For specs with no plan: generate a plan file at `docs/plans/{slug}-plan.md` using the plan
  template from `docs/plans/` references. Cover all CAP-IDs.
- For specs with partial plans: add missing CAP-IDs as tasks to the existing plan.

---

## Important Constraints

- **Never modify a spec without explicit authorization** from the user for that category of change.
- **Never silently discard content** — every rewrite must preserve all original material.
- **Never change the `Status` field** of a spec (only the user controls that).
- **Open questions must be answered by the user** — do not infer or fabricate answers.
- After all authorized changes are applied, report a final summary of what was changed.
