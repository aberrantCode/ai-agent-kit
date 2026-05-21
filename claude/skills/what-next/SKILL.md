---
name: what-next
description: >
  Decide what the agent should do next in the current repository. Use this skill whenever the user
  asks "what next?", "what should I work on?", "where did we leave off?", "what's on the backlog?",
  "help me pick the next task", or invokes /what-next or /what-next-update. Also trigger proactively
  when the user returns to a project after a break and wants direction. The skill inspects repo
  structure, detects the project-management framework in use, reads or builds a backlog, prioritises
  pending work using a weighted heuristic, and — after the user picks from the top three —
  hands the chosen task off to the right specialist agent. All user interaction goes through
  AskUserQuestion; results are cached to docs/what-next.md so subsequent runs skip re-analysis.
requires: []
---

# What Next?

Pick the right next action for any repository. The skill is **universal** — it makes no
assumption about language, framework, or team process, and adapts to whatever project-management
convention (if any) the repo already uses.

The guiding principles:

- **Never surprise the user.** Every branching decision goes through `AskUserQuestion` — never
  free-form prose prompts. The user can always see the choices and pick "Other".
- **Delegate, don't compete.** If the repo already has a project-management system (the
  `project-manager` skill's `docs/features/` + `docs/plans/` convention, a Makefile target, a
  `.github/ISSUE_TEMPLATE/`, etc.), work *with* it. Do not create a parallel `backlog.md` on top of
  an existing scheme.
- **Cache aggressively, verify cheaply.** A repo-wide analysis is expensive; the cached
  `docs/what-next.md` lets subsequent runs be sub-second. A fingerprint of key files tells us in
  milliseconds whether the cache is stale.

---

## Master Decision Flow

On every invocation, walk the following decision tree top-to-bottom. Stop at the first terminal
action.

```
1. Does docs/what-next.md exist?
   ├─ No  → go to Step 2 (cold analysis)
   └─ Yes → fingerprint check
          ├─ stale → offer refresh (Step 2 or § Update Flow)
          └─ fresh → load cached metadata, jump to Step 6 (prioritise + pick)

2. Analyse repo structure (Step 2)
3. Detect PM framework (Step 3)
4. Locate / build the task store (Step 4)
5. Collect tasks (Step 5)
6. Prioritise + pick top three (Step 6)
7. AskUserQuestion: which of the top three? (Step 7)
8. Spawn the appropriate agent for the chosen task (Step 8)
9. Persist/refresh docs/what-next.md (Step 9)
```

---

## Step 1 — Cache Check

Read `docs/what-next.md` if it exists. The file schema is defined in
`references/what-next-schema.md`.

A cached file contains a `fingerprints:` block listing SHA-256 hashes of the key files it analysed
last time. Recompute those hashes now and compare:

- **Any hash changed or any tracked file is missing** → cache is stale. AskUserQuestion whether
  to refresh now or trust the cache for this run.
- **All hashes match** → cache is fresh. Load the stored PM framework, areas, and task-store
  locations, then jump to Step 5 (collecting tasks).

If the file does not exist, continue to Step 2.

Full fingerprint algorithm: see `references/fingerprint.md`.

---

## Step 2 — Analyse Repo Structure

Run these inspections (parallel where possible):

1. **Top-level layout** — list the first two levels of directories. Skip hidden dirs and common
   noise (`node_modules`, `.venv`, `dist`, `build`, `target`, `.next`).
2. **Stack detection** — look for anchor files: `package.json`, `pyproject.toml`, `go.mod`,
   `Cargo.toml`, `pom.xml`, `*.csproj`, `Gemfile`, `composer.json`, `Dockerfile`, `docker-compose.yml`.
   Record all stacks found.
3. **Monorepo signals** — `pnpm-workspace.yaml`, `lerna.json`, `turbo.json`, `nx.json`, multiple
   `package.json` under `packages/` or `apps/`, Cargo `[workspace]`, Go `work.sum`.
4. **Areas for task-ID prefixes** — enumerate meaningful top-level or `src/*` folders. Convert
   each to a 2–4-letter prefix (`src/auth` → `AUTH`, `packages/ui` → `UI`,
   `api/payments` → `PAY`). See `references/area-inference.md` for the heuristic.
5. **Infrastructure gaps worth flagging** — quick existence checks that affect *task sequencing*
   (not a full lint pass; only things that would change what the user should do next):
   - No test runner wired up (no `scripts.test` in `package.json`, no `pytest` config, no `go test`
     targets in a Makefile, etc.) → observation: "no test runner configured".
   - No CI config (`.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`) → observation:
     "no CI — manual validation only".
   - No linter/formatter config when one is conventional for the stack → observation: "no
     lint/format config".
   Record any hits as a short `observations:` list in `docs/what-next.md`. Step 7 will surface
   one of these as a hint next to the top-three prompt when relevant.

