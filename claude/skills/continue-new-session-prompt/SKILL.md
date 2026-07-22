---
name: continue-new-session-prompt
description: >
  Hand off the current session's unresolved decisions to a fresh Claude Code session running in a
  new Windows Terminal tab. Use this skill whenever the user says "continue in a new session",
  "spawn a new terminal and keep going", "hand this off", "open a new window and work through
  those items", "/continue-new-session-prompt", or otherwise asks for the open items from your
  last response to be executed elsewhere — including when they just say "go do all that in a new
  session". The skill turns the decision list you most recently gave them into a self-contained
  handoff prompt (state already established, tasks in dependency order, hard constraints, cheap
  subagent delegation, /loop for anything that needs polling), writes it under docs/PROMPTS/, and
  launches it via a script so no prompt text ever passes through shell quoting.
category: Foundations & Workflow
requires: []
---

# Continue in a New Session

Turn the open decisions from the conversation you are in right now into a prompt a fresh session
can execute unattended, then launch that session in its own Windows Terminal tab.

The value here is not the terminal spawn — that part is three lines of PowerShell. It is that the
new session starts with **no conversation history at all**. Everything you learned by doing the
work — the counts you verified, the paths you fixed, the dead ends — is invisible to it unless you
write it down. A handoff prompt that says "continue where we left off" produces an agent that
re-derives what you already know, and often re-derives it wrong. Most of your effort belongs in
capturing state, not in describing tasks.

## When you have nothing to hand off

If your last response had no decision list, or every item on it was informational rather than
actionable, say so and stop. Do not manufacture tasks to fill a prompt. Ask the user what they
want the new session to do instead.

## Step 1 — Recover the items

Take the numbered decision list from your most recent response. For each item, resolve it into a
concrete instruction using the recommendation you already gave. The user asking for this skill is
usually accepting your recommendations wholesale; if any item genuinely has no default and the
answer changes the work, use `AskUserQuestion` to settle it before writing the prompt rather than
passing the ambiguity downstream — an unattended session cannot ask.

Drop items that are questions about the handoff itself ("should the new session self-merge?") —
resolve those here and encode the answer as a constraint.

## Step 2 — Order the tasks by dependency

Sequence matters more than completeness. A task that regenerates data invalidates the reviews of
whatever ran before it; a task that fixes a rule must land before anything re-runs that rule, or
the run reproduces the bug you just fixed. Walk the list and ask of each pair: does doing B before
A waste A?

State the ordering rationale in the prompt itself, briefly. An agent that understands *why* task 1
precedes task 2 will hold the line when task 2 looks tempting; one that was only told the order
will reorder it the moment something blocks.

## Step 3 — Create the worktree

Give the new session somewhere to work before it starts, rather than making it decide:

```powershell
pwsh -File <skill-dir>/scripts/new-task-worktree.ps1 `
    -RepoPath 'C:\path\to\repo' -Slug 'reset-move-queue' -Type refactor -SyncDeps
