---
name: statusline-audit
description: >
  Sub-skill of `statusline`. Read-only health check of the live status-line script against the
  three known root causes of vanishing token counts (mtime fallback, transcript-only token
  source, unsanitized numbers) plus archive drift and exit-code hygiene. Triggers on "audit my
  status line", "is my status line correct", "check my status line for the known bugs", "why does
  my status line keep breaking". Never mutates anything.
---

# Operation: audit

**Goal.** Verify the live status-line script against every failure this skill has learned about,
and report a pass/fail table with a recommended fix. Strictly read-only.

## Output Contract (binding — inlined, adapted for a read-only report)

`/audit-statusline` may load this file without the parent SKILL.md in context. Stay silent while
checking; the deliverable **is** the check table plus a recommendation. A probe that can't run
degrades its own row ("unavailable — reason"), never the whole audit. Close with a single
`AskUserQuestion` offering the top fix only if a check failed. Banned: interpretive asides,
teaching essays, self-narration. Overrides any explanatory output style.

## What to check

Resolve the live script the same way `inspect` does (winning `statusLine` layer → script path).
Read it, then run each check. `ARCHIVE` = this skill's `assets/statusline.sh`; `LIVE` = the
deployed script (typically `~/.claude/statusline.sh`).

| # | Check | How | Fail signal |
|---|---|---|---|
| C1 | **No mtime/newest-file fallback** (root cause #1) | grep LIVE for `ls -t`, `-newer`, `--sort=.*time`, `stat .*mtime`, "newest" | any hit → it can show a *prior* session's context |
| C2 | **Reads native `context_window`** (root cause #2/#3) | grep LIVE for `context_window` | absent → transcript-only → blanks on worktree/handoff sessions |
| C3 | **Sanitizes parsed numbers to digits** | grep LIVE for `[!0-9]` (or equivalent) | absent while parsing numbers → CRLF corruption risk |
| C4 | **Exit-code hygiene** | `echo '{}' \| <command>; echo $?` and `printf '' \| <command>; echo $?` | non-zero → Claude Code hides the status line |
| C5 | **Session identity by `session_id`** | grep LIVE for `session_id` used to resolve the transcript | resolves purely by `transcript_path` with no `session_id` fallback → stale-path blanks |
| C6 | **No archive drift** | `diff <ARCHIVE> <LIVE>` | differs → live and source of truth have diverged (the recurring ad-hoc-edit problem) |
| C7 | **Worktree/handoff simulation renders tokens** | pipe a `context_window`-present, transcript-absent payload (see `inspect` step 4) | blank token segment → the exact screenshot symptom |
| C8 | **`.gitattributes` pins the asset to LF** | grep repo `.gitattributes` for a rule covering the asset's `*.sh` | absent → CRLF can corrupt the shipped script downstream |

## Report

One table: `| Check | Result | Detail |`, most-severe failure first. Then a one-line verdict
(healthy / N issues) and a recommendation:

- Any of C1/C2/C5/C7 failed → recommend `/install-statusline` (redeploy the canonical asset) — it
  fixes the token-source class wholesale.
- Only C6 (drift) failed → recommend `/modify-statusline` to reconcile (asset wins unless the
  user wants the live change captured back).
- Only C3/C4/C8 failed → recommend `/modify-statusline` for the targeted fix.
- All pass → say so and stop.

Offer to launch the top recommendation via `AskUserQuestion`; never launch it yourself.
