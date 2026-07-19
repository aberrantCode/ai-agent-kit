<!-- repo-init:begin managed block - do not edit by hand -->
## Git workflow

`main` and `dev` are protected by rulesets: no direct pushes, no force-pushes, no deletion.
All changes land through a pull request targeting `dev`; `dev` merges into `main` only for
releases.

- Feature branches: `type/short-description` off `dev` (`feat` `fix` `refactor` `docs` `test`
  `chore` `perf` `ci`)
- Merge strategy is a **merge commit** — squash and rebase merges are disabled at the repo
  level, so do not propose them
- Release tags (`v*`) are immutable: fix a bad release with a new version, never by
  repointing a published tag
- Commits are conventional (`<type>: <description>`), atomic, no `WIP` on a branch that
  reaches a PR

### Worktrees

Per-task worktrees live at `<repo>-wt/.worktrees/<task>` — a **sibling** directory, outside
this repository. That is why they never appear in `git status`. `.worktrees/` and
`.claude/worktrees/` are gitignored defensively, for worktrees other tooling creates in-repo.

Run destructive git operations (merge, branch delete) from the **primary checkout**, never
from inside a secondary worktree: `cd "$(git rev-parse --show-toplevel)"`.

Cleanup order is worktree → local branch → remote. Removing a worktree does not delete its
backing branch.

### Local CI gate

CI for this repository runs **locally, via git hooks — not GitHub Actions.** Actions are
reserved for tag-triggered release automation.

Hooks are committed to the repo, but activated by local git config that is **not cloned**.
After cloning, activate them once:

```bash
git config core.hooksPath .githooks
```

If that config is unset, the hooks in this repo are present but **inert** — every commit and
push silently skips validation. `pre-commit` scans staged changes for secrets; `pre-push`
runs the full validation gate.

Re-run `/init-repo` at any time to check this repository against the standard and repair
drift.
<!-- repo-init:end -->
