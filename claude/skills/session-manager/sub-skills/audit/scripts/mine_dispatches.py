#!/usr/bin/env python3
"""Mine Claude Code transcripts for subagent-dispatch records and per-session main-loop models.

Ground truth for "was a subagent spawned, and with what model" is
~/.claude/projects/<project>/<session-id>/subagents/**/*.meta.json -- NOT the parent
transcript alone. A still-open or concurrent session's parent .jsonl may be stale or
altogether missing while its subagent dispatch records already exist, so meta.json
mtime (not parent-jsonl mtime) is the correct signal for "did a dispatch happen in
this window".

Two known gotchas this script already handles (found the hard way -- see
../transcripts/references/transcript-data-model.md and the
cc_transcripts library docstring for the full story):

1. glob("**/*.meta.json", recursive=True) also matches files at the top level of the
   globbed directory, since ** can match zero directories. Naively re-globbing per
   Workflow tool_use block double- or quadruple-counts the same inner agents. Fixed by
   deduping meta.json paths and attributing each session's workflow-run agents ONCE.
2. A session can fire multiple Workflow tool_use calls that all resume the same run
   (resumeFromRunId) -- these should not be treated as separate independent dispatch
   batches.

Usage:
    python scripts/mine_dispatches.py --since "2026-07-31 00:00:00" [--project-substring ac-repo-radar]

Output: one JSON object on stdout: {"dispatches": [...], "workflow_entry_points": [...],
"session_main_loop_models": {...}}
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402


def session_dominant_model(jpath):
    """Best-effort main-loop model for a whole session (most common assistant-turn model)."""
    from collections import Counter
    counts = Counter()
    for _rec, msg in cct.iter_messages(jpath, role="assistant"):
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
    ap.add_argument("--projects-root", default=cct.projects_root())
    args = ap.parse_args()

    projects_root = cct.to_posix(args.projects_root)
    cutoff = cct.parse_since(args.since)

    meta_paths = cct.subagent_meta_paths(projects_root, since=cutoff, project_substring=args.project_substring)

    records = []
    jsonl_blocks_cache = {}

    for mp in meta_paths:
        pm = cct.parse_meta_path(mp, root=projects_root)
        project, session_id, project_dir = pm["project"], pm["session"], pm["project_dir"]
        is_workflow_inner, wf_dir = pm["is_workflow_inner"], pm["wf_dir"]

        m = cct.load_json(mp)
        if not m:
            continue

        cache_key = (project_dir, session_id)
        if cache_key not in jsonl_blocks_cache:
            jsonl_blocks_cache[cache_key] = list(cct.iter_tool_uses(
                project_dir + "/" + session_id + ".jsonl", cct.DISPATCH_TOOL_NAMES))
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
    for jp, slug, _sid, _mt in cct.iter_sessions(projects_root, since=cutoff,
                                                 project_substring=args.project_substring):
        dom = session_dominant_model(jp)
        if dom:
            session_models[slug + "/" + os.path.basename(jp)] = dom

    print(json.dumps({
        "dispatches": records,
        "workflow_entry_points": workflow_entry_points,
        "session_main_loop_models": session_models,
    }))


if __name__ == "__main__":
    main()
