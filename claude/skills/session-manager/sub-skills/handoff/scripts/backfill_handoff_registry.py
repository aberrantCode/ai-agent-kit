#!/usr/bin/env python3
"""backfill_handoff_registry.py -- forensic backfill for the handoff correlation registry.

Joins every discoverable `docs/PROMPTS/*.md` handoff prompt to the child Claude Code session it
launched, by finding the session whose FIRST non-injected user turn is the launcher's fixed
opener ("Read and follow the instructions in the file at <path> exactly. Its full contents are
your task; treat them as your first message.") referencing that prompt's path. Appends one
`source: forensic` row per resolved (or confidently-exhausted) prompt to
`~/.claude/telemetry/handoffs.jsonl`. See
`../references/handoff-registry.md` for the full schema and confidence rubric.

Read-only on everything except the registry file itself:
  - ~/.claude/projects/**        read-only, never written
  - docs/PROMPTS/*.md            read-only, never written (never delete the prompt — a human gate)
  - ~/.claude/telemetry/handoffs.jsonl   APPEND only, idempotent on (prompt, child_sid)

Dead end (do not reintroduce): joining on the prompt's title heading or de-dated filename slug
measured 0% precision -- the child's first turn does not contain the prompt's title, it contains
the launcher's fixed opener string. See transcripts/references/transcript-data-model.md.

Usage:
    python backfill_handoff_registry.py                  # dry run, report only
    python backfill_handoff_registry.py --apply           # append forensic rows
    python backfill_handoff_registry.py --format md        # human-readable report
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "..", "..", "transcripts", "scripts"))
import cc_transcripts as cct  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DEFAULT_REGISTRY_PATH = os.path.join(os.path.expanduser("~"), ".claude", "telemetry", "handoffs.jsonl")

# The launcher's fixed opener (see dispatch/scripts/launch-claude-session.ps1). `(.+?)` captures
# the path verbatim -- no path format is assumed, so a basename-only match is still detected when
# the captured path differs from any known prompt's full path.
OPENER_RE = re.compile(
    r"^Read and follow the instructions in the file at (.+?) exactly\.\s*"
    r"Its full contents are your task; treat them as your first message\.?\s*$",
    re.IGNORECASE | re.DOTALL,
)

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _norm_path(p: str) -> str:
    """Case/separator-normalised path for comparison only -- never written out this way."""
    return cct.to_posix(os.path.normpath(p)).lower()


def parse_frontmatter(text: str) -> dict:
    """Minimal `key: value` YAML-frontmatter reader -- good enough for the flat string fields
    these prompts use (handoff_id, title, model, base_branch, branch, repo, depends_on). No lists,
    no nesting; a prompt without a frontmatter block yields {}."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        line = line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        km = re.match(r"^([A-Za-z0-9_\-]+):\s*(.*)$", line)
        if km:
            out[km.group(1)] = km.group(2).strip()
    return out


def discover_repo_roots() -> list[str]:
    """Main-checkout roots for every repo that has ANY transcript on this machine, derived from
    git identity (never a slug) -- so repos outside ai-agent-kit are found too, matching the
    prompt's own multi-checkout framing ('96 handoff-style prompt files in main checkouts')."""
    roots = set()
    for pdir in cct.project_dirs():
        cwd = cct.project_cwd(pdir, newest_only=True)
        if not cwd or not os.path.isdir(cwd):
            continue
        common = cct.common_dir(cwd)
        if common:
            # cct.common_dir() normcases its result (lowercase on Windows) for comparison
            # purposes; realpath() restores the true on-disk case so paths we write into the
            # registry match what a live row (built from PowerShell's Resolve-Path, which keeps
            # real case) would write for the exact same file -- otherwise the same prompt gets two
            # different-looking "prompt" strings depending on which writer touched it last.
            roots.add(os.path.realpath(os.path.dirname(common)))
    return sorted(roots)


def discover_prompts(repo_roots: list[str]) -> list[dict]:
    """Every docs/PROMPTS/*.md under each discovered repo root. One entry per file:
    {path, repo_root, frontmatter, mtime}."""
    out = []
    for root in repo_roots:
        for p in sorted(glob.glob(os.path.join(root, "docs", "PROMPTS", "*.md"))):
            try:
                with open(p, encoding="utf-8", errors="replace") as f:
                    text = f.read()
                mtime = os.path.getmtime(p)
            except OSError:
                continue
            out.append({
                "path": os.path.realpath(p),
                "repo_root": root,
                "frontmatter": parse_frontmatter(text),
                "mtime": mtime,
            })
    return out


