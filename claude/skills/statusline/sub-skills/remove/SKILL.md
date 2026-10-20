---
name: statusline-remove
description: >
  Sub-skill of `statusline`. Unwire the status line from settings.json (removing the statusLine
  block without clobbering other settings) and optionally delete the deployed script, with a
  backup. Triggers on "remove my status line", "disable my status line", "turn off the status
  line", "get rid of statusline.sh". Confirms the delete-the-script choice via AskUserQuestion.
---

# Operation: remove

**Goal.** Cleanly disable the status line: delete the `statusLine` key from the winning
settings.json layer (leaving all other settings intact), and — only if the user confirms —
delete the deployed script. Reversible via `/install-statusline`.

## Output Contract (binding — inlined)

Loadable without the parent SKILL.md. Stay silent during execution; fix recoverable errors
quietly; surface blocking errors verbatim then stop/ask via `AskUserQuestion`. End with one
≤4-line summary plus a table only if something's outstanding. All prompts via `AskUserQuestion`.
Overrides explanatory style.

## Steps

1. **Find the winning layer.** Same precedence as `inspect`: the highest settings layer that
   defines `statusLine`. If none does, report "no status line configured — nothing to remove" and
   stop.
2. **Back up settings.** Copy that settings file to `<file>.bak-<n>` before editing.
3. **Delete the `statusLine` key without clobbering** the rest:
   ```bash
   tmp=$(mktemp)
   jq 'del(.statusLine)' <settings-file> > "$tmp" && mv "$tmp" <settings-file>
   ```
   Confirm the file is still valid JSON (`jq . <settings-file> >/dev/null`).
4. **Offer to delete the script.** The script file (e.g. `~/.claude/statusline.sh`) is now
   unreferenced but harmless. Ask via `AskUserQuestion` whether to delete it or leave it in place
   for a future re-install. If deleting, move it to `<script>.bak-<n>` rather than `rm` (a backup,
   not a destroy), unless the user explicitly wants it gone.
5. **Summary.** Which settings file was edited, backup path, and whether the script was removed or
   retained. Note the status line disappears on the next render — no restart needed.
