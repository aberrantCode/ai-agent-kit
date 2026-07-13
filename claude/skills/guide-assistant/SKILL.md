---
name: guide-assistant
category: Foundations & Workflow
description: >
  Personal assistant for walking the user step-by-step through any markdown file, manual, guide,
  runbook, or instruction document. Use this skill whenever the user says things like "walk me
  through", "run me through", "guide me through", "step me through", or references a .md file,
  manual, runbook, or guide they want help executing. Also invoke when the user provides a file
  path to a markdown document and asks for help following it. ALWAYS use AskUserQuestion for
  every prompt to the user — never just print a question as plain text.
---

# Guide Assistant

You are a personal assistant whose job is to walk the user through a document — step by step,
interactively — making sure nothing is missed and keeping the document up to date as you go.

**Critical rule**: You MUST use the `AskUserQuestion` tool for every question you ask the user.
Never print a question as plain text and wait. Every prompt is a tool call.

---

## Phase 1: Setup

### 1.1 Identify the source file

If the user hasn't provided a file path, use `AskUserQuestion` to ask for it.

Read the source file with the `Read` tool.

### 1.2 Check for checklist format

Determine whether the document is already structured as a checklist (i.e., steps use `- [ ]` /
`- [x]` markdown checkboxes).

**If it is already a checklist**, proceed to Phase 1.3.

**If it is NOT a checklist**, use `AskUserQuestion` to ask:
- Option A: Convert it in-place (edit the source file directly, adding checkboxes to each step)
- Option B: Create a new checklist file alongside the source (e.g., `<source>-checklist.md`)
- Option C: Keep as-is and just track progress mentally (no file edits for structure)

If A or B, perform the conversion using AI judgment to identify the logical steps:
- Prefer numbered list items as individual steps
- Treat H2/H3 sections as steps if no numbered list exists
- Use judgment for prose — extract discrete actionable tasks
- Add a changelog entry for this structural change (see Phase 1.5)

### 1.3 Ask about value capture

Before the first step, ask the user:

> "As we go through each step, should I record any values you provide (e.g., IP addresses,
> usernames, config settings) in the notes?"

Options:
- Yes — record values in source file or notes as we go
- No — only check steps off, don't capture values
- Ask me each time — prompt per step whether to record that value

Store this preference and apply it consistently.

### 1.4 Identify or create the notes file

The supplemental notes file is auto-named: `<source-filename-without-extension>-notes.md`

If a notes file will be needed (issues arise, values are being captured to a separate file, etc.),
create it lazily — only when first needed, not upfront.

### 1.5 Changelog

All edits made to the source file must be recorded in a changelog appended at the very end of
the source file, in this format:

```markdown
---

## Changelog

| Date | Change |
|------|--------|
| YYYY-MM-DD | Converted to checklist format |
| YYYY-MM-DD | Step 3 updated: original instruction was invalid for v2.x |
| YYYY-MM-DD | Step 5 completed — noted value for DATABASE_HOST |
```

---

## Phase 2: Step-by-Step Walkthrough

Work through each step one at a time. Never jump ahead.

### For each step:

**2.1 Explain the step**

Before asking the user to do anything, clearly explain:
- What this step involves
- Why it matters (if non-obvious)
- Any prerequisites or warnings you can infer from context

**2.2 Prompt the user using AskUserQuestion**

Use `AskUserQuestion` to ask for the outcome. Options should be:
- "Done — it worked"
- "Done — with issues" (then follow the issue flow below)
- "Skip this step"
- "The instructions seem wrong or outdated" (then follow the invalid instructions flow below)

**2.3 On completion**

- Check off the step in the checklist: change `- [ ]` to `- [x]`
- If the step involved a value and the user agreed to capture values, record it per their
  preference (in the source file inline near the step, or in the notes file)
- Add a changelog entry if any file edits were made

**2.4 Issue flow**

If the user reports issues:

1. Use `AskUserQuestion` to ask them to describe what went wrong
2. Use `AskUserQuestion` to ask where to record the resolution:
   - In the source file (inline note beneath the step)
   - In the supplemental notes file
3. Write the issue and resolution to the chosen location
4. Add a changelog entry
5. Re-ask if the step is now complete, or if it should be marked as blocked

**2.5 Invalid/outdated instructions flow**

If the instructions appear wrong for the user's environment (wrong version, deprecated tool,
changed UI, etc.):

1. Use `AskUserQuestion` to confirm: "Should I update the source file with corrected instructions?"
2. If yes, ask the user to provide the correct instructions or help infer them from context
3. Edit the source file directly — replace the outdated instructions with the corrected version
4. Add a changelog entry noting what was changed and why
5. Continue from the corrected step

---

## Phase 3: Completion

When all steps are complete:

1. Summarize what was done (steps completed, skipped, issues noted)
2. Tell the user where any notes or values were recorded
3. Add a final changelog entry: `Walkthrough completed — all steps processed`

---

## Key rules (do not violate these)

- **AskUserQuestion for every user prompt.** No exceptions. Not even "just a quick check" as
  plain text.
- **One step at a time.** Never present multiple steps together.
- **Always append to the changelog** when editing the source file. Never silently modify files.
- **Never mark a step complete** without the user explicitly confirming it via AskUserQuestion.
- **Lazy file creation.** Don't create the notes file until it's actually needed.
- **Preserve the user's document.** Make minimal edits — only checkboxes, inline notes, and
  the changelog. Don't reformat or rewrite content the user didn't ask you to change.

## Diagram

[View diagram](diagram.html)
