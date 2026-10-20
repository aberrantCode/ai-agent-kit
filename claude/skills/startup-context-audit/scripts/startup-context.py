#!/usr/bin/env python3
"""
Startup-context breakdown for Claude Code sessions.

Answers: "why does a newly launched session already show tokens > 0, and how
much?" It reads the local session logs (``~/.claude/projects/*/*.jsonl``) and,
for each repo, computes the FIRST-TURN context size = the tokens loaded before
any real work (system prompt + CLAUDE.md stack + tool schemas + skill/MCP
inventory + the tiny first user message). That first-turn total IS the "count
> 0" you see at launch.

It also decomposes the CURRENT repo's baseline into the readable buckets we can
actually open on disk (global CLAUDE.md, rules/*, project CLAUDE.md, memory) via
a chars/4 token estimate (or tiktoken if installed); the remainder is the
harness (system prompt + tool schemas + skill/agent/MCP inventory + injected
hooks), which is not on disk and is reported as the difference.

Usage:
    python startup-context.py                     # audit current repo + top 10
    python startup-context.py --top 20            # widen the per-repo table
    python startup-context.py --project AC_OPBTA  # only repos whose cwd matches
    python startup-context.py --dev-root /code    # non-default workspace root
    python startup-context.py --json              # machine-readable output

No network access; everything is read locally from ~/.claude/projects.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HOME = Path.home()
PROJECTS = HOME / ".claude" / "projects"
CHARS_PER_TOK = 4.0  # rough English estimate; used when tiktoken is unavailable

# Optional precise tokenizer. Falls back to chars/4 when absent (the common case
# on a fresh workstation). We only ever use it for on-disk file buckets — the
# session baselines come straight from each JSONL's own usage records.
try:  # pragma: no cover - environment dependent
    import tiktoken

    _ENC = tiktoken.get_encoding("cl100k_base")

    def _count_text(text: str) -> int:
        return len(_ENC.encode(text))

    TOKENIZER = "tiktoken/cl100k_base"
except Exception:  # noqa: BLE001 - any import/init failure means fall back
    _ENC = None

    def _count_text(text: str) -> int:
        return round(len(text) / CHARS_PER_TOK)

    TOKENIZER = "chars/4 estimate"


def est_tokens_file(p: Path) -> int:
    """Token estimate for a single on-disk file (0 if unreadable/missing)."""
    try:
        return _count_text(p.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return 0


def first_turn_context(jsonl: Path):
    """Return (total_tokens, breakdown, timestamp) for the first non-sidechain
    assistant usage record in a session file, or None if there is none.

    total = input + cache_read + cache_creation — the whole context the model
    saw on turn one, which is exactly the "already > 0" number at launch.
    """
    try:
        with open(jsonl, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("isSidechain"):
                    continue
                msg = rec.get("message") or {}
                usage = msg.get("usage")
                if not usage:
                    continue
                inp = usage.get("input_tokens", 0) or 0
                cr = usage.get("cache_read_input_tokens", 0) or 0
                cw = usage.get("cache_creation_input_tokens", 0) or 0
                total = inp + cr + cw
                if total <= 0:
                    continue
                return total, {"input": inp, "cache_read": cr, "cache_write": cw}, rec.get("timestamp")
    except OSError:
        return None
    return None


def sessions_for(project_dir: Path):
    """First-turn context for every session file under a project dir, newest first."""
    files = sorted(project_dir.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    out = []
    for f in files:
        ft = first_turn_context(f)
        if ft:
            out.append((f, ft[0], ft[1], f.stat().st_mtime))
    return out


def cwd_of(project_dir: Path):
    """Read the real cwd from the first record that carries one.

    The ~/.claude/projects/<dir> name encodes '_', ':' and '\\' all as '-', so
    it is lossy and ambiguous — never decode it. Invert instead by reading the
    real `cwd` field the CLI writes into each session's JSONL.
    """
    for jsonl in project_dir.glob("*.jsonl"):
        try:
            with open(jsonl, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    cwd = rec.get("cwd")
                    if cwd:
                        return cwd
        except OSError:
            continue
    return None


def fmt(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def find_repo_root(start: Path) -> Path:
    """Walk up from `start` to the nearest ancestor containing a .git entry;
    fall back to `start` itself if none is found (e.g. not inside a repo)."""
    start = start.resolve()
    for d in (start, *start.parents):
        if (d / ".git").exists():
            return d
        if d == d.parent:  # reached filesystem root
            break
    return start


def decompose_baseline(repo_root: Path, project_dir: Path, fresh: int):
    """Break the leanest fresh baseline into readable on-disk buckets + harness
    remainder. Returns a dict suitable for JSON or console rendering."""
    g_claude = est_tokens_file(HOME / ".claude" / "CLAUDE.md")
    rules_dir = HOME / ".claude" / "rules"
    rules = (
        {p.name: est_tokens_file(p) for p in sorted(rules_dir.glob("*.md"))}
        if rules_dir.exists()
        else {}
    )
    rules_total = sum(rules.values())
    proj_claude = est_tokens_file(repo_root / "CLAUDE.md")
    mem_file = project_dir / "memory" / "MEMORY.md"
    memory = est_tokens_file(mem_file) if mem_file.exists() else 0

    readable = g_claude + rules_total + proj_claude + memory
    harness = max(0, fresh - readable)
    return {
        "global_claude_md": g_claude,
        "rules": rules,
        "rules_total": rules_total,
        "project_claude_md": proj_claude,
        "memory_md": memory,
        "readable_total": readable,
        "harness_remainder": harness,
        "fresh_baseline": fresh,
    }


def build_report(dev_root: Path, top: int, project_filter: str | None):
    """Assemble the full report structure (Part 1 + Part 2) as plain data."""
    # Map every project dir -> real cwd (inverted from JSONL, never decoded).
    dir_cwd = {}
    if PROJECTS.exists():
        for pd in PROJECTS.iterdir():
            if not pd.is_dir():
                continue
            c = cwd_of(pd)
            if c:
                dir_cwd[pd] = c

    def matches_filter(path_str: str) -> bool:
        return project_filter is None or project_filter.lower() in path_str.lower()

    # ---- Part 1: current repo baseline decomposition ----
    repo_root = find_repo_root(Path.cwd())
    part1 = {"repo": repo_root.name, "repo_path": str(repo_root)}
    this_pd = None
    for pd, c in dir_cwd.items():
        if Path(c) == repo_root:
            this_pd = pd
            break

    if this_pd:
        sess = sessions_for(this_pd)
        if sess:
            baselines = [s[1] for s in sess[:20]]
            fresh = min(baselines)  # cleanest 'newly launched' proxy
            latest = sess[0][1]
            part1.update(
                {
                    "sessions_analyzed": len(sess),
                    "latest_baseline": latest,
                    "latest_breakdown": sess[0][2],
                    "fresh_baseline": fresh,
                    "decomposition": decompose_baseline(repo_root, this_pd, fresh),
                }
            )
        else:
            part1["error"] = "No sessions with usage found for this repo."
    else:
        part1["error"] = "Could not locate this repo's session history."

    # ---- Part 2: N most-recently-modified repos with history ----
    repos = []
    if dev_root.exists():
        for d in dev_root.iterdir():
            if not d.is_dir():
                continue
            if (d / ".git").exists() and matches_filter(str(d)):
                repos.append((d, d.stat().st_mtime))
    repos.sort(key=lambda t: t[1], reverse=True)

    # cwd -> project dir map (repo-root only; first writer wins, excludes worktrees)
    cwd_to_pd = {}
    for pd, c in dir_cwd.items():
        cwd_to_pd.setdefault(Path(c), pd)

    rows = []
    for repo_path, _mtime in repos:
        pd = cwd_to_pd.get(repo_path)
        if not pd:
            continue
        sess = sessions_for(pd)
        if not sess:
            continue
        baselines = [s[1] for s in sess[:20]]
        rows.append(
            {
                "repo": repo_path.name,
                "sessions": len(sess),
                "fresh_baseline": min(baselines),
                "latest_baseline": sess[0][1],
                "project_claude_md": est_tokens_file(repo_path / "CLAUDE.md"),
            }
        )
        if len(rows) >= top:
            break

    return {
        "tokenizer": TOKENIZER,
        "dev_root": str(dev_root),
        "project_filter": project_filter,
        "part1_current_repo": part1,
        "part2_repos": rows,
    }


def render_console(report: dict) -> None:
    p1 = report["part1_current_repo"]
    bar = "=" * 74
    print(bar)
    print(f"PART 1 - Current repo startup baseline (repo: {p1['repo']})")
    print(bar)
    print(f"Token accounting for on-disk buckets: {report['tokenizer']}")
    print()

    if "decomposition" in p1:
        d = p1["decomposition"]
        lb = p1["latest_breakdown"]
        print(f"Sessions analyzed:          {p1['sessions_analyzed']}")
        print(
            f"Latest session baseline:    {fmt(p1['latest_baseline'])} tokens  "
            f"(fresh={fmt(lb['input'])} + cache_r={fmt(lb['cache_read'])} "
            f"+ cache_w={fmt(lb['cache_write'])})"
        )
        print(f"Leanest fresh-start seen:   {fmt(p1['fresh_baseline'])} tokens  <-- true 'new session' cost")
        print()
        print("Decomposition of the leanest fresh-start baseline:")
        print(f"  {'~/.claude/CLAUDE.md (global)':<40} {fmt(d['global_claude_md']):>8}")
        print(f"  {'~/.claude/rules/*.md (' + str(len(d['rules'])) + ' files)':<40} {fmt(d['rules_total']):>8}")
        for name, t in sorted(d["rules"].items(), key=lambda kv: -kv[1]):
            print(f"      {name:<36} {fmt(t):>8}")
        print(f"  {'project CLAUDE.md':<40} {fmt(d['project_claude_md']):>8}")
        print(f"  {'MEMORY.md (auto-memory index)':<40} {fmt(d['memory_md']):>8}")
        print(f"  {'-' * 40} {'-' * 8}")
        print(f"  {'= readable on-disk instructions':<40} {fmt(d['readable_total']):>8}")
        print(f"  {'= harness (sysprompt+tools+skills+MCP+hooks)':<40} {fmt(d['harness_remainder']):>8}   (remainder)")
        print(f"  {'TOTAL fresh baseline':<40} {fmt(d['fresh_baseline']):>8}")
    else:
        print(p1.get("error", "No data."))

    # ---- Part 2 ----
    print()
    print(bar)
    print(f"PART 2 - Fresh-session baseline for {len(report['part2_repos'])} most-recently-modified repos")
    print(bar)
    print(f"{'repo':<26}{'sessions':>9}{'fresh base':>12}{'latest base':>13}{'proj CLAUDE.md':>16}")
    print("-" * 76)
    for r in report["part2_repos"]:
        print(
            f"{r['repo']:<26}{r['sessions']:>9}{fmt(r['fresh_baseline']):>12}"
            f"{fmt(r['latest_baseline']):>13}{fmt(r['project_claude_md']):>16}"
        )
    print()
    print("fresh base  = leanest first-turn context seen across recent sessions (the")
    print("              token count a genuinely new session starts at)")
    print("latest base = first-turn context of the most recent session (higher if resumed)")
    print("proj CLAUDE.md = that repo's own CLAUDE.md size; the global ~/.claude stack")
    print("              is identical across all repos, so per-repo spread comes from")
    print("              project-local .claude/ extensions and MCP servers.")


def parse_args(argv=None):
    ap = argparse.ArgumentParser(
        description="Break down the startup (first-turn) context cost of Claude Code sessions."
    )
    ap.add_argument(
        "--dev-root",
        default="C:/development",
        help="Workspace root scanned for sibling git repos in Part 2 (default: C:/development).",
    )
    ap.add_argument(
        "--top",
        type=int,
        default=10,
        help="How many recently-modified repos to list in Part 2 (default: 10).",
    )
    ap.add_argument(
        "--project",
        default=None,
        help="Case-insensitive substring; only repos whose path matches are considered.",
    )
    ap.add_argument("--json", action="store_true", help="Emit machine-readable JSON instead of a table.")
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    if not PROJECTS.exists():
        msg = f"No session history found at {PROJECTS}"
        if args.json:
            print(json.dumps({"error": msg}))
        else:
            print(msg, file=sys.stderr)
        return 1

    report = build_report(Path(args.dev_root), args.top, args.project)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        render_console(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
