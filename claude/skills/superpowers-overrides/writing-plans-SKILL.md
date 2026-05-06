---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## CRITICAL: Documentation Location

**Plans are NEVER saved to `docs/superpowers/` or any path containing "superpowers".**

Plans follow the project's existing documentation conventions. Detect where similar docs are stored (docs/plans/, docs/features/, etc.) and save there. If no convention exists, prompt the user for location preference, defaulting to `docs/plans/`.

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

**Plan Location Detection:**
Plans are saved to the appropriate location based on project conventions:

1. **Check for existing docs structure** — Do `docs/plans/`, `docs/features/`, or similar directories exist?
2. **Follow repo pattern** — If `docs/plans/` exists → save there. If `docs/features/` exists → save there.
3. **Ask user if ambiguous** — If multiple valid locations exist or no clear convention → ask where to save
4. **Default location** — `docs/plans/` is the default if no convention is detected

**Example locations (depending on repo structure):**
- `docs/plans/YYYY-MM-DD-<feature-name>.md` (project uses dedicated plans directory)
- `docs/features/<feature-name>.md` (project keeps features and plans together)
- `docs/YYYY-MM-DD-<feature-name>.md` (minimal structure, all docs in docs/ root)
- User-specified location (if no clear convention)

## Plan Location Detection Algorithm

Before saving the plan, detect where it should go based on project conventions:

```
1. Check if docs/plans/ exists
   ├─ YES: Use docs/plans/
   │  └─ Save as: docs/plans/YYYY-MM-DD-<feature-name>.md
   │
   └─ NO: Continue to step 2

2. Check if docs/features/ exists
   ├─ YES: Use docs/features/
   │  └─ Save as: docs/features/<feature-name>.md or docs/features/plan-<feature-name>.md
   │
   └─ NO: Continue to step 3

3. Check for other docs directories (docs/requirements/, docs/specs/)
   ├─ YES: Ask user which location makes sense for plans
   │
   └─ NO: Continue to step 4

4. If docs/ exists but no clear convention
   ├─ Ask user: "Where should I save the plan?"
   │  - Suggest: docs/plans/ (default)
   │  - Suggest: docs/features/
   │  - Allow: custom path
   │
   └─ NO docs/ directory: Suggest creating docs/plans/ and ask user to confirm
```

**When prompting the user:**
- Show detected directories so user understands the options
- Make a recommendation based on common patterns
- Always confirm location before saving

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

After saving the plan, offer execution choice (always reference the actual location where plan was saved):

**"Plan complete and saved to `<detected-or-chosen-location>/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review
- Will reference plan from actual location

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
- Will reference plan from actual location
