#!/usr/bin/env python3
"""Detect every session with a real ``/repo-status`` invocation across all transcripts.

Built on the shared, read-only ``cc_transcripts`` library (do NOT re-derive discovery /
iteration / counting -- it already fixes the zero-dir ``**``, resumeFromRunId multi-count,
missing-parent-jsonl, sidechain, and Windows path-translation traps).

Why a bespoke detector instead of ``is_injected`` filtering: ``cc_transcripts.is_injected``
classifies a ``<command-name>`` turn as "injected" (it is in ``INJECTED_PREFIXES``). A
``/repo-status`` invocation turn IS a ``<command-name>`` turn, so filtering user turns through
``is_injected`` and expecting invocations to survive loses every one of them. We therefore treat
the command-name marker as the POSITIVE invocation signal, and use ``is_injected`` only to
distinguish a genuinely typed ``/repo-status`` user turn from harness noise.

Two invocation signals, deduped to sessions:
  * MARKER  -- a user-role text block containing ``<command-name> ... repo-status ...``
              (strongest: the harness injects this when the slash command fires).
  * TYPED   -- a NON-injected user text turn in which the operator literally typed
              ``/repo-status`` (slash form, word-bounded).

Loose ``repo-status`` mentions (skill/command DEFINITIONS, descriptions, catalog, planning
chatter, assistant text, tool_result file reads) are NOT invocations and are excluded: we only
scan ``role == "user"`` messages, tool_result turns yield no text blocks, and TYPED requires the
slash form in a non-injected turn.

Usage:
    python scripts/analysis/detect_repo_status_invocations.py [--since "YYYY-MM-DD"] \
        [--projects-root PATH] > invocations.json

Output: one JSON object on stdout ::

    {
      "corpus": {"project_dirs": N, "jsonl_files": N, "sessions_scanned": N},
      "sessions": [                         # one per session that has >=1 invocation
        {"project": slug, "session": id, "path": jsonl, "cwd": real_cwd,
         "git_branch": branch, "n_invocations": K, "signals": ["marker", ...],
         "invocations": [
            {"index": i, "uuid": u, "ts": iso, "signal": "marker"|"typed",
             "snippet": "..."}]}],
      "totals": {"sessions_with_invocation": S, "total_invocations": I,
                 "by_signal": {"marker": M, "typed": T}}
    }
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "claude", "skills", "session-manager",
                                "sub-skills", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402

# <command-name> ... repo-status ... </command-name>  (slash optional; CLI has used both forms)
MARKER_RE = re.compile(r"<command-name>\s*/?repo-status\s*</command-name>", re.IGNORECASE)
# operator literally typed the slash command, word-bounded so /repo-status-foo doesn't match
TYPED_RE = re.compile(r"(?:^|[\s`'\"(])/repo-status(?![\w-])", re.IGNORECASE)


def git_branch(rec: dict):
    return rec.get("gitBranch")


def session_branch(path: str):
    for rec in cct.iter_records(path):
        b = rec.get("gitBranch")
        if b:
            return b
    return None


def snippet(text: str, limit: int = 160) -> str:
    s = " ".join(text.split())
    return s[:limit] + ("…" if len(s) > limit else "")


def scan_session(path: str) -> list[dict]:
    """Return the list of invocation hits in one transcript (empty if none)."""
    hits = []
    for i, (rec, msg) in enumerate(cct.iter_messages(path, role="user")):
        text = cct.all_text(msg.get("content"))
        if not text.strip():
            continue  # tool_result / non-text user turns carry no operator text
        signal = None
        if MARKER_RE.search(text):
            signal = "marker"
        elif TYPED_RE.search(text) and not cct.is_injected(text):
            signal = "typed"
        if signal:
            hits.append({
                "index": i,
                "uuid": rec.get("uuid"),
                "ts": rec.get("timestamp", ""),
                "signal": signal,
                "snippet": snippet(text),
            })
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", default=None, help='cutoff local time, e.g. "2026-01-01"')
    ap.add_argument("--projects-root", default=None)
    args = ap.parse_args()

    root = args.projects_root
    pdirs = cct.project_dirs(root)
    total_jsonl = 0
    sessions_scanned = 0
    sessions_out = []

    for jpath, slug, sid, _mt in cct.iter_sessions(root, since=args.since):
        total_jsonl += 1
        sessions_scanned += 1
        hits = scan_session(jpath)
        if not hits:
            continue
        signals = sorted({h["signal"] for h in hits})
        sessions_out.append({
            "project": slug,
            "session": sid,
            "path": cct.to_posix(jpath),
            "cwd": cct.session_cwd(jpath),
            "git_branch": session_branch(jpath),
            "n_invocations": len(hits),
            "signals": signals,
            "invocations": hits,
        })

    total_invocations = sum(s["n_invocations"] for s in sessions_out)
    by_signal = {"marker": 0, "typed": 0}
    for s in sessions_out:
        for h in s["invocations"]:
            by_signal[h["signal"]] += 1

    # stable, newest-evidence-last ordering by session id for reproducibility
    sessions_out.sort(key=lambda s: (s["project"], s["session"]))

    print(json.dumps({
        "corpus": {
            "project_dirs": len(pdirs),
            "jsonl_files": total_jsonl,
            "sessions_scanned": sessions_scanned,
        },
        "sessions": sessions_out,
        "totals": {
            "sessions_with_invocation": len(sessions_out),
            "total_invocations": total_invocations,
            "by_signal": by_signal,
        },
    }, indent=2))


if __name__ == "__main__":
    main()
