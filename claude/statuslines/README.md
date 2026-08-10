# statuslines/

Claude Code status-line scripts. A status line is a shell script Claude Code runs on every
render; it receives a JSON blob on stdin and prints one line to stdout. Wire one up in
`~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" }
```

## `statusline.sh`

Renders `<ctx> ctx · <out> out  |  <branch> <status>`:

| Field | Meaning |
|---|---|
| `ctx` | Current context-window fill — sum of the last main-thread `usage` record (`input + cache_read + cache_creation + output`). Colored against a 200k window: green < 50%, yellow 50–80%, red > 80%. This is the "how close to compaction" gauge. |
| `out` | Cumulative `output_tokens` across the whole session — tracks work actually produced. |
| `branch` | Current git branch, truncated to 25 chars. |
| `status` | `*` for uncommitted changes, `↑N`/`↓N` for ahead/behind upstream. |

### Design notes

- **Session identity comes from `session_id`**, not the newest transcript in the folder. The
  transcript filename is always `<session_id>.jsonl`; resolving by that key prevents a fresh or
  `/handoff`-spawned session from displaying a *prior* session's ending context (a stale 150k+).
  When the current session's transcript isn't on disk yet, the token fields are omitted rather
  than borrowing another session's number.
- **Only main-thread records count** (`isSidechain == false`) — a subagent's context is not this
  session's fill.
- **Integers are sanitized to digits** (`${v//[!0-9]/}`) before arithmetic, guarding against a
  stray `\r` from CRLF streams on Windows/Git-Bash.