def repo_and_branch_from_session(path: str):
    """Ground truth from the child's OWN transcript -- same derivation the live launcher uses
    (git, not prompt text), so forensic and live rows describe 'repo'/'branch' identically."""
    cwd = None
    branch = None
    for rec in cct.iter_records(path):
        if cwd is None and rec.get("cwd"):
            cwd = rec["cwd"]
        if branch is None and rec.get("gitBranch") is not None:
            branch = rec.get("gitBranch")
        if cwd and branch is not None:
            break
    repo = None
    if cwd:
        common = cct.common_dir(cwd)
        if common:
            repo = os.path.realpath(os.path.dirname(common))  # restore true case, see discover_repo_roots
    return repo, branch


def first_turn_opener(path: str):
    """The session's first non-injected, non-sidechain user turn, if any, as (text, timestamp).
    None if the session has no qualifying user turn at all (e.g. pure-subagent noise, or empty)."""
    for rec, msg in cct.iter_messages(path, role="user", skip_sidechains=True):
        content = msg.get("content")
        if isinstance(content, list) and any(
            isinstance(b, dict) and b.get("type") == "tool_result" for b in content
        ):
            continue
        text = cct.first_text(content) if isinstance(content, list) else (
            content if isinstance(content, str) else ""
        )
        if not text or cct.is_injected(text):
            continue
        return text.strip(), rec.get("timestamp")
    return None


def scan_openers():
    """One pass over every main transcript on the machine. Returns two dicts keyed by normalised
    path:
      exact[path_norm]    -> list of candidate dicts (opener's captured path matches exactly)
      by_basename[name]   -> list of candidate dicts (only the basename matches), EXCLUDING any
                              candidate already counted as an exact match for some other prompt.
    A candidate dict: {session, project_dir, extracted_path, ts}."""
    exact: dict[str, list[dict]] = {}
    by_basename: dict[str, list[dict]] = {}
    for pdir in cct.project_dirs():
        for path in cct.jsonl_files(pdir):
            found = first_turn_opener(path)
            if not found:
                continue
            text, ts = found
            m = OPENER_RE.match(text)
            if not m:
                continue
            extracted = m.group(1).strip().strip("'\"")
            candidate = {
                "session": os.path.splitext(os.path.basename(path))[0],
                "path": path,
                "project_dir": pdir,
                "extracted_path": extracted,
                "ts": ts,
            }
            exact.setdefault(_norm_path(extracted), []).append(candidate)
            by_basename.setdefault(os.path.basename(extracted).lower(), []).append(candidate)
    return exact, by_basename


def pick_best(candidates: list[dict], prompt_mtime: float) -> tuple[dict, list[dict]]:
    """Prefer the earliest candidate whose first turn is on/after the prompt's own mtime (a child
    cannot have been launched before the prompt it reads existed); fall back to the earliest
    overall if none parse. Returns (best, others) -- 'others' is the ambiguity to log."""
    def ts_epoch(c):
        dt = cct.parse_timestamp(c["ts"])
        return dt.timestamp() if dt else None

    after = [c for c in candidates if (ts_epoch(c) or 0) >= prompt_mtime]
    pool = after if after else candidates
    pool_sorted = sorted(pool, key=lambda c: (ts_epoch(c) is None, ts_epoch(c) or 0))
    best = pool_sorted[0]
    others = [c for c in candidates if c is not best]
    return best, others


def existing_keys(registry_path: str) -> set[tuple[str, str | None]]:
    keys = set()
    if not os.path.isfile(registry_path):
        return keys
    for rec in cct.iter_records(registry_path):
        keys.add((rec.get("prompt"), rec.get("child_sid")))
    return keys


