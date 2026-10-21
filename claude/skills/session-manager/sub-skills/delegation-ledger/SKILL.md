---
name: sm-delegation-ledger
description: >
  Sub-skill of `session-manager`. Record and report delegated-subagent outcomes: log every
  escalation, redo and failure, plus the end-of-session ok totals (the denominator), to
  ~/.claude/telemetry/delegation-outcomes.jsonl (log-delegation-outcome.ps1), and aggregate
  them into failure share per category and model (delegation-report.ps1). Use for
  "/delegation-report", "log this delegation", "log the delegation tally", "how often do haiku
  subagents fail", "which delegations got escalated", "which categories should stop going to haiku".
---

# delegation-ledger

Formerly the "Delegation logging" section of the `session-handoff` handoff skill; it now lives
here because the ledger serves any session that delegates, not only handed-off ones.

## Why delegation is logged

The cheap-model default (subagents spawned with `model: "haiku"`) is a bet, and bets need a
scoreboard. Without a ledger the evidence is anecdote -- "haiku seemed flaky that one time" --
which cannot change a routing policy in either direction. Logging answers next month's question,
"which categories should stop going to haiku?", with data rather than impressions.

Two kinds of row make the data interpretable:

- **Failures** (one row each): the cheap model was escalated, the parent redid its work, or the
  task was dropped.
- **Tallies** (the denominator): how many dispatches went to a model and succeeded. Escalations
  alone give a list of failures with no way to tell five-out-of-eight from five-out-of-four-hundred;
  the first means stop using haiku for that work, the second means the default is working fine.

## When to log

Scripts live in `scripts/` beside this file; run them with `pwsh -NoProfile -File`.

1. **Every failure, at the moment it happens** -- whenever you escalate a subagent to a stronger
   model, redo a subagent's work yourself, or drop a task it could not complete. Log it even when
   recovery took seconds; the recovery is invisible later and only the ledger remembers.

   ```
   scripts/log-delegation-outcome.ps1 -Category extract -Model haiku -Outcome escalated `
       -FailureMode wrong-answer -EscalatedTo sonnet `
       -Evidence 'reported 46,929 approved rows; actual journal count was 55,644' `
       -Repo dropbox_audit -Branch refactor/reset-move-queue
   ```

   `-Outcome` is `escalated`, `redone-by-parent`, or `failed`. `-Category` is one of `search`,
   `extract`, `summarize`, `edit`, `test-run`, `verify`, `docs`, `other`. `-FailureMode` (required
   for any non-ok outcome) is one of `wrong-answer`, `incomplete`, `hallucinated-reference`,
   `ignored-constraint`, `format-violation`, `timeout`, `tool-misuse`, `other` -- a fixed
   vocabulary so categories stay comparable across sessions. `-Evidence` is one line of concrete
   detail (the wrong value, the invented path, the ignored constraint); "was vague" helps nobody.

2. **Once at the end of the session, as a required final step** -- log the totals per category
   and model, each **tagged** so the retire gate can find it:

   ```
   scripts/log-delegation-outcome.ps1 -Category search -Model haiku -Outcome ok -Dispatches 12 `
       -PromptPath <this session's handoff prompt file> -Branch <branch> -Task <prompt-slug>
   ```

   The tag is not optional bookkeeping. The [`retire`](../retire/SKILL.md) gate
   (`../retire/scripts/complete-task-session.ps1`, check 5) refuses to run unless it finds an `ok`
   tally matched by prompt filename (`-PromptPath`), `-Branch`, or a `-Task` starting with the
   prompt slug (prompt basename minus the leading date and `.md`). An untagged totals row reads as
   "no tally logged" and blocks cleanup; `log-delegation-outcome.ps1` warns when you omit all
   three tags. Make this step the last thing before reporting finished -- it is the one tired
   sessions drop, and without it every escalation logged is uninterpretable.

## Ledger

- Path: `~/.claude/telemetry/delegation-outcomes.jsonl` (override with `-LedgerPath`; the file is
  created on first write). The path is unchanged by the move into `session-manager`.
- Append-only JSONL, one object per line: `timestamp` (UTC), `category`, `model`, `outcome`
  (`ok` | `escalated` | `redone-by-parent` | `failed`), `dispatches` (default 1; set N on tally
  rows), `failure_mode`, `escalated_to`, `evidence`, `task`, `repo`, `branch`, `prompt`.

## Reporting

```
scripts/delegation-report.ps1 [-LedgerPath <file>] [-MinSample N] [-FailureThreshold 0.2] [-Since yyyy-MM-dd]
```

Reports failure share per category and model and flags pairs above the threshold. It withholds
recommendations below `-MinSample` dispatches and says "insufficient data" rather than drawing
conclusions from a handful of rows. Use `-Since` after a model upgrade so old evidence about a
retired model does not count. With no ledger yet it says so and exits.

When a category is flagged, fold that into the *next* handoff prompt (see
[`handoff`](../handoff/SKILL.md)) by naming it as work to keep in the main session -- today's
failures become tomorrow's routing rules.
