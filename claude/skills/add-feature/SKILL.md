---
name: add-feature
description: >
  Use when the user wants to spec out, plan, or document a new feature. Triggers on /add-feature,
  /create-feature-spec, or when the user says things like "I want to add a feature", "spec out a
  feature", "create a feature spec", "write a feature specification", "plan a new feature",
  "document a feature idea", "let's design a feature", or "I have a feature idea". Offers two
  workflow styles: a conversational 7-phase interview that produces a date-prefixed spec in
  /docs/features/, or a template-first mode that expands a single-sentence description into a
  comprehensive spec using the project's canonical template with iterative refinement. If
  project-manager scaffolding is present, defer to project-manager:add-feature instead so the
  canonical CAP-ID workflow is used. After saving, automatically generates a visual diagram of the
  spec and offers to create an implementation plan. Use this proactively whenever a user describes a
  feature they want to build, even if they don't explicitly say "spec" or "specification".
---

# Add Feature Spec

Produce a thorough feature specification document saved to `/docs/features/`, using one of two
workflow styles selected in Phase 0.

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

---

## Phase 0 — Style Selection

Choose the workflow style before gathering any requirements:

- If the user invoked `/create-feature-spec`, or provided a single-sentence feature description
  and a canonical template exists at `docs/templates/FEATURE_SPECIFICATION.md`, use
  **Template-First Mode**.
- If the user invoked `/add-feature` or is describing a feature idea conversationally, default to
  **Conversational Mode**.
- If the signal is ambiguous, use `AskUserQuestion` to let the user pick:
  - **Conversational** — a guided 7-phase interview; best for ideas that need shaping
  - **Template-first** — expand a one-sentence description into the project's canonical template;
    best when the feature is already well understood

---

# Conversational Mode (7-Phase Interview)

Work through phases **in order**. Use `AskUserQuestion` for structured choices at each phase.
Briefly summarize what you captured after each phase before moving on — this catches misunderstandings
early and keeps the user engaged.

## Phase 1 — Feature Identity

Ask for the feature name and a crisp problem statement. The goal is a clear one-liner that could
appear in a changelog.

Use `AskUserQuestion` to confirm tone if unclear, but mostly ask via natural dialogue:
- What is the feature name?
- What problem does it solve, or what does it enable? (1-3 sentences)
- Is this user-facing, developer-facing, or internal/infrastructure?

## Phase 2 — Context & Motivation

Understand why this feature is being built and who requested it.

Ask:
- Who is requesting this? (e.g., user feedback, stakeholder ask, technical debt, competitive gap)
- What is the priority or urgency?
- Is there any background context, links, or related work to include?

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

## Phase 4 — User Stories & Personas

Define who uses this feature and what success looks like.

Ask:
- Who are the primary users/personas affected?
- What are the key user stories? (format: "As a [user], I want [action] so that [outcome]")
- What are the acceptance criteria — how will we know this is "done"?

Be specific about acceptance criteria. If the user gives vague ones ("it should work"), gently
push for something measurable or observable.

## Phase 5 — Technical Design

Draw on your Phase 3 codebase scan to ground this conversation. Suggest likely affected components
and ask the user to confirm or correct.

Ask:
- Which components, services, or systems need to be created or changed?
- Are there significant architectural decisions or constraints to document?
- Are there external dependencies, API integrations, or data migrations involved?

Your scan findings go into the "Affected Components" list. The user's answers populate
"Architecture Notes" and "Dependencies".

## Phase 6 — Out of Scope

Explicitly document what this feature will NOT include. This is one of the most valuable sections —
it prevents scope creep and aligns stakeholders.

Ask:
- What related things are explicitly out of scope for this feature?
- Are there related improvements that should be tracked separately?

If the user struggles here, prompt: "What would be a natural extension that we're consciously
deferring?" or "What might stakeholders assume is included that actually isn't?"

## Phase 7 — Risks & Open Questions

Surface unknowns that need resolution before or during implementation.

Ask:
- Are there open questions or decisions not yet made?
- What are the technical risks (complexity, performance, security, migration)?
- Are there blockers or dependencies on other teams or features?

## Generate the Spec (Conversational Mode)

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

# Template-First Mode (Single Sentence → Canonical Template)

