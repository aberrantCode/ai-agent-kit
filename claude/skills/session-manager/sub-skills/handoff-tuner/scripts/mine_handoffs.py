#!/usr/bin/env python3
"""mine_handoffs.py -- enumerate handoffs and resolve each to its artifacts (read-only).

Stage 1 of the handoff-tuner loop (mine). For every handoff it can find it resolves:
  * the prompt file (docs/PROMPTS/*.md) it was built from
  * the child Claude Code session that executed it (if joinable)
  * the delegation-ledger rows logged under its handoff_id
  * the child session's token usage (first-turn context + burn)

Join policy, per the D2 prompt and the handoff registry schema
(../../handoff/references/handoff-registry.md):

  REGISTRY-FIRST: read ~/.claude/telemetry/handoffs.jsonl; group rows by handoff_id and keep
  the strongest row per id (a non-null child_sid beats null; higher confidence wins ties).

  FORENSIC FALLBACK: for handoff_ids / prompts the registry has NOT joined to a child, run the
  SAME launcher-opener join the backfill script uses -- IN MEMORY, never writing a row. This
  reuses backfill_handoff_registry.scan_openers / discover_prompts verbatim so the dead-end
  (title/slug join = 0% precision) is not reintroduced and the counting fixes in cc_transcripts
  are inherited, not re-derived.

Read-only on everything: ~/.claude/projects/** and the two telemetry JSONL files are only read.
Nothing here writes to a transcript tree, the registry, or the delegation ledger.

Usage:
    python mine_handoffs.py                       # JSON to stdout, full corpus
    python mine_handoffs.py --repo-substring ai-agent-kit
    python mine_handoffs.py --since "2026-07-25 00:00:00"   # only prompts modified on/after
    python mine_handoffs.py --format md           # human-readable summary
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "transcripts", "scripts"))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "handoff", "scripts"))
import cc_transcripts as cct  # noqa: E402
import backfill_handoff_registry as bf  # noqa: E402  (reuse the forensic join, do not re-derive)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DEFAULT_REGISTRY = os.path.join(os.path.expanduser("~"), ".claude", "telemetry", "handoffs.jsonl")
DEFAULT_LEDGER = os.path.join(os.path.expanduser("~"), ".claude", "telemetry", "delegation-outcomes.jsonl")


def read_registry(path: str) -> dict:
    """{handoff_id: strongest_row}. Strongest = has child_sid, then highest confidence."""
    best: dict[str, dict] = {}
    for rec in cct.iter_records(path):
        hid = rec.get("handoff_id")
        if not hid:
            continue
        cur = best.get(hid)
        if cur is None:
            best[hid] = rec
            continue
        better = (
            (bool(rec.get("child_sid")), float(rec.get("confidence") or 0.0))
            > (bool(cur.get("child_sid")), float(cur.get("confidence") or 0.0))
        )
        if better:
            best[hid] = rec
    return best


def index_child_jsonl() -> dict:
    """{session_id: jsonl_path} across every project dir (one listdir pass per dir)."""
    out = {}
    for pdir in cct.project_dirs():
        for p in cct.jsonl_files(pdir):
            sid = os.path.splitext(os.path.basename(p))[0]
            out.setdefault(sid, p)
    return out


def ledger_rows_by_handoff(path: str) -> dict:
    """{handoff_id: [rows]} from the delegation-outcomes ledger."""
    out: dict[str, list] = {}
    for rec in cct.iter_records(path):
        hid = rec.get("handoff_id")
        if hid:
            out.setdefault(hid, []).append(rec)
    return out


def child_token_usage(jsonl_path: str) -> dict:
    """first_turn_context, total input/output/cache, assistant-turn count. Tokens come straight
    from each record's own usage dict (gotcha 15) -- never estimated here."""
    first_ctx = None
    tin = tout = tcr = tcc = 0
    turns = 0
    for _rec, msg in cct.iter_messages(jsonl_path, role="assistant"):
        usage = msg.get("usage")
        if not isinstance(usage, dict):
            continue
        i, o, cr, cc = cct.usage_tokens(usage)
        if first_ctx is None:
            first_ctx = i + cr + cc
        tin += i
        tout += o
        tcr += cr
        tcc += cc
        turns += 1
    return {
        "first_turn_context": first_ctx,
        "total_input": tin,
        "total_output": tout,
        "total_cache_read": tcr,
        "total_cache_creation": tcc,
        "assistant_turns": turns,
    }


