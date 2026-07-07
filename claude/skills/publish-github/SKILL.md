---
name: publish-github
description: >
  End-to-end workflow for publishing a local project as a new GitHub repository with
  security hardening, structured branching, and branch protection rules. Use this skill
  whenever the user wants to create a GitHub repo, publish a project to GitHub, initialize
  git and push to remote, run `gh repo create`, set up branch protection, or types
  `/publish-github`. This skill covers: gitleaks secrets-detection hook, .gitignore and
  .gitattributes creation, `main`/`dev` branch setup, and GitHub branch protection rules
  that enforce PRs on both branches. Always invoke this skill — even if the user says
  "just push to GitHub quickly" — because security hardening and branch protection should
  never be optional.
status: deprecated
---

> **Deprecated — folded into the `github` skill.** Use `/publish-github` from the `github`
> bundle (`claude/skills/github/`), which runs a leaner version of this workflow under the
> parent skill's minimal-output contract. This file is retained for history only.

# Publish to GitHub

Complete workflow to initialize a local project as a GitHub repository with:
- Secrets detection via gitleaks (pre-commit hook)
- Comprehensive `.gitignore` and `.gitattributes`
- `main` as the protected primary branch
- `dev` branch for integration work
- Branch protection rules: both branches require PRs

Work through these phases in order. Stop and report clearly if any prerequisite fails.

---

## Phase 1 — Prerequisites

### 1.1 Check `gh` CLI

```bash
gh --version
```

If missing, provide platform-specific install instructions and **abort** — the user must
install `gh` before continuing:

| OS | Command |
|----|---------|
| Windows | `winget install GitHub.cli` or `choco install gh` or `scoop install gh` |
| macOS | `brew install gh` |
| Linux | `sudo apt install gh` (Debian/Ubuntu) — or see https://cli.github.com |

After install, tell the user to rerun the command.

### 1.2 Verify `gh` authentication

```bash
gh auth status
```

If not authenticated, initiate login:

```bash
gh auth login
```

Walk the user through the prompts. If they cancel or it fails, **abort** with:
> "GitHub authentication is required. Run `gh auth login` manually and try again."

### 1.3 Check and install `gitleaks`

```bash
gitleaks version
```

If missing, install automatically based on detected OS:

| OS | Command |
|----|---------|
| Windows (choco) | `choco install gitleaks -y` |
| Windows (scoop) | `scoop install gitleaks` |
| Windows (winget) | `winget install Gitleaks.Gitleaks` |
| macOS | `brew install gitleaks` |
| Linux | Download the latest binary from https://github.com/gitleaks/gitleaks/releases |

Verify the install succeeded with `gitleaks version`. If it still fails after the install
attempt, continue but note in the final summary that secrets scanning will warn rather
than block until gitleaks is installed.

---

## Phase 2 — Git Initialization

### 2.1 Detect existing `.git` directory

Check whether `.git/` already exists in the current directory.

**No `.git/` found — initialize a new repo:**
```bash
# Git 2.28+
git init --initial-branch=main

# Older git (fallback)
git init
git symbolic-ref HEAD refs/heads/main
```

**`.git/` found — adapt the existing repo:**
1. Check the current default branch: `git symbolic-ref --short HEAD`
2. If the default branch is `master`, rename it — but the method depends on whether
   commits exist:
   ```bash
   # If commits exist:
   git branch -m master main

   # If NO commits exist (fresh repo, `git branch` shows nothing):
   git symbolic-ref HEAD refs/heads/main
   ```
3. Confirm the repo is in a workable state (no ongoing rebase/merge in progress).
4. Run a gitleaks history scan to check for secrets already in commit history:
   ```bash
   gitleaks detect --redact --verbose
   ```
   If secrets are found, warn the user — they should be rotated before publishing. The
   user can proceed or abort; don't block automatically since secrets may already be
   revoked. Note: `gitleaks detect` scans history; `gitleaks protect --staged` (the
   hook) only scans new staged changes.

---

## Phase 3 — Project Files

### 3.1 Create `.gitignore`

If `.gitignore` already exists, leave it in place (don't overwrite the developer's
customizations). If it does not exist, create a comprehensive generic one:

```gitignore
# ── OS ──────────────────────────────────────────────────────────
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
Thumbs.db
ehthumbs.db
desktop.ini

# ── Editors ─────────────────────────────────────────────────────
.vscode/
.idea/
*.swp
*.swo
*~
.project
.classpath
.settings/
*.sublime-workspace
*.sublime-project
.vim/

# ── Environment & Secrets ────────────────────────────────────────
.env
.env.*
!.env.example
!.env.sample
*.pem
*.key
*.p12
*.pfx
*.cer
*.crt
secrets.json
secrets.yaml
secrets.yml
credentials.json
.secret
*.secret
.token
*.token
.netrc
*.kubeconfig

# ── Build outputs ────────────────────────────────────────────────
dist/
build/
out/
target/
bin/
obj/
*.o
*.obj
*.exe
*.dll
*.so
*.dylib
*.pyc
*.pyo
__pycache__/
*.class
*.jar
.gradle/
*.war

# ── JS / Node ────────────────────────────────────────────────────
node_modules/
.pnp
.pnp.js
.yarn/cache
.yarn/unplugged
.yarn/build-state.yml
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
.next/
.nuxt/
.svelte-kit/
.output/
.vercel/

# ── Python ───────────────────────────────────────────────────────
*.egg-info/
.eggs/
pip-log.txt
pip-delete-this-directory.txt
.venv/
venv/
ENV/
.pytest_cache/
.mypy_cache/
.ruff_cache/

# ── Coverage & testing ───────────────────────────────────────────
coverage/
.nyc_output/
*.lcov
htmlcov/
.coverage
.coverage.*

# ── Logs & temp ──────────────────────────────────────────────────
*.log
logs/
tmp/
temp/
*.tmp
*.bak
*.orig
*.cache
.cache/
```

### 3.2 Create `.gitattributes`

Create `.gitattributes` (overwrite if it exists and is empty; otherwise skip):

```gitattributes
# Normalize all text files to LF on commit
* text=auto eol=lf

# Windows scripts — keep CRLF
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf

# Binary files — no conversion
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.webp binary
*.avif binary
*.woff binary
*.woff2 binary
*.ttf binary
*.otf binary
*.eot binary
*.pdf binary
*.zip binary
*.gz binary
*.tar binary
*.7z binary
*.rar binary
*.mp4 binary
*.mp3 binary
*.wav binary
*.ogg binary
*.db binary
*.sqlite binary
*.sqlite3 binary
*.exe binary
*.dll binary
*.so binary
*.dylib binary
*.a binary
*.lib binary
```

### 3.3 Install gitleaks pre-commit hook

Create `.git/hooks/pre-commit` with this content:

```sh
#!/bin/sh
# ── Secrets Detection: gitleaks ─────────────────────────────────
# Blocks commits that contain secrets. Install gitleaks to enable:
# https://github.com/gitleaks/gitleaks

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect --staged --redact --verbose
  EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌  Secret(s) detected by gitleaks. Commit ABORTED."
    echo "    Remove the secret(s) shown above before committing."
    echo "    False positive? Add an exclusion to .gitleaks.toml"
    echo "    Docs: https://github.com/gitleaks/gitleaks#configuration"
    exit 1
  fi
else
  echo "⚠️  WARNING: gitleaks not found — secrets scanning skipped."
  echo "    Install gitleaks: https://github.com/gitleaks/gitleaks"
fi
```

After writing the file, make it executable:
- Unix/macOS: `chmod +x .git/hooks/pre-commit`
- Windows: Git for Windows reads the file directly via Git Bash — no chmod needed, but
  ensure the shebang (`#!/bin/sh`) is present and the file has Unix line endings.

---

## Phase 4 — Determine Visibility

If the user's original request already contains the word **"public"** or **"private"**
(case-insensitive), use that value and skip this step.

Otherwise, use the `AskUserQuestion` tool:

- **Question**: "Should the GitHub repository be public or private?"
- **Options**:
  - `Public` — Anyone on the internet can see the code
  - `Private` — Only you and invited collaborators can see it

---

## Phase 5 — Initial Commit

First, verify git identity is configured — a missing identity causes `git commit` to fail
with a fatal error:

