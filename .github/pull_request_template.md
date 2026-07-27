<!-- .github/pull_request_template.md — installed by /init-project -->

## Summary

<!-- 1-3 bullets. What changed and why. -->

-
-

## Project-Manager Traceability

> Required. PRs that do not trace to a feature spec and a task file are rejected during review.

- **Feature spec:** `docs/features/{{feature-slug}}.md`
- **Plan:** `docs/plans/{{feature-slug}}-plan.md`
- **Task file(s):** `docs/tasks/archive/{{feature-slug}}-pN-tM.md`
- **Capabilities covered:** `[XX-CAP-NN]`, `[XX-CAP-NN]`, ...

If this PR is intentionally out-of-band (hotfix, infrastructure, dependency bump), check the box below and explain:

- [ ] Out-of-band change. Justification: ...

## Test Plan

- [ ]
- [ ]

## Checks

- [ ] All changes trace to capability IDs listed above (or out-of-band box checked)
- [ ] Acceptance criteria for the covered capabilities all pass
- [ ] Task file `## Completion` block was written with `Status: success`
- [ ] No new dependencies introduced without listing them in the task `Notes:` field
- [ ] No `[placeholder]` text remaining in any modified spec or plan
