# Backlog Templates

Exact contents for `backlog.md` and `backlog-archive.md`. Write these verbatim when bootstrapping
a new task store.

## `backlog.md` (starter)

```markdown
# Backlog

Managed by the `/what-next` skill. Tasks use area-scoped IDs (see `docs/what-next.md` for the
area map). Completed tasks are moved to `backlog-archive.md` — never edit IDs in place.

## Pending

- [ ] GEN-001: Define initial tasks for this project

## Conventions

- Check a box (`- [x]`) to mark a task done. `/what-next` will move it to the archive on the
  next run.
- Add tags inline with curly braces: `{priority: p1}`, `{security}`, `{blocks: AUTH-004}`.
- One task per line. Keep the line under 120 characters when possible.
```

## `backlog-archive.md` (starter)

```markdown
# Backlog Archive

Completed tasks, most recent date first. IDs are preserved; they are never reused.

<!-- entries will be appended here by /what-next -->
```

## Appending a completed task

When a task flips from `- [ ]` to `- [x]` in `backlog.md`:

1. Remove the line from `backlog.md`.
2. Find or create a `## YYYY-MM-DD` heading in `backlog-archive.md` (top of file after the intro,
   so the most recent day sits nearest the top).
3. Append the task line under that heading, preserving the `- [x]` checkbox, the ID, and any tags.
4. Add a trailing `{completed: YYYY-MM-DD}` tag.

Example archive entry:

```markdown
## 2026-04-21

- [x] AUTH-004: Refactor login middleware {priority: p1} {security} {completed: 2026-04-21}
- [x] UI-011: Fix button alignment on mobile {priority: p2} {completed: 2026-04-21}
```

## ID reservation

When generating new IDs:

1. Scan *both* `backlog.md` and `backlog-archive.md` for existing IDs with the target prefix.
2. Take `max(existing) + 1`, zero-padded to three digits.
3. If no existing ID of that prefix exists, start at `001`.

This guarantees no collisions even across long project lifetimes.

## Migrating an unfamiliar format

If the repo already has a `backlog.md` in a different format (prose paragraphs, Kanban tables,
etc.), AskUserQuestion before rewriting:

```
Question: "I found backlog.md but it doesn't use the checklist format /what-next expects.
How would you like to proceed?"
Options:
  - "Rewrite it into checklist format (I'll preserve all content)"
  - "Leave it alone and create backlog-what-next.md alongside"
  - "Cancel — I'll handle migration manually"
```

Never rewrite silently.