def build_row(prompt: dict, exact_idx: dict, basename_idx: dict, seen_keys: set):
    fm = prompt["frontmatter"]
    handoff_id = fm.get("handoff_id") or ("bf-" + re.sub(
        r"[^a-z0-9]+", "-", os.path.splitext(os.path.basename(prompt["path"]))[0].lower()
    ).strip("-"))

    path_norm = _norm_path(prompt["path"])
    basename = os.path.basename(prompt["path"]).lower()

    candidates = exact_idx.get(path_norm, [])
    match_kind = "exact"
    if not candidates:
        # This prompt had no exact-path hit; fall back to basename-only. (A session landing here
        # may separately be an exact match for some OTHER prompt that happens to share this
        # basename -- rare, and still a truthful, lower-confidence basename match for this one.)
        candidates = basename_idx.get(basename, [])
        match_kind = "basename"

    ambiguity_note = None
    if not candidates:
        child_sid, ts, confidence = None, None, 0.0
        repo, branch = (prompt["repo_root"], fm.get("branch")) if prompt["repo_root"] else (None, None)
    else:
        best, others = pick_best(candidates, prompt["mtime"])
        child_sid = best["session"]
        ts = best["ts"] or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        ambiguous = len(candidates) > 1
        if match_kind == "exact":
            confidence = 0.5 if ambiguous else 0.95
        else:
            confidence = 0.4 if ambiguous else 0.7
        if ambiguous:
            ambiguity_note = f"{len(others)} other candidate(s): " + ", ".join(
                c["session"] for c in others
            )
        repo, branch = repo_and_branch_from_session(best["path"])
        if not repo:
            repo = prompt["repo_root"]
        if not branch:
            branch = fm.get("branch")

    dt = cct.parse_timestamp(ts) if ts else None
    ts_str = dt.strftime("%Y-%m-%dT%H:%M:%SZ") if dt else (
        ts or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    key = (prompt["path"], child_sid)
    row = {
        "handoff_id": handoff_id,
        "ts": ts_str,
        "parent_sid": None,  # never recoverable forensically -- never guessed
        "child_sid": child_sid,
        "prompt": prompt["path"],
        "branch": branch,
        "repo": repo,
        "source": "forensic",
        "confidence": confidence,
    }
    return row, key, match_kind if candidates else "none", ambiguity_note


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--registry-path", default=DEFAULT_REGISTRY_PATH)
    ap.add_argument("--apply", action="store_true", help="append rows (default: dry run / report only)")
    ap.add_argument("--format", choices=["json", "md"], default="md")
    args = ap.parse_args()

    repo_roots = discover_repo_roots()
    prompts = discover_prompts(repo_roots)
    exact_idx, basename_idx = scan_openers()
    seen_keys = existing_keys(args.registry_path)

    rows, skipped, conf_bucket = [], [], {"high": 0, "medium": 0, "low": 0, "none": 0}
    ambiguities = []
    for prompt in prompts:
        row, key, match_kind, ambiguity_note = build_row(prompt, exact_idx, basename_idx, seen_keys)
        if key in seen_keys:
            skipped.append({"prompt": prompt["path"], "reason": "already registered", "key": key})
            continue
        seen_keys.add(key)
        rows.append(row)
        if row["confidence"] >= 0.85:
            conf_bucket["high"] += 1
        elif row["confidence"] >= 0.5:
            conf_bucket["medium"] += 1
        elif row["confidence"] > 0.0:
            conf_bucket["low"] += 1
        else:
            conf_bucket["none"] += 1
        if ambiguity_note:
            ambiguities.append({"prompt": prompt["path"], "note": ambiguity_note})

    if args.apply and rows:
        d = os.path.dirname(args.registry_path)
        if d:
            os.makedirs(d, exist_ok=True)
        with open(args.registry_path, "a", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")

    joined = sum(1 for r in rows if r["child_sid"])
    report = {
        "repo_roots": repo_roots,
        "candidates": len(prompts),
        "new_rows": len(rows),
        "joined": joined,
        "unresolved": len(rows) - joined,
        "skipped_already_registered": len(skipped),
        "confidence_distribution": conf_bucket,
        "ambiguities": ambiguities,
        "applied": bool(args.apply),
        "registry_path": args.registry_path,
    }

    if args.format == "json":
        print(json.dumps({"report": report, "rows": rows}, indent=2, ensure_ascii=False))
        return 0

    w = print
    w(f"# Handoff registry backfill{'  (APPLIED)' if args.apply else '  (dry run)'}\n")
    w(f"- Repo roots scanned: {len(repo_roots)}")
    for r in repo_roots:
        w(f"  - {r}")
    w(f"- Prompt candidates: {report['candidates']}")
    w(f"- New rows: {report['new_rows']} ({joined} joined to a child, {report['unresolved']} unresolved)")
    w(f"- Already registered (skipped): {report['skipped_already_registered']}")
    w(f"- Confidence distribution: high={conf_bucket['high']} medium={conf_bucket['medium']} "
      f"low={conf_bucket['low']} none={conf_bucket['none']}")
    if ambiguities:
        w(f"\n## Ambiguous matches ({len(ambiguities)})")
        for a in ambiguities:
            w(f"- {a['prompt']}: {a['note']}")
    w("\n## Rows" + (" written" if args.apply else " that WOULD be written (pass --apply)"))
    for row in rows:
        w(f"- `{row['handoff_id']}` conf={row['confidence']} child_sid={row['child_sid']} "
          f"prompt={row['prompt']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
