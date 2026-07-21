---
name: github-publish
description: >
  Sub-skill of `github`. Publish a local project as a new GitHub repository with security
  hardening — gitleaks pre-commit hook, .gitignore/.gitattributes, main + dev branches, and
  branch protection rules requiring PRs on both. Triggers on "publish this repo", "push this to
  GitHub", "create a new repo for this". Honors the Output Contract inlined below.
---

# Operation: publish

**Goal.** Turn the current local project into a hardened GitHub repo: `main` (protected) + `dev`
(protected, self-merge), gitleaks secrets hook, and sane ignore/attributes files. This is the
**day-0 bookend** to the bundle's day-N ops. Obey the **Output Contract** below: silent run,
errors as they occur, one concise summary. Security hardening is never optional — even on a
"just push it quickly" request.

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

## Phase 3 — Project files

- **`.gitignore`** — if absent, write a comprehensive generic one covering: OS cruft, editor
  dirs, **secrets** (`.env*` except examples, `*.pem/*.key/*.p12`, `credentials.json`,
  `*.token`), build outputs, `node_modules/` + framework caches, Python venv/caches, coverage,
  logs/temp. If it exists, leave it.
- **`.gitattributes`** — if absent/empty, write: `* text=auto eol=lf`; CRLF for
  `*.bat/*.cmd/*.ps1`; `binary` for common media/archive/db extensions.
- **gitleaks pre-commit hook** — write `.git/hooks/pre-commit`:

  ```sh
  #!/bin/sh
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks protect --staged --redact --verbose
    if [ $? -ne 0 ]; then
      echo "Secret(s) detected by gitleaks. Commit ABORTED."
      echo "    False positive? Add an exclusion to .gitleaks.toml"
      exit 1
    fi
  else
    echo "gitleaks not found — secrets scanning skipped."
  fi
  ```

  Make it executable (`chmod +x .git/hooks/pre-commit`; on Windows ensure the `#!/bin/sh`
  shebang + LF endings).

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

## Phase 8 — Branch protection

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

**main** — require a PR with ≥1 approval, dismiss stale reviews, no direct push/force/delete:

```bash
gh api -X PUT "/repos/$REPO/branches/main/protection" --input - << 'EOF'
{ "required_status_checks": null, "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1, "dismiss_stale_reviews": true, "require_code_owner_reviews": false },
  "restrictions": null, "allow_force_pushes": false, "allow_deletions": false }
EOF
```

**dev** — same but `required_approving_review_count: 0` (self-merge). If GitHub returns **422**,
retry with count 1 and warn the user they'll need an approver (or a CODEOWNER bypass). A **403**
on a private repo means branch protection needs a paid plan — give manual UI steps.

---

## Phase 9–10 — Switch to dev, summarize

`git checkout dev`. Then the single summary block (only expected output):

```
Published <owner>/<repo> (private) — main protected (1 reviewer), dev protected (self-merge). gitleaks hook installed. On dev.
```

Offer `gh repo view --web`.

---

## Error Reference

| Error | Action |
|---|---|
| `gh repo create` name taken | suggest `<name>-2` or ask for a new name |
| Branch protection 403/422 | warn; give manual GitHub UI steps |
| `gitleaks protect` crashes | fall back to `gitleaks detect`; note it |
| Existing repo dirty | ask to commit/stash first |
| `--initial-branch` unsupported | `git init` + `git symbolic-ref HEAD refs/heads/main` |
