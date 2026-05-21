---
name: init-project
description: Use when starting a new project from scratch or retrofitting the project-manager workflow onto an existing repo. Scaffolds the docs/ tree, copies canonical templates, installs agent-enforcement artifacts (AGENTS.md, CLAUDE.md fragment, pre-commit guard, Claude Code hook, PR template, ROADMAP), and seeds INITIAL_PROMPT.md. Idempotent: re-running only fills gaps.
---

# Init Project

Bootstraps a repository so that every agent and operator who touches it is funneled through the `project-manager` workflow. Produces a complete set of artifacts in one pass and is **safe to re-run** — existing files are never overwritten without explicit user authorization through `AskUserQuestion`.

**When to use:**

- Starting a brand-new project where no `docs/` structure exists
- Adopting `project-manager` in an existing repo that has been working without it
- Recovering scaffolding after partial deletion

**When not to use:**

- The repo already has a healthy `docs/features/`, `docs/plans/`, `docs/tasks/` and `AGENTS.md` — use `/reinit` to normalize content instead
- You only want to add a new spec — use `/add-feature`

---

## Discovery and Authorization (Phase 0)

Before writing anything:

1. **Detect existing state.** Glob each of these and record which exist:
   - `docs/INITIAL_PROMPT.md`
   - `docs/features/template.md`, `docs/features/README.md`
   - `docs/plans/template.md`
   - `docs/tasks/template.md`
   - `docs/tasks/active/`, `docs/tasks/archive/`, `docs/tasks/locks/`, `docs/tasks/logs/`
   - `docs/issues/`, `docs/workflow/SDLC.md`, `docs/workflow/FOCUS.md`, `docs/workflow/INDEX.md`
   - `AGENTS.md`, `CLAUDE.md`, `ROADMAP.md`
   - `scripts/guard-pm-flow.ps1`
   - `.git/hooks/pre-commit`
   - `.claude/settings.json`, `.claude/settings.local.json`
   - `.github/pull_request_template.md`

2. **Detect project name.** Try in order: `package.json` `name` field, top-level folder name, `git config remote.origin.url` basename. Use `AskUserQuestion` to confirm.

3. **Detect whether the repo is git-initialized.** Run `git rev-parse --git-dir`. If not a repo, ask the user whether to run `git init` before continuing (this affects whether the Git pre-commit hook can be installed).

4. **Use `AskUserQuestion` to confirm the enforcement layers to install.** Default-select all four:
   - AGENTS.md + CLAUDE.md fragment (soft guidance, always recommended)
   - Pre-commit guard script + Git hook (medium; requires `pwsh` or `powershell`)
   - Claude Code PreToolUse hook in `.claude/settings.json` (only meaningful if user uses Claude Code)
   - PR template + ROADMAP.md (only meaningful if hosted on GitHub)

5. **Use `AskUserQuestion` to ask for the INITIAL_PROMPT seed.** Offer:
   - (a) "I have product intent ready — paste it now" (preview opens an `AskUserQuestion` follow-up to capture the text)
   - (b) "Use a stub and I'll fill in `docs/INITIAL_PROMPT.md` myself" (Recommended)
   - (c) "Skip — project is too early to define"

---

## Scaffolding (Phase 1)

For every directory and file from the discovery list that does **not** already exist, create it. For each path that **does** exist, follow these rules:

- **`docs/INITIAL_PROMPT.md`** — Never overwrite. If it exists, leave it. If the user pasted product intent in Phase 0(a), write only when the file is absent. If the user picked Phase 0(a) and the file exists, use `AskUserQuestion` to choose between (i) leave existing, (ii) write to `docs/INITIAL_PROMPT.md.new` for manual merge.
- **`docs/features/template.md`** — If absent, copy from `references/feature-spec-template.md` in the skill bundle. If present, diff: if different, ask via `AskUserQuestion` whether to overwrite, keep, or write `.new` alongside.
- **`docs/plans/template.md`, `docs/tasks/template.md`** — Same diff-and-ask flow.
- **`AGENTS.md`** — If absent, copy from `references/init-project/AGENTS.md.template` with `{{PROJECT_NAME}}` substituted. If present, check whether it already contains the marker `<!-- BEGIN project-manager fragment -->`. If yes, do nothing. If no, **append** the contents of `CLAUDE_FRAGMENT.md.template` (yes, named for CLAUDE but the same fragment is valid for AGENTS); never replace existing content.
- **`CLAUDE.md`** — Same as AGENTS.md: append the fragment if the marker is absent, otherwise no-op.
- **`scripts/guard-pm-flow.ps1`** — If absent, copy verbatim from `references/init-project/guard-pm-flow.ps1.template` (no substitutions). If present, leave it.
- **`.git/hooks/pre-commit`** — If absent, copy verbatim from `references/init-project/pre-commit-hook.template`. Set executable bit on POSIX (`git update-index --chmod=+x` is not needed for hooks — just `chmod +x` via shell). If present, leave it and warn the user to manually wire in `scripts/guard-pm-flow.ps1`.
- **`.claude/settings.json`** — JSON merge. Read the existing file (or `{}`), shallow-merge the `hooks.PreToolUse` array (do not duplicate entries with the same `command`). Write back with 2-space indentation.
- **`.github/pull_request_template.md`** — If absent, copy from template (no substitution). If present, leave it.
- **`ROADMAP.md`** — If absent, copy from template with substitutions. If present, leave it.
- **`docs/workflow/SDLC.md`** — If absent, copy from template. If present, leave it.
- **`docs/workflow/FOCUS.md`** — If absent, copy from template. If present, leave it.
- **`docs/workflow/INDEX.md`** — If absent, copy from template. If present, leave it.
- **`docs/tasks/locks/`** — Create the directory and seed `.gitkeep`. Lock records are runtime
  artifacts using `references/init-project/task-lock.md.template` as their shape.
