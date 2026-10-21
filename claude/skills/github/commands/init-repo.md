---
description: Harden this repo to the Repo-Configuration Standard — protected main/dev rulesets, immutable tags, merge-commit-only, secret-scanning push protection, local hook gate. Re-runnable; applies only the drift you confirm.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/repo-init/SKILL.md` to run its `repo-init` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:repo-init)`.

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
