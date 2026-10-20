# Claude Code status-line payload & failure reference

Loaded on demand by the `statusline` skill and its sub-skills. Verified against Claude Code
v2.1.x. Read this when authoring or debugging a status-line script — especially the **Token /
context fields** and **Failure modes** sections.

## Table of contents
- [1. Settings schema](#1-settings-schema)
- [2. Stdin payload](#2-stdin-payload)
- [3. Token / context / cost fields](#3-token--context--cost-fields)
- [4. Ways to display token consumption](#4-ways-to-display-token-consumption)
- [5. Failure modes](#5-failure-modes)
- [6. Cross-platform execution](#6-cross-platform-execution)

---

## 1. Settings schema

`statusLine` lives in a `settings.json` layer. Precedence: **project `.claude/settings.local.json`
> project `.claude/settings.json` > user `~/.claude/settings.json`**. The highest layer that
defines `statusLine` wins outright (it is not deep-merged field-by-field).

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 5,
    "hideVimModeIndicator": false
  }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | string | yes | Only `"command"` is supported today. |
| `command` | string | yes | Shell command or script path. On Windows **use forward slashes** — backslashes are consumed as escapes before the shell sees them. |
| `padding` | number | no | Extra horizontal spacing. Default `0`. |
| `refreshInterval` | number | no | Re-run every N seconds (min 1). Event-driven otherwise. Use for time/idle updates. |
| `hideVimModeIndicator` | boolean | no | Suppress built-in `-- INSERT --` when the script renders `vim.mode` itself. |

---

## 2. Stdin payload

Claude Code pipes this JSON to the command's **stdin** on every render. Abridged to the fields a
token-aware status line cares about (see the CLI docs for the full set — `pr`, `worktree`,
`rate_limits`, `vim`, `agent`, `effort`, `output_style`, etc.):

```json
{
  "cwd": "/current/dir",
  "session_id": "abc123",
  "transcript_path": "/path/to/<session_id>.jsonl",
  "model": { "id": "claude-opus-4-8", "display_name": "Opus" },
  "workspace": { "current_dir": "/current/dir", "project_dir": "/project/dir" },
  "version": "2.1.90",
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 15500,
    "total_output_tokens": 1200,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false
}
```

**Conditionally absent or null:**
- `context_window` and `context_window.current_usage` are **`null` before the first API response**
  and immediately after `/compact` until the next response. A script must tolerate this and show
  no token segment (not `null`, not an error).
- `transcript_path` may point to a file **not yet on disk**, especially in `/handoff`-spawned and
  worktree sessions. Those sessions may have only a `subagents/` directory and **no flat
  `<session_id>.jsonl` at all** for part of their life.

---

## 3. Token / context / cost fields

**This is the crux.** The recurring "no token count" problem traces to which fields actually
carry token data.

| Path | Meaning |
|---|---|
| `context_window.used_percentage` | Pre-computed context fill %, 0–100. **Preferred gauge.** |
| `context_window.total_input_tokens` | All input tokens in context now (fresh + cache write + cache read). |
| `context_window.total_output_tokens` | Output tokens from the **most recent** response (not cumulative). |
| `context_window.context_window_size` | Max window (200000, or 1000000 for extended-context models). |
| `cost.total_cost_usd` | Client-side USD estimate for the session. **No token counts live here** — cost is USD + duration only. |
| `exceeds_200k_tokens` | Boolean; total exceeded 200k on the most recent response. |

**Not in the payload — you must derive these yourself by parsing `transcript_path`:**
- Cumulative input/output tokens across the whole session.
- Per-call token breakdowns.
- Cache-hit USD savings.

---

## 4. Ways to display token consumption

**Method A — native stdin fields (preferred, robust).** Read `context_window.used_percentage`
and `context_window.total_input_tokens` directly. Present after the first API response
**regardless of any transcript file**, so it works in worktree/handoff sessions where
transcript-parsing cannot. This is what `assets/statusline.sh` does first.

**Method B — parse `transcript_path` (fallback / for cumulative totals).** Each line is a JSON
event; assistant messages carry `.message.usage`. Sum across main-thread records
(`.isSidechain == false`). Needed only for cumulative session totals or on a CLI too old to send
`context_window`. Resolve the file by **`session_id` exact match** — never "newest `.jsonl` in the
folder" (that shows a *different* session's number).

**Method C — `ccusage` (third-party, not built in).** `npx ccusage statusline` reads the
transcript and formats usage. Adds an npm dependency and inherits the same transcript-resolution
fragility as Method B. Not used by this skill's default script; documented only as an option.

**Not a status-line mechanism:** the `/context` command prints to the chat, not to the script's
stdout. Don't conflate them.

---

## 5. Failure modes

Ranked by how often they cause "no token count" specifically:

1. **Reading a token field that doesn't exist for this session's state.** Script assumes a
   transcript that isn't on disk (worktree/handoff), or reads `context_window` before the first
   response → renders blank. *Fix:* prefer `context_window`; tolerate its absence; fall back to a
   session_id-keyed transcript; show nothing rather than a wrong number.
2. **"Newest `.jsonl` in dir" fallback.** Paints a prior session's ending context (150k+) onto a
   fresh session. *Fix:* never do this; key strictly on `session_id`.
3. **CRLF corruption of a parsed number.** A `\r` from a CRLF stream survives `read`/`jq` on the
   last field and fails numeric tests silently. *Fix:* sanitize every value to digits
   (`${v//[!0-9]/}`).
4. **Non-zero exit code.** Any exit ≠ 0 makes Claude Code hide the output. *Fix:* `set -uo
   pipefail` (not `-e`), guard every command, test `echo '{}' | script; echo $?` → 0.
5. **Output to stderr instead of stdout.** Only stdout renders.
6. **Windows path backslashes / PowerShell quoting** in the `command` string. *Fix:* forward
   slashes always.
7. **`disableAllHooks` / `allowManagedHooksOnly` / untrusted workspace** silently suppress the
   status line entirely. *Fix:* check these before assuming the script is at fault.
8. **Slow script cancelled mid-render** (large-repo `git`, transcript re-parse every render).
   *Fix:* keep it under ~100ms; cache expensive work keyed on `session_id`.

**Debugging:** `claude --debug 2>&1 | grep -i statusline` surfaces exit code + stderr from the
first invocation. Or pipe a mock payload straight into the `command`:
`echo '<payload>' | bash ~/.claude/statusline.sh`.

---

## 6. Cross-platform execution

- **Windows:** the `command` runs via **Git Bash if installed**, else PowerShell. Use forward
  slashes in every path. `~` expands to the Windows home dir. A `.ps1` is invoked as
  `powershell -NoProfile -File C:/Users/you/.claude/statusline.ps1`.
- **macOS / Linux:** bash/python/node run directly via shebang.
- **Terminal size:** Claude Code sets `COLUMNS` / `LINES` env vars (v2.1.153+) — read those
  instead of `tput cols`, which fails in captured-output mode.