def resolve_handoffs(registry_path=DEFAULT_REGISTRY, ledger_path=DEFAULT_LEDGER,
                     repo_substring=None, since=None) -> dict:
    """The one resolution pass every downstream stage (scoring, churn) imports.
    Returns {"handoffs": [...], "coverage": {...}}."""
    cutoff = cct.parse_since(since) if since else None
    registry = read_registry(registry_path)
    child_idx = index_child_jsonl()
    ledger = ledger_rows_by_handoff(ledger_path)

    # Forensic fallback inputs (reused verbatim from the backfill module).
    repo_roots = bf.discover_repo_roots()
    prompts = bf.discover_prompts(repo_roots)
    exact_idx, basename_idx = bf.scan_openers()
    prompt_by_hid: dict[str, dict] = {}
    for pr in prompts:
        fm = pr["frontmatter"]
        hid = fm.get("handoff_id") or ("bf-" + __import__("re").sub(
            r"[^a-z0-9]+", "-",
            os.path.splitext(os.path.basename(pr["path"]))[0].lower()).strip("-"))
        prompt_by_hid.setdefault(hid, pr)

    all_hids = set(registry) | set(prompt_by_hid)
    records, from_registry, from_forensic, unjoined = [], 0, 0, 0

    for hid in sorted(all_hids):
        reg = registry.get(hid)
        pr = prompt_by_hid.get(hid)

        prompt_path = (reg or {}).get("prompt") or (pr or {}).get("path")
        repo = (reg or {}).get("repo") or (pr or {}).get("repo_root")
        branch = (reg or {}).get("branch") or ((pr or {}).get("frontmatter") or {}).get("branch")
        child_sid = (reg or {}).get("child_sid")
        confidence = (reg or {}).get("confidence")
        source = (reg or {}).get("source")

        if repo_substring:
            hay = (repo or "") + "|" + (prompt_path or "")
            if repo_substring.lower() not in hay.lower():
                continue
        if cutoff is not None and pr is not None and pr.get("mtime", 0) < cutoff:
            continue

        # Registry-first: if the registry already joined a child, trust it.
        if child_sid:
            from_registry += 1
            join_via = "registry"
        elif pr is not None:
            # Forensic fallback in memory: build the row the backfill WOULD write (no --apply).
            row, _key, match_kind, _amb = bf.build_row(pr, exact_idx, basename_idx, set())
            if row.get("child_sid"):
                child_sid = row["child_sid"]
                confidence = row["confidence"]
                source = "forensic(in-memory)"
                branch = branch or row.get("branch")
                repo = repo or row.get("repo")
                from_forensic += 1
                join_via = "forensic:" + match_kind
            else:
                unjoined += 1
                join_via = "none"
        else:
            unjoined += 1
            join_via = "registry-only-no-prompt"

        child_jsonl = child_idx.get(child_sid) if child_sid else None
        tokens = child_token_usage(child_jsonl) if child_jsonl else None
        lrows = ledger.get(hid, [])

        records.append({
            "handoff_id": hid,
            "prompt": prompt_path,
            "repo": repo,
            "branch": branch,
            "child_sid": child_sid,
            "child_jsonl": child_jsonl,
            "child_jsonl_present": bool(child_jsonl),
            "confidence": confidence,
            "source": source,
            "join_via": join_via,
            "has_prompt_file": bool(prompt_path and os.path.isfile(prompt_path)),
            "ledger_rows": len(lrows),
            "ledger_escalations": sum(1 for r in lrows if r.get("outcome") in
                                      ("escalated", "redone-by-parent", "failed")),
            "tokens": tokens,
        })

    joined = from_registry + from_forensic
    total = len(records)
    coverage = {
        "total_handoffs": total,
        "joined": joined,
        "joined_via_registry": from_registry,
        "joined_via_forensic": from_forensic,
        "unjoined": total - joined,
        "join_rate_pct": round(100 * joined / total, 1) if total else 0.0,
        "child_jsonl_present": sum(1 for r in records if r["child_jsonl_present"]),
        "repo_roots_scanned": len(repo_roots),
    }
    return {"handoffs": records, "coverage": coverage}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--registry-path", default=DEFAULT_REGISTRY)
    ap.add_argument("--ledger-path", default=DEFAULT_LEDGER)
    ap.add_argument("--repo-substring", default=None, help="only handoffs whose repo/prompt path contains this")
    ap.add_argument("--since", default=None, help='only prompts modified on/after, e.g. "2026-07-25 00:00:00"')
    ap.add_argument("--format", choices=["json", "md"], default="json")
    args = ap.parse_args()

    result = resolve_handoffs(args.registry_path, args.ledger_path, args.repo_substring, args.since)

    if args.format == "json":
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    cov = result["coverage"]
    w = print
    w(f"# Handoff mining\n")
    w(f"- Handoffs: {cov['total_handoffs']}  (joined {cov['joined']} = {cov['join_rate_pct']}%: "
      f"{cov['joined_via_registry']} registry + {cov['joined_via_forensic']} forensic; "
      f"{cov['unjoined']} unjoined)")
    w(f"- Child transcripts present on disk: {cov['child_jsonl_present']}")
    w(f"- Repo roots scanned: {cov['repo_roots_scanned']}\n")
    w("## Joined handoffs")
    for r in result["handoffs"]:
        if not r["child_sid"]:
            continue
        tok = r["tokens"] or {}
        w(f"- `{r['handoff_id']}` via {r['join_via']} conf={r['confidence']} "
          f"ctx={tok.get('first_turn_context')} out={tok.get('total_output')} "
          f"ledger={r['ledger_rows']}({r['ledger_escalations']} esc)  {r['prompt']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