Record everything in memory; it will be persisted to `docs/what-next.md` at Step 9.

---

## Step 3 — Detect the PM Framework

Scan file-based markers in this order. The **first** match wins unless otherwise noted.

| Priority | Marker                                                    | Framework tag        | Action                                  |
|----------|-----------------------------------------------------------|----------------------|-----------------------------------------|
| 1        | `docs/features/` has `.md` files AND `docs/plans/` exists | `project-manager`    | **Delegate to /continue-tasks** (below) |
| 2        | `docs/features/` exists but plans are missing             | `project-manager-partial` | Suggest `/reinit` or `/continue-tasks` |
| 3        | `docs/INITIAL_PROMPT.md` exists                           | `project-manager-seed`    | Suggest `/continue-tasks`              |
| 4        | `backlog.md` or `BACKLOG.md` at repo root                 | `backlog-md`         | Read as primary task store              |
| 5        | `tasks.md` or `TASKS.md`                                  | `tasks-md`           | Read as primary task store              |
| 6        | `plan.md` or `PLAN.md`                                    | `plan-md`            | Read; backlog items may be implicit     |
| 7        | `TODO.md` or `todo.md`                                    | `todo-md`            | Read as primary task store              |
| 8        | `.github/ISSUE_TEMPLATE/` exists                          | `github-issues`      | Record but do NOT fetch issues (file-based detection only). Note in what-next.md. |
| 9        | `CHANGELOG.md` with an `[Unreleased]` section             | `changelog-driven`   | Unreleased items may hint at direction  |
| 10       | None of the above                                         | `none`               | No PM artefacts present                 |

### Important: Delegation Rule (Priority 1)

If the framework is `project-manager`, operate *on top of* project-manager's state — do not create
a parallel `backlog.md` and do not invent area-scoped IDs. The `project-manager` skill is the
authoritative, battle-tested workflow for execution; `/what-next` makes it easier to choose *which*
task to hand off next.

Flow:

1. Read every `docs/plans/*.md`. Parse each phase table row-by-row. Classify by the `Status:`
   column (`todo` | `in-progress` | `done` | `blocked`). Record totals per status.
2. Apply Step 6's weighted heuristic to the `todo` tasks, using the plan's phase order + priority
   + any `{blocks: ...}` tags to compute scores. Take the top 3 concrete todos (across all plans).
   These tasks already have IDs like `auth P1-T3` — reuse them verbatim.
3. Compose the Step 7 `AskUserQuestion` with these five options (in order):
   - `{top-1 ID}: {short title}` — "{reason it ranked #1}"
   - `{top-2 ID}: {short title}` — "{reason}"
   - `{top-3 ID}: {short title}` — "{reason}"
   - `Run /review-tasks for a full snapshot` — read-only PM status report
   - `Invoke /continue-tasks to run the full orchestration loop` — hand control to project-manager
4. On user choice:
   - **Top-N task** → mark that row `in-progress` in its plan file (same mutation project-manager
     would have made), then hand off to the right specialist agent per Step 8. Do not build a
     backlog.md.
   - **/review-tasks** → print the structured report (feature count, plan count, per-feature
     status table) without spawning anything.
   - **/continue-tasks** → print a one-line confirmation recommending the user invoke it.
     Do not auto-spawn the project-manager orchestration loop from inside `/what-next`.
5. Record `pm_framework: project-manager` in `docs/what-next.md`.

Why this shape: just saying "go run /continue-tasks" hides the decision the user is actually
making. Surfacing the top-3 todos first lets them prioritise cheaply, then chose the execution
path (direct specialist vs. full PM loop). The "no competing backlog" invariant is preserved —
the plans remain the single source of truth and mutation happens in place.

---

## Step 4 — Locate / Build the Task Store

This step only runs for frameworks 4–9 from Step 3 (i.e., not `project-manager`).

### Case A — An existing task file was found

Read it. Parse tasks as checklist items: `- [ ] ID: description` or `- [x] ID: description`. If the
file uses a different format (plain bullets, headings), normalise it in memory but do not rewrite
the file yet — that happens only if the user approves.

### Case B — No task file found, no tasks knowable yet

AskUserQuestion: "No task store was found. How would you like to proceed?"

Options (exactly these four, in this order):

1. **Run /project-manager setup** — "Bootstrap the full project-manager orchestration (feature
   specs, plans, tasks). Best for larger initiatives."
2. **Create a backlog.md** (Recommended) — "Lightweight single-file checklist. I'll create
   backlog.md with area-scoped IDs based on your repo structure."
3. **Run a repo-wide code analysis** — "Spawn code-review, security, architecture, and
   test-coverage agents; turn their findings into backlog items."
