#!/usr/bin/env python3
"""Splice clips from several chapter-section folders into one interleaved video.

Each GROUP is a folder of clips (typically the `sections/` output of
generate-cuts.py / cut-chapters.sh). The script builds a pool per group, drops
clips whose filename contains an excluded substring, optionally picks a random
subset, then interleaves the groups round-robin:

    A1, B1, C1, A2, B2, C2, ...

When groups are unequal in length, the longer group's leftovers are appended in
order once the shorter groups are exhausted. All inputs are normalised (scale +
pad to the target size, setsar=1, constant fps, 48 kHz stereo audio) and joined
with ffmpeg's concat filter in one full re-encode, so mismatched fps / SAR / GOP
between source videos cannot glitch the output.

Usage:
  splice_clips.py --group LABEL=DIR [--group LABEL=DIR ...] --out FILE
                  [--exclude SUBSTR ...] [--pick N | --pick LABEL=N ...]
                  [--seed N] [--random-order] [--width W --height H --fps F]
                  [--dry-run]

  --group    LABEL=DIR. DIR is a folder of .mp4 clips, or a download folder that
             contains a `sections/` subfolder (that subfolder is used). Order of
             --group flags is the interleave order.
  --exclude  Case-insensitive filename substring to drop (repeatable), e.g.
             --exclude get-ready --exclude intro. Default: exclude nothing.
  --pick     Randomly pick N clips from every group (`--pick 3`) or from one
             group (`--pick abs=4`, repeatable; a bare number sets the default
             for groups without their own). Default: use ALL eligible clips.
  --seed     Seed the random pick so it is reproducible.
  --random-order  Keep picks in the order they were drawn. By default picks are
             re-sorted into source order (lowest chapter number first).
  --dry-run  Print the selected sequence and the ffmpeg command; run nothing.

Idempotent: overwrites --out on every run. ffmpeg comes from PATH, else from the
imageio-ffmpeg package if installed.
"""
from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Mapping, Sequence

DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_FPS = 1920, 1080, 30


def parse_group(spec: str) -> tuple[str, Path]:
    """Split 'LABEL=DIR' into (label, Path)."""
    label, sep, raw = spec.partition("=")
    if not sep or not label.strip() or not raw.strip():
        raise SystemExit(f"--group must look like LABEL=DIR, got: {spec!r}")
    return label.strip(), Path(raw.strip())


def parse_picks(specs: Sequence[str]) -> tuple[int | None, dict[str, int]]:
    """Parse --pick values into (default_count, per_label_counts)."""
    default: int | None = None
    per_label: dict[str, int] = {}
    for spec in specs:
        label, sep, num = spec.rpartition("=")
        raw = num if sep else spec
        try:
            count = int(raw)
        except ValueError:
            raise SystemExit(f"--pick must be N or LABEL=N, got: {spec!r}")
        if count < 1:
            raise SystemExit(f"--pick count must be >= 1, got: {spec!r}")
        if sep and label.strip():
            per_label[label.strip()] = count
        else:
            default = count
    return default, per_label


def clip_dir(path: Path) -> Path:
    """Use <path>/sections when it exists, else the path itself."""
    sections = path / "sections"
    return sections if sections.is_dir() else path


def eligible_clips(path: Path, exclude: Sequence[str] = ()) -> list[Path]:
    """Sorted .mp4 clips in the group folder minus excluded substrings."""
    folder = clip_dir(path)
    if not folder.is_dir():
        raise SystemExit(f"group folder not found: {folder}")
    needles = [x.lower() for x in exclude if x]
    return [
        c for c in sorted(folder.glob("*.mp4"))
        if not any(n in c.name.lower() for n in needles)
    ]


def pick_clips(rng: random.Random, pool: Sequence[Path], count: int,
               keep_source_order: bool = True) -> list[Path]:
    """Randomly pick `count` clips; by default restore ascending source order."""
    if count > len(pool):
        raise SystemExit(f"need {count} clips but the pool has only {len(pool)}")
    chosen = rng.sample(list(pool), count)
    if keep_source_order:
        order = {clip: i for i, clip in enumerate(pool)}
        chosen.sort(key=order.__getitem__)
    return chosen


