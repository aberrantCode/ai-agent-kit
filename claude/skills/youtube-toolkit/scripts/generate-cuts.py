#!/usr/bin/env python3
"""Generate chapters.txt and cut-chapters.sh from a yt-dlp info.json.

Reads the chapter markers YouTube ships (start/end/title) and produces, next to the
video:
  - chapters.txt      human-readable timestamp table
  - cut-chapters.sh   ffmpeg commands, one output file per chapter -> sections/

Everything is derived from the info.json, so re-running stays in sync with the source.

Usage:
  generate-cuts.py [--out DIR] [--info PATH] [--src PATH] [--default-mode MODE]
    --out   folder holding the download (default: current dir). info.json and the
            video are auto-discovered here unless --info/--src are given.
    --info  explicit path to the *.info.json
    --src   explicit path to the source video
    --default-mode  reencode (precise 1080p H.264, default) or copy (keyframe-snapped);
            this is the MODE the generated script uses when MODE is not set.
"""
import argparse
import glob
import json
import os
import re
import sys


def slug(title: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return s or "chapter"


def hhmmss(seconds: float) -> str:
    s = int(round(seconds))
    return f"{s // 3600:02d}:{(s % 3600) // 60:02d}:{s % 60:02d}"


def pick_one(pattern, out, kind):
    hits = sorted(glob.glob(os.path.join(out, pattern)))
    if not hits:
        sys.exit(f"No {kind} found in '{out}' (looked for {pattern}).")
    if len(hits) > 1:
        print(f"warning: multiple {kind} files, using {hits[0]}", file=sys.stderr)
    return hits[0]


def render_chapters_txt(data: dict, chapters: list) -> str:
    """Readable timestamp table for the chapters."""
    dur = data.get("duration", chapters[-1]["end_time"])
    lines = [
        f"# {data.get('title', 'video')}",
        f"# duration: {hhmmss(dur)}  ({len(chapters)} chapters)",
        "",
        f"{'#':>2}  {'START':>8}  {'END':>8}  {'LEN':>6}  TITLE",
    ]
    for i, c in enumerate(chapters, 1):
        lines.append(
            f"{i:>2}  {hhmmss(c['start_time']):>8}  {hhmmss(c['end_time']):>8}  "
            f"{hhmmss(c['end_time'] - c['start_time']):>6}  {c['title']}"
        )
    return "\n".join(lines) + "\n"


def render_cut_script(chapters: list, src_name: str, default_mode: str = "reencode") -> str:
    """Bash script with one ffmpeg cut per chapter, written to sections/.

    MODE=copy     : instant, no re-encode. Cuts snap to the nearest keyframe (a clip
                    may start slightly early). Preserves source quality; largest files.
    MODE=reencode : frame-accurate, re-encoded to 1080p H.264 + AAC. Slower (decodes
                    the source - heavy for 4K AV1), smaller, universally playable.
    """
    tag_re = ", default" if default_mode == "reencode" else ""
    tag_cp = ", default" if default_mode == "copy" else ""
    sh = [
        "#!/usr/bin/env bash",
        f"# Extract each chapter of {src_name} into its own file.",
        f"# Usage:  MODE=reencode ./cut-chapters.sh   (precise 1080p H.264{tag_re})",
        f"#         MODE=copy     ./cut-chapters.sh   (instant, keyframe-snapped{tag_cp})",
        "set -euo pipefail",
        f'SRC="{src_name}"',
        'OUT="sections"',
        f'MODE="${{MODE:-{default_mode}}}"',
        'mkdir -p "$OUT"',
        "",
    ]
    for i, c in enumerate(chapters, 1):
        start, end = c["start_time"], c["end_time"]
        name = f"{i:02d}-{slug(c['title'])}"
        sh.append(f'# {i:02d}  {c["title"]}  ({hhmmss(start)}-{hhmmss(end)})')
        sh.append('if [ "$MODE" = "copy" ]; then')
        sh.append(
            f'  ffmpeg -y -ss {start} -to {end} -i "$SRC" '
            f'-c copy -avoid_negative_ts make_zero "$OUT/{name}.mp4"'
        )
        sh.append("else")
        sh.append(
            f'  ffmpeg -y -ss {start} -to {end} -i "$SRC" '
            f'-vf "scale=-2:1080" -c:v libx264 -crf 20 -preset medium '
            f'-c:a aac -b:a 160k "$OUT/{name}.mp4"'
        )
        sh.append("fi")
        sh.append("")
    sh.append('echo "Done -> $OUT/"')
    return "\n".join(sh) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=".")
    ap.add_argument("--info")
    ap.add_argument("--src")
    ap.add_argument("--default-mode", choices=["reencode", "copy"], default="reencode")
    args = ap.parse_args()

    info_path = args.info or pick_one("*.info.json", args.out, "info.json")
    with open(info_path, encoding="utf-8") as fh:
        data = json.load(fh)

    chapters = data.get("chapters") or []
    if not chapters:
        sys.exit(
            "This video has no chapters - chapter-splitting doesn't apply. "
            "Use a custom ffmpeg time range instead (see SKILL.md)."
        )

    # Source video: prefer the merged mp4 sitting next to the info.json.
    src = args.src
    if not src:
        base = re.sub(r"\.info\.json$", "", os.path.basename(info_path))
        cand = os.path.join(args.out, base + ".mp4")
        src = cand if os.path.exists(cand) else pick_one("*.mp4", args.out, "video")
    src_name = os.path.basename(src)

    with open(os.path.join(args.out, "chapters.txt"), "w", encoding="utf-8") as fh:
        fh.write(render_chapters_txt(data, chapters))
    with open(os.path.join(args.out, "cut-chapters.sh"), "w",
              encoding="utf-8", newline="\n") as fh:
        fh.write(render_cut_script(chapters, src_name, args.default_mode))

    print(f"Wrote {args.out}/chapters.txt and {args.out}/cut-chapters.sh "
          f"({len(chapters)} chapters). Source: {src_name}")


if __name__ == "__main__":
    main()
