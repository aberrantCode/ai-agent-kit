#!/usr/bin/env python3
"""measure_churn.py -- dynamic churn + token measurement on joined child sessions (read-only).

Stage 2b of the handoff-tuner loop (measure, dynamic half). The static scorer reads the prompt;
this reads what the child session actually DID, to catch churn a well-formed prompt can still
cause. Runs only on handoffs whose child transcript is joined and present (see mine_handoffs);
everything else is reported as a coverage gap, never silently dropped.

Per joined child it measures:

  [V] duplicate_worktree_creation  -- Bash tool_use whose command creates a worktree, despite the
                                      prompt's "your worktree already exists" instruction. Hard
                                      signal: the command text is unambiguous.
  [V] unattended_user_questions    -- AskUserQuestion tool_use blocks. A session dispatched under
                                      --dangerously-skip-permissions has no human to answer; each is
                                      a stall the prompt should have pre-resolved.
  [V] ledger_escalations           -- delegation-outcomes rows under this handoff_id with outcome
                                      escalated / redone-by-parent / failed. Real redo cost.
  [?] early_orientation_reads      -- Read/Grep/Glob/git-inspect tool_uses in the first N assistant
                                      turns. A PROXY for re-deriving facts the prompt already stated
                                      [V]; high counts suggest the prompt under-front-loaded state.
                                      Tagged [?] because some orientation is always legitimate.
  [V] first_turn_context / tokens  -- straight from the child's own usage records (never estimated).

Read-only: reads ~/.claude/projects/** and the two telemetry JSONL files; writes nothing.

Usage:
    python measure_churn.py                     # JSON, all joined children
    python measure_churn.py --repo-substring ai-agent-kit
    python measure_churn.py --early-turns 15 --format md
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402
import mine_handoffs as mh  # noqa: E402  (reuse the one resolution pass)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

WORKTREE_CREATE_RE = re.compile(r"worktree\s+add|new-task-worktree", re.IGNORECASE)
GIT_INSPECT_RE = re.compile(r"\bgit\s+(log|status|rev-parse|diff|branch|show)\b", re.IGNORECASE)
ORIENTATION_TOOLS = {"Read", "Grep", "Glob"}


def measure_child(jsonl_path: str, early_turns: int) -> dict:
    """Compute per-child churn metrics from the transcript. Skips sidechain (subagent) turns so
    the metrics describe the MAIN loop's behaviour, not its workers'."""
    dup_worktree = 0
    user_questions = 0
    early_reads = 0

    # Count orientation tool-uses in the first `early_turns` ASSISTANT turns.
    assistant_turn = 0
    for rec, msg in cct.iter_messages(jsonl_path, skip_sidechains=True):
        role = msg.get("role")
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        if role != "assistant":
            continue
        assistant_turn += 1
        in_early = assistant_turn <= early_turns
        for block in content:
            if not (isinstance(block, dict) and block.get("type") == "tool_use"):
                continue
            name = block.get("name")
            inp = block.get("input") or {}
            if name == "AskUserQuestion":
                user_questions += 1
            if name == "Bash":
                cmd = str(inp.get("command", ""))
                if WORKTREE_CREATE_RE.search(cmd):
                    dup_worktree += 1
                if in_early and GIT_INSPECT_RE.search(cmd):
                    early_reads += 1
            if in_early and name in ORIENTATION_TOOLS:
                early_reads += 1

    return {
        "dup_worktree_creation": dup_worktree,
        "unattended_user_questions": user_questions,
        "early_orientation_reads": early_reads,
        "assistant_turns": assistant_turn,
    }


def run(repo_substring=None, since=None, early_turns=15) -> dict:
    mined = mh.resolve_handoffs(repo_substring=repo_substring, since=since)
    out = []
    measured = 0
    for h in mined["handoffs"]:
        jsonl = h.get("child_jsonl")
        base = {
            "handoff_id": h["handoff_id"],
            "prompt": h["prompt"],
            "repo": h["repo"],
            "child_sid": h["child_sid"],
            "joined": bool(h["child_sid"]),
            "child_jsonl_present": h["child_jsonl_present"],
            "confidence": h["confidence"],
            "tokens": h.get("tokens"),
            "ledger_rows": h["ledger_rows"],
            "ledger_escalations": h["ledger_escalations"],
        }
        if jsonl and os.path.isfile(jsonl):
            base["churn"] = measure_child(jsonl, early_turns)
            measured += 1
        else:
            base["churn"] = None
            base["coverage_gap"] = "no child transcript on disk" if h["child_sid"] else "unjoined"
        out.append(base)

    joined = [r for r in out if r["joined"]]
    return {
        "early_turns": early_turns,
        "coverage": {
            **mined["coverage"],
            "measured_children": measured,
        },
        "aggregate": {
            "children_measured": measured,
            "with_dup_worktree": sum(1 for r in joined if r["churn"] and r["churn"]["dup_worktree_creation"]),
            "with_user_questions": sum(1 for r in joined if r["churn"] and r["churn"]["unattended_user_questions"]),
            "with_ledger_escalations": sum(1 for r in joined if r["ledger_escalations"]),
            "total_output_tokens": sum((r["tokens"] or {}).get("total_output") or 0 for r in joined),
        },
        "children": out,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo-substring", default=None)
    ap.add_argument("--since", default=None)
    ap.add_argument("--early-turns", type=int, default=15)
    ap.add_argument("--format", choices=["json", "md"], default="json")
    args = ap.parse_args()

    result = run(args.repo_substring, args.since, args.early_turns)

    if args.format == "json":
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    cov, agg = result["coverage"], result["aggregate"]
    w = print
    w(f"# Dynamic churn (early_turns={result['early_turns']})\n")
    w(f"- Joined children measured: {agg['children_measured']} of {cov['total_handoffs']} handoffs "
      f"(join rate {cov['join_rate_pct']}%)")
    w(f"- with duplicate-worktree creation: {agg['with_dup_worktree']}")
    w(f"- with unattended user-questions: {agg['with_user_questions']}")
    w(f"- with ledger escalations/redos: {agg['with_ledger_escalations']}")
    w(f"- total output tokens across measured children: {agg['total_output_tokens']:,}\n")
    w("## Per joined child")
    for r in result["children"]:
        if not r["joined"]:
            continue
        c = r["churn"] or {}
        t = r["tokens"] or {}
        w(f"- `{r['handoff_id']}` ctx={t.get('first_turn_context')} out={t.get('total_output')} "
          f"turns={c.get('assistant_turns')} dupWT={c.get('dup_worktree_creation')} "
          f"Q={c.get('unattended_user_questions')} earlyReads={c.get('early_orientation_reads')} "
          f"esc={r['ledger_escalations']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
