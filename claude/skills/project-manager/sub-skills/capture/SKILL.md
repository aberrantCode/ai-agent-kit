---
name: capture
description: Front-door intake for bugs, chores, tech-debt, and ideas — captures every item as a backlog row. Infers type and priority. Atomically allocates monotonic `BL-*` ids. Triggers on `/pm-capture` and phrases like "capture this", "add to backlog", "log a bug/chore/idea".
---

# Capture

Single front door for intake. Every bug, chore, tech-debt item, and idea lands as a `BL-NNN` row in `docs/backlog.md`. Atomically allocates monotonic IDs (race-safe). Append-only; never commits.

**Prerequisite:** The project must have been initialized with `/init-project` (or equivalent manual scaffolding). Specifically, this skill assumes:

- `docs/backlog.md` — live backlog table
- `docs/backlog-archive.md` — completed items

If either is missing, stop and tell the user to run `/init-project` first (or that the repo hasn't adopted the intake lane).

---

## Phase 1 — Gather the Item

Check whether the invocation contains meaningful item text (the thing being captured).

If **no text** was provided, use `AskUserQuestion` to ask:

> "What do you want to capture? Describe the bug, chore, tech-debt, or idea. (A few sentences is enough.)"

After receiving text, summarize it back to the user to confirm you understood it correctly before proceeding.

---

## Phase 2 — Infer Type, Area, and Priority

Examine the text to infer:

- **Type** ∈ {`bug`, `chore`, `debt`, `idea`}
  - `bug` — a defect or regression
  - `chore` — mechanical, routine, or maintenance work
  - `debt` — refactoring, optimization, or technical-debt reduction
  - `idea` — new capability or exploratory work (captured as idea, not jumped to spec)

- **Area** — a short system area or component name (e.g., `ui`, `api`, `infra`, `db`, `auth`, `discovery`). If unclear, infer from context or ask via `AskUserQuestion`.

- **Priority** — one of `p0`, `p1`, `p2`, `p3`:
  - `p0` — blocking, critical
  - `p1` — high priority
  - `p2` — medium (default)
  - `p3` — low priority
  - Default to `p2` unless the text signals urgency or criticality.

**Important:** Do NOT triage the item into a lane (feature vs. chore) here. An `idea`-type row remains `type: idea` and is captured as-is. Lane triage happens at `/groom`. Do not jump a genuine idea straight to a spec file.

---

## Phase 3 — Atomic ID Allocation Under `docs/backlog.lock`

Acquire an advisory lock and compute the next monotonic id. Follow the **lease pattern** exactly:

### 3a — Check for an Existing Lock

Read `docs/backlog.lock` if it exists.

- **If it exists and `lease_expires_at` is in the future:** The lock is held. Stop and tell the user:
  > "Another capture is in progress (lock held until {{lease_expires_at}}). Please wait or contact {{claimed_by}} to release it."

- **If it exists but `lease_expires_at` is in the past:** The lock is expired and may be reclaimed. Proceed.

- **If it does not exist:** Proceed.

### 3b — Acquire the Lock

Write `docs/backlog.lock` with the following YAML frontmatter (reusing the task-lock pattern):

```yaml
---
task: "backlog-capture"
feature: "intake"
claimed_by: "{{agent-or-user}}"
claimed_at: "{{ISO 8601 TIMESTAMP}}"
lease_expires_at: "{{ISO 8601 TIMESTAMP, 2 minutes from now}}"
status: active
reason: "capture {{item-summary}}"
---
```

### 3c — Compute the Next ID (CRITICAL)

**Scan both files** to find the maximum id:

1. Read `docs/backlog.md` and extract all `BL-NNN` ids from the table (the ID column).
2. Read `docs/backlog-archive.md` and extract all `BL-NNN` ids from the table (the ID column).
3. Combine both sets and find `max(all_ids)`.
4. Increment by 1: `next_id = max + 1`. **If neither file has any `BL-*` id yet** (first-ever capture — the scaffolded backlog ships with zero live rows), start at `next_id = 1`.
5. Format as zero-padded 3-digit: `BL-{{next_id}}` (e.g., `BL-001`, `BL-042`, `BL-123`).

**Why both files?** Archiving completed rows to `backlog-archive.md` ensures their ids don't get recycled. Scanning only the live file would break this invariant.

### 3d — Append the New Row to `docs/backlog.md`

Append a single row to the table in `docs/backlog.md`:

```markdown
| {{BL-NNN}} | {{type}} | {{area}} | {{pri}} | open | {{item}} | |
```

- **ID:** The computed `BL-NNN`
- **Type:** `bug` / `chore` / `debt` / `idea` (inferred)
- **Area:** Short system area (inferred)
- **Pri:** `p0` / `p1` / `p2` / `p3` (inferred)
- **Status:** Always `open` (new items start here)
- **Item:** The captured text (sentence or two)
- **Link:** Empty (no link yet; triage and promotion fill this in)

### 3e — Release the Lock

Overwrite `docs/backlog.lock` with:

```yaml
---
task: "backlog-capture"
feature: "intake"
claimed_by: "{{agent-or-user}}"
claimed_at: "{{ISO 8601 TIMESTAMP}}"
lease_expires_at: "{{RELEASED TIMESTAMP}}"
status: released
reason: "capture {{BL-NNN}} completed"
---
```

Or delete the file entirely (either is acceptable).

---

## Phase 4 — Report and Do Not Commit

Tell the user:

> "✓ Captured as `{{BL-NNN}}` — {{type}}, {{area}}, {{pri}}.
>
> Next: Run `/pm-groom BL-NNN` to triage it into the feature or chore lane."

**Important:** Do NOT stage or commit. The user or orchestrator owns git. The row is now in `docs/backlog.md` and ready for triage.

---

## Completion Checklist

Verify before reporting done:

- [ ] `docs/backlog.md` exists (if not, user was directed to `/init-project`)
- [ ] Advisory lock acquired and released cleanly (no stale lock left behind)
- [ ] Next ID computed by scanning **both** `docs/backlog.md` **and** `docs/backlog-archive.md`
- [ ] New row appended to `docs/backlog.md` table with: `Status: open`, empty `Link` column
- [ ] Type ∈ {`bug`, `chore`, `debt`, `idea`} inferred from text
- [ ] Area inferred (e.g., `ui`, `api`, `infra`)
- [ ] Priority inferred; default `p2` unless text signals urgency
- [ ] User informed of the new `BL-NNN` id and next step (`/pm-groom`)
- [ ] **No commit made.** Row is live in the file; user owns git.