4. **I'll tell you the tasks myself** — "Open an input dialog so you can list tasks; I'll seed
   backlog.md from them."

Branch on the answer:

- **Option 1** → hand off to the `project-manager` skill (`/project-manager` or
  `/continue-tasks`). Write `pm_framework: project-manager (bootstrapped by what-next)` to the cache
  and stop.
- **Option 2** → generate `backlog.md` at repo root using `references/backlog-templates.md`.
  Seed with one placeholder task (`- [ ] GEN-001: Define initial tasks for this project`) so the
  file is immediately valid, then continue to Step 5.
- **Option 3** → run the code-analysis flow below.
- **Option 4** → use `AskUserQuestion` with a free-text note field and create one backlog item
  per task the user supplies.

### Code-analysis flow (Option 3)

Spawn **four agents in parallel** via the Agent tool:

| Agent | Purpose | Findings become |
|-------|---------|-----------------|
| `code-reviewer` | Quality, smells, duplication, untested areas | `- [ ] {AREA}-NNN: {finding}` |
| `security-reviewer` | OWASP / secrets / unsafe crypto | `- [ ] SEC-NNN: {finding}` (always `SEC` prefix) |
| `architect` | Structural debt, coupling, missing abstractions | `- [ ] ARCH-NNN: {finding}` |
| `tdd-guide` | Test-coverage gaps (read-only audit) | `- [ ] TEST-NNN: {finding}` |

Each agent must return a short punch-list (<25 items) in the format:
`- {severity}: {file:line}: {one-line description}`

Merge their output into `backlog.md` with area-scoped IDs. Start numbering at 001 per area.

After seeding, AskUserQuestion whether to trim the list (many findings may be noise) or accept
all before continuing.

---

## Step 5 — Collect Tasks

Read the primary task store and classify each item by status:

