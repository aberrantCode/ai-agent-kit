---
name: git-workflow
description: Protected-branch rules, feature-branch naming and workflow, commit message format, PR standards and description format, and the dev→main release flow
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: git-workflow
source: ~/.claude/rules/git-workflow.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Protected Branches

**NEVER delete `dev` or `main`.** These are permanent branches.
**NEVER push directly to `dev` or `main`.** All changes go through a PR.

| Branch | Purpose | Updated via |
|--------|---------|-------------|
| `main` | Production | PR from `dev` (releases only) |
| `dev`  | Integration | PR from feature branches |
| `type/short-description` | Feature work | Branches off `dev`, PR back to `dev` |

## Branch Naming

Feature branches must follow: `type/short-description`

Types mirror conventional commits: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

Examples: `feat/new-local-user`, `fix/login-bug`, `chore/update-deps`

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

- **Atomic commits** — one logical change per commit; must not break the build
- **No `WIP` commits** — squash before opening a PR
- Attribution disabled globally via `~/.claude/settings.json`

## Feature Branch Workflow

```bash
# 1. Start from latest dev
git checkout dev
git pull

# 2. Create feature branch
git checkout -b feat/my-feature

# 3. Work with atomic commits
git add <files>
git commit -m "feat: description"

# 4. Before opening PR — rebase onto latest dev to prevent merge conflicts
git fetch origin
git rebase origin/dev
# resolve any conflicts, then:
git push --force-with-lease

# 5. Open PR targeting dev
```

## PR Standards

- **Target branch:** always `dev` (never `main` directly, except release PRs)
- **Merge strategy:** regular merge commit — preserves full commit history from feature branches on `dev`
- See the [[scope-cohesion-over-line-count]] guardrail — scope cohesion, not a line count, is the PR gate.
- **Branch cleanup:** delete feature branch immediately after PR merges

### Pre-PR Checklist (Claude enforces before opening any PR)

- [ ] Rebased onto latest `origin/dev`
- [ ] Tests pass
- [ ] PR is cohesive — single scope, all changes related (see [[scope-cohesion-over-line-count]])
- [ ] PR description includes Summary + Test Plan

### PR Description Format

```markdown
## Summary
- <bullet 1>
- <bullet 2>

## Test Plan
- [ ] <verification step>
- [ ] <verification step>
```

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history since branching from `dev` (not just latest commit)
2. Use `git diff dev...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch
6. Confirm rebase from `dev` was done before submitting

## Release Flow (`dev` → `main`)

1. Open a PR from `dev` → `main` when ready to release
2. PR title: `release: vX.Y.Z` or `release: <description>`
3. Merge (squash or standard both acceptable for release PRs)
4. Tag the release on `main`: `git tag vX.Y.Z && git push --tags`
5. `dev` continues from where it is — never deleted or reset after a release

## Feature Implementation Workflow

1. **Plan First** — use planner agent for complex features
2. **TDD Approach** — write tests first (RED → GREEN → IMPROVE), verify 80%+ coverage
3. **Code Review** — use code-reviewer agent after writing code; address CRITICAL and HIGH issues
4. **Pre-PR sync** — rebase onto `origin/dev`, run tests
5. **Commit & Push** — atomic commits, conventional commit format
