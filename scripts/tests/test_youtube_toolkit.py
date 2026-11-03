"""Unit tests for the youtube-toolkit bundled scripts (stdlib unittest, no real ffmpeg).

Covers `generate-cuts.py` (chapter table + cut script) and `splice_clips.py`
(group selection, round-robin interleave, ffmpeg command). subprocess / ffmpeg
lookups are mocked; nothing here touches video.

Run from the repo root:
    python -m unittest discover -s scripts/tests -p "test_*.py"
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import random
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "claude" / "skills" / "youtube-toolkit" / "scripts"


def load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


cuts = load("yt_generate_cuts", "generate-cuts.py")
splice = load("yt_splice_clips", "splice_clips.py")

CHAPTERS = [
    {"start_time": 0, "end_time": 20, "title": "Get Ready!"},
    {"start_time": 20, "end_time": 80, "title": "Reverse Crunches"},
    {"start_time": 80, "end_time": 140.5, "title": "Leg Raises"},
]


def touch_clips(folder: Path, names) -> list[Path]:
    folder.mkdir(parents=True, exist_ok=True)
    out = []
    for n in names:
        p = folder / n
        p.write_bytes(b"")
        out.append(p)
    return out


class GenerateCutsTests(unittest.TestCase):
    def test_slug_and_hhmmss(self):
        self.assertEqual(cuts.slug("Get Ready!"), "get-ready")
        self.assertEqual(cuts.slug("!!!"), "chapter")
        self.assertEqual(cuts.hhmmss(3725), "01:02:05")

    def test_chapters_txt_lists_every_chapter(self):
        txt = cuts.render_chapters_txt({"title": "T", "duration": 140}, CHAPTERS)
        self.assertIn("# T", txt)
        self.assertIn("(3 chapters)", txt)
        self.assertIn("Reverse Crunches", txt)
        self.assertIn("00:01:20", txt)

    def test_cut_script_one_cut_per_chapter(self):
        sh = cuts.render_cut_script(CHAPTERS, "vid.mp4")
        self.assertTrue(sh.startswith("#!/usr/bin/env bash"))
        self.assertEqual(sh.count("ffmpeg -y"), 2 * len(CHAPTERS))  # copy + reencode
        self.assertIn('SRC="vid.mp4"', sh)
        self.assertIn('"$OUT/02-reverse-crunches.mp4"', sh)
        self.assertIn("-ss 80 -to 140.5", sh)

    def test_cut_script_default_mode(self):
        self.assertIn('MODE="${MODE:-reencode}"', cuts.render_cut_script(CHAPTERS, "v.mp4"))
        self.assertIn('MODE="${MODE:-copy}"',
                      cuts.render_cut_script(CHAPTERS, "v.mp4", "copy"))

    def test_main_writes_files_from_info_json(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "vid.info.json").write_text(
                json.dumps({"title": "T", "duration": 140, "chapters": CHAPTERS}),
                encoding="utf-8")
            (Path(d) / "vid.mp4").write_bytes(b"")
            with mock.patch("sys.argv", ["generate-cuts.py", "--out", d,
                                         "--default-mode", "copy"]), \
                    contextlib.redirect_stdout(io.StringIO()):
                cuts.main()
            self.assertTrue((Path(d) / "chapters.txt").exists())
            script = (Path(d) / "cut-chapters.sh").read_text(encoding="utf-8")
            self.assertIn('SRC="vid.mp4"', script)
            self.assertIn("MODE:-copy", script)

    def test_main_exits_without_chapters(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "vid.info.json").write_text(json.dumps({"title": "T"}),
                                                   encoding="utf-8")
            with mock.patch("sys.argv", ["generate-cuts.py", "--out", d]):
                with self.assertRaises(SystemExit):
                    cuts.main()


class SpliceSelectionTests(unittest.TestCase):
    def test_parse_group(self):
        self.assertEqual(splice.parse_group("abs=./a"), ("abs", Path("./a")))
        for bad in ("abs", "=x", "abs="):
            with self.assertRaises(SystemExit):
                splice.parse_group(bad)

    def test_parse_picks(self):
        self.assertEqual(splice.parse_picks(["3", "abs=5"]), (3, {"abs": 5}))
        self.assertEqual(splice.parse_picks([]), (None, {}))
        for bad in (["x"], ["0"], ["abs=0"]):
            with self.assertRaises(SystemExit):
                splice.parse_picks(bad)

    def test_eligible_clips_excludes_and_prefers_sections(self):
        with tempfile.TemporaryDirectory() as d:
            sec = Path(d) / "abs" / "sections"
            touch_clips(sec, ["01-get-ready.mp4", "02-crunch.mp4", "03-Wall-Sit.mp4",
                              "04-plank.mp4", "notes.txt"])
            pool = splice.eligible_clips(Path(d) / "abs", ["get-ready", "wall-sit"])
            self.assertEqual([c.name for c in pool], ["02-crunch.mp4", "04-plank.mp4"])
            # no exclusions -> all mp4s
            self.assertEqual(len(splice.eligible_clips(Path(d) / "abs")), 4)

    def test_eligible_clips_plain_folder_and_missing(self):
        with tempfile.TemporaryDirectory() as d:
            touch_clips(Path(d) / "flat", ["a.mp4"])
            self.assertEqual(len(splice.eligible_clips(Path(d) / "flat")), 1)
            with self.assertRaises(SystemExit):
                splice.eligible_clips(Path(d) / "nope")

    def test_pick_clips_sorted_and_seeded(self):
        pool = [Path(f"{i:02d}.mp4") for i in range(1, 11)]
        a = splice.pick_clips(random.Random(7), pool, 4)
        b = splice.pick_clips(random.Random(7), pool, 4)
        self.assertEqual(a, b)
        self.assertEqual(a, sorted(a))
        self.assertEqual(len(set(a)), 4)

    def test_pick_clips_random_order_and_overdraw(self):
        pool = [Path(f"{i:02d}.mp4") for i in range(1, 11)]
        drawn = splice.pick_clips(random.Random(3), pool, 6, keep_source_order=False)
        self.assertEqual(sorted(drawn), sorted(set(drawn)))
        with self.assertRaises(SystemExit):
            splice.pick_clips(random.Random(0), pool, 11)

    def test_interleave_equal_and_unequal(self):
        a, b, c = ([Path(f"{x}{i}.mp4") for i in (1, 2)] for x in "abc")
        self.assertEqual([p.name for p in splice.interleave([a, b, c])],
                         ["a1.mp4", "b1.mp4", "c1.mp4", "a2.mp4", "b2.mp4", "c2.mp4"])
        long = [Path(f"l{i}.mp4") for i in (1, 2, 3, 4)]
        short = [Path("s1.mp4")]
        self.assertEqual([p.name for p in splice.interleave([short, long])],
                         ["s1.mp4", "l1.mp4", "l2.mp4", "l3.mp4", "l4.mp4"])
        self.assertEqual(splice.interleave([]), [])

    def test_select_groups_rejects_unknown_pick_and_empty_pool(self):
        with tempfile.TemporaryDirectory() as d:
            touch_clips(Path(d) / "a", ["01-intro.mp4"])
            groups = {"a": Path(d) / "a"}
            with self.assertRaises(SystemExit):
                splice.select_groups(groups, [], None, {"zzz": 1}, random.Random(0))
            with self.assertRaises(SystemExit):
                splice.select_groups(groups, ["intro"], None, {}, random.Random(0))


class SpliceCommandTests(unittest.TestCase):
    def test_build_filter_normalises_every_input(self):
        fil = splice.build_filter(3, 1280, 720, 24)
        self.assertEqual(fil.count("setsar=1"), 3)
        self.assertEqual(fil.count("fps=24"), 3)
        self.assertIn("scale=1280:720", fil)
        self.assertTrue(fil.endswith("[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[outv][outa]"))

    def test_build_command_shape(self):
        seq = [Path("a.mp4"), Path("b.mp4")]
        cmd = splice.build_command("ffmpeg", seq, Path("out.mp4"))
        self.assertEqual(cmd[:2], ["ffmpeg", "-y"])
        self.assertEqual([cmd[i + 1] for i, t in enumerate(cmd) if t == "-i"],
                         ["a.mp4", "b.mp4"])
        self.assertEqual(cmd[-1], "out.mp4")
        self.assertIn("libx264", cmd)

    def test_resolve_ffmpeg_prefers_path(self):
        with mock.patch.object(splice.shutil, "which", return_value="/usr/bin/ffmpeg"):
            self.assertEqual(splice.resolve_ffmpeg(), "/usr/bin/ffmpeg")

    def test_resolve_ffmpeg_missing_exits(self):
        with mock.patch.object(splice.shutil, "which", return_value=None), \
                mock.patch.dict("sys.modules", {"imageio_ffmpeg": None}):
            with self.assertRaises(SystemExit):
                splice.resolve_ffmpeg()


class SpliceMainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        touch_clips(root / "abs" / "sections",
                    [f"{i:02d}-x.mp4" for i in range(1, 6)] + ["00-get-ready.mp4"])
        touch_clips(root / "arms" / "sections", [f"{i:02d}-y.mp4" for i in range(1, 4)])
        self.root = root
        self.out = root / "mix" / "out.mp4"

    def argv(self, *extra):
        return ["--group", f"abs={self.root / 'abs'}",
                "--group", f"arms={self.root / 'arms'}",
                "--out", str(self.out), *extra]

    def run_main(self, *extra):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = splice.main(self.argv(*extra))
        return rc, buf.getvalue()

    def test_dry_run_runs_nothing(self):
        with mock.patch.object(splice.subprocess, "run") as run:
            rc, out = self.run_main("--dry-run", "--exclude", "get-ready")
        self.assertEqual(rc, 0)
        run.assert_not_called()
        self.assertIn("8 clips", out)  # 5 abs + 3 arms, get-ready excluded
        self.assertNotIn("get-ready", out.split("Dry run")[0])
        self.assertFalse(self.out.parent.exists())

    def test_runs_ffmpeg_once_and_creates_output_dir(self):
        with mock.patch.object(splice, "resolve_ffmpeg", return_value="ffmpeg"), \
                mock.patch.object(splice.subprocess, "run") as run:
            rc, _ = self.run_main("--exclude", "get-ready", "--pick", "2", "--seed", "1")
        self.assertEqual(rc, 0)
        run.assert_called_once()
        cmd = run.call_args.args[0]
        self.assertEqual(cmd[0], "ffmpeg")
        self.assertEqual(cmd.count("-i"), 4)  # 2 picks per group
        self.assertTrue(run.call_args.kwargs.get("check"))
        self.assertTrue(self.out.parent.is_dir())

    def test_per_group_pick_and_interleave_order(self):
        with mock.patch.object(splice.subprocess, "run"):
            _, out = self.run_main("--dry-run", "--exclude", "get-ready",
                                   "--pick", "abs=3", "--pick", "arms=1", "--seed", "5")
        labels = [ln.split()[1] for ln in out.splitlines() if ln[:4].strip().rstrip(".").isdigit()]
        self.assertEqual(labels, ["abs", "arms", "abs", "abs"])

    def test_duplicate_group_label_rejected(self):
        with self.assertRaises(SystemExit):
            splice.main(["--group", f"a={self.root / 'abs'}",
                         "--group", f"a={self.root / 'arms'}", "--out", str(self.out)])


if __name__ == "__main__":
    unittest.main()