- `- [x] ...` → **completed** → move to `backlog-archive.md` (see Step 9's archive rule)
- `- [ ] ... in-progress` or `🔄` marker → **in-progress**
- `- [ ] ... blocked` or contains `blocked by:` → **blocked**
- `- [ ] ...` otherwise → **pending**

If the total pending count is zero (everything is done or archived), AskUserQuestion: "The backlog
is empty. Run the code-analysis flow again, add tasks manually, or stop?" — using the same
options as Step 4 Case B.

---

## Step 6 — Prioritise

Apply the weighted heuristic from `references/priority-weights.md`. Summary of the default weights:

| Signal                                                    | Weight |
|-----------------------------------------------------------|-------:|
| Task blocks one or more other tasks                       |    +40 |
| Task tagged `security` or `build-breaking`                |    +30 |
| Task targets code with failing tests                       |    +25 |
| Task is already `in-progress`                             |    +20 |
| Explicit `priority: p1` in frontmatter or line tag         |    +15 |
| Explicit `priority: p2`                                   |     +5 |
| Age in days (log-scaled)                                   |     +3 |
| Explicit `priority: p3`                                   |     -5 |

Sort descending; take the top three. If fewer than three tasks are pending, show whatever exists.

Tie-breakers (in order): explicit priority, fewer dependencies, shorter description.

The weights are **defaults** — if the cached `what-next.md` overrides them in a
`priority_weights:` block, use those.

---

## Step 7 — Present Top Three via AskUserQuestion

Always use the `AskUserQuestion` tool. Never print the question as prose.

If Step 2 recorded any `observations:` (no test runner, no CI, etc.), include the most relevant
one as a **single-sentence hint above the question text**, phrased as an FYI, not a new option.
Example: *"FYI no test runner is configured — some of these tasks may need test setup first."*
One hint maximum — more than that becomes noise. Skip the hint if all observations are unrelated
to the top-three tasks.

```
AskUserQuestion(
  questions: [{
    question: "Which task should we tackle next?",
    header: "Next task",
    options: [
      { label: "{ID-1}: {short title}",
        description: "{one-line reason this ranked #1 — e.g., blocks 3 other tasks}" },
      { label: "{ID-2}: {short title}",
        description: "{reason ranked #2}" },
      { label: "{ID-3}: {short title}",
        description: "{reason ranked #3}" },
      { label: "Show me the full backlog",
        description: "Dump the sorted pending list so I can pick something else" }
    ]
  }]
)
```

If the user picks "Show me the full backlog", print the sorted pending list and ask again with the
same structure (now choosing from up to 10 options).

---

## Step 8 — Hand Off to the Right Agent

Classify the chosen task by the keywords in its description, then map to an agent using the table
below (this mirrors `project-manager`'s convention for consistency):

| Keywords / tags in task                                | Agent type                |
|--------------------------------------------------------|---------------------------|
| `architecture`, `design`, `refactor-plan`              | `architect`               |
| `plan`, `spec`, `breakdown`                            | `planner`                 |
| `feature`, `implement`, `add`, `build`, `api endpoint` | `tdd-guide`               |
| `review`, `quality`                                    | `code-reviewer`           |
| `security`, `SEC-`                                     | `security-reviewer`       |
| `build`, `types`, `tsc`, `compile error`               | `build-error-resolver`    |
| `e2e`, `playwright`, `end-to-end`                      | `e2e-runner`              |
| `docs`, `readme`, `documentation`                      | `doc-updater`             |
| `cleanup`, `dead code`, `knip`                         | `refactor-cleaner`        |
| anything else                                          | `general-purpose`         |

Before spawning:

1. Mark the task as in-progress in `backlog.md` by appending `(in-progress)` to its line.
2. Record `current_task: {ID}` in `docs/what-next.md` so a later run can resume cleanly.

Spawn the agent with a self-contained briefing: the task ID, description, surrounding context from
the repo (relevant file paths, stack info, any linked tasks), and instructions to return a summary
when done. Do not assume the agent can see the conversation.

When the agent returns: update the checkbox to `- [x]` in `backlog.md` and move the completed item
to `backlog-archive.md` per the archive rule.

---

## Step 9 — Persist / Refresh docs/what-next.md

After Steps 2–6 complete, write `docs/what-next.md` with the schema from
`references/what-next-schema.md`. Key sections:

- `generated`: ISO date
- `pm_framework`: detected framework tag
- `areas`: map of `PREFIX → folder path`
- `task_store`: primary file path (e.g., `backlog.md`, or `docs/plans/` for project-manager)
- `fingerprints`: SHA-256 of each tracked file
- `priority_weights`: optional overrides
- `current_task`: set when Step 8 spawns an agent; cleared on completion

### Archive rule (backlog lifecycle)

When a task flips from `- [ ]` to `- [x]`:

1. Remove the line from `backlog.md`.
2. Append it to `backlog-archive.md` under a `## {YYYY-MM-DD}` heading (create the heading if today
   doesn't yet exist).
3. Preserve the original ID — IDs are monotonic per area and never reused.

This keeps `backlog.md` focused on pending work (short, easy to read) while preserving audit
history in `backlog-archive.md`.

---

## Update Flow (`/what-next update` / `/what-next-update`)

This is the explicit refresh path for requirement #12. Treat it as Steps 2–9 with these
differences:

- Always re-run the repo analysis even if fingerprints match.
- Reconcile the cached backlog against the current repo: if referenced files have been deleted or
  renamed, mark those tasks as `stale` (not `done`) and AskUserQuestion whether to close or
  rewrite them.
- After refresh, print a short diff summary ("Areas changed: + MOBILE; Tasks added: 4; Archived: 2")
  and proceed to Step 6 (prioritise) so the user can immediately pick next work.

---

## Guardrails

- **Never commit to `dev` or `main` directly.** When creating `backlog.md`, `backlog-archive.md`,
  or `docs/what-next.md`, stage the files but do not commit. The user owns the commit decision.
- **Never delete task history.** Completed tasks move to `backlog-archive.md`, never discarded.
- **Never silently rewrite an existing `backlog.md`.** If the format is unfamiliar, AskUserQuestion
  before normalising.
- **Never fetch from external systems.** `github-issues`, Jira, Linear, etc. are recorded in
  `docs/what-next.md` as references only — file-based detection only per design.

---

## Reference files

Read these lazily, only when the relevant decision branch fires:

- `references/fingerprint.md` — exact algorithm for cache-freshness hashing.
- `references/area-inference.md` — heuristics for converting folder names to 2–4-letter
  prefixes, including collision handling.
- `references/priority-weights.md` — full weight table, worked examples, how to tune via
  `docs/what-next.md`.
- `references/backlog-templates.md` — starter `backlog.md` and `backlog-archive.md` contents.
- `references/what-next-schema.md` — full schema of the `docs/what-next.md` cache file.

## Supporting visuals

- [Decision flow](diagram.html) — master 9-step pipeline (Steps 1–9 above).
- [Solution architecture](diagrams/solution.html) — components, runtime state, and invariants.
- [Feature matrix](diagrams/features.html) — capabilities grouped by domain, with iter-2 deltas highlighted.
- [Development plan](diagrams/plan.html) — iteration history + proposed iteration 3+ work.

## Evaluation harness

Any change to this file or `references/*.md` should be re-graded before shipping.
See [evals/README.md](evals/README.md) for the 7-step loop
(`setup_iteration.py` → spawn subagents → `save_timing.py` → `grade.py` →
`migrate_layout.py` → aggregate → review viewer). Past benchmarks are kept in
`evals/benchmarks/`.
