---
name: github-publish
description: >
  Sub-skill of `github`. Publish a local project as a new GitHub repository — git init, initial
  commit, repo creation, and pushing main + dev — then hand off to `repo-init` for all
  configuration hardening. Triggers on "publish this repo", "push this to GitHub", "create a
  new repo for this". Honors the Output Contract inlined below.
---

# Operation: publish

**Goal.** Get the current local project onto GitHub as a repo with `main` and `dev` pushed.
This is the **day-0 bookend** to the bundle's day-N ops. Obey the **Output Contract** below:
silent run, errors as they occur, one concise summary.

---

## Output Contract (binding — inlined, not a reference)

The `/publish` command may load this file without the parent `github` SKILL.md in
context, in which case a pointer to "the parent Output Contract" resolves to
nothing. The contract is therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now publishing…"), no per-command status, no play-by-play.
2. **Errors — split them in two.**
   - *Recoverable* (you know the fix and can apply it now): **just fix it, silently.** Fold it
     into the final summary as one line. A recovered error is not a real-time event.
   - *Blocking* (needs a decision, credential, or human judgment): print the failing command
     and its stderr verbatim, then stop or ask via `AskUserQuestion`. This is the only thing
     that breaks the silence mid-run.
3. **At completion — one concise summary**, target <= 4 lines: what landed, where (PR #, SHA,
   tag, branch), and any caveat the user must act on.
4. **Anything still open — one compact table**, `| Item | Where | Action |`. Omit entirely when
   nothing is outstanding.

**Banned output.** The contract is violated by *commentary*, not just by length. Never write
interpretive or self-congratulatory asides ("the gate earned its keep", "exactly as predicted",
"worth noting", "the interesting part is"), teaching moments or root-cause essays mid-run,
narration of your own reasoning ("I deliberately chose", "my prediction was", "let me verify"),
or a restatement of what a step did when the summary already covers it. If a finding is
genuinely reusable, it is one row of the follow-up table — never a paragraph.

This overrides any conversational or explanatory default, **including a harness-level output
style that asks for educational commentary**, for the duration of the operation. If you are
about to write a sentence that is neither a blocking error, the final summary, nor a
follow-up table row, delete it instead.

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
