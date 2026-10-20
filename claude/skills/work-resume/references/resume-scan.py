#!/usr/bin/env python3
"""
resume-scan.py — reduce a repo's Claude Code transcripts to a small, bounded
"where did I leave off" digest so the agent can decide what to pick up next
WITHOUT loading hundreds of MB of JSONL into context.

Read-only. Mutates nothing. Prints JSON (default) or Markdown to stdout.

Companion skill: work-resume (SKILL.md). This script does ONLY the mechanical
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
import subprocess
import sys
import time
from datetime import datetime, timezone

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = os.path.expanduser("~")
PROJECTS = os.path.join(HOME, ".claude", "projects")

MIN_SMART = 6      # smart window never returns fewer than this (if they exist)
MAX_SMART = 15     # ...nor more than this
SMART_DAYS = 21

# Hook-injected / non-human `type:user` content — never a genuine operator turn.
# Copied from analyze-conversations so the two skills agree on what "the operator
# actually said" means.
INJECTED_PREFIXES = (
    "<system-reminder>", "[honcho memory", "[request interrupted",
    "caveat:", "<command-name>", "<command-message>", "<local-command-stdout>",
    "<local-command-caveat>", "base directory for this skill",
    "this session is being continued", "launching skill:", "tool loaded.",
    "<user-prompt-submit-hook>", "your questions have been answered",
)

# Tools whose presence near the end of a session means real edits were in flight.
EDIT_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}
WS_RE = re.compile(r"\s+")


def slugify(path: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def is_injected(text: str) -> bool:
    return text.lstrip().lower().startswith(INJECTED_PREFIXES)


def first_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                return b.get("text", "")
    return ""


def all_text(content) -> str:
    if isinstance(content, str):
        return content
    out = []
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                out.append(b.get("text", ""))
    return "\n".join(out)


def excerpt(text: str, n: int) -> str:
    t = WS_RE.sub(" ", (text or "").strip())
    return (t[:n] + "…") if len(t) > n else t


def tail(text: str, n: int) -> str:
    t = (text or "").strip()
    return ("…" + t[-n:]) if len(t) > n else t


def _norm(p: str) -> str:
    """Case/-separator-normalised absolute path for reliable comparison."""
    try:
        return os.path.normcase(os.path.abspath(os.path.realpath(p)))
    except Exception:
        return os.path.normcase(os.path.abspath(p))


def _git(args, cwd=None) -> str:
    try:
        return subprocess.run(
            ["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=15
        ).stdout
    except Exception:
        return ""


def common_dir(path: str):
    """The git *common* dir for `path` — the origin repo's real .git. For any
    worktree this resolves to the MAIN checkout's .git, so it is the identity
    two worktrees of the same repo share. Returns a normalised path or None."""
    out = _git(["-C", path, "rev-parse", "--git-common-dir"]).strip()
    if not out:
        return None
    if not os.path.isabs(out):
        out = os.path.join(path, out)
    return _norm(out)


def registered_worktrees(repo: str):
    """Paths of every worktree git still tracks for `repo` — live AND
    removed-but-not-yet-pruned — regardless of naming convention or location."""
    paths = []
    for line in _git(["-C", repo, "worktree", "list", "--porcelain"]).splitlines():
        if line.startswith("worktree "):
            paths.append(os.path.abspath(line[len("worktree "):].strip()))
    return paths


def _session_cwd(project_dir: str):
    """Cheap: the working dir recorded in the newest transcript of a project
    dir. Lets us attribute a worktree session to a repo by identity, not name."""
    try:
        js = [f for f in os.listdir(project_dir) if f.endswith(".jsonl")]
    except OSError:
        return None
    if not js:
        return None
    js.sort(key=lambda f: os.path.getmtime(os.path.join(project_dir, f)), reverse=True)
    try:
        for line in open(os.path.join(project_dir, js[0]), encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if d.get("cwd"):
                return d["cwd"]
    except Exception:
        pass
    return None


def worktree_slugs(repo: str):
    """Return {slug: path} for every place THIS repo's sessions live — across
    all three worktree conventions on this workstation:

      - in-repo `<repo>/.worktrees/<name>`
      - sibling `<repo>-wt/<name>` (or `<repo>-wt` itself)
      - shared containers `C:\\development\\.worktrees\\<name>` and
        `C:\\development\\github-repos-wt\\<name>` that hold worktrees for
        *several* repos

    Correlation is git-authoritative, not name-based, because the shared
    containers do not embed the origin repo in their path:

      1. the main checkout;
      2. `git worktree list` — every worktree git tracks (live + prunable),
         any convention/location;
      3. recovery for worktrees git has already PRUNED but whose transcripts
         remain: scan worktree-shaped project dirs and attribute each by
         identity — a dir whose slug embeds this repo (`<mainslug>--worktrees-`
         / `<mainslug>-wt`) is trusted; a shared-container dir is included only
         if its recorded cwd still resolves (via git-common-dir) to THIS repo.

    Residual edge: a worktree that was pruned AND lived in a shared container
    AND whose directory is now deleted cannot be attributed (no git trace, no
    resolvable cwd). Rare, and reported implicitly by its absence.
    """
    main = os.path.abspath(repo)
    mainslug = slugify(main)
    slugs = {mainslug: main}
    tcommon = common_dir(repo)

    # (2) git-tracked worktrees — convention-independent, absolute paths
    for p in registered_worktrees(repo):
        slugs.setdefault(slugify(p), p)

    # (3) pruned-but-transcripts-remain recovery
    try:
        names = os.listdir(PROJECTS)
    except OSError:
        names = []
    for name in names:
        if name in slugs:
            continue
        looks_wt = ("--worktrees-" in name) or ("-wt-" in name) or name.endswith("-wt")
        if not looks_wt:
            continue
        embeds_repo = name.startswith(mainslug + "--worktrees-") or name.startswith(mainslug + "-wt")
        cwd = _session_cwd(os.path.join(PROJECTS, name))
        if embeds_repo:
            slugs.setdefault(name, cwd or name)          # name attributes it
        elif tcommon and cwd and os.path.isdir(cwd) and common_dir(cwd) == tcommon:
            slugs.setdefault(name, cwd)                  # git-verified membership
    return slugs


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
    try:
        fh = open(path, encoding="utf-8")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
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
                txt = all_text(content)
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
                    text = first_text(content)
                else:
                    text = content if isinstance(content, str) else ""
                if not text or is_injected(text):
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

    slugs = worktree_slugs(args.repo)
    dirs = {s: os.path.join(PROJECTS, s) for s in slugs}
    present = {s: d for s, d in dirs.items() if os.path.isdir(d)}
    if not present:
        print(f"ERROR: no transcripts for {args.repo} "
              f"(looked for slug(s): {', '.join(slugs)})", file=sys.stderr)
        return 3

    files = []
    for slug, d in present.items():
        for fn in os.listdir(d):
            if fn.endswith(".jsonl"):
                p = os.path.join(d, fn)
                try:
                    files.append((p, os.path.getmtime(p)))
                except OSError:
                    pass
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
