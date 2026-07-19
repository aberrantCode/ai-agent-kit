---
name: spec-consistency-doc-refactoring-pattern
category: Foundations & Workflow
description: Use when resolving inconsistencies between design/spec documents and deployed reality, or repairing structural drift in large markdown docs (mangled backlogs, misaligned specs, redundant catalog fields) — atomic, scope-limited fixes that preserve intent and prose without a full re-architecture.
status: active
version: 2026-07-05
---

# Spec Consistency & Doc Refactoring Pattern

## When to use

When a review surfaces spec-vs-reality drift (a doc says one thing, the deployed system does another), when a large markdown doc (e.g. `backlog.md`) becomes structurally mangled, or when multiple source-of-truth (SoT) documents drift out of sync with each other. This is a documentation/spec surgery pattern, not a rewrite pattern.

## Method

1. **Keep the fix scoped to exactly the finding.** Don't expand a consistency fix into a re-architecture — e.g., resolving one deferred review finding should touch only what that finding covers, even if it's "the lighter half" of a related decision already made elsewhere. Resist the urge to "fix everything nearby while you're in there."
2. **Classify the fix before touching anything**: is this documentation-only (zero live/runtime effect — e.g. a commented-out placeholder) or does it require a code/config change too? Doc-only fixes can move faster and carry less review risk; don't conflate the two in one commit.
3. **Prefer line-oriented transformations over structural round-trips.** When editing YAML/config-adjacent docs, avoid parse-and-reserialize (YAML round-trip) approaches — they silently destroy comments and exact formatting. Make targeted line edits instead.
4. **Use standard markdown structures to encode relationships, not invented conventions.** Footnotes, example sections, and standard heading structures can signal semantic relationships (e.g., "this decision supersedes that one") without introducing a bespoke annotation syntax that future editors won't recognize.
5. **For structurally mangled docs** (body sections out of order, broken anchors, collapsed content): repair atomically in a single pass. Use anchor-based joining to guarantee a bijection between old and new anchor sets (nothing silently dropped or duplicated). When wrapping long lines, do it fence-aware: skip `|` tables, `#` headings, `---` rules, and inline code spans; only insert whitespace-only breaks in prose.
6. **Verify the repair, don't just eyeball it.** Run a word-multiset diff between old and new content (proves no prose was lost or altered, only reordered/reformatted) and check that every anchor referenced elsewhere in the repo still resolves.
7. **Apply the "derive, don't duplicate" principle** to catalogs and specs: if a field's value can be computed/derived from another canonical field, don't maintain both — this is usually the root cause of the drift you're being asked to fix. Also check for implicit contract conflicts (e.g., an enum definition in one doc doesn't match the enforcement gate that reads it elsewhere).
8. **When a new spec surface is added, update every SoT mirror in one coherent change**: the central spec section, any README/SKILL docstrings referencing it, the lint rule that enforces it (e.g. required STATUS_ENUMS or required-field sets), and an idempotent migration script if existing data needs to move to the new shape.
9. **Prove new lint rules with a negative test**: show the rule fails on the old/bad shape and passes after migration, before shipping the rule as enforced.
10. **Prefer atomic, single-commit changes** — they're trivially revertible if later evidence contradicts the choice made. Pair spec-consistency fixes with a design-review step before the PR when the fix touches a canonical decision, to catch intent misalignment early.

## Gotchas

- A commented-out placeholder with zero live effect is easy to mistake for "needs code changes too" — always check whether the fix is actually a live behavior change before scoping the PR.
- YAML round-tripping is the single most common way to accidentally destroy formatting/comments in a doc fix — default to line-oriented edits for anything hand-formatted.
- Redundant catalog fields usually indicate a missing "derive, don't duplicate" step upstream — fixing the immediate inconsistency without addressing the duplication just delays the next drift.
- Don't skip the word-multiset diff step on large structural repairs — it's the cheapest way to catch accidental prose loss before it ships.

## Diagram

[View diagram](diagram.html)
