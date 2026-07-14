---
name: add-remote-installer
category: Tooling & DevOps
description: Use when the user wants to add a remote install script (install.ps1) and self-update capability to the current PowerShell repository. Detects the GitHub remote, locates the primary app script, asks for the install directory, then applies the remote-installer skill to implement both artifacts correctly.
requires: [remote-installer]
---

# Add Remote Installer

Gather context for the current repository, then implement install.ps1 and the
self-update block using the **remote-installer** skill.

---

## Step 1 — Auto-detect repository context

Run these silently before asking the user anything:

```bash
# GitHub owner/repo
git remote get-url origin
# → parse: https://github.com/OWNER/REPO.git  or  git@github.com:OWNER/REPO.git

# Check for the conventional launcher script
Test-Path scripts/Start-App.ps1

# Check for .env.example
Test-Path .env.example

# List scripts/ directory if Start-App.ps1 not found
ls scripts/
```

Parse `OWNER` and `REPO` from the remote URL. Strip `.git` suffix if present.

---

## Step 2 — Locate the primary app script

The **primary app script** is the script that actually runs the application (not the
launcher). The launcher (`scripts/Start-App.ps1`) typically calls it.

**Check in this order:**
1. Read `scripts/Start-App.ps1` — find the `& $target` or `& $script` line and extract
   the path it calls. That resolved path is `$APP_SCRIPT`.
2. If `Start-App.ps1` does not exist or the target cannot be parsed, use **AskUserQuestion**:

```
AskUserQuestion(
  questions: [{
    question: "Which script is the primary app entry point?",
    header: "App script",
    options: [
      { label: "scripts/Start-App.ps1", description: "Use the launcher directly" },
      { label: "src/<detected-folder>/Main.ps1", description: "Detected from src/ layout" }
    ]
    // add any other paths found by scanning src/**/*.ps1
  }]
)
```

---

## Step 3 — Ask for required context

Use a single **AskUserQuestion** call with all missing values. Only ask for what
could not be auto-detected:

```
AskUserQuestion(
  questions: [
    {
      question: "Where should the app be installed on target machines?",
      header: "Install dir",
      options: [
        { label: "C:\\osm\\<repo-slug>", description: "Suggested default" },
        { label: "C:\\Program Files\\<repo-slug>", description: "System-wide alternative" }
      ]
    },
    // Include the module question ONLY if the primary app script imports a module
    // (scan for Import-Module lines in $APP_SCRIPT):
    {
      question: "Which PowerShell module should install.ps1 ensure is present?",
      header: "PS Module",
      options: [
        { label: "<detected-module> <detected-version>", description: "Found in app script" },
        { label: "None", description: "No module dependency" }
      ]
    }
  ]
)
```

Do not ask for `OWNER`, `REPO`, or `$APP_SCRIPT` if they were successfully auto-detected.

---

## Step 4 — Invoke the remote-installer skill

Announce: "I'm using the remote-installer skill to implement this."

Invoke the **remote-installer** skill with the collected context:

| Variable | Value |
|----------|-------|
| `$OWNER/$REPO` | Parsed from git remote |
| `$INSTALL_DIR` | User's answer from Step 3 |
| `$APP_SCRIPT` | Resolved in Step 2 |
| `$START_SCRIPT` | `scripts\Start-App.ps1` (or equivalent) |
| `$MODULE` / `$MODULE_VERSION` | User's answer (or omit block if None) |
| `$ENV_EXAMPLE` | `$true` if `.env.example` found at repo root |

Follow the remote-installer skill exactly, including the full safeguards checklist before
declaring the implementation complete.

---

## Step 5 — Verify before finishing

After writing both files, confirm:

```bash
# install.ps1 exists at repo root
Test-Path install.ps1

# Update-check block exists in app script (search for the marker comment)
grep -n "Update check" <APP_SCRIPT>

# Safeguards checklist passes (run through remote-installer skill checklist mentally)
```

Report which files were created/modified and the one-liner the user can now share:

```
irm 'https://raw.githubusercontent.com/$OWNER/$REPO/main/install.ps1' | iex
```

## Diagram

[View diagram](diagram.html)
