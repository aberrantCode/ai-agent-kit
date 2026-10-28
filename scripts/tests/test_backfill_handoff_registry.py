"""Unit tests for the session-manager handoff backfill script (stdlib unittest only).

Run from the repo root:
    python -m unittest discover -s scripts/tests -p "test_*.py"

All fixtures are tiny synthetic transcript trees + prompt files built in a TemporaryDirectory; the
real ~/.claude and docs/PROMPTS are never read (HOME/USERPROFILE are overridden per test).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB_DIR = os.path.join(REPO, "claude", "skills", "session-manager", "sub-skills", "transcripts", "scripts")
HANDOFF_SCRIPTS_DIR = os.path.join(REPO, "claude", "skills", "session-manager", "sub-skills", "handoff", "scripts")
sys.path.insert(0, LIB_DIR)
sys.path.insert(0, HANDOFF_SCRIPTS_DIR)
import cc_transcripts as cct  # noqa: E402
import backfill_handoff_registry as bhr  # noqa: E402


def write_jsonl(path, records):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")


def user_rec(text, ts=None, cwd=None, branch=None):
    rec = {"type": "user", "message": {"role": "user", "content": text}}
    if ts:
        rec["timestamp"] = ts
    if cwd:
        rec["cwd"] = cwd
    if branch is not None:
        rec["gitBranch"] = branch
    return rec


def opener_text(prompt_path):
    return (f"Read and follow the instructions in the file at {prompt_path} exactly. "
            f"Its full contents are your task; treat them as your first message.")


def fake_git(args, cwd=None, capture_output=True, text=True, timeout=15):
    """Stand-in for subprocess.run(["git", ...]) used by cc_transcripts._git. Treats every path
    under FAKE_REPO_ROOT as one repo whose common dir is FAKE_REPO_ROOT/.git -- enough for
    common_dir()/project_cwd() resolution without a real git repository."""
    root = mock._FAKE_REPO_ROOT  # set per-test
    out = ""
    if "rev-parse" in args and "--git-common-dir" in args:
        out = os.path.join(root, ".git") + "\n"
    return subprocess.CompletedProcess(args, 0, stdout=out, stderr="")


class BackfillBase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        # realpath() up front: on this machine %TEMP% is itself an 8.3 short-name path, and
        # cc_transcripts.common_dir() canonicalises through realpath() on the read side -- doing
        # it here too keeps fixture paths and discovered paths in the same canonical form instead
        # of silently diverging on a short-name alias (a Windows-only test artifact, not a real
        # join bug -- confirmed separately against the live ~/.claude/projects corpus).
        self.tmp = os.path.realpath(self._tmp.name)

        # Fake repo root with a docs/PROMPTS dir and a fake .git so common_dir() resolves.
        self.repo_root = os.path.join(self.tmp, "repo")
        self.prompts_dir = os.path.join(self.repo_root, "docs", "PROMPTS")
        os.makedirs(self.prompts_dir)
        os.makedirs(os.path.join(self.repo_root, ".git"))
        mock._FAKE_REPO_ROOT = self.repo_root

        self.projects_root = os.path.join(self.tmp, "projects")
        os.makedirs(self.projects_root)

        self._git_patch = mock.patch("cc_transcripts._git", side_effect=self._git)
        self._git_patch.start()
        self.addCleanup(self._git_patch.stop)

    def _git(self, args, cwd=None):
        if "rev-parse" in args and "--git-common-dir" in args:
            return os.path.join(self.repo_root, ".git") + "\n"
        return ""

    def write_prompt(self, name, frontmatter=None, body="# Task\n"):
        path = os.path.join(self.prompts_dir, name)
        text = ""
        if frontmatter:
            text += "---\n"
            for k, v in frontmatter.items():
                text += f"{k}: {v}\n"
            text += "---\n"
        text += body
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return os.path.abspath(path)

    def write_session(self, project_slug, session_id, records):
        # discover_repo_roots() needs at least one record with a real, existing `cwd` to resolve
        # the repo root via git-common-dir -- inject the fixture's repo root if no record set one.
        records = [dict(r) for r in records]
        if not any(r.get("cwd") for r in records):
            records[0]["cwd"] = self.repo_root
        pdir = os.path.join(self.projects_root, project_slug)
        write_jsonl(os.path.join(pdir, session_id + ".jsonl"), records)

    def discover(self):
        with mock.patch.object(cct, "projects_root", return_value=self.projects_root):
            roots = bhr.discover_repo_roots()
            prompts = bhr.discover_prompts(roots)
            exact_idx, basename_idx = bhr.scan_openers()
        return roots, prompts, exact_idx, basename_idx


class TestExactOpenerJoin(BackfillBase):
    def test_exact_path_opener_joins_with_high_confidence(self):
        prompt_path = self.write_prompt("2026-01-01-thing.md", frontmatter={"handoff_id": "d1-thing"})
        self.write_session("proj", "child-session-1", [
            user_rec(opener_text(prompt_path), ts="2026-01-01T12:00:00Z",
                     cwd=self.repo_root, branch="feat/thing"),
        ])

        roots, prompts, exact_idx, basename_idx = self.discover()
        self.assertEqual(len(prompts), 1)
        row, key, kind, ambiguity = bhr.build_row(prompts[0], exact_idx, basename_idx, set())

        self.assertEqual(row["child_sid"], "child-session-1")
        self.assertEqual(row["handoff_id"], "d1-thing")
        self.assertEqual(row["source"], "forensic")
        self.assertGreaterEqual(row["confidence"], 0.85)
        self.assertIsNone(row["parent_sid"])
        self.assertEqual(row["branch"], "feat/thing")
        self.assertIsNone(ambiguity)

    def test_no_handoff_id_in_frontmatter_synthesizes_bf_prefixed_id(self):
        self.write_prompt("2026-02-02-other-thing.md")  # no frontmatter at all
        # Repo-root discovery needs at least one transcript somewhere under this repo; its
        # content is irrelevant to this test, it just has to exist.
        self.write_session("proj", "unrelated-session", [user_rec("hi")])
        _, prompts, exact_idx, basename_idx = self.discover()
        row, *_ = bhr.build_row(prompts[0], exact_idx, basename_idx, set())
        self.assertTrue(row["handoff_id"].startswith("bf-"))
        self.assertIn("2026-02-02-other-thing", row["handoff_id"])


class TestBasenameOnlyIsLowerConfidence(BackfillBase):
    def test_basename_only_match_scores_below_exact(self):
        # The opener references a DIFFERENT absolute path with the same basename (as if the
        # prompt had moved or the dispatch happened on another machine).
        prompt_path = self.write_prompt("2026-03-03-moved.md")
        moved_path = os.path.join(self.tmp, "elsewhere", "docs", "PROMPTS", "2026-03-03-moved.md")
        self.write_session("proj", "child-session-2", [
            user_rec(opener_text(moved_path), ts="2026-03-03T12:00:00Z"),
        ])

        _, prompts, exact_idx, basename_idx = self.discover()
        row, *_ = bhr.build_row(prompts[0], exact_idx, basename_idx, set())

        self.assertEqual(row["child_sid"], "child-session-2")
        self.assertLess(row["confidence"], 0.85)
        self.assertGreater(row["confidence"], 0.0)


class TestNonFirstTurnMentionDoesNotJoin(BackfillBase):
    def test_basename_mentioned_mid_session_is_not_a_match(self):
        """A session that merely READS the prompt file (e.g. a tool_result echoing its path, or
        the authoring session typing the filename later) must not be treated as the child -- only
        the exact opener as the literal FIRST non-injected user turn counts."""
        prompt_path = self.write_prompt("2026-04-04-authored.md")
        self.write_session("proj", "authoring-session", [
            user_rec("let's work on this", ts="2026-04-04T09:00:00Z"),
            {
                "type": "user",
                "timestamp": "2026-04-04T09:05:00Z",
                "message": {"role": "user", "content": [
                    {"type": "tool_result", "content": f"...{prompt_path}..."}
                ]},
            },
        ])

        _, prompts, exact_idx, basename_idx = self.discover()
        row, key, kind, ambiguity = bhr.build_row(prompts[0], exact_idx, basename_idx, set())

        self.assertIsNone(row["child_sid"])
        self.assertEqual(row["confidence"], 0.0)


class TestAmbiguousMultipleCandidates(BackfillBase):
    def test_multiple_exact_matches_keep_best_and_log_ambiguity(self):
        prompt_path = self.write_prompt("2026-05-05-dup.md")
        self.write_session("proj", "dup-session-a", [
            user_rec(opener_text(prompt_path), ts="2026-05-06T09:00:00Z"),
        ])
        self.write_session("proj", "dup-session-b", [
            user_rec(opener_text(prompt_path), ts="2026-05-06T10:00:00Z"),
        ])

        _, prompts, exact_idx, basename_idx = self.discover()
        row, key, kind, ambiguity = bhr.build_row(prompts[0], exact_idx, basename_idx, set())

        self.assertIsNotNone(ambiguity)
        self.assertIn(row["child_sid"], ("dup-session-a", "dup-session-b"))
        self.assertLessEqual(row["confidence"], 0.5)


class TestIdempotency(BackfillBase):
    def test_existing_key_is_skipped_on_rerun(self):
        prompt_path = self.write_prompt("2026-06-06-again.md", frontmatter={"handoff_id": "d1-again"})
        self.write_session("proj", "child-session-3", [
            user_rec(opener_text(prompt_path), ts="2026-06-06T12:00:00Z"),
        ])
        _, prompts, exact_idx, basename_idx = self.discover()

        seen = {(prompt_path, "child-session-3")}
        row, key, *_ = bhr.build_row(prompts[0], exact_idx, basename_idx, seen)
        self.assertIn(key, seen, "idempotency key must match what a prior run would have recorded")

    def test_prior_unresolved_row_is_left_in_place_not_reappended(self):
        prompt_path = self.write_prompt("2026-07-07-nomatch.md")
        self.write_session("proj", "unrelated-session", [user_rec("hi")])
        _, prompts, exact_idx, basename_idx = self.discover()
        seen = {(prompt_path, None)}
        row, key, *_ = bhr.build_row(prompts[0], exact_idx, basename_idx, seen)
        self.assertEqual(key, (prompt_path, None))
        self.assertIn(key, seen)


if __name__ == "__main__":
    unittest.main()
