---
description: Bring this repository's configuration up to the Repo-Configuration Standard — ruleset-protected main/dev, immutable release tags, merge-commit-only policy, secret-scanning push protection, an active local hook gate, and the standard artifact set. Re-runnable: diffs live state against the standard and applies only the groups you confirm. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Apply the `github` skill and execute its `repo-init` operation (`sub-skills/repo-init`).

If the repo has no GitHub remote, invoke `sub-skills/publish` first to create and push it,
then resume. If it is already published, probe live state, diff it against the standard, and
present the drift grouped by domain via `AskUserQuestion` (multiSelect) before changing
anything. A fully conformant repo is a no-op — report and stop without prompting.

An optional message may name a single group to reconcile (`protection`, `merge`, `security`,
`actions`, `hooks`, `artifacts`, `metadata`), or `--check` to diff and report without
offering to apply.

Never apply anything the operator did not select. Repo-level settings (rulesets, merge
policy, security toggles) take effect on GitHub immediately and are not part of any commit —
say so in the summary.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
