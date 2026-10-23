---
name: sm-handoff
description: >
  Sub-skill of `session-manager`. Hand off open work to a fresh session — "continue in a new
  session", "spawn a new terminal and keep going", "hand this off", "open a new window and work
  through those items", "go do all that in a new session", "/handoff". Writes a self-contained,
  claim-tagged handoff prompt (state established, dead ends, tasks in dependency order, hard
  constraints, delegation, model choice) in launch mode (default; hands the file to dispatch),
  scope mode ("/dispatch-session-prompt"), copy mode (copy-ready prompt for Claude, Codex or
  Gemini; "/continue-new-session"; launches nothing) or chain mode (self-similar batch handoff for
  a large migration split across many sessions). Formerly `session-handoff/handoff`,
  `continue-new-session` and `recursive-batch-handoff`.
---

# handoff — write the prompt for the next session

Turn the open work of the conversation you are in into a prompt a fresh session can execute, then
(depending on mode) hand that file to [`dispatch`](../dispatch/SKILL.md) or print it.

The value is not the terminal spawn. It is that the new session starts with **no conversation
history at all**. Everything you learned by doing the work — the counts you verified, the paths you
fixed, the dead ends — is invisible to it unless you write it down. A prompt that says "continue
where we left off" produces an agent that re-derives what you already know, and often re-derives
it wrong. Most of your effort belongs in capturing state, not describing tasks.

This sub-skill **writes** the prompt. Creating the worktree, launching, and verifying the launch
belong to `dispatch`; post-merge cleanup to [`retire`](../retire/SKILL.md); the delegation
scoreboard to [`delegation-ledger`](../delegation-ledger/SKILL.md). Reference them; do not
re-document them. For the state-file convention a copy or chain prompt may point at, see
[`checkpoint`](../checkpoint/SKILL.md).

## Modes

| Mode | Invoked by | Scope comes from | Output | Launches? |
|---|---|---|---|---|
| **launch** (default) | `/handoff` | recovered from this conversation | prompt file under `docs/PROMPTS/` | yes, via `dispatch` |
| **scope** | `/dispatch-session-prompt <task>` | the invocation's arguments | prompt file under `docs/PROMPTS/` | yes, via `dispatch` |
| **copy** | `/continue-new-session` | this session's latest recap | one fenced block printed to chat | **never** |
| **chain** | "split this migration across sessions", batch/recursive handoff | a discovery command | self-similar prompt file | yes (via `dispatch`) or printed, per the user |

Launch and scope share every step; only how Step 1 is satisfied differs. Copy and chain have their
own sections below but reuse the claim-tagging and section rules.

## When you have nothing to hand off

If your last response had no decision list, or every item was informational rather than
actionable, say so and stop. Do not manufacture tasks to fill a prompt; ask the user what the new
session should do. (Scope mode: this applies only if the supplied scope itself is empty or purely
informational.)

## Heavy context: offer, never start