- **`docs/tasks/logs/`** — Create the directory and seed `.gitkeep`. Task logs use
  `references/init-project/task-log.md.template` as their shape.
- **`docs/features/README.md`** — If absent, copy from template. If present, leave it.

Always create directory parents implicitly. Always preserve LF line endings on POSIX-targeted files and CRLF on Windows-only files.

---

## Template Substitution (Phase 2)

After Phase 1, all files are on disk. Substitute the following tokens **in newly created files only** (do not touch pre-existing files):

| Token             | Replaced with                                        |
|-------------------|------------------------------------------------------|
| `{{PROJECT_NAME}}` | Project name from Phase 0                            |
| `{{TODAY}}`        | Current date in `YYYY-MM-DD`                         |
| `{{author}}`       | `git config user.name` if available, else `unknown`  |

Other tokens (`{{feature-slug}}`, `{{XX-CAP-NN}}`, etc.) are intentionally left in templates — they'll be filled by `/add-feature` or `/init-features` later.

---

## Wiring (Phase 3)

1. **Make the pre-commit hook executable.** On POSIX, `chmod +x .git/hooks/pre-commit`. On Windows-Git, the executable bit is implicit; verify the file has no UTF-8 BOM (the BOM breaks `sh` shebang parsing).

2. **Verify PowerShell is available.** Run `pwsh -v` then fall back to `powershell -v`. If neither works, tell the user the guard will be inert and suggest installing PowerShell 7+.

3. **Test the guard.** Run `pwsh -NoProfile -File scripts/guard-pm-flow.ps1` once with no staged changes — it should exit 0 silently. Report the exit code to the user.

4. **`.gitignore` entry.** Append `docs/issues/guard-bypass.log` to the project's `.gitignore` if not already present (creates one if absent). Bypass logs are local-only, not for sharing.

---

## Reporting (Phase 4)

Print a structured summary to the user:

```
Init Project Report — {{PROJECT_NAME}}

Created:
  docs/INITIAL_PROMPT.md          (stub)
  docs/features/template.md
  docs/features/README.md
  docs/plans/template.md
  docs/tasks/template.md
  docs/tasks/active/.gitkeep
  docs/tasks/archive/.gitkeep
  docs/tasks/locks/.gitkeep
  docs/tasks/logs/.gitkeep
  docs/issues/.gitkeep
  docs/workflow/SDLC.md
  docs/workflow/FOCUS.md
  docs/workflow/INDEX.md
  AGENTS.md
  ROADMAP.md
  scripts/guard-pm-flow.ps1
  .git/hooks/pre-commit
  .github/pull_request_template.md
  .claude/settings.json            (merged: PreToolUse hook added)

Appended:
  CLAUDE.md                        (project-manager fragment)

Skipped (already present):
  ...

Next steps:
  1. Fill in docs/INITIAL_PROMPT.md with product intent.
  2. Run /init-features to capture feature specs.
  3. Run /continue-tasks to enter the orchestration loop.
  4. Verify the pre-commit guard with: git commit --allow-empty -m "chore: verify guard"
```

If anything failed (e.g. the guard test exited non-zero, or `.claude/settings.json` was malformed), enumerate failures separately and stop. Do not pretend partial success is total success.

---

## Idempotency Contract

Running `/init-project` twice produces the same result as running it once. Specifically:

- Existing files are never overwritten silently
- The CLAUDE.md / AGENTS.md fragment is detected by marker comments and not appended twice
- `.claude/settings.json` hook entries are deduped by `command` string
- Pre-commit hook is left alone if present (the user may have customized it)

If a user reports "init keeps failing on file X", the fix is almost always to delete that one file and re-run; never to nuke the whole tree.

---

## Constraints

- **Never use plain-text prompts to the user.** Every operator decision must go through `AskUserQuestion`.
- **Never delete files.** Even on overwrite, write the new content to `<original>.new` and let the user merge.
- **Never assume the repo is greenfield.** Always Phase 0 first.
- **Never embed today's date as a literal in a template.** Use `{{TODAY}}` and substitute at copy time, so re-running the init in 6 months produces correct dates without template edits.

---

## Red Flags — STOP

- Trying to install the Claude Code hook without `.claude/` directory present and the user not using Claude Code → ask whether to skip that enforcement layer
- About to overwrite an existing `CLAUDE.md` → never. Append-with-marker only.
- About to write a feature spec → wrong skill. `/init-project` never creates feature specs; that's `/init-features` or `/add-feature`.
- About to run `git init` without asking → no. Confirm via `AskUserQuestion`.