def interleave(groups: Sequence[Sequence[Path]]) -> list[Path]:
    """Round-robin across groups; leftovers of longer groups follow in order."""
    sequence: list[Path] = []
    for i in range(max((len(g) for g in groups), default=0)):
        for g in groups:
            if i < len(g):
                sequence.append(g[i])
    return sequence


def build_filter(n: int, width: int, height: int, fps: int) -> str:
    """filter_complex that normalises n inputs then concats them."""
    parts = []
    labels = ""
    for i in range(n):
        parts.append(
            f"[{i}:v]scale={width}:{height}:force_original_aspect_ratio=decrease,"
            f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,setsar=1,"
            f"fps={fps},format=yuv420p[v{i}];"
            f"[{i}:a]aresample=48000,aformat=channel_layouts=stereo[a{i}]"
        )
        labels += f"[v{i}][a{i}]"
    return ";".join(parts) + f";{labels}concat=n={n}:v=1:a=1[outv][outa]"


def build_command(ffmpeg: str, sequence: Sequence[Path], out: Path,
                  width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT,
                  fps: int = DEFAULT_FPS) -> list[str]:
    cmd = [ffmpeg, "-y"]
    for clip in sequence:
        cmd += ["-i", str(clip)]
    cmd += [
        "-filter_complex", build_filter(len(sequence), width, height, fps),
        "-map", "[outv]", "-map", "[outa]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart", str(out),
    ]
    return cmd


def resolve_ffmpeg() -> str:
    """ffmpeg from PATH, else the binary bundled with imageio-ffmpeg."""
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
    except ImportError:
        raise SystemExit("ffmpeg not found: put it on PATH or `pip install imageio-ffmpeg`")
    return imageio_ffmpeg.get_ffmpeg_exe()


def select_groups(groups: Mapping[str, Path], exclude: Sequence[str],
                  default_pick: int | None, picks: Mapping[str, int],
                  rng: random.Random, keep_source_order: bool = True
                  ) -> dict[str, list[Path]]:
    """Per-label ordered clip lists (all eligible, or a random pick)."""
    unknown = set(picks) - set(groups)
    if unknown:
        raise SystemExit(f"--pick names unknown group(s): {', '.join(sorted(unknown))}")
    selected: dict[str, list[Path]] = {}
    for label, path in groups.items():
        pool = eligible_clips(path, exclude)
        if not pool:
            raise SystemExit(f"group {label!r}: no eligible clips in {clip_dir(path)}")
        count = picks.get(label, default_pick)
        selected[label] = (pick_clips(rng, pool, count, keep_source_order)
                           if count is not None else pool)
    return selected


def main(argv: Sequence[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--group", action="append", required=True, metavar="LABEL=DIR")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--exclude", action="append", default=[], metavar="SUBSTR")
    ap.add_argument("--pick", action="append", default=[], metavar="N|LABEL=N")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--random-order", action="store_true")
    ap.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    ap.add_argument("--height", type=int, default=DEFAULT_HEIGHT)
    ap.add_argument("--fps", type=int, default=DEFAULT_FPS)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    groups: dict[str, Path] = {}
    for spec in args.group:
        label, path = parse_group(spec)
        if label in groups:
            raise SystemExit(f"duplicate group label: {label!r}")
        groups[label] = path

    default_pick, picks = parse_picks(args.pick)
    rng = random.Random(args.seed)
    selected = select_groups(groups, args.exclude, default_pick, picks, rng,
                             keep_source_order=not args.random_order)
    sequence = interleave(list(selected.values()))
    owner = {clip: label for label, clips in selected.items() for clip in clips}

    print(f"Selected sequence ({len(sequence)} clips, round-robin across "
          f"{', '.join(groups)}):")
    for idx, clip in enumerate(sequence, 1):
        print(f"  {idx:>2}. {owner[clip]:<12} {clip.name}")

    ffmpeg = "ffmpeg" if args.dry_run else resolve_ffmpeg()
    cmd = build_command(ffmpeg, sequence, args.out, args.width, args.height, args.fps)
    if args.dry_run:
        print("\nDry run - ffmpeg command:\n  " + " ".join(cmd))
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(cmd, check=True)
    print(f"\nWrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
