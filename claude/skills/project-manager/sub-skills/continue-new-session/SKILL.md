---
name: continue-new-session
description: >
  Generate a copy-ready prompt that a fresh session (Claude Code, Codex, or Gemini) can paste in to
  immediately begin work on the next recommended action that was identified in this session's most
  recent recap. Reference-style — names file paths with short excerpts, no large inline content.
---

# Continue New Session

This command produces a single Markdown-formatted prompt that the user can copy into a brand new
session so an agent starts there exactly where this session left off — working on the next action
that was just recommended in this session's recap.

## Operating Principle

The current session is the source of truth. You have the conversation history in your context,
including any "next step" you recommended at the end of the previous assistant turn. Use that
directly. Do NOT re-derive a next action from project state when a recap-recommended action exists.

If, and only if, you cannot find a recommended next action in your own recent recap, fall back to
the project state derivation in the **Fallback** section below.

## Step 1 — Locate the recap-recommended next action

Scan your own most recent assistant turn (the one immediately preceding this user invocation) for:

- An explicit "next step" / "next" / "follow-up" recommendation in the recap
- An end-of-turn summary line of the form "Next: ..." or "Next up: ..." or "Recommended next: ..."
- A trailing bullet listing the action to take next session

Capture three things from that recommendation:

1. **Action verb + object** — e.g., "implement P2-T3 for `auth-flow`", "write unit tests for the
   plan-validator", "rebase `feat/x` onto `dev`".
2. **The plan/feature/task identifier** (if mentioned) — feature slug, plan path, CAP-ID, task ID.
3. **Any explicit follow-on guidance** — "use TDD", "spawn the security-reviewer first", "open a PR
   when done", etc.

If the previous turn had no recap, or the recap did not include a next action, jump to **Fallback**.

## Step 2 — Resolve file paths for context

For each identifier captured in Step 1, locate the relevant files **without reading their full
content** (the new session will read them itself):

- Feature spec → `docs/features/{slug}.md`
- Plan → `docs/plans/{slug}-plan.md`
- Active task → `docs/tasks/active/{slug}-p{N}-t{M}.md` (only if one already exists)
- Workflow pointers → `docs/workflow/FOCUS.md`, `docs/workflow/INDEX.md` (always include if they
  exist)

Verify each path exists. If a referenced path does not exist, note that fact in the prompt rather
than emitting a broken reference.

For each existing file, capture a 2–3 line excerpt: the first non-empty heading and the next 1–2
content lines. This is enough orientation for the new session without bloating the prompt.

## Step 3 — Emit the prompt

Print the prompt to chat inside a single fenced Markdown code block so the user can copy it as one
unit. Use the template below verbatim, substituting the captured values.

````markdown
# Session Handoff — Continue Work

You are starting a fresh session to continue a project that uses the **project-manager** skill
(`/continue-tasks` orchestration loop). The previous session recommended this next action:

> **{action verb + object from Step 1}**
> {one-line context if any explicit follow-on guidance was captured}

## Project pointers

- Workflow focus: `docs/workflow/FOCUS.md`
  > {excerpt}
- Workflow index: `docs/workflow/INDEX.md`
  > {excerpt}

## Work pointers

- Feature spec: `docs/features/{slug}.md`
  > {excerpt}
- Plan: `docs/plans/{slug}-plan.md`
  > {excerpt}
- Active task (if any): `docs/tasks/active/{slug}-p{N}-t{M}.md`
  > {excerpt}

## What to do

1. Read the pointers above in full.
2. {Imperative restatement of the recommended next action.}
3. Follow the project-manager skill conventions: only one active task file at a time, append a
   `## Completion` sentinel when done, never edit feature specs without `AskUserQuestion` user
   confirmation.
4. If the next action is to run the orchestration loop, invoke `/continue-tasks`. If it's a
   specific implementation step, do that step first and then run `/update-tasks`.

## Constraints

- Stay on the current branch unless the recap explicitly said to branch.
- Do not regenerate plans that already exist.
- Do not skip verification tasks.
````

Replace every `{...}` placeholder with the captured value, or omit the line if the value is
missing. Never emit a line with an unresolved `{placeholder}` in the final output.

After the code block, print a single short sentence directing the user to paste it into a new
session — for example: "Paste the block above into a new Claude Code, Codex, or Gemini session to
pick up where we left off."

Do not write the prompt to any file. Do not modify any project state. This command is read-only.

## Fallback — when there is no recap-recommended action

If Step 1 found no recap recommendation (e.g., the previous turn was purely a question, or this is
the first message of the session), tell the user so explicitly, then derive a substitute next action
from project state:

1. Read `docs/workflow/FOCUS.md` and use its `## Next Action` heading if present.
2. Otherwise, if `references/scripts/pm-next.ps1` exists, run it and use its top recommendation.
3. Otherwise, scan `docs/plans/*.md` for the first `todo` task in the lowest phase of the
   highest-priority approved feature with no dependency blockers.
4. If none of the above yields a candidate, print: "No recap recommendation found and no eligible
   next task exists. Run `/review-tasks` for a project snapshot or `/init-features` if specs are
   missing." Stop without emitting a prompt block.

When falling back, prefix the prompt's recommended-action line with `(derived from {source})` so the
new session understands the provenance.

## Output Contract

- Always exactly one fenced markdown code block containing the handoff prompt (unless the fallback
  reaches its terminal "no candidate" state).
- Never claim a file exists when it doesn't.
- Never embed the full contents of a spec, plan, or task — only short orientation excerpts.
- Never modify files in `docs/`.

## Related Commands

- `/continue-tasks` — the orchestration loop the new session will most often invoke
- `/iterate-tasks` — self-perpetuating subagent variant of this command; reuses Step 1's
  recap-reading primitive, then dispatches the next action as a fresh subagent and emits the
  next-next prompt automatically. Use it when you want the loop to keep advancing within the
  same session instead of paste-into-a-new-session.
- `/review-tasks` — read-only project snapshot the user can run instead if they want context
  before starting
- `/update-tasks` — reconcile active task files after the new session finishes a step
