"""Grade each run's outputs against its assertions and write grading.json.

Reads assertions from `evals/evals.json` and the per-eval fixture outputs from
`<workspace>/iteration-<N>/eval-<id>-<name>/<kind>/outputs/`, writing a
grading.json directly next to each `outputs/` directory. Use `migrate_layout.py`
afterwards to wrap those in `run-1/` for the aggregator.

Grading is heuristic — signals come from each run's `summary.json` (the
subagents produce a structured one) plus keyword checks in `transcript.md`,
`questions-asked.md`, `backlog.md`, and `docs/what-next.md`. That means fresh
evals only need an entry in evals.json plus a grader block in EVALUATORS below.

Usage:
    python grade.py <iteration-number> [--workspace PATH]
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Callable


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def read_json(path: Path) -> dict:
    try:
        return json.loads(read(path))
    except Exception:
        return {}


def _id_of(task) -> str:
    if isinstance(task, dict):
        return task.get("id", "")
    return str(task)


# ---------------------------------------------------------------------------
# Per-eval graders. Each returns a list of {text, passed, evidence}.
# `text` fields must match the corresponding assertion in evals.json.
# ---------------------------------------------------------------------------

def grade_eval_1(outputs: Path, assertions: list[str]) -> list[dict]:
    summary = read_json(outputs / "summary.json")
    backlog = read(outputs / "backlog.md")
    questions = read(outputs / "questions-asked.md")

    decision_path = summary.get("decision_path", "")
    reads_backlog = (
        "backlog" in decision_path.lower()
        or "case a" in decision_path.lower()
        or bool(backlog)
    )
    top3 = summary.get("top_three", []) or []
    has_top_three = (
        isinstance(top3, list)
        and len(top3) >= 3
        and any(isinstance(t, dict) and "score" in t for t in top3)
    )
    auth001_first = bool(top3) and "AUTH-001" in _id_of(top3[0])
    sec_in_top3 = any("SEC-001" in _id_of(t) for t in top3)
    askuq_used = "askuserquestion" in questions.lower()
    auth002_not_in_top3 = not any("AUTH-002" in _id_of(t) for t in top3)

    signals = [
        (reads_backlog, f"decision_path mentions backlog/Case A; backlog.md size={len(backlog)}"),
        (has_top_three, f"top_three has {len(top3)} items with score fields"),
        (auth001_first, f"top_three[0] = {top3[0] if top3 else 'n/a'}"),
        (sec_in_top3, f"SEC-001 in top_three: {sec_in_top3}"),
        (askuq_used, f"AskUserQuestion referenced in questions-asked.md: {askuq_used}"),
        (True, "agent_spawned records what WOULD have been spawned, not actually spawned"),
        (auth002_not_in_top3, f"AUTH-002 in top-three? {not auth002_not_in_top3}"),
    ]
    return _zip(assertions, signals)


def grade_eval_2(outputs: Path, assertions: list[str]) -> list[dict]:
    summary = read_json(outputs / "summary.json")
    whatnext_md = read(outputs / "docs" / "what-next.md")
    questions_text = read(outputs / "questions-asked.md").lower()

    pm_detected = (
        summary.get("pm_framework") == "project-manager"
        or "project-manager" in whatnext_md
    )
    no_backlog = (
        (summary.get("backlog_md_created") is False)
        and not (outputs / "backlog.md").exists()
    )
    delegated_to = (summary.get("delegated_to") or "").lower()
    delegates = (
        "continue-tasks" in delegated_to
        or "review-tasks" in delegated_to
        or "continue-tasks" in questions_text
        or "review-tasks" in questions_text
    )
    whatnext_correct = bool(whatnext_md) and "project-manager" in whatnext_md.lower()
    top_tasks = summary.get("top_tasks_surfaced") or summary.get("top_three") or []
    plan_ids = [_id_of(t) for t in top_tasks]
    has_plan_ids = any(re.search(r"P\d+-T\d+", pid) for pid in plan_ids)

    signals = [
        (pm_detected, f"summary.pm_framework='{summary.get('pm_framework')}'"),
        (no_backlog, f"backlog.md exists in outputs: {(outputs / 'backlog.md').exists()}"),
        (delegates, f"delegated_to='{summary.get('delegated_to')}', questions mention delegation: {('continue-tasks' in questions_text) or ('review-tasks' in questions_text)}"),
        (whatnext_correct, f"docs/what-next.md len={len(whatnext_md)} mentions project-manager"),
        (has_plan_ids, f"top_tasks ids: {plan_ids}"),
    ]
    return _zip(assertions, signals)


def grade_eval_3(outputs: Path, assertions: list[str]) -> list[dict]:
    summary = read_json(outputs / "summary.json")
    questions = read(outputs / "questions-asked.md")
    whatnext_md = read(outputs / "docs" / "what-next.md")

    pm_none = summary.get("pm_framework") == "none"
    options = summary.get("bootstrap_options_offered", [])
    option_text = " ".join(options).lower() if isinstance(options, list) else ""
    four_options = (
        isinstance(options, list)
        and len(options) == 4
        and all(kw in option_text for kw in ["project-manager", "backlog", "analysis", "tasks"])
    )
    areas = summary.get("inferred_areas", {})
    has_areas = all(a in areas for a in ["AUTH", "UI", "API"])
    area_confirmation = "area" in questions.lower() and any(
        kw in questions.lower() for kw in ["confirm", "look right", "adjust"]
    )
    chose = summary.get("chose_option") or ""
    compliant = True
    if "backlog" in chose.lower():
        compliant = (outputs / "backlog.md").exists()
    observations = summary.get("observations", []) or []
    obs_text = (" ".join(observations) + " " + whatnext_md).lower()
    has_infra_obs = any(
        kw in obs_text for kw in ["test runner", "no ci", "no lint", "lint/format"]
    )

    signals = [
        (pm_none, f"summary.pm_framework='{summary.get('pm_framework')}'"),
        (four_options, f"options offered: {options}"),
        (has_areas, f"inferred_areas={areas}"),
        (area_confirmation, f"questions-asked.md references area confirmation: {area_confirmation}"),
        (compliant, f"chose={chose}, backlog.md exists: {(outputs / 'backlog.md').exists()}"),
        (has_infra_obs, f"observations={observations}"),
    ]
    return _zip(assertions, signals)


def grade_eval_4(outputs: Path, assertions: list[str]) -> list[dict]:
    summary = read_json(outputs / "summary.json")
    whatnext_md = read(outputs / "docs" / "what-next.md")
    backlog_md = read(outputs / "backlog.md")

    fp_value = summary.get("fingerprints_refreshed")
    fp_refreshed = fp_value is True or (isinstance(fp_value, int) and fp_value > 0)
    stale_list = summary.get("stale_tasks_marked", []) or []
    closed_list = summary.get("tasks_auto_closed", []) or []
    legacy_stale_handled = (
        "LEGACY-001" in stale_list
        and "LEGACY-001" not in closed_list
        and "- [x] LEGACY-001" not in backlog_md
    )
    diff = summary.get("diff_summary", "")
    has_diff = bool(diff) and len(diff) >= 10
    has_fresh_fp = bool(whatnext_md) and not re.search(r":\s*stale-hash-\d+", whatnext_md)
    proceeded = summary.get("proceeded_to_top_three") is True and bool(summary.get("top_three"))
    top3 = summary.get("top_three", []) or []
    legacy_not_in_top3 = not any("LEGACY-001" in _id_of(t) for t in top3)

    signals = [
        (fp_refreshed, f"fingerprints_refreshed={fp_value}"),
        (legacy_stale_handled, f"stale={stale_list}, auto_closed={closed_list}, checkbox unchecked={'- [x] LEGACY-001' not in backlog_md}"),
        (has_diff, f"diff_summary: {diff!r}"),
        (has_fresh_fp, f"fresh fingerprints: {has_fresh_fp}"),
        (proceeded, f"proceeded_to_top_three={summary.get('proceeded_to_top_three')}"),
        (legacy_not_in_top3, f"top_three ids: {[_id_of(t) for t in top3]}"),
    ]
    return _zip(assertions, signals)


def _zip(assertions: list[str], signals: list[tuple[bool, str]]) -> list[dict]:
    if len(assertions) != len(signals):
        raise ValueError(
            f"assertion/signal count mismatch: {len(assertions)} assertions vs {len(signals)} signals"
        )
    return [
        {"text": text, "passed": bool(passed), "evidence": evidence}
        for text, (passed, evidence) in zip(assertions, signals)
    ]


EVALUATORS: dict[int, Callable[[Path, list[str]], list[dict]]] = {
    1: grade_eval_1,
    2: grade_eval_2,
    3: grade_eval_3,
    4: grade_eval_4,
}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iteration", type=int)
    parser.add_argument("--workspace", type=Path)
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    evals_dir = harness_dir.parent
    skill_dir = evals_dir.parent
    workspace_root = args.workspace or (skill_dir.parent / f"{skill_dir.name}-workspace")
    iteration_dir = workspace_root / f"iteration-{args.iteration}"
    if not iteration_dir.exists():
        parser.error(f"iteration directory not found: {iteration_dir}")

    evals_json = json.loads((evals_dir / "evals.json").read_text(encoding="utf-8"))
    evals_by_id = {e["id"]: e for e in evals_json["evals"]}

    for eval_dir in sorted(iteration_dir.glob("eval-*")):
        parts = eval_dir.name.split("-", 2)
        eval_id = int(parts[1])
        evaluator = EVALUATORS.get(eval_id)
        if evaluator is None:
            print(f"  WARN: no evaluator registered for eval_id={eval_id}; skipping {eval_dir.name}")
            continue
        raw_assertions = evals_by_id.get(eval_id, {}).get("assertions", [])
        assertion_texts = [a["text"] if isinstance(a, dict) else str(a) for a in raw_assertions]

        for kind in ("with_skill", "without_skill"):
            outputs = eval_dir / kind / "outputs"
            if not outputs.exists():
                continue
            grades = evaluator(outputs, assertion_texts)
            passed = sum(1 for g in grades if g["passed"])
            total = len(grades)
            grading = {
                "summary": {
                    "pass_rate": round(passed / total, 4) if total else 0.0,
                    "passed": passed,
                    "failed": total - passed,
                    "total": total,
                },
                "expectations": grades,
            }
            (eval_dir / kind / "grading.json").write_text(
                json.dumps(grading, indent=2), encoding="utf-8"
            )
            print(f"  eval-{eval_id} / {kind:14s}: {passed}/{total}")


if __name__ == "__main__":
    main()
