---
feature: "{{Feature Name}}"
slug: "{{feature-slug}}"
status: draft        # draft | approved | implemented | deprecated
priority: p2         # p0 | p1 | p2 | p3
area: "{{area}}"     # functional area (e.g. data-model, ui, ingestion)
depends_on: []       # list of other feature slugs
owner: "{{author}}"
version: 1.0
last_updated: "{{TODAY}}"
related: []          # PRs, issues, external tickets
---

# {{Feature Name}}

> **How to read this spec.** Sections marked **REQUIRED** must be populated before the spec moves to `status: approved`. Sections marked **OPTIONAL** may be omitted on slim specs but the heading must still exist (write `_n/a_` underneath). Never delete instruction blockquotes from the template file itself — only from your filled-in copy.

---

## Metadata

| Field         | Value                |
|---------------|----------------------|
| Status        | Draft                |
| Owner         | {{author}}           |
| Last Updated  | {{TODAY}}            |
| Version       | 1.0                  |
| Related       | _none_               |

---

## Executive Overview

**REQUIRED.** 2-4 sentences of prose. What it does, why it exists, who it serves, what success looks like. No bullets.

---

## Problem Statement

**REQUIRED.** Who is affected, what their current workaround is, why it falls short.

---

## Use Cases

**REQUIRED.** At least three:

1. **Primary (happy path).** ...
2. **Power user.** ...
3. **Admin / operator.** ...

---

## Capabilities

**REQUIRED.** Use the CAP-ID format `[XX-CAP-NN]` where `XX` is the 2-letter feature abbreviation registered in `docs/workflow/SDLC.md` and `NN` is a zero-padded sequential integer. Tag each capability with priority `[P0]`, `[P1]`, or `[P2]`. Use imperative voice ("User can…", "System automatically…", "Admin may…"). Each capability must be a single, testable sentence.

- [ ] `[XX-CAP-01]` `[P0]` User can ...
- [ ] `[XX-CAP-02]` `[P0]` System automatically ...
- [ ] `[XX-CAP-03]` `[P1]` Admin may ...

---

## Acceptance Criteria

**REQUIRED.** Given/When/Then for every P0 capability. Each criterion must be testable and binary pass/fail.

- **AC-01** (covers `[XX-CAP-01]`)
  - **Given** ...
  - **When** ...
  - **Then** ...

---

## Out of Scope

**REQUIRED.** Explicit exclusions to prevent scope creep. List items deferred during requirements gathering and capabilities removed during overlap resolution.

- ...

---

## Edge Cases

**REQUIRED.** Plausible boundary conditions. One bullet per case; reference the affected capability ID where applicable.

- ...

---

## Known Issues & Limitations

**OPTIONAL.** Deferred items, known performance limits, third-party constraints.

- ...

---

## Open Questions

**REQUIRED.** Use the table below. Mark `Status: Resolved` once answered. If no open questions, write `None.` and omit the table.

| # | Question | Raised by | Status |
|---|----------|-----------|--------|
| 1 | ...      | ...       | Open   |

---

## Change History

**REQUIRED.** Append-only.

| Date       | Author       | Change                          |
|------------|--------------|---------------------------------|
| {{TODAY}}  | {{author}}   | Initial draft                   |
