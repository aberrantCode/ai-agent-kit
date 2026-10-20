#!/usr/bin/env python3
"""Mine Claude Code transcripts for subagent-dispatch records and per-session main-loop models.

Ground truth for "was a subagent spawned, and with what model" is
~/.claude/projects/<project>/<session-id>/subagents/**/*.meta.json -- NOT the parent
transcript alone. A still-open or concurrent session's parent .jsonl may be stale or
altogether missing while its subagent dispatch records already exist, so meta.json
mtime (not parent-jsonl mtime) is the correct signal for "did a dispatch happen in
this window".

Two known gotchas this script already handles (found the hard way -- see
references/transcript-data-model.md for the full story):

1. glob("**/*.meta.json", recursive=True) also matches files at the top level of the
   globbed directory, since ** can match zero directories. Naively re-globbing per
   Workflow tool_use block double- or quadruple-counts the same inner agents. Fixed by
   deduping meta.json paths and attributing each session's workflow-run agents ONCE.
2. A session can fire multiple Workflow tool_use calls that all resume the same run
   (resumeFromRunId) -- these should not be treated as separate independent dispatch
   batches.

Usage:
    python mine_dispatches.py --since "2026-07-31 00:00:00" [--project-substring ac-repo-radar]

Output: one JSON object on stdout: {"dispatches": [...], "workflow_entry_points": [...],
"session_main_loop_models": {...}}
"""
import argparse
import datetime
import glob
import json
import os


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def jsonl_tool_blocks(jpath):
    """[(tool_use_id, ts, main_model, tool_name, input_dict), ...] for one session's parent jsonl."""
    out = []
    if not os.path.exists(jpath):
        return out
    with open(jpath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            msg = ev.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            main_model = msg.get("model", "unknown")
            ts = ev.get("timestamp", "")
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") in ("Task", "Agent", "Workflow"):
                    out.append((block.get("id"), ts, main_model, block.get("name"), block.get("input", {}) or {}))
    return out


def session_dominant_model(jpath):
    """Best-effort main-loop model for a whole session (most common assistant-turn model)."""
    from collections import Counter
    counts = Counter()
    if not os.path.exists(jpath):
        return None
    with open(jpath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            msg = ev.get("message")
            if isinstance(msg, dict) and msg.get("role") == "assistant":
                m = msg.get("model")
                if m:
                    counts[m] += 1
    if not counts:
        return None
    return counts.most_common(1)[0][0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", required=True, help='cutoff, e.g. "2026-07-31 00:00:00" (local time)')
    ap.add_argument("--project-substring", default=None, help="only include project dirs containing this substring")
    ap.add_argument("--projects-root", default=os.path.expanduser("~/.claude/projects"))
    args = ap.parse_args()

    projects_root = args.projects_root.replace("\\", "/")
    cutoff = datetime.datetime.strptime(args.since, "%Y-%m-%d %H:%M:%S").timestamp()

    meta_paths = [p.replace("\\", "/") for p in glob.glob(projects_root + "/*/*/subagents/**/*.meta.json", recursive=True)]
    meta_paths = [p for p in meta_paths if os.path.getmtime(p) >= cutoff]
    if args.project_substring:
        meta_paths = [p for p in meta_paths if args.project_substring in p]

    records = []
    jsonl_blocks_cache = {}

    for mp in meta_paths:
        parts = mp.split("/")
        proj_idx = parts.index("projects")
        project = parts[proj_idx + 1]
        session_id = parts[proj_idx + 2]
        project_dir = "/".join(parts[:proj_idx + 2])
        is_workflow_inner = "workflows" in parts[proj_idx + 3:]
        wf_dir = None
        if is_workflow_inner:
            wf_i = parts.index("workflows", proj_idx + 3)
            wf_dir = parts[wf_i + 1] if len(parts) > wf_i + 1 else None

        m = load_json(mp)
        if not m:
            continue

        cache_key = (project_dir, session_id)
        if cache_key not in jsonl_blocks_cache:
            jsonl_blocks_cache[cache_key] = jsonl_tool_blocks(project_dir + "/" + session_id + ".jsonl")
        blocks = jsonl_blocks_cache[cache_key]

        ts, main_model, desc = "", "unknown (parent jsonl not found)", m.get("description", "")

        if not is_workflow_inner:
            tool_use_id = m.get("toolUseId")
            match = next((b for b in blocks if b[0] == tool_use_id), None)
            if match:
                _, ts, main_model, _tool_name, inp = match
                desc = inp.get("description") or inp.get("label") or desc
        else:
            wf_block = next((b for b in blocks if b[3] == "Workflow"), None)
            if wf_block:
                _, ts, main_model, _, _ = wf_block

        records.append({
            "project": project, "session": session_id,
            "kind": "workflow_inner_agent" if is_workflow_inner else "direct_dispatch",
            "wf_dir": wf_dir,
            "agent_type": m.get("agentType", "unknown"),
            "description": desc,
            "requested_model": m.get("model", "unset"),
            "spawn_depth": m.get("spawnDepth"),
            "parent_agent_id": m.get("parentAgentId"),
            "ts": ts,
            "main_session_model": main_model,
        })

    workflow_entry_points = []
    for (project_dir, session_id), blocks in jsonl_blocks_cache.items():
        for (_tid, ts, main_model, tool_name, inp) in blocks:
            if tool_name == "Workflow":
                workflow_entry_points.append({
                    "project": os.path.basename(project_dir), "session": session_id,
                    "ts": ts, "main_session_model": main_model,
                    "description": inp.get("description", ""),
                })

    # Dominant main-loop model per session touched in the window (sessions with a
    # findable .jsonl only -- independent of whether they dispatched any subagent).
    session_models = {}
    jsonl_glob = projects_root + "/*/*.jsonl"
    if args.project_substring:
        candidates = [p for p in glob.glob(jsonl_glob) if args.project_substring in p.replace("\\", "/")]
    else:
        candidates = glob.glob(jsonl_glob)
    for jp in candidates:
        jp_norm = jp.replace("\\", "/")
        if os.path.getmtime(jp_norm) < cutoff:
            continue
        dom = session_dominant_model(jp_norm)
        if dom:
            key = "/".join(jp_norm.split("/")[-2:])
            session_models[key] = dom

    print(json.dumps({
        "dispatches": records,
        "workflow_entry_points": workflow_entry_points,
        "session_main_loop_models": session_models,
    }))


if __name__ == "__main__":
    main()
