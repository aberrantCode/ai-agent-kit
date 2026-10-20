---
description: Measure the startup (first-turn) context cost of Claude Code sessions and explain why a newly launched session already shows tokens > 0. Runs the startup-context-audit script — decomposes the current repo's fresh baseline into readable on-disk instructions (global CLAUDE.md, rules, project CLAUDE.md, memory) versus the non-visible harness (system prompt + tool schemas + skill/MCP inventory + hooks), then tables the fresh baseline for recently-used repos. Read-only; touches nothing.
---

Apply the `startup-context-audit` skill.

Run the bundled `scripts/startup-context.py` (use the absolute path inside the
skill's directory) and present its two parts: the current repo's fresh-baseline
decomposition, then the per-repo baseline table. Lead with the headline — the
repo's fresh baseline and how much of it is the on-disk instruction stack versus
the harness remainder.

Pass through any options the operator gives: `--project <substring>` to scope to
one repo, `--top N` to widen the table, `--dev-root <path>` for a non-default
workspace root, `--json` for machine-readable output. This is a pure measurement:
do NOT change any setting, model, or file.