```bash
git config user.email
git config user.name
```

If either is empty, prompt the user to set them:

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Do not proceed to the commit until identity is confirmed.

Then confirm we're on `main`:

```bash
git checkout main 2>/dev/null || true
```

If the git repo has no commits yet, stage everything and create one:

```bash
git add -A
git commit -m "chore: initial commit"
```

If commits already exist, skip the commit but still verify the current branch is `main`
before moving to Phase 6.

---

## Phase 6 — Create GitHub Repository & Push `main`

Determine the repo name from the current directory name. If the name contains spaces
or special characters, sanitize it (replace spaces with hyphens, strip non-alphanumeric
characters except hyphens and underscores).

```bash
gh repo create <repo-name> --[public|private] --source=. --remote=origin --push
```

This single command: creates the GitHub repo, sets `origin`, and pushes `main`.

---

## Phase 7 — Create `dev` Branch

```bash
git checkout -b dev
git push -u origin dev
```

---

## Phase 8 — Branch Protection Rules

Get the owner/repo slug:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### 8.1 Protect `main`

Requires a PR (any branch) with at least 1 approving review before merging into `main`.
Stale reviews are dismissed when new commits are pushed. No direct pushes allowed.
`enforce_admins: false` lets the repo admin bypass in genuine emergencies — this is the
GitHub default behavior. Note: branch protection rules restrict the *target* branch but
cannot enforce which *source* branch a PR must come from — that is a workflow convention,
not a technical guard.

```bash
gh api -X PUT "/repos/$REPO/branches/main/protection" \
  --input - << 'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

### 8.2 Protect `dev`

Goal: no direct pushes allowed, but the PR author can self-merge without a reviewer.

First, attempt `required_approving_review_count: 0`. The GitHub REST API accepts 0 even
though the UI enforces a minimum of 1 — this allows PRs with no approvals required:

```bash
gh api -X PUT "/repos/$REPO/branches/dev/protection" \
  --input - << 'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

**If the API returns a 422 error** (GitHub rejected count 0), fall back to count 1 and
warn the user:

```
⚠️  GitHub requires at least 1 reviewer for dev branch protection on this plan.
    Dev branch is protected but you'll need someone to approve your PRs — or add
    yourself as a CODEOWNER and enable "Allow specified actors to bypass required
    pull requests" in Settings → Branches → dev.
```

> **Note on private repos with free GitHub plans**: Branch protection rules require
> GitHub Pro, Team, or Enterprise for private repositories. If the API call returns a
> 403, tell the user what to configure manually:
> GitHub → Repository → Settings → Branches → Add branch protection rule

---

## Phase 9 — Switch to `dev`

```bash
git checkout dev
```

(You should already be on `dev` from Phase 7, but confirm.)

---

## Phase 10 — Summary

Print a clear success message, adapting the file status lines to reflect what actually
happened (created vs. already existed):

```
✅  Repository published!

  GitHub:     https://github.com/<owner>/<repo>
  Visibility: [public | private]

  Branches:
    main  ──  protected · requires PR · 1 reviewer minimum
    dev   ──  protected · requires PR · self-merge allowed

  Local:      switched to branch 'dev'

  Security:
    [✓ created | ✓ already existed] .gitignore
    [✓ created | ✓ already existed] .gitattributes
    ✓ gitleaks pre-commit hook installed

  Workflow:
    1. Create feature branches off dev
    2. PR feature → dev  (no review required, self-merge OK)
    3. PR dev → main     (requires 1 reviewer)
```

Then offer to open the repo in the browser:

```bash
gh repo view --web
```

---

## Error Reference

| Error | Action |
|-------|--------|
| `gh repo create` fails: name taken | Suggest `<name>-2` or ask the user for a new name |
| Branch protection 403/422 | Warn; provide manual setup steps for GitHub UI |
| `gitleaks protect` crashes (version mismatch) | Fall back to `gitleaks detect`; note the issue |
| Existing repo has uncommitted changes | Warn; ask user to commit or stash before proceeding |
| `git init --initial-branch` flag unsupported | Fall back to `git init` + `git symbolic-ref HEAD refs/heads/main` |

## Diagram

[View diagram](diagram.html)