When context is getting heavy (long transcript, repeated compaction, slowing quality), offer a
handoff in **one sentence** ("Context is getting heavy — want me to hand this off to a fresh
session?") and wait. Never start a handoff automatically; the user decides.

## Claim tagging (all modes)

Per the [`claim-discipline`](../../../claim-discipline/SKILL.md) skill, tag every state claim in
the prompt:

- `[V]` — verified **this session** by a tool call you can name (a grep count, a test run, a
  `git log`). Re-run a cheap check before tagging if you are unsure.
- `[?]` — recalled, inferred, or carried over from earlier context; the new session must verify it
  before relying on it.

An untagged state claim is a defect. Every number in "State already established" must be `[V]` or
explicitly `[?]` — a confidently wrong count sends the new session down a false path with no one
there to catch it.

**Self-check before Step 4 (this rule is widely violated — a `handoff-tuner` run on 2026-10-23 found
76 of 92 prompts carried at least one untagged state claim):** scan the State section line by line.
Every bullet that states a count, a path, an id, a SHA, or a PR number must carry a `[V]` or `[?]`.
If a line has a number or a backticked token and no tag, it is a defect — tag it or delete it.

## Step 1 — Recover the items (launch / scope)

**Launch mode:** take the numbered decision list from your most recent response. Resolve each item
into a concrete instruction using the recommendation you already gave. The user asking for a
handoff is usually accepting your recommendations wholesale; if an item genuinely has no default
and the answer changes the work, use `AskUserQuestion` to settle it before writing the prompt — an
unattended session cannot ask.

Drop items that are questions about the handoff itself ("should the new session self-merge?") —
resolve them here and encode the answer as a constraint.

**Scope mode:** skip recovery. There may be no prior decision list, and if one exists it is not the
source of truth. Parse the supplied argument/message into the same shape (an ordered list of
concrete instructions), resolving ambiguity via `AskUserQuestion` under the same rule, and apply
the same drop-questions-about-the-handoff rule. Then continue at Step 2.

## Step 2 — Order the tasks by dependency

Sequence matters more than completeness. A task that regenerates data invalidates the reviews of
whatever ran before it; a task that fixes a rule must land before anything re-runs that rule, or
the run reproduces the bug you just fixed. For each pair ask: does doing B before A waste A?

State the ordering rationale in the prompt, briefly. An agent that understands *why* task 1
precedes task 2 holds the line when task 2 looks tempting; one told only the order reorders it the
moment something blocks.

## Step 3 — Write the prompt file

Write to `docs/PROMPTS/<YYYY-MM-DD>-<short-slug>.md` **in the main checkout, never inside the
worktree.** A prompt in the worktree becomes part of the branch's diff, gets reviewed as if it were
a deliverable, and needs its own commit to remove. In the main checkout the branch stays clean and
retiring the prompt is a file deletion.

The worktree is created by `dispatch` (see
[`dispatch/scripts/new-task-worktree.ps1`](../dispatch/scripts/new-task-worktree.ps1)) before the
session starts. Tell the new session, explicitly, that its worktree and branch **already exist**
and it should work there rather than create another — otherwise a session that reads the repo's
worktree convention will dutifully create a second one and split its work across two trees.

> **Absolute script paths.** Any script reference you copy into the generated prompt (e.g. the
> delegation scripts below) must be written as the resolved absolute path
> (`~/.claude/skills/session-manager/sub-skills/<sibling>/scripts/<name>.ps1` when installed
> globally). Never emit a bare `scripts/…` path: the receiving session resolves it against *its
> own* repo root, where the script does not exist, and reads the miss as "never scaffolded."

### Required frontmatter

Every generated prompt opens with a YAML frontmatter block — this is also the input `dispatch`
reads for the worktree/launch call, so it has to exist before Step 4, not be added after:

```yaml
---
handoff_id: <short-stable-id, e.g. d1-corr-26a>
title: <one-line title>
model: <pinned model id, see "Choosing the model" below>
base_branch: <usually dev>
branch: <type/slug>
repo: <absolute repo path>
---
```

`handoff_id` is the join key the [registry](references/handoff-registry.md) correlates this
handoff on — generate it once here (short, stable, grep-friendly; collisions are cheap to avoid
since you control the slug) and reuse it everywhere below: the Correlation section, the
`dispatch` call, and any `log-delegation-outcome.ps1 -HandoffId` calls the prompt instructs. Add
`depends_on: <other handoff_id>` when this handoff is a deliberate follow-on to another (e.g. a
second phase that must not start until the first merges).

### Required sections

1. **Orientation.** Point at the repo's own `CLAUDE.md`/`AGENTS.md` and tell it to follow that
   exactly. Do not restate the repo's conventions — you will get them subtly wrong and create a
   conflicting second source of truth.
2. **Hard constraints, first and unmissable.** Anything destructive, irreversible, or
   outward-facing the session must not do. Include the escape hatch: if a task appears to require
   a forbidden action, stop and ask rather than improvise. This matters most under
   `--dangerously-skip-permissions` (the `dispatch` default), where this text is the *only*
   guardrail left — write it as the last line of defence.
3. **Correlation (required).** Tell the child session to, on its own first turn, append its own
   row to the [handoff registry](references/handoff-registry.md)
   (`~/.claude/telemetry/handoffs.jsonl`): same `handoff_id` as the frontmatter, `source: live`,
   `confidence: 1.0`, and its own session id as `child_sid` (available to it as
   `$env:CLAUDE_CODE_SESSION_ID` / the equivalent session-identity read for its platform). Also
   tell it to pass `-HandoffId <handoff_id>` on every
   `log-delegation-outcome.ps1` call it makes, so delegation outcomes correlate back to this
   handoff. This closes the loop the dispatch-time row (written by `launch-claude-session.ps1`,
   `child_sid: null`) leaves open — without the self-report, `child_sid` stays null forever for a
   live handoff.

   **This section is the single most-dropped required element** — a `handoff-tuner` run on
   2026-10-23 found **0 of 92** handoff prompts in the corpus contained it, including every
   launcher-era prompt written *after* this requirement was documented. Treat it as non-optional:
   paste a concrete self-report instruction into the generated prompt (not a paraphrase), e.g.

   > **Correlation (do this first).** On your first turn, append one line to
   > `~/.claude/telemetry/handoffs.jsonl`: `{"handoff_id":"<this id>","ts":"<UTC>","parent_sid":null,
   > "child_sid":"<your $env:CLAUDE_CODE_SESSION_ID>","prompt":"<abs path>","branch":"<branch>",
   > "repo":"<abs repo>","source":"live","confidence":1.0}`. Pass `-HandoffId <this id>` on every
   > `log-delegation-outcome.ps1` call.

   Before handing off (Step 4), re-read the prompt you wrote and confirm the Correlation section is
   present and names the real `handoff_id`. If it is missing, the live join cannot complete.
4. **State already established.** Verified facts — counts, IDs, file paths, what is already
   merged, what is already green — each tagged `[V]`/`[?]`, and marked "already done, do not redo".
5. **What we tried / dead ends (required).** Approaches attempted and abandoned, with the concrete
   reason (error text, wrong assumption, measured result). Prevents the new session re-walking
   them. If genuinely none, write "None — first attempt" rather than omitting the section.
6. **Tasks, in order.** Per task: what to do, what "done" looks like, what to report, plus the
   ordering rationale from Step 2. Prefer pointing at existing scripts and flags over describing
   procedures. All tasks run on the one branch unless the work genuinely splits into independently
   reviewable PRs, in which case say so and name the extra branches.
7. **Finishing.** Merge into the base branch, sync local to `origin/<base>`, report — then stop.
   It must not delete its own prompt file: the `retire` gate includes a human confirmation it
   cannot evaluate on its own behalf.
8. **Delegation.** Spawn subagents for mechanical work with `model: "haiku"` passed explicitly — a
   subagent with no model set silently inherits the parent's expensive model, so the cheap default
   must be stated. Name real candidates in this repo's work: locating call sites, extracting counts
   from journals, reading a doc and pulling out a value, drafting a summary script, cross-checking
   docs against code. Equally name what stays in the main session — design decisions, sequencing,
   anything adversarial. Remind it to dispatch independent lookups in parallel in one message.
9. **Delegation logging.** The cheap-model default is a bet, and bets need a scoreboard. Instruct
   the session to record outcomes with the `delegation-ledger` scripts
   ([`log-delegation-outcome.ps1`](../delegation-ledger/scripts/log-delegation-outcome.ps1),
   reviewed with [`delegation-report.ps1`](../delegation-ledger/scripts/delegation-report.ps1)):
   - on every escalation, redo, or dropped task: log a `-Category`, a `-FailureMode` from the fixed
     vocabulary, and one line of concrete `-Evidence` — even if recovered in seconds;
   - **once at the end, as the required last step before reporting finished**: log totals
     (`-Outcome ok -Dispatches N` per category), **each tagged with `-PromptPath <this prompt
     file>`** (or `-Branch`). The `retire` gate refuses to run without a correlated tally unless
     `-NoDelegation` is declared. A required line survives a tired session; "consider logging" does
     not.

   When `delegation-report.ps1` has flagged a category, name that category in the *next* prompt as
   one to keep in the main session — today's failures become tomorrow's routing rules. Rationale
   and vocabulary live in `delegation-ledger`; do not restate them here.
10. **Polling, only when something must be watched.** If a task waits on state the harness cannot
    notify about (CI, a deploy, a long external job, a draining queue), instruct `/loop` with an
    interval matched to how fast the state changes (`/loop 10m <task>`), or bare `/loop` to
    self-pace. Not for work that merely takes a while — backgrounded commands already notify, and a
    polling loop around them burns tokens. If nothing waits on external state, omit this.
11. **Reporting.** Terse output, ending each turn with a single numbered list of items needing a
    decision; verify counts before stating them; correct earlier wrong claims in one line.
12. **Model note.** State which model you pinned and why (see below).

### Choosing the model

Choosing the model is part of writing the prompt, not a launcher setting. You just decided what the
tasks are, so you know whether they need frontier reasoning or are mostly mechanical. Weigh the
*hardest* task, not the average — four doc updates plus one subtle rule change still needs the model
that can do the rule change. Pass the choice to `dispatch` as `-SetEnv "ANTHROPIC_MODEL=<id>"` and
say in the prompt which model you picked and why: the spawned session can `/model` switch mid-run,
and can only do so sensibly if it knows what you assumed. If the task mix is split, prefer the
stronger model for the session and tell it to delegate the mechanical parts to
`model: "haiku"` subagents — cheaper than under-powering the main loop and watching it flail.

## Step 4 — Hand off to dispatch (launch / scope)

Do not launch from here. Give [`dispatch`](../dispatch/SKILL.md) the prompt path, repo, slug/type,
the pinned model, a hyphenated title, **and the frontmatter `handoff_id` (passed through to
`launch-claude-session.ps1 -HandoffId`)**; it creates the worktree
(`dispatch/scripts/new-task-worktree.ps1`), launches
(`dispatch/scripts/launch-claude-session.ps1`), verifies the PID and reports.

> **Pass the `handoff_id` — do not let the launcher mint one.** When `-HandoffId` is omitted the
> launcher synthesizes `lv-<title>-<unixms>` so the dispatch row is never without a key — but that
> synthetic id can never join the prompt's frontmatter id or the forensic row, leaving an orphan.
> A `handoff-tuner` run on 2026-10-23 found exactly this: the one live registry row carried a
> synthesized `lv-…` id with `child_sid: null` instead of the prompt's `handoff_id`, so **no live
> join completed**. The frontmatter `handoff_id`, the Correlation self-report, and this `-HandoffId`
> pass-through are the three parts of one chain; drop any and the live correlation breaks. Record the prompt
path and branch it returns — `retire` needs both, and after a context compaction they are
otherwise gone. If Windows Terminal is unavailable, `dispatch` covers the fallback; if even that
fails, report the prompt file path and the exact command the user can run — the prompt, the
expensive part, is already written.

## Copy mode (`/continue-new-session`)

Print a prompt the user pastes into a fresh **Claude, Codex or Gemini** session. **Launches
nothing, writes no file, modifies no project state.**

1. Name the target CLI (ask via `AskUserQuestion` if unstated; default Claude) and tailor only the
   conventions line (`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`).
2. **Locate the recap-recommended next action** in your own most recent assistant turn ("Next:",
   "Next up:", "Recommended next:", a trailing next-step bullet). Capture: action verb + object;
   the plan/feature/task identifier (feature slug, plan path, CAP-ID, task ID); any follow-on
   guidance ("use TDD", "open a PR when done"). Do not re-derive from project state when a recap
   action exists.
3. **Resolve context paths without reading full content:** feature spec `docs/features/{slug}.md`,
   plan `docs/plans/{slug}-plan.md`, active task `docs/tasks/active/{slug}-p{N}-t{M}.md` (only if
   it exists), `docs/STATUS.md` (§1 = run state/next action) and `docs/workflow/INDEX.md` if
   present. Verify each path exists; if not, say so in the prompt rather than emit a broken
   reference. For each existing file add a 2–3 line excerpt (first heading plus 1–2 content lines).
   Never embed whole specs, plans or tasks.
4. **Fallback** when the recap has no next action: tell the user, then derive one from
   `docs/STATUS.md` §1, else `references/scripts/pm-next.ps1` of project-manager if present, else
   the first `todo` task of the lowest phase of the highest-priority approved feature with no
   blockers; prefix the action line with `(derived from <source>)`. If nothing qualifies, print
   "No recap recommendation found and no eligible next task exists. Run `/review-tasks` or
   `/init-features`." and stop with no prompt block.
5. **Emit exactly one fenced markdown block** with: header naming the target CLI; the recommended
   action; project and work pointers with excerpts; "What to do" (read pointers, do the action,
   follow project-manager conventions — one active task, `## Completion` sentinel, no spec edits
   without confirmation; `/continue-tasks` for the loop or `/update-tasks` after a specific step);
   constraints (stay on current branch unless told, do not regenerate existing plans, do not skip
   verification); a state section with claims tagged `[V]`/`[?]`; and the required **What we tried
   / dead ends** section. Omit any line whose value is missing — never emit an unresolved
   `{placeholder}`. If the work is long-running, point at the `checkpoint` state file
   (`_project_specs/session/current-state.md`) instead of copying its contents.
6. After the block print one sentence telling the user to paste it into a new Claude Code, Codex or
   Gemini session.

## Chain mode (batch / recursive handoff)

For a large migration, refactor or batch operation (dozens to hundreds of homogeneous targets, or a
live queued operation) that cannot fit one session or PR. The prompt **repeats its own structure**
each session, so no central master plan can go stale.

The chain prompt must contain, in this order:

1. **Sequence number** — `Handoff N` (and total, if known); increment on re-emit.
2. **Recurring failure modes first** — anything this batch discovered that the next session would
   otherwise rediscover (e.g. "already-fixed-in-code stale backlog rows"), tagged `[V]`/`[?]`,
   plus the **What we tried / dead ends** section.
3. **Discovery command** — a grep/query/count that is the single source of truth for "what's left".
   Re-run it fresh at the start of every session; never trust a prior narrative of remaining scope.
4. **Batch-selection heuristic** — next coherent group (largest prefix group, subdirectory,
   name-glob) with a size cap (about 20–30 targets) so the PR stays reviewable.
5. **Execution recipe** — per-target judgment, not blind sed/find-replace (similar files differ in
   ways that need individual handling); normal TDD discipline; one batch per PR/change.
6. **Progress log** — prepend a new entry per batch (e.g. `docs/progress.md`), newest on top, so a
   stalled batch is spotted at a glance. This log plus the discovery command are the only sources
   of truth; do not also keep a separate master plan.
7. **The next handoff** — an explicit instruction to repeat this whole process at the end and
   **re-emit this same prompt verbatim** with only current state and the sequence number updated
   (written to `docs/PROMPTS/`, then handed to `dispatch` or printed, per the user's choice). Also
   a stop condition: when discovery returns zero, report done and emit no further handoff.
8. **Live/queued operations** (ffmpeg, DB migrations, deployments): each iteration first verifies
   the prior batch is draining (its count falling) and only increases batch size once the prior
   batch has fully cleared, to avoid orphaning a queue across a service restart.

The standard sections (orientation, hard constraints, delegation, delegation logging, model,
reporting) still apply. Multi-phase feature/infra chains use the same recursive structure with
explicit decision gates even when the "batch" is a follow-on task rather than a file group.

## Gotchas

- A summary of "what's left" written by a prior session lets scope drift; chain prompts carry a
  command, not a narrative.
- Never write the prompt inside the worktree; never let the spawned session delete its own prompt.
- A bare `scripts/…` path in the prompt resolves against the wrong repo — use absolute paths.
- Do not start a handoff unprompted; offer it in one sentence.
