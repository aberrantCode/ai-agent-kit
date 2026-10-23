#!/usr/bin/env python3
"""Extract a compact, readable episode slice around each ``/repo-status`` invocation.

Consumes the detector output (``invocations.json``) and, for each session, emits one
``episode-<session>.json`` under the output dir: an ordered list of events from the first
invocation forward, so a (haiku) subagent can characterise what the command actually did
without re-parsing raw JSONL or hitting the Windows path trap.

Event kinds:
  * ``user``        -- an operator (or harness) user turn; ``injected`` flags harness noise.
  * ``assistant``   -- assistant free text (the report and any prose).
  * ``tool_use``    -- a tool call; ``name`` + ``input`` (Bash ``command`` surfaced verbatim).
  * ``tool_result`` -- truncated stdout/err + ``is_error``.

Each session slice runs from the first invocation record to end-of-session, capped at
``--max-events`` events; ``truncated``/``events_after_cap`` record any cap so coverage loss is
logged, never hidden.

Usage:
    python scripts/analysis/extract_episodes.py --invocations .analysis-out/invocations.json \
        --out-dir .analysis-out/episodes [--max-events 120]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "claude", "skills", "session-manager",
                                "sub-skills", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402

CMD_CHARS = 2000      # Bash command text kept verbatim up to here
RESULT_CHARS = 700    # tool_result stdout/err kept up to here
TEXT_CHARS = 6000     # assistant/user text kept up to here (reports can be long)


def clip(s, n):
    if s is None:
        return None
    s = str(s)
    return s if len(s) <= n else s[:n] + f"…[+{len(s) - n} chars]"


def summarize_input(name, inp):
    if not isinstance(inp, dict):
        return {"raw": clip(inp, CMD_CHARS)}
    if name in ("Bash",):
        return {"command": clip(inp.get("command"), CMD_CHARS),
                "description": inp.get("description")}
    # keep small inputs whole, clip large text fields
    out = {}
    for k, v in inp.items():
        out[k] = clip(v, CMD_CHARS) if isinstance(v, str) else v
    return out


def summarize_result(content):
    """Return (text, is_error-ish). tool_result content is str or list of blocks."""
    if isinstance(content, str):
        return clip(content, RESULT_CHARS)
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict):
                if b.get("type") == "text":
                    parts.append(b.get("text", ""))
                elif b.get("type") == "tool_result":
                    parts.append(str(b.get("content", "")))
            else:
                parts.append(str(b))
        return clip("\n".join(parts), RESULT_CHARS)
    return clip(content, RESULT_CHARS)


def record_to_events(rec):
    """Yield 0+ compact events for one transcript record."""
    msg = rec.get("message")
    if not isinstance(msg, dict):
        return
    role = msg.get("role")
    ts = rec.get("timestamp", "")
    content = msg.get("content")

    if role == "user":
        # user turns may be operator text OR tool_result blocks
        if isinstance(content, list):
            tool_results = [b for b in content if isinstance(b, dict)
                            and b.get("type") == "tool_result"]
            for b in tool_results:
                yield {"kind": "tool_result", "ts": ts,
                       "tool_use_id": b.get("tool_use_id"),
                       "is_error": bool(b.get("is_error")),
                       "content": summarize_result(b.get("content"))}
        text = cct.all_text(content)
        if text.strip():
            yield {"kind": "user", "ts": ts,
                   "injected": cct.is_injected(text),
                   "text": clip(text, TEXT_CHARS)}
    elif role == "assistant":
        if isinstance(content, list):
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "text" and b.get("text", "").strip():
                    yield {"kind": "assistant", "ts": ts,
                           "text": clip(b.get("text"), TEXT_CHARS)}
                elif b.get("type") == "tool_use":
                    yield {"kind": "tool_use", "ts": ts,
                           "id": b.get("id"), "name": b.get("name"),
                           "input": summarize_input(b.get("name"), b.get("input", {}))}
        elif isinstance(content, str) and content.strip():
            yield {"kind": "assistant", "ts": ts, "text": clip(content, TEXT_CHARS)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--invocations", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--max-events", type=int, default=120)
    args = ap.parse_args()

    data = json.load(open(args.invocations, encoding="utf-8"))
    os.makedirs(args.out_dir, exist_ok=True)
    index = []

    for s in data["sessions"]:
        path = cct.msys_to_native(s["path"])
        first_uuid = s["invocations"][0]["uuid"]
        inv_uuids = {h["uuid"] for h in s["invocations"]}

        all_recs = list(cct.iter_records(path))
        start = next((i for i, r in enumerate(all_recs)
                      if r.get("uuid") == first_uuid), None)
        if start is None:
            index.append({"session": s["session"], "error": "invocation uuid not found"})
            continue

        window = all_recs[start:]
        events = []
        for i, rec in enumerate(window):
            is_inv = rec.get("uuid") in inv_uuids
            for ev in record_to_events(rec):
                if is_inv and ev["kind"] == "user":
                    ev["is_invocation"] = True
                events.append(ev)
            if len(events) >= args.max_events:
                break
        truncated = len(events) >= args.max_events
        events_after = max(0, len(window) - (i + 1)) if truncated else 0

        out = {
            "session": s["session"],
            "project": s["project"],
            "cwd": s["cwd"],
            "git_branch": s["git_branch"],
            "n_invocations": s["n_invocations"],
            "invocation_signals": s["signals"],
            "truncated": truncated,
            "records_after_cap": events_after,
            "events": events,
        }
        fn = os.path.join(args.out_dir, f"episode-{s['session'][:12]}.json")
        with open(fn, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=1)
        index.append({"session": s["session"], "project": s["project"],
                      "file": cct.to_posix(fn), "events": len(events),
                      "truncated": truncated, "records_after_cap": events_after,
                      "bytes": os.path.getsize(fn)})

    with open(os.path.join(args.out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2)
    print(json.dumps(index, indent=2))


if __name__ == "__main__":
    main()
