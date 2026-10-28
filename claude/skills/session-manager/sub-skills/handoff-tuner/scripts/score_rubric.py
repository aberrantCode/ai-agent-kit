#!/usr/bin/env python3
"""score_rubric.py -- static rubric scorer for handoff prompts (read-only).

Stage 2a of the handoff-tuner loop (measure, static half). Scores each docs/PROMPTS/*.md handoff
prompt against the machine-checkable rubric in ../references/rubric.json -- which is itself the
testable projection of ../../handoff/SKILL.md's Required-frontmatter + Required-sections rules.

The rubric is DATA, never code: this script reads rubric.json and applies it. Changing a weight,
adding a check, or retiring one is a rubric.json edit + a version bump in references/rubric.vN.md,
not a code change here. That is what makes the loop self-tunable through a reviewed diff.

What it checks (all heuristic, text-level -- a coverage proxy, not a correctness judge):
  * required frontmatter fields present
  * each required section present (heading) and non-empty (a body_pattern matches)
  * state claims inside the State section are tagged [V] / [?]
  * references to sibling-bundle scripts are absolute, not bare `scripts/...`
  * the prompt warns the child its worktree/branch already exists

Usage:
    python score_rubric.py PROMPT.md [PROMPT2.md ...]      # score specific files
    python score_rubric.py --all                           # score every discoverable prompt
    python score_rubric.py --all --repo-substring ai-agent-kit
    python score_rubric.py --all --format md
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "transcripts", "scripts"))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "handoff", "scripts"))
import cc_transcripts as cct  # noqa: E402
import backfill_handoff_registry as bf  # noqa: E402  (discover_repo_roots/discover_prompts, parse_frontmatter)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

RUBRIC_PATH = os.path.join(_HERE, "..", "references", "rubric.json")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
# A "factual line" inside the State section that ought to carry a [V]/[?] tag: a bullet or numbered
# item that contains a digit or a backticked token (a path/count/id) -- i.e. a concrete claim, not
# a prose sentence. Kept deliberately narrow to avoid flagging ordinary instruction prose.
STATE_CLAIM_RE = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+.*(?:\d|`[^`]+`)")


def load_rubric(path=RUBRIC_PATH) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def split_sections(body: str):
    """Return [(heading_text_lower, [lines])] for the markdown body (frontmatter stripped).
    A preamble before the first heading is keyed under ''."""
    sections = []
    cur_key, cur_lines = "", []
    for line in body.splitlines():
        m = HEADING_RE.match(line)
        if m:
            sections.append((cur_key, cur_lines))
            cur_key, cur_lines = m.group(1).strip().lower(), []
        else:
            cur_lines.append(line)
    sections.append((cur_key, cur_lines))
    return sections


def strip_frontmatter(text: str) -> str:
    m = bf.FRONTMATTER_RE.match(text)
    return text[m.end():] if m else text


def find_section(sections, heading_patterns):
    """First (heading, lines) whose heading contains any pattern, else None."""
    for key, lines in sections:
        for pat in heading_patterns:
            if pat in key:
                return key, lines
    return None


def score_prompt(path: str, rubric: dict) -> dict:
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    fm = bf.parse_frontmatter(text)
    body = strip_frontmatter(text)
    sections = split_sections(body)
    body_lower = body.lower()
    real = os.path.realpath(path)

    # v2: a handoff that TARGETS a home repo (the archive) may legitimately use repo-relative script
    # paths, so the cross-bundle-script check is skipped for it. Detect by the prompt path or its
    # frontmatter `repo` field containing a home_repo marker.
    home_markers = [m.lower() for m in rubric.get("home_repo_markers", [])]
    targets_home = any(m in real.lower() or m in str(fm.get("repo", "")).lower() for m in home_markers)

    # Two running totals: `craft` over non-floor items (ranks prompts), `conv` over everything
    # (convention compliance, includes the ~100%-fail floors). v1 reported only the latter.
    earned = {"craft": 0.0, "conv": 0.0}
    total = {"craft": 0.0, "conv": 0.0}
    failures = []       # non-floor failures (the craft signal)
    floor_gaps = []     # floor failures (universal post-convention gaps)

    def record(is_floor, weight, passed, fail_obj):
        total["conv"] += weight
        if passed:
            earned["conv"] += weight
        if not is_floor:
            total["craft"] += weight
            if passed:
                earned["craft"] += weight
        if not passed:
            (floor_gaps if is_floor else failures).append({**fail_obj, "floor": is_floor})

    # --- frontmatter fields ---
    for field in rubric["frontmatter_fields"]:
        record(field.get("floor", False), field["weight"], bool(fm.get(field["key"])),
               {"kind": "frontmatter", "id": field["key"],
                "detail": f"missing frontmatter field `{field['key']}`"})

    # --- required sections ---
    for sec in rubric["sections"]:
        is_floor = sec.get("floor", False)
        found = find_section(sections, sec["heading_patterns"])
        if not found:
            record(is_floor, sec["weight"], False,
                   {"kind": "section", "id": sec["id"],
                    "detail": f"missing section (no heading matching {sec['heading_patterns']})"})
            continue
        _key, lines = found
        sec_text = "\n".join(lines).lower()
        body_pats = sec.get("body_patterns") or []
        if not body_pats:
            passed = bool(sec_text.strip())
            record(is_floor, sec["weight"], passed,
                   {"kind": "section", "id": sec["id"], "detail": "section is empty"})
        else:
            passed = any(re.search(bp, sec_text) for bp in body_pats)
            record(is_floor, sec["weight"], passed,
                   {"kind": "section", "id": sec["id"],
                    "detail": f"section present but no expected content {body_pats}"})

    # --- cross-cutting checks ---
    for chk in rubric["checks"]:
        is_floor = chk.get("floor", False)
        w, cid = chk["weight"], chk["id"]
        if chk["kind"] == "frontmatter":
            missing = [ff["key"] for ff in rubric["frontmatter_fields"] if not fm.get(ff["key"])]
            record(is_floor, w, not missing,
                   {"kind": "check", "id": cid, "detail": f"frontmatter incomplete: missing {missing}"})
        elif chk["kind"] == "tagged_claims":
            sec = next((s for s in rubric["sections"] if s["id"] == chk["scope_section"]), None)
            found = find_section(sections, sec["heading_patterns"]) if sec else None
            if not found:
                record(is_floor, w, True, {})       # no State section -> neutral (section check handles it)
                continue
            _k, lines = found
            tag_re = re.compile("|".join(chk["tag_patterns"]))
            untagged = [ln.strip() for ln in lines
                        if STATE_CLAIM_RE.match(ln) and not tag_re.search(ln)]
            record(is_floor, w, not untagged,
                   {"kind": "check", "id": cid,
                    "detail": f"{len(untagged)} untagged state claim(s)", "examples": untagged[:3]})
        elif chk["kind"] == "bare_script_path":
            if chk.get("skip_if_home_repo") and targets_home:
                record(is_floor, w, True, {})       # archive-targeted: repo-relative paths are fine
                continue
            bad = []
            for name in chk["cross_bundle_scripts"]:
                for m in re.finditer(r"(\S*" + re.escape(name) + r")", text):
                    ref = m.group(1)
                    low = ref.lower()
                    if any(mark.lower() in low for mark in chk["absolute_markers"]):
                        continue
                    if ref == name or "scripts/" + name in low or low.startswith("scripts/"):
                        bad.append(ref)
            bad = sorted(set(bad))
            record(is_floor, w, not bad,
                   {"kind": "check", "id": cid,
                    "detail": f"{len(bad)} bare cross-bundle script path(s)", "examples": bad[:3]})
        elif chk["kind"] == "regex_any":
            passed = any(re.search(p, body_lower) for p in chk["patterns"])
            record(is_floor, w, passed,
                   {"kind": "check", "id": cid, "detail": chk.get("rationale", cid)})

    composite = round(100 * earned["craft"] / total["craft"], 1) if total["craft"] else 0.0
    conv_composite = round(100 * earned["conv"] / total["conv"], 1) if total["conv"] else 0.0
    band = "poor"
    for b in rubric["scoring"]["bands"]:
        if composite >= b["min"]:
            band = b["label"]
            break
    return {
        "prompt": real,
        "composite": composite,               # v2: craft (non-floor) composite — this ranks prompts
        "convention_composite": conv_composite,  # v1-equivalent, includes floors
        "band": band,
        "earned": round(earned["craft"], 1),
        "total": round(total["craft"], 1),
        "n_failures": len(failures),
        "failures": failures,
        "floor_gaps": floor_gaps,
    }


def discover_all_prompts(repo_substring=None):
    roots = bf.discover_repo_roots()
    out = []
    for pr in bf.discover_prompts(roots):
        if repo_substring and repo_substring.lower() not in pr["path"].lower():
            continue
        out.append(pr["path"])
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prompts", nargs="*", help="prompt .md files to score")
    ap.add_argument("--all", action="store_true", help="score every discoverable docs/PROMPTS/*.md")
    ap.add_argument("--repo-substring", default=None)
    ap.add_argument("--rubric", default=RUBRIC_PATH)
    ap.add_argument("--format", choices=["json", "md"], default="json")
    args = ap.parse_args()

    rubric = load_rubric(args.rubric)
    paths = list(args.prompts)
    if args.all:
        paths += discover_all_prompts(args.repo_substring)
    paths = sorted(set(os.path.realpath(p) for p in paths if os.path.isfile(p)))
    if not paths:
        print("no prompt files given/found", file=sys.stderr)
        return 2

    results = [score_prompt(p, rubric) for p in paths]
    results.sort(key=lambda r: r["composite"])

    if args.format == "json":
        bands = {}
        for r in results:
            bands[r["band"]] = bands.get(r["band"], 0) + 1
        avg = round(sum(r["composite"] for r in results) / len(results), 1)
        print(json.dumps({"rubric_version": rubric["version"], "n": len(results),
                          "avg_composite": avg, "band_counts": bands, "results": results},
                         indent=2, ensure_ascii=False))
        return 0

    w = print
    avg = round(sum(r["composite"] for r in results) / len(results), 1)
    w(f"# Static rubric scores (rubric v{rubric['version']}) — {len(results)} prompts, avg {avg}\n")
    from collections import Counter
    bands = Counter(r["band"] for r in results)
    w("Bands: " + ", ".join(f"{k}={v}" for k, v in bands.items()) + "\n")
    # most common failure ids
    fc = Counter(f["id"] for r in results for f in r["failures"])
    w("## Most common failures")
    for fid, n in fc.most_common():
        w(f"- `{fid}`: {n} prompt(s)")
    w("\n## Lowest-scoring prompts")
    for r in results[:15]:
        w(f"- {r['composite']} ({r['band']}) {os.path.basename(r['prompt'])}"
          f" — {', '.join(f['id'] for f in r['failures'][:5])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