```

It fetches, fast-forwards the local base branch to `origin/<base>`, branches the worktree from
**`origin/<base>` rather than the local ref**, and syncs dependencies. Branching from the remote is
the point: a local `dev` that nobody has pulled in a week would otherwise seed the new session with
a stale tree, and it would spend its first half-hour confused about why its diff includes work
someone already merged.

The sync is fast-forward only. If the local base has diverged, the script stops rather than
resetting — divergence means someone has unpushed commits, and that is a person's problem, not a
thing to resolve automatically. Surface it and ask.

The script prints `WorktreePath` and `Branch`. Both are needed for the launch and again at cleanup,
so keep them.

## Step 4 — Write the prompt

Write to `docs/PROMPTS/<YYYY-MM-DD>-<short-slug>.md` **in the main checkout, never inside the
worktree.** A prompt file living in the worktree becomes part of the branch's diff, gets reviewed
as if it were deliverable, and then needs its own commit to remove. Keeping it in the main
checkout means the branch stays clean and retiring the prompt later is just a file deletion.

Tell the new session, explicitly, that its worktree and branch already exist and it should work
there rather than creating another — otherwise a session that reads the repo's worktree convention
will dutifully create a second one and split its own work across two trees.

Cover:

**Orientation.** Point at the repo's own `CLAUDE.md`/`AGENTS.md` and tell it to follow that
exactly. Do not restate the repo's conventions — you will get them subtly wrong and create a
conflicting second source of truth.

**Hard constraints, first and unmissable.** Anything destructive, irreversible, or outward-facing
that the new session must not do. Include the escape hatch: if a task appears to require a
forbidden action, stop and ask rather than improvise. This section matters most when the session
runs with `--dangerously-skip-permissions`, where the constraint text is the *only* guardrail
left.

**State already established.** The verified facts — counts, IDs, file paths, what is already
merged, what is already green. Mark them explicitly as "already done, do not redo". Every number
here must be one you actually measured this session; a confidently wrong count sends the new
session down a false path with no one there to catch it.

**Tasks, in order.** Per task: what to do, what "done" looks like, and what to report. Prefer
pointing at existing scripts and flags over describing procedures. All tasks run on the one branch
created in step 3 unless the work genuinely splits into independently reviewable PRs, in which case
say so and name the additional branches.

**Finishing.** Tell it to merge into the base branch, sync local to `origin/<base>`, and report —
then stop. It must not delete its own prompt file: the retirement gate in step 6 includes a human
confirmation it cannot evaluate on its own behalf.

**Delegation.** Tell it to spawn subagents for mechanical work with `model: "haiku"` passed
explicitly — a subagent with no model set silently inherits the parent's expensive model, so the
cheap default has to be stated. Name the actual candidates in this repo's work: locating call
sites, extracting counts from journals, reading a doc and pulling out a value, drafting a summary
script, cross-checking docs against code. Equally, name what stays in the main session — design
decisions, sequencing, anything adversarial — so it does not fan out judgment to a small model.
Remind it to dispatch independent lookups in parallel in one message.

**Delegation logging.** The cheap-model default is a bet, and bets need a scoreboard. Instruct the
session to record outcomes with `scripts/log-delegation-outcome.ps1`:

- Whenever it escalates a subagent to a stronger model, redoes a subagent's work itself, or drops a
  task the subagent could not complete — log it with a `-Category`, a `-FailureMode` from the fixed
  vocabulary, and one line of concrete `-Evidence` (the wrong value, the invented path, the ignored
  constraint).
- Once at the end of the session, log the totals: `-Outcome ok -Dispatches N` per category. This is
  the denominator, and it is the part sessions skip. Escalations alone produce a list of failures
  with no way to tell whether that is five out of eight or five out of four hundred — the first
  means stop using haiku for that work, the second means the default is working fine.

Be explicit that a failure is worth logging even when it was recovered in seconds. The recovery is
invisible later; only the ledger remembers, and the whole point is to answer next month's question
"which categories should stop going to haiku?" with data rather than impressions.

Review the accumulated evidence with `scripts/delegation-report.ps1`, which reports failure share
per category and model and flags the pairs worth changing. It withholds recommendations below a
minimum sample rather than drawing conclusions from three data points — and says so, because "not
enough data yet" is itself worth knowing. When it does flag a category, fold that into the *next*
handoff prompt by naming that category as one to keep in the main session. That is the loop closing:
today's failures become tomorrow's routing rules.

**Polling, when something must be watched.** If a task waits on state the harness cannot notify
about — CI, a deploy, a long external job, a queue draining — instruct the new session to use
`/loop` with an interval matched to how fast that state actually changes (`/loop 10m <task>`), or
bare `/loop` to let it self-pace. Do not reach for `/loop` for work that simply takes a while:
backgrounded commands already notify on completion, and a polling loop around them just burns
tokens. If nothing in the task list waits on external state, omit this entirely.

**Reporting.** Tell it to follow the user's output discipline: terse, ending each turn with a
single numbered list of items needing a decision. Tell it to verify counts before stating them,
and to correct its own earlier claims in one line when they turn out wrong.

Make the end-of-session delegation tally a **required** final step, not a suggestion — the last
thing it does before reporting finished. It is the ledger's denominator (see **Delegation
logging** above), and it is precisely the step a session drops when it is tired and wants to be
done. A required line survives that; a hopeful "consider logging totals" does not, and without the
denominator every escalation the session *did* log is uninterpretable.

## Step 5 — Launch it in the worktree

Point `-WorkingDirectory` at the worktree from step 3, not the repo root — that is what makes the
new session start already inside its own isolated checkout:

```powershell
pwsh -File <skill-dir>/scripts/launch-claude-session.ps1 `
    -PromptPath 'C:\repo\docs\PROMPTS\2026-07-21-thing.md' `
    -WorkingDirectory 'C:\repo\.worktrees\reset-move-queue' `
    -Title 'repo-reset-move-queue'
```

The script exists because of a specific failure: passing the prompt inline through
`wt` → `pwsh -Command` means the text crosses two parsers, and a title containing a space is
enough to make `wt` treat the remainder as a command and fail with "the system cannot find the
file specified". Reading the prompt from a file inside a `-File` script removes every layer of
quoting. Keep titles hyphenated anyway.

