---
name: statusline-install
description: >
  Sub-skill of `statusline`. Deploy the canonical, worktree/handoff-safe status-line script to
  ~/.claude/statusline.sh and wire the statusLine block into settings.json, idempotently and with
  a backup. Triggers on "install a status line", "set up my status line", "deploy the status
  line", "give me a status line that shows tokens", "fix my status line" (deploy path). Verifies
  by simulation before declaring done.
---

# Operation: install

**Goal.** Make `assets/statusline.sh` the live status line: deploy it and wire `settings.json`,
without clobbering other settings, and verify by simulation.

## Output Contract (binding — inlined)

Loadable without the parent SKILL.md. Stay silent during execution; fix recoverable errors
quietly; surface only blocking errors (print the failing command + stderr, then stop/ask via
`AskUserQuestion`). End with one ≤4-line summary (what deployed, where, backup path) plus a table
only if something is outstanding. All prompts via `AskUserQuestion`. Overrides explanatory style.

## Steps

1. **Locate the source asset.** It is `assets/statusline.sh` beside this bundle. Resolve the
   bundle root whether running from the archive (`.../claude/skills/statusline/`) or an installed
   global copy (`~/.claude/skills/statusline/`). Confirm the file exists; if not, that's a
   blocking error — stop.
2. **Target path.** Default deploy target is `~/.claude/statusline.sh` (forward slashes). If the
   user named a different path, use it.
3. **Back up any existing live script.** If the target exists, copy it to
   `<target>.bak-<n>` (increment `<n>` to avoid overwriting a prior backup — do not use a
   timestamp; the clock is not reliably available). Note the backup path for the summary.
4. **Deploy.** Copy the asset to the target. Ensure LF line endings on write (the asset is pinned
   LF in `.gitattributes`; if the copy went through a CRLF tool, normalize).
5. **Wire `settings.json` without clobbering.** Edit `~/.claude/settings.json` to contain:
   ```json
   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" }
   ```
   Merge into the existing JSON — preserve every other key. Prefer `jq`:
   ```bash
   tmp=$(mktemp)
   jq '.statusLine = {"type":"command","command":"bash ~/.claude/statusline.sh"}' \
     ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
   ```
   If `~/.claude/settings.json` is absent, create it as `{ "statusLine": {…} }`. If the target
   path differs from the default, set the command to `bash <target>` accordingly.
6. **Verify by simulation.** Pipe a worktree/handoff-shaped payload (native `context_window`
   present, `transcript_path` absent) into the wired command and confirm a token segment renders
   and exit code is 0:
   ```bash
   echo '{"model":{"display_name":"Sonnet 5"},"workspace":{"current_dir":"'"$PWD"'"},"session_id":"x","transcript_path":"/no/such.jsonl","context_window":{"total_input_tokens":84000,"context_window_size":200000,"used_percentage":42}}' | bash ~/.claude/statusline.sh; echo "exit=$?"
   ```
   Also run the empty-payload case (`echo '{}' | … ; echo $?`) and confirm exit 0. If the token
   segment is blank or exit is non-zero, that's a blocking error — stop and surface it; do not
   claim success.
7. **Summary.** One block: deployed `<asset> → <target>`, backup at `<path>` (or "no prior
   script"), settings.json wired, simulation rendered `<sample line>`. Note that a running
   Claude Code session re-reads the status line on the next render — no restart needed.
