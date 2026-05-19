---
name: add-feature
description: >
  Use when the user wants to spec out, plan, or document a new feature. Triggers on /add-feature
  or when the user says things like "I want to add a feature", "spec out a feature", "create a feature
  spec", "write a feature specification", "plan a new feature", "document a feature idea", "let's
  design a feature", or "I have a feature idea". Walks through a structured 7-phase conversational
  workflow that produces a thorough feature spec saved to /docs/features/ with a date-prefixed filename.
  If project-manager scaffolding is present, defer to project-manager:add-feature instead so the
  canonical CAP-ID workflow is used. After saving, automatically generates a visual diagram of the
  spec and offers to create an implementation plan. Use this proactively whenever a user describes a
  feature they want to build, even if they don't explicitly say "spec" or "specification".
---

# Add Feature Spec

Guide the user through a structured, conversational 7-phase workflow to produce a thorough feature
specification document saved to `/docs/features/`.

## Project-Manager Repositories

Before starting this standalone workflow, check whether the current repository is managed by the
`project-manager` skill. If all of these exist, stop this workflow and invoke
`project-manager:add-feature` instead:

- `docs/workflow/SDLC.md`
- `docs/features/template.md`
- `docs/tasks/`

Project-manager repositories require CAP-ID prefixes, approved-spec gating, feature index updates,
and plan-compatible frontmatter. The standalone date-prefixed spec format is not compatible with
that lifecycle.

Work through phases **in order**. Use `AskUserQuestion` for structured choices at each phase.
Briefly summarize what you captured after each phase before moving on — this catches misunderstandings
early and keeps the user engaged.

---

## Phase 1 — Feature Identity

Ask for the feature name and a crisp problem statement. The goal is a clear one-liner that could
appear in a changelog.

Use `AskUserQuestion` to confirm tone if unclear, but mostly ask via natural dialogue:
- What is the feature name?
- What problem does it solve, or what does it enable? (1-3 sentences)
- Is this user-facing, developer-facing, or internal/infrastructure?

---

## Phase 2 — Context & Motivation

Understand why this feature is being built and who requested it.

Ask:
- Who is requesting this? (e.g., user feedback, stakeholder ask, technical debt, competitive gap)
- What is the priority or urgency?
- Is there any background context, links, or related work to include?

---

## Phase 3 — Codebase Scan

Before asking about technical design, **actively scan the codebase** to identify relevant existing
code. This is essential — don't skip it.

Look for:
- Files, modules, and components related to the feature's domain
- Existing patterns and conventions the new feature should follow
- Data models, APIs, or services likely to be affected
- Related features or partial implementations

After scanning, summarize your findings to the user:
> "I found these relevant files/components: [list]. These are likely affected by this feature."

Ask the user to confirm or correct your findings. Their corrections matter — local knowledge beats
static analysis.

---

## Phase 4 — User Stories & Personas

Define who uses this feature and what success looks like.

Ask:
- Who are the primary users/personas affected?
- What are the key user stories? (format: "As a [user], I want [action] so that [outcome]")
- What are the acceptance criteria — how will we know this is "done"?

Be specific about acceptance criteria. If the user gives vague ones ("it should work"), gently
push for something measurable or observable.

---

## Phase 5 — Technical Design

Draw on your Phase 3 codebase scan to ground this conversation. Suggest likely affected components
and ask the user to confirm or correct.

Ask:
- Which components, services, or systems need to be created or changed?
- Are there significant architectural decisions or constraints to document?
- Are there external dependencies, API integrations, or data migrations involved?

Your scan findings go into the "Affected Components" list. The user's answers populate
"Architecture Notes" and "Dependencies".

---

## Phase 6 — Out of Scope

Explicitly document what this feature will NOT include. This is one of the most valuable sections —
it prevents scope creep and aligns stakeholders.

Ask:
- What related things are explicitly out of scope for this feature?
- Are there related improvements that should be tracked separately?

