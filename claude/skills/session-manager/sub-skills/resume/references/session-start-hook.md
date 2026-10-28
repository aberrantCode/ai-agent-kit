# Optional SessionStart hook: inject the newest handoff/checkpoint

**Documentation only. Nothing here is installed by this bundle.** Copy it into your own
settings if you want it.

Purpose: when a Claude Code session starts in a repo, find the newest of
`_project_specs/session/current-state.md` (written by [checkpoint](../../checkpoint/SKILL.md))
and `docs/PROMPTS/*.md` (handoff prompts), and inject it as additional context so a fresh
session already knows where the last one stopped.

## settings.json (user `~/.claude/settings.json` or project `.claude/settings.json`)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "python \"$HOME/.claude/hooks/sm-session-start.py\""
          }
        ]
      }
    ]
  }
}
```

Save the script below as `~/.claude/hooks/sm-session-start.py` (any path works; adjust
`command`).

## Script

```python
#!/usr/bin/env python3
"""SessionStart hook: inject the newest handoff/checkpoint file from the cwd repo."""
import glob, json, os, sys

MAX_CHARS = 8000  # keep injected context small

def main() -> int:
    try:
        payload = json.load(sys.stdin)          # hook input; contains "cwd"
    except Exception:
        payload = {}
    cwd = payload.get("cwd") or os.getcwd()

    candidates = glob.glob(os.path.join(cwd, "docs", "PROMPTS", "*.md"))
    state = os.path.join(cwd, "_project_specs", "session", "current-state.md")
    if os.path.isfile(state):
        candidates.append(state)
    if not candidates:
        return 0                                  # nothing to inject; stay silent

    newest = max(candidates, key=os.path.getmtime)
    with open(newest, encoding="utf-8", errors="replace") as fh:
        body = fh.read()[:MAX_CHARS]

    rel = os.path.relpath(newest, cwd)
    context = (f"Newest session handoff/checkpoint ({rel}). Treat it as a pointer to what the "
               f"last session expected next; verify against git before acting.\n\n{body}")
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }}))
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

## Notes and caveats

- Shape used: a command hook reading the hook JSON on stdin (with `cwd`) and printing
  `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}` on
  stdout, exit 0. As I understand the Claude Code hooks docs, plain stdout from a SessionStart
  command hook is also added as context; the JSON form is the explicit one. Unverified here:
  confirm against the current hooks reference before relying on either.
- Also unverified: the exact `matcher` values accepted for SessionStart (`startup`, `resume`,
  `clear`, `compact` as I recall them), and whether `$HOME` expands in `command` on Windows
  (use an absolute path or `%USERPROFILE%` if not).
- The hook only reads files. It does not run `resume-scan.py`; the scan stays on-demand via
  `/work-resume` because it is heavier than a startup hook should be.
- A stale file is injected as readily as a fresh one; the injected text tells the model to
  verify against git. Remove the hook if the noise outweighs the value.
