#!/usr/bin/env python3
"""
resume-scan.py — reduce a repo's Claude Code transcripts to a small, bounded
"where did I leave off" digest so the agent can decide what to pick up next
WITHOUT loading hundreds of MB of JSONL into context.

Read-only. Mutates nothing. Prints JSON (default) or Markdown to stdout.

Companion skill: session-manager `resume` sub-skill (SKILL.md). This script does ONLY the mechanical
half of the funnel — locate the repo's sessions (including its git worktrees),
stream each one, and emit a per-session digest: the initiating goal, the last
operator turn, the last assistant turn (the "what was expected next" signal),
and mechanical hints (did the session end mid-tool-call, which files were being
edited, cwd/branch). It deliberately does NOT classify the resumption state —
that is a reading task the agent does from this digest.

Transcript layout (Claude Code):
  ~/.claude/projects/<slug>/<session-uuid>.jsonl   (one JSON event per line)
where <slug> is the session's absolute cwd with every non-alphanumeric char
replaced by '-'. A git worktree checked out under a different path therefore
lands in its OWN sibling <slug> dir; this script unions the main checkout's
slug with the slug of every path returned by `git worktree list`, so a worktree
anywhere on disk is found — not just ones under .worktrees/.

WINDOW — strategy adapts to the value (mirrors analyze-conversations):
  --window smart     newest-first; sessions in the last 21 days, but always at
                     least MIN_SMART and at most MAX_SMART (the default)
  --window 14d       calendar window: sessions with mtime in the last 14 days
  --window 10s       session window: the 10 most-recent sessions by mtime
  --window 2026-07-01 every session touched on/after that date
  --window all       every session across the repo + its worktrees
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

PROJECTS = cct.projects_root()

MIN_SMART = 6      # smart window never returns fewer than this (if they exist)
MAX_SMART = 15     # ...nor more than this
SMART_DAYS = 21

# Tools whose presence near the end of a session means real edits were in flight.
EDIT_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}
WS_RE = re.compile(r"\s+")


def excerpt(text: str, n: int) -> str:
    t = WS_RE.sub(" ", (text or "").strip())
    return (t[:n] + "…") if len(t) > n else t


def tail(text: str, n: int) -> str:
    t = (text or "").strip()
    return ("…" + t[-n:]) if len(t) > n else t


def parse_window(window, files):
    """files = [(path, mtime), ...] newest first. Returns (selected, note)."""
    window = (window or "smart").strip().lower()
    now = time.time()
    if window == "smart":
        cut = now - SMART_DAYS * 86400
        sel = [(p, mt) for p, mt in files if mt >= cut]
        if len(sel) < MIN_SMART:
            sel = files[:MIN_SMART]
        sel = sel[:MAX_SMART]
        return sel, f"smart: last {SMART_DAYS}d, clamped to [{MIN_SMART},{MAX_SMART}]"
    m = re.fullmatch(r"(\d+)d", window)
    if m:
        cut = now - int(m.group(1)) * 86400
        return [(p, mt) for p, mt in files if mt >= cut], f"last {m.group(1)} day(s)"
    m = re.fullmatch(r"(\d+)s", window)
    if m:
        n = int(m.group(1))
        return files[:n], f"{n} most-recent session(s)"
    if window == "all":
        return list(files), "full corpus"
    try:
        d = datetime.strptime(window, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        return [(p, mt) for p, mt in files if mt >= d.timestamp()], f"since {window}"
    except ValueError:
        cut = now - SMART_DAYS * 86400
        return [(p, mt) for p, mt in files if mt >= cut], "default smart-ish (unparsed)"


def digest_session(path):
    """Single streaming pass over one transcript -> bounded digest dict."""
    sid = os.path.basename(path)[:8]
    first_prompt = None
    last_prompt = None
    last_assistant_text = None
    last_assistant_ts = None
    last_ts = None
    cwd = None
    branch = None
    n_user = n_asst = 0
    # tail state to judge "ended mid-action"
    last_event_kind = None      # 'assistant_text' | 'assistant_tool' | 'tool_result' | 'user_text'
    last_tool = None
    recent_edit_files = []      # last few files touched by Edit/Write near the end
    for ev in cct.iter_records(path):
        if ev.get("isSidechain"):
            continue  # subagent turns are not the operator's thread
        if ev.get("cwd"):
            cwd = ev["cwd"]
        if ev.get("gitBranch") is not None:
            branch = ev.get("gitBranch")
        if ev.get("timestamp"):
            last_ts = ev["timestamp"]
        etype = ev.get("type")
        msg = ev.get("message") or {}
        content = msg.get("content")

        if etype == "assistant":
            n_asst += 1
            txt = cct.all_text(content)
            ended_tool = False
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        ended_tool = True
                        last_tool = b.get("name", "?")
                        if b.get("name") in EDIT_TOOLS:
                            fp = (b.get("input") or {}).get("file_path")
                            if fp:
                                recent_edit_files.append(fp)
            if txt.strip():
                last_assistant_text = txt
                last_assistant_ts = ev.get("timestamp")
            last_event_kind = "assistant_tool" if ended_tool else "assistant_text"
            continue

        if etype == "user":
            # separate genuine operator text from tool_result / injected noise
            if isinstance(content, list):
                is_tool_result = any(
                    isinstance(b, dict) and b.get("type") == "tool_result"
                    for b in content
                )
                if is_tool_result:
                    last_event_kind = "tool_result"
                    continue
                text = cct.first_text(content)
            else:
                text = content if isinstance(content, str) else ""
            if not text or cct.is_injected(text):
                continue
            n_user += 1
            last_event_kind = "user_text"
            if first_prompt is None:
                first_prompt = text
            last_prompt = text

    if last_ts is None and last_assistant_ts is None:
        return None
    # de-dup edit files, keep last 5 unique in order of last appearance
    seen = []
    for f in reversed(recent_edit_files):
        if f not in seen:
            seen.append(f)
        if len(seen) >= 5:
            break
    return {
        "session": sid,
        "path": path,
        "mtime": os.path.getmtime(path),
        "last_ts": last_ts,
        "cwd": cwd,
        "branch": branch,
        "n_user_turns": n_user,
        "n_assistant_turns": n_asst,
        "first_prompt": excerpt(first_prompt or "", 400),
        "last_prompt": excerpt(last_prompt or "", 400),
        "last_assistant_tail": tail(last_assistant_text or "", 1800),
        "last_event_kind": last_event_kind,
        "last_tool": last_tool,
        "ended_mid_action": last_event_kind in ("assistant_tool", "tool_result"),
        "recent_edit_files": list(reversed(seen)),
    }


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--repo", default=os.getcwd(),
                    help="main repo checkout root (default: cwd)")
    ap.add_argument("--window", default="smart",
                    help="smart | Nd | Ns | YYYY-MM-DD | all (default smart)")
    ap.add_argument("--max-files", type=int, default=40,
                    help="hard cap on sessions digested (oldest past cap dropped + reported)")
    ap.add_argument("--format", choices=["json", "md"], default="json")
    args = ap.parse_args()

    if not os.path.isdir(PROJECTS):
        print(f"ERROR: no Claude Code projects dir at {PROJECTS}", file=sys.stderr)
        return 2

    slugs = cct.worktree_project_dirs(args.repo, PROJECTS)
    dirs = {s: os.path.join(PROJECTS, s) for s in slugs}
    present = {s: d for s, d in dirs.items() if os.path.isdir(d)}
    if not present:
        print(f"ERROR: no transcripts for {args.repo} "
              f"(looked for slug(s): {', '.join(slugs)})", file=sys.stderr)
        return 3

    files = []
    for slug, d in present.items():
        files.extend(cct.session_files(d))
    files.sort(key=lambda x: x[1], reverse=True)

    selected, note = parse_window(args.window, files)
    dropped = 0
    if len(selected) > args.max_files:
        dropped = len(selected) - args.max_files
        selected = selected[: args.max_files]

    digests = []
    for path, _mt in selected:
        d = digest_session(path)
        if d:
            # which worktree did this session belong to?
            slug = os.path.basename(os.path.dirname(path))
            d["worktree_path"] = slugs.get(slug)
            digests.append(d)

    meta = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo": os.path.abspath(args.repo),
        "worktrees": slugs,
        "projects_dirs": list(present.values()),
        "window": note,
        "sessions_found": len(files),
        "sessions_digested": len(digests),
        "dropped_past_cap": dropped,
    }

    if args.format == "json":
        print(json.dumps({"meta": meta, "sessions": digests},
                         indent=2, ensure_ascii=False))
        return 0

    # --- markdown (human inspection via /work-scan) -------------------------
    w = print
    w(f"# Resume scan — {meta['repo']}\n")
    w(f"- Window: {note}  |  digested {len(digests)} of {len(files)} session(s)")
    if dropped:
        w(f"- **{dropped} older session(s) dropped past --max-files={args.max_files}.**")
    w(f"- Worktrees: {', '.join(p for p in slugs.values())}\n")
    for i, d in enumerate(digests):
        when = (d["last_ts"] or "")[:16].replace("T", " ")
        flag = "⏳ mid-action" if d["ended_mid_action"] else "💬 spoke-to-operator"
        w(f"## {i}. {d['session']}  ·  {when}  ·  `{d['branch']}`  ·  {flag}")
        if d["worktree_path"] and os.path.abspath(d["worktree_path"]) != meta["repo"]:
            w(f"> worktree: `{d['worktree_path']}`")
        w(f"- **Goal (first prompt):** {d['first_prompt']}")
        if d["last_prompt"] and d["last_prompt"] != d["first_prompt"]:
            w(f"- **Last operator turn:** {d['last_prompt']}")
        if d["recent_edit_files"]:
            w(f"- **Files edited near end:** {', '.join(d['recent_edit_files'])}")
        w(f"- **Last assistant turn (tail):**\n\n  > {d['last_assistant_tail']}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
