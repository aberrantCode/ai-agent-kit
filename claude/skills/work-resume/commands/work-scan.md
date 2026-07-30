---
description: Low-level inspection of this repo's recent Claude Code sessions — dumps the raw per-session digest (goal, last turn, edited files, branch/worktree, mid-action flag) that /work-resume builds on, with no classification or action. Accepts an optional recall window (e.g. "14d", "10s", a date, or "all"); defaults to the smart window. Use to debug what the scanner sees.
---

Apply the `work-resume` skill's extractor directly for inspection. Run:

```bash
python references/resume-scan.py --repo . --format md
```

If the operator's message indicates a recall window, pass it through as
`--window <value>` (`14d` = last 14 days, `10s` = last 10 sessions,
`YYYY-MM-DD` = since a date, `all` = full corpus). With no argument, omit the
flag and use the smart default (newest-first, last 21 days, clamped to 6–15
sessions).

Show the extractor's Markdown output largely as-is — this command is deliberately
transparent, for seeing exactly which sessions and worktrees the scanner found
and what signal each carries. Do not classify, reconcile, or act; that is
`/work-resume`'s job.
