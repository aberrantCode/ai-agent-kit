---
name: github-publish
description: Sub-skill of `github`. Publish a local project as a new GitHub repository — git init, initial commit, repo creation, and pushing main + dev — then hand off to `repo-init` for all configuration hardening. Honors the parent Output Contract.
---

# Operation: publish

**Goal.** Get the current local project onto GitHub as a repo with `main` and `dev` pushed.
This is the **day-0 bookend** to the bundle's day-N ops. Obey the parent **Output Contract**:
silent run, errors as they occur, one concise summary.

---

## Scope — publish creates, repo-init configures

`publish` owns exactly one thing: **turning a local directory into a GitHub repository.**
Every configuration decision — branch protection, merge policy, security settings, hooks,
`.gitignore`/`.gitattributes`, templates — belongs to `sub-skills/repo-init`, which owns the
Repo-Configuration Standard.

This split exists so the standard has **one** definition. When `publish` carried its own copy
of the protection and ignore-file logic, the two drifted, and a repo's configuration depended
on which command happened to create it.

Hardening is still never optional — it is simply applied by `repo-init` at the end of this
operation rather than inline here.

**Loop guard.** `repo-init` invokes `publish` when a repo has no remote. When `publish` was
reached that way, skip Phase 9 and return control — do not call back into `repo-init`.

---

## Phase 1 — Prerequisites (abort on failure)

```bash
gh --version        # missing → give install cmd (winget/brew/apt) and abort
gh auth status      # not authed → gh auth login; if it fails, abort
gitleaks version    # missing → install (choco/scoop/winget/brew/release binary); if still
                    #   missing, continue but note in the summary that scanning only warns
```

---

## Phase 2 — Git init

- **No `.git/`** → `git init --initial-branch=main` (fallback: `git init` then
  `git symbolic-ref HEAD refs/heads/main`).
- **Existing `.git/`** → if default is `master`, rename: `git branch -m master main` (commits
  exist) or `git symbolic-ref HEAD refs/heads/main` (no commits). Then scan history for secrets
  already committed: `gitleaks detect --redact --verbose` — warn (don't auto-block) if any are
  found; they should be rotated before publishing.

---

## Phase 3 — Minimum-viable ignore file (pre-commit safety only)

The full artifact set is `repo-init`'s job. `publish` writes only what is needed so that
Phase 5's initial commit cannot capture a secret — because once a secret is in the first
commit and pushed, it is leaked regardless of what happens afterwards.

If `.gitignore` is absent, write a minimal secrets-only stub: `.env*` (except `*.example`),
`*.pem`, `*.key`, `*.p12`, `credentials.json`, `*.token`. If it exists, leave it alone.

Then run `gitleaks detect --redact --verbose` over the working tree. Findings **block** —
surface them and stop; publishing a leaked secret is not recoverable by a later cleanup.

Everything else — the comprehensive `.gitignore`, `.gitattributes`, the versioned hook gate,
`.gitleaks.toml`, templates — is applied by `repo-init` in Phase 9.

---

## Phase 4 — Visibility

If the invocation contains "public" or "private", use it. Otherwise ask via `AskUserQuestion`
(Public / Private).

---

## Phase 5 — Initial commit

Verify identity (`git config user.email` / `user.name`) — set via `--global` if empty, do not
commit until confirmed. On `main`, if no commits exist: `git add -A && git commit -m "chore: initial commit"`.
If commits exist, skip but confirm the branch is `main`.

---

## Phase 6 — Create repo & push main

Derive the repo name from the directory (sanitize spaces/special chars to hyphens):

```bash
gh repo create <repo-name> --public|--private --source=. --remote=origin --push
```

---

## Phase 7 — Create dev

```bash
git checkout -b dev
git push -u origin dev
```

---

## Phase 8 — Switch to dev

```bash
git checkout dev
```

---

## Phase 9 — Hand off to repo-init

Invoke `sub-skills/repo-init` against the now-published repo. It applies the entire
Repo-Configuration Standard: branch and tag rulesets, merge policy, security settings, the
versioned hook gate, the full artifact set, and the `.github/repo-standard.yml` manifest.

On a brand-new repo everything is drift by definition, so `repo-init` presents one grouped
confirmation covering the whole standard. Do not pre-answer it on the user's behalf.

**Skip this phase entirely if `repo-init` invoked `publish`** — it will continue on its own
once control returns.

---

## Phase 10 — Summarize

One summary block covering both halves (only expected output):

```
Published <owner>/<repo> (private) — main + dev pushed. Standard applied via repo-init:
rulesets on main/dev/tags, merge-commit only, push protection on, hooks active in .githooks.
On dev.
```

Offer `gh repo view --web`.

---

## Error Reference

| Error | Action |
|---|---|
| `gh repo create` name taken | suggest `<name>-2` or ask for a new name |
| `gitleaks detect` finds a secret pre-commit | **STOP** — do not publish. Rotate, remove, re-scan |
| `gitleaks protect` crashes | fall back to `gitleaks detect`; note it |
| Existing repo dirty | ask to commit/stash first |
| `--initial-branch` unsupported | `git init` + `git symbolic-ref HEAD refs/heads/main` |
| `repo-init` fails at Phase 9 | The repo **is** published — report that plainly, note it is unconfigured, and tell the user to re-run `/init-repo`. Never imply the publish itself failed |
