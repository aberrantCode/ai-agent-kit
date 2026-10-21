---
name: sm-transcripts
description: >
  Sub-skill of `session-manager`. For skill authors, not end users: the shared stdlib-only
  Claude Code transcript (JSONL) library `cc_transcripts.py` — project-directory discovery incl.
  worktree path encodings, session iteration with --since and project filters, message/tool_use
  iteration, subagent meta.json loading, the Windows/git-bash path fix, and every documented
  counting gotcha. Use when writing or fixing any script that reads ~/.claude/projects
  transcripts.
---

# transcripts

Shared library for every `session-manager` script that reads Claude Code transcripts under
`~/.claude/projects`. Audience: skill authors writing or fixing a script, not end users. There
is no slash command and nothing to run directly; you `import` it.

`scripts/cc_transcripts.py` is stdlib-only (Python 3.10+) and read-only. Its module docstring
is the authoritative API reference and carries the full gotcha list; the on-disk format is in
`references/transcript-data-model.md`.

## Import it

Locate the module relative to your own file; never rely on `PYTHONPATH`. From a script at
`sub-skills/<name>/scripts/<script>.py`:

```python
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402
```

## What it gives you

| Need | Use |
|---|---|
| Projects root (honours HOME/USERPROFILE at call time) | `projects_root(root=None)` |
| Project dirs, session files, sessions across projects | `project_dirs`, `session_files` (newest first), `jsonl_files` (dir order), `iter_sessions(root, since, project_substring)` |
| `--since` parsing | `parse_since` (epoch, `datetime`, or `"YYYY-MM-DD HH:MM:SS"` local time) |
| Records / messages / tool_use blocks | `iter_records`, `iter_messages(role, skip_sidechains)`, `iter_tool_uses(names)` -> `ToolUse(id, ts, model, name, input)` |
| Real cwd of a session / project | `session_cwd`, `project_cwd` (never decode the slug) |
| Text and operator-turn filtering | `first_text`, `all_text`, `is_injected`, `INJECTED_PREFIXES` |
| Timestamps and token buckets | `parse_timestamp`, `usage_tokens` |
| Worktree-aware discovery | `worktree_project_dirs(repo)`, `registered_worktrees`, `common_dir` |
| Subagent dispatch records | `subagent_meta_paths(root, since, project_substring)`, `parse_meta_path`, `load_json` |
| Path hygiene (Windows + git-bash) | `to_posix`, `msys_to_native`, `slugify` |

`iter_records(path, stats={})` fills `stats["lines"]` / `stats["bad"]` when you need physical
line counts as well as records.

## Rules for scripts that use it

- Keep window parsing, notes, and report rendering in your script; only discovery and parsing
  live here. Do not copy a helper back out of the library.
- Pass your own prefix tuple to `is_injected(text, prefixes=...)` if you genuinely need a
  different injected-turn definition; otherwise use the default.
- `iter_sessions` and `jsonl_files` yield in directory order, not sorted. Sort in the caller if
  ordering matters to your output (and keep that sort stable).
- `project_substring` matches the project slug, not the full path. To scope by real working
  directory, compare against `project_cwd(...)` yourself.

## Counting bugs and gotchas (summary; full list in the module docstring)

1. `**` matches zero directories: one recursive glob plus a non-recursive one counts top-level
   `*.meta.json` twice. Use `subagent_meta_paths` (single glob, deduped).
2. A session can fire several `Workflow` tool_use blocks for the same run (`resumeFromRunId`).
   Attribute a run's agents once, keyed by `parse_meta_path(...)["wf_dir"]`, not per block.
3. Window dispatches by `meta.json` mtime, not the parent jsonl; the parent can be stale or
   missing. Report `"unknown (parent jsonl not found)"` rather than dropping or guessing.
4. `model` is absent (not null) in meta.json when inherited; `parentAgentId`/`spawnDepth` mark
   nested delegation.
5. The slug is a lossy encoding; read `cwd`. Worktrees get their own slug dirs; correlate by
   git common dir.
6. `type:user` includes tool results and harness injections; `isSidechain` records are not the
   operator's thread; trust `is_error`, not text sniffing.
7. Normalise separators with `to_posix`; in git-bash, `/c/...` strings inside `python -c` are not
   translated, so build paths from `projects_root()` or argv.
8. CLI schema drifts between versions (`Task` vs `Agent`, optional `message`/`usage`/`model`):
   guard every key access.

## Tests

`python -m unittest discover -s scripts/tests -p "test_*.py"` from the repo root (fixtures are
synthetic trees in a temp dir; the real `~/.claude` is never read).