Create a comprehensive feature specification from a single-sentence description, using the
template at `@docs/templates/FEATURE_SPECIFICATION.md`.

**Input**: The user provides a single sentence describing the new feature.

**Process**:

1. **Initial Analysis**:
   - Read `@docs/templates/FEATURE_SPECIFICATION.md` to understand the required structure
   - Parse the user's feature description to identify the core problem and proposed solution
   - Identify which sections of the template are most relevant (some may be optional based on feature scope)

2. **Gather Context** (use tools, don't ask yet):
   - Search the codebase for similar features using Glob/Grep
   - Identify relevant existing components, services, and data models
   - Understand current architecture patterns from CLAUDE.md and existing feature docs
   - Check for related API endpoints, UI components, database tables

3. **Ask Clarifying Questions**:
   - Use the `AskUserQuestion` tool to ask 3-4 strategic questions that will help you create a better spec
   - Focus on: scope boundaries, user personas, technical approach preferences, integration points
   - Example questions:
     - "What is the primary user problem this feature solves?"
     - "Should this integrate with existing features (e.g., workflows, companies)?"
     - "What level of technical detail do you want (high-level vs implementation-focused)?"
     - "Are there any known constraints or requirements?"

4. **Create Initial Draft**:
   - Generate a complete feature specification following the template structure
   - Fill in all REQUIRED sections with substantive content (not just placeholders)
   - Include optional sections where relevant
   - Use examples from the codebase to ground technical details
   - Follow the project's architecture conventions (e.g., hexagonal architecture, canonical
     models, API standards — as documented in CLAUDE.md and existing feature docs)
   - Match the quality and depth of the project's strongest existing feature spec

5. **Iterative Refinement**:
   - After presenting the initial draft, use `AskUserQuestion` to ask:
     - "What sections need more detail or clarification?"
     - "Are there any missing aspects or concerns not addressed?"
     - "Should any sections be expanded, condensed, or restructured?"
   - Continue refining based on feedback until the user approves
   - Each iteration should improve specific sections, not rewrite the entire document

6. **Quality Checklist** (before marking complete):
   - [ ] All REQUIRED sections have substantive content
   - [ ] User personas and user stories are clear and actionable
   - [ ] Architecture section shows how feature fits into existing system
   - [ ] Data model includes canonical models, database schema, validation rules
   - [ ] API specification has detailed endpoint examples with request/response
   - [ ] Implementation strategy broken into logical phases with deliverables
   - [ ] Success metrics are measurable and specific
   - [ ] Open questions and future enhancements are captured
   - [ ] Related documentation and ADRs are linked
   - [ ] Examples in appendices illustrate key use cases

7. **Output Location**:
   - Save the final specification to `/docs/features/{FEATURE_NAME}.md`
   - Use kebab-case for the filename (e.g., `real-time-chat.md`)
   - Ensure the filename matches the feature name in the document header

**Key Principles (Template-First Mode)**:
- **Iterative**: Use AskUserQuestion at each major decision point
- **Comprehensive**: Don't skip sections - if optional, explain why it's not applicable
- **Grounded**: Reference existing code, patterns, and components from the codebase
- **User-focused**: Write for multiple audiences (product, engineering, UX)
- **Actionable**: Implementation strategy should be clear enough for a developer to start work

**First Action in this mode**: Ask the user 3-4 clarifying questions using `AskUserQuestion` to understand:
1. The core problem and user need
2. Scope and boundaries (what's in vs out)
3. Integration requirements (which existing features/entities)
4. Technical preferences or constraints

Then proceed to create the specification iteratively.

---

## Post-Generation Actions

After saving the spec file (either mode), do both of the following:

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
- **Don't skip phases.** Each phase builds context for the next. The codebase scan (Phase 3
  conversational / Step 2 template-first) is especially important — use it actively rather than
  ignoring it.
- **Push back on vagueness.** If an acceptance criterion is unmeasurable or an out-of-scope item
  is ambiguous, press gently for something more concrete. A weak spec creates implementation debt.
- **Lean on the codebase scan.** Suggest specific affected files/components rather
  than speaking in abstractions. Ground the spec in what's actually there.
- **Be opinionated about quality.** The spec should be good enough that a developer could start
  implementation without ambiguity about scope or approach.