Spawned sessions run with `--dangerously-skip-permissions` by default — nobody is sitting there to
answer prompts, and a session blocked on an approval dialog in a background tab is just a stalled
session. `-NoSkipPermissions` opts out for a run you intend to babysit. Because that guardrail is
off, the hard-constraints section of the prompt is the only thing standing between the session and
an irreversible action: write it as if it were the last line of defence, because it is.

**Environment.** A session launched from a script inherits nothing from the shell you are sitting
in, so anything that matters has to be stated. The script defaults cover terminal colour, keeping
bash calls anchored to the project root, bash and subagent-stall timeouts long enough for real
work, and silencing nonessential network traffic — see `$script:DefaultEnvironment` in the script
for the current set and the reasoning per variable. Add or change variables with `-SetEnv` using
`KEY=VALUE` pairs, and drop a default with a bare `KEY=`:

```powershell
-SetEnv "ANTHROPIC_LOG=debug","FORCE_COLOR="
```

**Choosing the model is part of writing the prompt, not a launcher setting.** You are the one who
just decided what the tasks are, so you are the one who knows whether they need frontier reasoning
or are mostly mechanical. Weigh the *hardest* task in the list, not the average — a run that is
four doc updates and one subtle rule change still needs the model that can do the rule change.

Pass the choice through as `-SetEnv "ANTHROPIC_MODEL=<id>"`, and say in the prompt which model you
picked and why. That last part matters: the spawned session can switch with `/model` mid-run, and
it can only make that call sensibly if it knows what you assumed. If the task mix is genuinely
split, prefer the stronger model for the session and tell it to delegate the mechanical parts to
`model: "haiku"` subagents — that is cheaper than under-powering the main loop and watching it
flail.

`KEY=VALUE` rather than a hashtable because `pwsh -File` passes every argument through as a
literal string — a hashtable fails type conversion at the binder, and even a comma-separated array
arrives as one string. The script re-splits that itself, so both `-File` and `-Command` invocation
work and commas inside a value survive.

`-DryRun` writes the runner script and prints it without launching. Worth doing when you have
changed the environment or the prompt path and want to see exactly what the new tab will execute.

## Step 6 — Verify the launch and report

The script prints the PID of the launched `claude` process, or an error if it never started.
Confirm from that output, not from the fact that `Start-Process` returned — the failure mode is a
terminal tab that opens and immediately dies, which looks identical to success from the caller's
side.

Report in one short block: the worktree path and branch, where the prompt file landed, the PID, the
model you pinned and why, and the task order. Record the prompt path and branch — step 7 needs
both, and after a context compaction they are otherwise gone.

## Step 7 — Retire the session, only once it has earned it

When the spawned session reports finished, run the gate rather than cleaning up by hand:

```powershell
pwsh -File <skill-dir>/scripts/complete-task-session.ps1 `
    -RepoPath 'C:\repo' -PromptPath 'C:\repo\docs\PROMPTS\2026-07-21-thing.md' `
    -Branch 'refactor/reset-move-queue' -Confirmed
```

It refuses to delete anything unless all four hold:

1. the branch is an ancestor of `origin/<base>` — actually merged, not just PR'd;
2. local `<base>` matches `origin/<base>` exactly — no unpushed or unpulled commits;
3. the repo's tests pass (auto-detected, or `-TestCommand`, or `-SkipTests` with the reason
   printed so a skip is never silent);
4. `-Confirmed` is present.

That fourth gate is the one that cannot be automated, and it is deliberately not a formality. A
merged branch with green tests can still be the wrong solution — that is exactly what a human
review catches and what no repo state can tell you. So **only pass `-Confirmed` after the user has
actually looked at the work and said it is right.** Asking them is the point of the gate; inferring
it defeats it. If they have not responded yet, run without the flag: the mechanical checks still
report, and nothing is deleted.

On success it deletes the prompt, removes the worktree (unforced, so it refuses on uncommitted
changes rather than discarding them), and deletes the local branch. On any failure it prints the
per-check verdict and exits non-zero, leaving everything intact — a failed gate should always be
recoverable by fixing the cause and re-running.

## If Windows Terminal is unavailable

`wt` ships with Windows 11 but can be absent on stripped-down or server installs. The script falls
back to launching `pwsh` in a plain console window automatically. If even that fails, do not
silently give up: report the prompt file path and the exact command the user can run themselves,
since the prompt — the expensive part — is already written and still useful.
