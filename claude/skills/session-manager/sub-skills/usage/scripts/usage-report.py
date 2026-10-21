#!/usr/bin/env python3
"""
Real token-usage report for Claude Code sessions.

Rule #4 of Dubi's 11 rules: "you can't fix what you can't measure." Claude Code
writes every token, model, and timestamp to local JSONL transcripts under
``~/.claude/projects/<project>/<session>.jsonl``. This script reads those
transcripts directly (no network access) and reports, for a given time window:

    - total tokens by kind (input, output, cache read, cache creation)
    - cache-hit % (cache_read / (input + cache_read + cache_creation))
    - model mix (share of tokens per model)
    - per-session breakdown

Cache-hit % and model mix are the two numbers that matter most: a low
cache-hit % (under ~60%) means too many fresh chats or cache-busting edits,
and a high Opus share for routine work means Rule #8 (use Haiku for simple
tasks) applies.

Usage:
    python3 scripts/usage-report.py                       # last 7 days, all projects
    python3 scripts/usage-report.py --days 14              # widen the window
    python3 scripts/usage-report.py --project my-repo       # scope to a project (cwd substring)
    python3 scripts/usage-report.py --json                 # machine-readable output

No third-party dependencies; stdlib only.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description="Real Claude Code token-usage report from local JSONL transcripts.")
    ap.add_argument("--days", type=int, default=7, help="Look-back window in days (default: 7).")
    ap.add_argument("--project", default=None, help="Case-insensitive substring; only sessions whose cwd matches.")
    ap.add_argument("--json", action="store_true", help="Emit machine-readable JSON instead of a summary.")
    return ap.parse_args(argv)


def extract_usage_event(rec: dict):
    """Pull (model, usage dict, timestamp) out of one assistant-message record.

    Returns None if the record isn't a usable assistant usage event. Every
    key access is guarded — transcript schemas vary across CLI versions.
    """
    if not isinstance(rec, dict):
        return None
    if rec.get("type") != "assistant":
        return None
    msg = rec.get("message")
    if not isinstance(msg, dict):
        return None
    usage = msg.get("usage")
    if not isinstance(usage, dict):
        return None
    model = msg.get("model") or "unknown"
    ts = cct.parse_timestamp(rec.get("timestamp"))
    return model, usage, ts


def collect_events(cutoff, project_filter):
    """Scan every session file and yield (session_id, cwd, model, usage, ts)
    for assistant usage events at or after `cutoff`, optionally scoped to a
    project cwd substring.

    The cwd is resolved once per file before any event is yielded, so a
    session that doesn't match `project_filter` is skipped entirely rather
    than partially emitted.
    """
    for project_dir in cct.project_dirs():
        for jsonl in cct.jsonl_files(project_dir):
            cwd = cct.session_cwd(jsonl)
            if project_filter and (not cwd or project_filter.lower() not in cwd.lower()):
                continue
            for rec in cct.iter_records(jsonl):
                event = extract_usage_event(rec)
                if event is None:
                    continue
                model, usage, ts = event
                if ts is None or ts < cutoff:
                    continue
                yield os.path.splitext(os.path.basename(jsonl))[0], cwd, model, usage, ts


def build_report(days: int, project_filter: str | None):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    sessions = defaultdict(lambda: {
        "cwd": None,
        "input": 0, "output": 0, "cache_read": 0, "cache_write": 0,
        "models": defaultdict(int),
        "events": 0,
    })
    model_totals = defaultdict(int)
    totals = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}

    for session_id, cwd, model, usage, ts in collect_events(cutoff, project_filter):
        inp, out, cache_read, cache_write = cct.usage_tokens(usage)
        total_tok = inp + out + cache_read + cache_write

        s = sessions[session_id]
        s["cwd"] = s["cwd"] or cwd
        s["input"] += inp
        s["output"] += out
        s["cache_read"] += cache_read
        s["cache_write"] += cache_write
        s["models"][model] += total_tok
        s["events"] += 1

        totals["input"] += inp
        totals["output"] += out
        totals["cache_read"] += cache_read
        totals["cache_write"] += cache_write
        model_totals[model] += total_tok

    grand_total = sum(totals.values())
    cacheable = totals["input"] + totals["cache_read"] + totals["cache_write"]
    cache_hit_pct = (totals["cache_read"] / cacheable * 100) if cacheable else 0.0

    model_mix = []
    for model, tok in sorted(model_totals.items(), key=lambda kv: -kv[1]):
        share = (tok / grand_total * 100) if grand_total else 0.0
        model_mix.append({"model": model, "tokens": tok, "share_pct": round(share, 1)})

    session_rows = []
    for session_id, s in sessions.items():
        sess_total = s["input"] + s["output"] + s["cache_read"] + s["cache_write"]
        sess_cacheable = s["input"] + s["cache_read"] + s["cache_write"]
        sess_hit_pct = (s["cache_read"] / sess_cacheable * 100) if sess_cacheable else 0.0
        top_model = max(s["models"].items(), key=lambda kv: kv[1])[0] if s["models"] else "unknown"
        session_rows.append({
            "session_id": session_id,
            "cwd": s["cwd"],
            "total_tokens": sess_total,
            "input": s["input"],
            "output": s["output"],
            "cache_read": s["cache_read"],
            "cache_write": s["cache_write"],
            "cache_hit_pct": round(sess_hit_pct, 1),
            "top_model": top_model,
            "events": s["events"],
        })
    session_rows.sort(key=lambda r: -r["total_tokens"])

    return {
        "days": days,
        "project_filter": project_filter,
        "totals": {**totals, "grand_total": grand_total},
        "cache_hit_pct": round(cache_hit_pct, 1),
        "model_mix": model_mix,
        "sessions": session_rows,
        "session_count": len(session_rows),
    }


def fmt(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def render_console(report: dict) -> None:
    bar = "=" * 72
    print(bar)
    label = f" (project: {report['project_filter']})" if report["project_filter"] else ""
    print(f"Claude Code token-usage report - last {report['days']} day(s){label}")
    print(bar)

    if report["session_count"] == 0:
        print("No sessions with usage found in this window.")
        return

    t = report["totals"]
    print(f"Sessions analyzed:   {report['session_count']}")
    print(f"Total tokens:        {fmt(t['grand_total'])}")
    print(f"  input:             {fmt(t['input'])}")
    print(f"  output:            {fmt(t['output'])}")
    print(f"  cache read:        {fmt(t['cache_read'])}")
    print(f"  cache write:       {fmt(t['cache_write'])}")
    print()
    print(f"Cache-hit %:         {report['cache_hit_pct']}%  (target: >= ~60%)")
    print()
    print("Model mix:")
    for row in report["model_mix"]:
        print(f"  {row['model']:<28} {fmt(row['tokens']):>8}  ({row['share_pct']}%)")
    print()
    print("Top sessions by total tokens:")
    print(f"  {'session':<12}{'total':>9}{'cache-hit%':>12}  {'top model':<24} cwd")
    print("  " + "-" * 70)
    for row in report["sessions"][:10]:
        print(
            f"  {row['session_id'][:8]:<12}{fmt(row['total_tokens']):>9}"
            f"{row['cache_hit_pct']:>11}%  {row['top_model']:<24} {row['cwd'] or ''}"
        )


def main(argv=None) -> int:
    args = parse_args(argv)
    report = build_report(args.days, args.project)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        render_console(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
