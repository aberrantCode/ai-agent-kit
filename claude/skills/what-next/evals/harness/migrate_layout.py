"""Wrap each run's grading.json + timing.json in a run-N/ subdirectory.

The skill-creator `aggregate_benchmark.py` script expects:
    <workspace>/iteration-<N>/
        eval-<id>-<name>/
            with_skill/run-1/grading.json
            with_skill/run-1/timing.json
            ...

Subagents write outputs directly under `<kind>/`, so this script relocates the
metrics into `run-1/` before aggregation. Idempotent — safe to re-run.

Also injects a `summary` block into grading.json if the grader didn't produce
one, computing it from the `expectations` array.

Usage:
    python migrate_layout.py <iteration-number> [--workspace PATH] [--run-number 1]
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def migrate(workspace_root: Path, iteration: int, run_number: int = 1) -> None:
    iteration_dir = workspace_root / f"iteration-{iteration}"
    for eval_dir in sorted(iteration_dir.glob("eval-*")):
        for kind in ("with_skill", "without_skill"):
            kind_dir = eval_dir / kind
            if not kind_dir.exists():
                continue
            run_dir = kind_dir / f"run-{run_number}"
            run_dir.mkdir(exist_ok=True)

            for fname in ("grading.json", "timing.json"):
                src = kind_dir / fname
                if src.exists() and not (run_dir / fname).exists():
                    shutil.move(str(src), str(run_dir / fname))

            # Ensure grading.json has a summary block.
            grading_path = run_dir / "grading.json"
            if grading_path.exists():
                data = json.loads(grading_path.read_text(encoding="utf-8"))
                if "summary" not in data:
                    exps = data.get("expectations", [])
                    passed = sum(1 for e in exps if e.get("passed"))
                    total = len(exps)
                    data["summary"] = {
                        "pass_rate": round(passed / total, 4) if total else 0.0,
                        "passed": passed,
                        "failed": total - passed,
                        "total": total,
                    }
                    grading_path.write_text(
                        json.dumps(data, indent=2), encoding="utf-8"
                    )
            print(f"  {eval_dir.name}/{kind}/run-{run_number}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iteration", type=int)
    parser.add_argument("--workspace", type=Path)
    parser.add_argument("--run-number", type=int, default=1)
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    skill_dir = harness_dir.parent.parent
    workspace_root = args.workspace or (skill_dir.parent / f"{skill_dir.name}-workspace")

    migrate(workspace_root, args.iteration, args.run_number)


if __name__ == "__main__":
    main()