If the user struggles here, prompt: "What would be a natural extension that we're consciously
deferring?" or "What might stakeholders assume is included that actually isn't?"

---

## Phase 7 — Risks & Open Questions

Surface unknowns that need resolution before or during implementation.

Ask:
- Are there open questions or decisions not yet made?
- What are the technical risks (complexity, performance, security, migration)?
- Are there blockers or dependencies on other teams or features?

---

## Generate the Spec

Assemble all gathered information into a feature spec markdown file.

### File naming

Format: `YYYY-MM-DD-<kebab-case-feature-name>.md`

Get today's date from the system. Derive the slug from the feature name provided in Phase 1.
Example: `2026-03-22-user-authentication.md`

### Save location

`/docs/features/<date-prefixed-slug>.md`

Create the `/docs/features/` directory if it doesn't exist.

### Conflict handling

If a file with the same slug already exists:
1. Show the user the existing file's content
2. Ask for confirmation before overwriting

### Spec template

Use this exact structure (fill in all sections; if a section has nothing to add, write "N/A — [reason]"):

    # Feature Spec: [Feature Name]

    **Date:** YYYY-MM-DD
    **Status:** Draft
    **Requested by:** [who/why]
    **Priority:** [priority/urgency]
    **Audience:** [user-facing / developer-facing / internal]

    ---

    ## Overview & Motivation

    [2-4 sentences: what problem this solves and why it matters now]

    [Background context or links if provided]

    ---

    ## User Stories & Acceptance Criteria

    **Personas affected:** [list personas]

    | User Story | Acceptance Criteria |
    |------------|---------------------|
    | As a [user], I want [action] so that [outcome] | - Criterion 1<br>- Criterion 2 |

    ---

    ## Technical Design

    ### Affected Components

    [List of files/services/modules affected — from codebase scan + user input]

    ### Architecture Notes

    [Key design decisions, patterns to follow, constraints]

    ### Dependencies

    [External APIs, services, data migrations, or other features this depends on]

    ---

    ## Out of Scope

    - [Item 1 — what is explicitly excluded and why]
    - [Item 2]

    ---

    ## Risks & Open Questions

    | Item | Type | Notes |
    |------|------|-------|
    | [Description] | Risk / Open Question | [Context or who needs to decide] |

    ---

    ## Implementation Notes

    [Optional: suggested approach, phasing, or rough effort notes provided by the user]

---

## Post-Generation Actions

After saving the spec file, do both of the following:

### 1. Generate and launch a visual diagram

**Immediately and automatically** invoke the `visual-explainer:generate-web-diagram` skill using
the Skill tool — do not ask for permission first. Pass this prompt:

> "diagram the feature spec in [path-to-spec]"

Replace `[path-to-spec]` with the actual path of the saved spec file. The skill will open the
diagram in the browser automatically.

### 2. Offer to write an implementation plan

After the diagram is generated, ask the user:

> "Would you like me to run `/superpowers:writing-plans` to generate a step-by-step implementation
> plan from this spec?"

If they say yes, invoke the `superpowers:writing-plans` skill via the Skill tool.

---

## Diagram

[View diagram](diagram.html)

---

## Principles

- **Summarize after every phase.** A brief "here's what I captured" before moving on catches
  misunderstandings early and keeps the user aligned.
- **Don't skip phases.** Each phase builds context for the next. The codebase scan in Phase 3
  is especially important — use it actively in Phase 5 rather than ignoring it.
- **Push back on vagueness.** If an acceptance criterion is unmeasurable or an out-of-scope item
  is ambiguous, press gently for something more concrete. A weak spec creates implementation debt.
- **Lean on the codebase scan.** Suggest specific affected files/components from Phase 3 rather
  than speaking in abstractions. Ground the spec in what's actually there.
- **Be opinionated about quality.** The spec should be good enough that a developer could start
  implementation without ambiguity about scope or approach.
