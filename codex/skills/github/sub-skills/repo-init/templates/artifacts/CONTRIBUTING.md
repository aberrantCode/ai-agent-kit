# Contributing

## Branches

| Branch | Purpose | Updated via |
|---|---|---|
| `main` | Production | PR from `dev` (releases only) |
| `dev` | Integration | PR from feature branches |
| `type/short-description` | Feature work | Branches off `dev`, PR back to `dev` |

`main` and `dev` are protected: no direct pushes, no force-pushes, no deletion. All changes
land through a pull request.

Branch names follow `type/short-description` where type is one of
`feat` `fix` `refactor` `docs` `test` `chore` `perf` `ci`.

## Commits

Conventional format, one logical change per commit:

```
<type>: <description>
```

If the description needs the word "and", it is two commits. No `WIP` commits reach a PR.

## Local validation gate

CI for this repository runs **locally**, via git hooks, not GitHub Actions. Hooks are
committed to the repo but activated by local config that is **not** cloned — so after
cloning, activate them once:

```bash
git config core.hooksPath .githooks
```

`pre-commit` scans staged changes for secrets. `pre-push` runs the full validation gate.
Run `/init-repo` to have this checked and repaired automatically.

## Pull requests

- Target `dev` (never `main` directly, except release PRs)
- Rebase onto latest `origin/dev` before opening
- Merge strategy is a merge commit — squash and rebase merges are disabled
- Keep under 800 lines changed; split if larger
- Include a Summary and a Test Plan
