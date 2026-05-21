"""Copy the canonical fixtures into a fresh iteration-N workspace.

Usage:
    python setup_iteration.py <iteration-number> [--workspace PATH]

Reads fixtures from `evals/fixtures/eval-*/` (sibling to this script).
Writes a workspace at:
    <workspace>/iteration-<N>/
        eval-<id>-<name>/
            eval_metadata.json
            with_skill/fixtures/    (copy of evals/fixtures/eval-...)
            with_skill/outputs/
            without_skill/fixtures/
            without_skill/outputs/

Default workspace is <skill-dir>-workspace/ (sibling to the skill dir), matching
the skill-creator convention.

Reads assertions from evals/evals.json.
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iteration", type=int, help="Iteration number (1-based)")
    parser.add_argument(
        "--workspace",
        type=Path,
        help="Workspace root (default: ../../what-next-workspace relative to this script)",
    )
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    evals_dir = harness_dir.parent
    skill_dir = evals_dir.parent
    fixtures_root = evals_dir / "fixtures"

    if args.workspace:
        workspace_root = args.workspace
    else:
        workspace_root = skill_dir.parent / f"{skill_dir.name}-workspace"

    iteration_dir = workspace_root / f"iteration-{args.iteration}"
    if iteration_dir.exists():
        shutil.rmtree(iteration_dir)
    iteration_dir.mkdir(parents=True)

    evals_json = json.loads((evals_dir / "evals.json").read_text(encoding="utf-8"))
    evals_by_id = {e["id"]: e for e in evals_json["evals"]}

    for fixture_dir in sorted(fixtures_root.glob("eval-*")):
        # Parse "eval-<id>-<name>" from directory name.
        parts = fixture_dir.name.split("-", 2)
        eval_id = int(parts[1])
        eval_name = parts[2]

        eval_def = evals_by_id.get(eval_id, {})

        eval_root = iteration_dir / fixture_dir.name
        for kind in ("with_skill", "without_skill"):
            shutil.copytree(fixture_dir, eval_root / kind / "fixtures")
            (eval_root / kind / "outputs").mkdir(parents=True, exist_ok=True)

        assertions = eval_def.get("assertions", [])
        # evals.json stores assertions as list of {text, check}; eval_metadata only needs text.
        metadata = {
            "eval_id": eval_id,
            "eval_name": eval_name,
            "prompt": eval_def.get("prompt", ""),
            "assertions": [{"text": a.get("text", a) if isinstance(a, dict) else a} for a in assertions],
        }
        (eval_root / "eval_metadata.json").write_text(
            json.dumps(metadata, indent=2), encoding="utf-8"
        )

    print(f"Workspace ready at: {iteration_dir}")
    for eval_root in sorted(iteration_dir.glob("eval-*")):
        print(f"  {eval_root.name}")


if __name__ == "__main__":
    main()
