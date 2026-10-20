---
name: markdown-review
description: Launch prose meant for the user to read and react to (plans, proposals, reports, audits, PR/release drafts) pre-rendered via a *.review.md VSCode association, with a pandoc/browser fallback — never leave the user to open and preview it themselves
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude]
targets: markdown-review
source: ~/.claude/rules/markdown-review.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Render prose that is meant to be read

When handing the user a prose document to read and react to, **launch it rendered**. Never leave
them to open VSCode and click preview.

**Render when all three hold:**
1. It's a prose document
2. It's for the user to read and form a judgment — a plan, proposal, report, analysis, audit,
   research write-up, or a PR/release description draft
3. It's non-trivial

**Don't render — this is plumbing, not prose:**
- Memory files (`~/.claude/projects/*/memory/`)
- Skill-managed caches — `what-next.md`, `TASKS.md`, `STATUS.md`
- Command / skill definitions (reviewed as code)
- Committed docs that go through the normal PR-diff review

One-line test: *"Do I want them to read this and react — or is it plumbing?"* Read-and-react → render.

## Mechanism — VSCode (preferred)

Name the file `*.review.md` and open it with `code`:

```bash
code /path/to/thing.review.md
```

It opens **pre-rendered** — no preview click. This works because the VSCode user settings
(`%APPDATA%\Code\User\settings.json`) contain:

```json
"workbench.editorAssociations": {
    "*.review.md": "vscode.markdown.preview.editor"
}
```

**Why the `*.review.md` glob and not `*.md`:** the association hijacks the default editor for
whatever it matches. Scoped to `*.review.md`, review docs render while ordinary markdown stays
editable as text. Binding it to `*.md` would render every markdown file and break editing.

The filename *is* the API — `.review.md` means "read this", plain `.md` means "edit this".

Verified working 2026-07-14 on VSCode 1.127.0: `vscode.markdown.preview.editor` is a real
registered custom-editor id. Do not assume otherwise and revert it — it has been tested.

## Fallback — browser (non-VSCode contexts)

`~/.claude/scripts/Show-Markdown.ps1` — pandoc → self-contained, dark-mode-aware HTML → browser.

```powershell
pwsh ~/.claude/scripts/Show-Markdown.ps1 <path.md>
pwsh ~/.claude/scripts/Show-Markdown.ps1 <path.md> -NoOpen   # render only, print the HTML path
```

Requires pandoc on PATH. Output is written to `$env:TEMP\claude-md-preview\` and is stable per
source path (idempotent, safe to re-run).

**Don't use `-Editor`** — it opens the rendered HTML *source* in a VSCode tab rather than a
rendered page. For VSCode, always use the `*.review.md` path above instead.
