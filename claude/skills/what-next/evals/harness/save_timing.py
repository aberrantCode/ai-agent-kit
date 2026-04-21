"""Record per-run token and duration metrics into timing.json files.

Usage:
    python save_timing.py <iteration-number> \
        --eval <id> --kind with_skill --tokens 54815 --duration-ms 125490 \
        [--eval ... --kind ... --tokens ... --duration-ms ...] ...

Each --eval/--kind/--tokens/--duration-ms quartet writes a timing.json at:
    <workspace>/iteration-<N>/eval-<id>-<name>/<kind>/timing.json

Or provide a JSON manifest:
    python save_timing.py <iteration-number> --from-json timings.json

where timings.json is like:
    [
      {"eval_id": 1, "kind": "with_skill",    "tokens": 54815, "duration_ms": 125490},
      {"eval_id": 1, "kind": "without_skill", "tokens": 39579, "duration_ms":  79302},
      ...
    ]

Timing data comes from subagent-completion notifications — capture it as each
notification arrives; there's no other opportunity.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def write_timing(workspace_root: Path, iteration: int, eval_id: int, kind: str, tokens: int, duration_ms: int) -> Path:
    iteration_dir = workspace_root / f"iteration-{iteration}"
    matches = list(iteration_dir.glob(f"eval-{eval_id}-*"))
    if not matches:
        raise FileNotFoundError(f"No eval directory for id={eval_id} in {iteration_dir}")
    kind_dir = matches[0] / kind
    kind_dir.mkdir(parents=True, exist_ok=True)
    path = kind_dir / "timing.json"
    payload = {
        "total_tokens": tokens,
        "duration_ms": duration_ms,
        "total_duration_seconds": round(duration_ms / 1000, 2),
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iteration", type=int)
    parser.add_argument("--workspace", type=Path)
    parser.add_argument("--eval", type=int, action="append", default=[])
    parser.add_argument("--kind", action="append", default=[])
    parser.add_argument("--tokens", type=int, action="append", default=[])
    parser.add_argument("--duration-ms", type=int, action="append", default=[])
    parser.add_argument("--from-json", type=Path)
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    skill_dir = harness_dir.parent.parent
    workspace_root = args.workspace or (skill_dir.parent / f"{skill_dir.name}-workspace")

    entries = []
    if args.from_json:
        entries = json.loads(args.from_json.read_text(encoding="utf-8"))
    else:
        if not (len(args.eval) == len(args.kind) == len(args.tokens) == len(args.duration_ms)):
            parser.error("--eval/--kind/--tokens/--duration-ms must be provided the same number of times")
        for eid, k, t, d in zip(args.eval, args.kind, args.tokens, args.duration_ms):
            entries.append({"eval_id": eid, "kind": k, "tokens": t, "duration_ms": d})

    for entry in entries:
        path = write_timing(
            workspace_root=workspace_root,
            iteration=args.iteration,
            eval_id=int(entry["eval_id"]),
            kind=str(entry["kind"]),
            tokens=int(entry["tokens"]),
            duration_ms=int(entry["duration_ms"]),
        )
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
