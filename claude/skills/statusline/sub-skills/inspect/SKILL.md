---
name: statusline-inspect
description: >
  Sub-skill of `statusline`. Read-only report of the live Claude Code status-line configuration —
  which settings layer defines it, the resolved script and what token source it uses, dependency
  availability, and a live simulation — ending with a recommendation. Triggers on "what is my
  status line", "inspect my status line", "why is my status line blank", "what does my status
  line show". Never mutates settings or the script.
---

# Operation: inspect

**Goal.** Report exactly what status line is wired up right now and whether it can show token
consumption. Strictly read-only: never write settings.json, never touch the script.

## Output Contract (binding — inlined, adapted for a read-only report)

`/inspect-statusline` may load this file without the parent `statusline` SKILL.md in context, so
the contract is restated here. Stay silent while gathering (no "let me check…"); a failed probe
degrades its own line with a one-word reason, not the whole report; the deliverable **is** the
report — there is no separate summary layered on top. Close with a single `AskUserQuestion`
offering the top recommended follow-up only if one applies. Banned: interpretive asides, teaching
essays mid-run, narration of your own reasoning. Overrides any explanatory output style.

## Steps

1. **Which layer defines `statusLine`.** Read, in precedence order (highest first): the current
   repo's `.claude/settings.local.json`, `.claude/settings.json`, then `~/.claude/settings.json`.
   Report the **first** that contains a `statusLine` key (that one wins) and quote its `command`.
   If none define it, report "no status line configured" and recommend `/install-statusline`.
2. **Resolve the script.** From the winning `command`, extract the script path (e.g. `bash
   ~/.claude/statusline.sh`). Read it. Report: language, and — the key question — **what token
   source it uses**: does it reference `.context_window` (native stdin, robust) or only parse the
   transcript (`transcript_path` / `<session_id>.jsonl`)? A transcript-only script is the root
   cause of blank tokens in worktree/handoff sessions — call that out.
3. **Dependencies.** Check the tools the script needs are on PATH (`jq`, `git`, `bash`, and
   `awk`; only check `node`/`ccusage` if the script actually uses them). Report each present/missing.
4. **Live simulation.** Pipe a worktree/handoff-shaped mock payload (native `context_window`
   present, `transcript_path` pointing at a non-existent file) into the command and capture
   stdout + exit code:
   ```bash
   echo '{"model":{"display_name":"Sonnet 5"},"workspace":{"current_dir":"'"$PWD"'"},"session_id":"x","transcript_path":"/no/such.jsonl","context_window":{"total_input_tokens":84000,"context_window_size":200000,"used_percentage":42}}' | <command>; echo "exit=$?"
   ```
   Report whether a token segment rendered. A blank token segment here (with `context_window`
   present) is the smoking gun for a transcript-only script.
5. **Report + recommend.** One structured readout of the above, then a recommendation:

   | Finding | Recommend |
   |---|---|
   | No `statusLine` configured | `/install-statusline` |
   | Configured but transcript-only (blanks on worktree/handoff) | `/modify-statusline` (or `/install-statusline` to redeploy the canonical asset) |
   | Live script differs from the archive asset | `/audit-statusline` then `/modify-statusline` |
   | Configured, reads `context_window`, simulates cleanly | nothing — it's healthy |

   Offer to launch the top recommendation via `AskUserQuestion`; never launch it yourself.
