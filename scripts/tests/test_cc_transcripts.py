"""Unit tests for the session-manager `cc_transcripts` library (stdlib unittest only).

Run from the repo root:
    python -m unittest discover -s scripts/tests -p "test_*.py"

All fixtures are tiny synthetic transcript trees built in a TemporaryDirectory; the real
~/.claude is never read.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime
from unittest import mock

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB_DIR = os.path.join(REPO, "claude", "skills", "session-manager", "sub-skills", "transcripts", "scripts")
sys.path.insert(0, LIB_DIR)
import cc_transcripts as cct  # noqa: E402


def write_jsonl(path, records, raw_lines=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
        for line in raw_lines or []:
            f.write(line + "\n")


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f)


def set_mtime(path, epoch):
    os.utime(path, (epoch, epoch))


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        # realpath, not .name: on Windows, tempfile can hand back an 8.3 SHORT path
        # (e.g. C:\Users\ERIK~1.OPB\...) when the username exceeds 8 chars, while git
        # resolves worktree paths to their LONG form (C:\Users\erik.OPBTA\...).
        # os.path.abspath does NOT reconcile the two, so the shared-container worktree
        # test would spuriously fail. Canonicalising the fixture root here makes every
        # derived path match what git reports.
        self.tmp = os.path.realpath(self._tmp.name)
        self.root = os.path.join(self.tmp, "projects")
        os.makedirs(self.root)


class TestPaths(Base):
    def test_slugify_is_lossy(self):
        self.assertEqual(cct.slugify(r"C:\development\ai-agent-kit"), "C--development-ai-agent-kit")
        self.assertEqual(cct.slugify("/a/b_c.d"), "-a-b-c-d")
        self.assertEqual(cct.slugify("a_b"), cct.slugify("a-b"))  # collision: never decode

    def test_to_posix(self):
        self.assertEqual(cct.to_posix("C:\\a\\b/c"), "C:/a/b/c")

    def test_msys_to_native(self):
        if os.name == "nt":
            self.assertEqual(cct.msys_to_native("/c/Users/x"), "C:/Users/x")
            self.assertEqual(cct.msys_to_native("/d"), "D:/")
            self.assertEqual(cct.msys_to_native("C:/Users/x"), "C:/Users/x")
        else:
            self.assertEqual(cct.msys_to_native("/c/Users/x"), "/c/Users/x")

    def test_projects_root_explicit_and_call_time_home(self):
        self.assertEqual(cct.projects_root("/x/y"), "/x/y")
        with mock.patch.dict(os.environ, {"HOME": self.tmp, "USERPROFILE": self.tmp}):
            self.assertEqual(cct.projects_root(),
                             os.path.join(os.path.expanduser("~"), ".claude", "projects"))
            self.assertTrue(cct.projects_root().startswith(self.tmp))
        other = os.path.join(self.tmp, "other")
        with mock.patch.dict(os.environ, {"HOME": other, "USERPROFILE": other}):
            self.assertTrue(cct.projects_root().startswith(other))

    def test_parse_since(self):
        self.assertIsNone(cct.parse_since(None))
        self.assertEqual(cct.parse_since(5), 5.0)
        dt = datetime(2026, 1, 2, 3, 4, 5)
        self.assertEqual(cct.parse_since(dt), dt.timestamp())
        self.assertEqual(cct.parse_since("2026-01-02 03:04:05"), dt.timestamp())
        self.assertEqual(cct.parse_since("2026-01-02"), datetime(2026, 1, 2).timestamp())
        with self.assertRaises(ValueError):
            cct.parse_since("yesterday")
        with self.assertRaises(ValueError):
            cct.parse_since(True)


class TestDiscovery(Base):
    def make(self):
        now = time.time()
        for slug, sid, age in [("proj-alpha", "s1", 100), ("proj-alpha", "s2", 5000),
                               ("proj-beta", "s3", 300)]:
            p = os.path.join(self.root, slug, sid + ".jsonl")
            write_jsonl(p, [{"type": "user"}])
            set_mtime(p, now - age)
        open(os.path.join(self.root, "stray.txt"), "w").close()
        open(os.path.join(self.root, "proj-alpha", "notes.txt"), "w").close()
        return now

    def test_project_dirs(self):
        self.make()
        names = sorted(os.path.basename(p) for p in cct.project_dirs(self.root))
        self.assertEqual(names, ["proj-alpha", "proj-beta"])
        names = [os.path.basename(p) for p in cct.project_dirs(self.root, "beta")]
        self.assertEqual(names, ["proj-beta"])
        self.assertEqual(cct.project_dirs(os.path.join(self.tmp, "nope")), [])

    def test_session_files_newest_first_and_only_jsonl(self):
        self.make()
        files = cct.session_files(os.path.join(self.root, "proj-alpha"))
        self.assertEqual([os.path.basename(p) for p, _ in files], ["s1.jsonl", "s2.jsonl"])
        self.assertGreater(files[0][1], files[1][1])
        self.assertEqual(cct.session_files(os.path.join(self.root, "missing")), [])

    def test_iter_sessions_since_and_substring(self):
        now = self.make()
        got = {(slug, sid) for _, slug, sid, _ in cct.iter_sessions(self.root)}
        self.assertEqual(got, {("proj-alpha", "s1"), ("proj-alpha", "s2"), ("proj-beta", "s3")})
        got = {sid for _, _, sid, _ in cct.iter_sessions(self.root, since=now - 1000)}
        self.assertEqual(got, {"s1", "s3"})
        got = {sid for _, _, sid, _ in cct.iter_sessions(self.root, project_substring="alpha")}
        self.assertEqual(got, {"s1", "s2"})
        dt = datetime.fromtimestamp(now - 1000)
        got = {sid for _, _, sid, _ in cct.iter_sessions(self.root, since=dt)}
        self.assertEqual(got, {"s1", "s3"})
        got = {sid for _, _, sid, _ in cct.iter_sessions(
            self.root, since=dt.strftime("%Y-%m-%d %H:%M:%S"))}
        self.assertEqual(got, {"s1", "s3"})

    def test_root_substring_does_not_match_root_path(self):
        self.make()
        root_name = os.path.basename(self.root)  # "projects"
        self.assertEqual(list(cct.iter_sessions(self.root, project_substring=root_name)), [])


class TestRecords(Base):
    def test_iter_records_skips_blank_malformed_nondict(self):
        p = os.path.join(self.tmp, "a.jsonl")
        write_jsonl(p, [{"a": 1}], raw_lines=["", "   ", "{not json", "[1,2]", json.dumps({"b": 2})])
        stats = {}
        self.assertEqual(list(cct.iter_records(p, stats=stats)), [{"a": 1}, {"b": 2}])
        self.assertEqual(stats, {"lines": 6, "bad": 1})

    def test_iter_records_missing_file(self):
        self.assertEqual(list(cct.iter_records(os.path.join(self.tmp, "nope.jsonl"))), [])
        self.assertEqual(list(cct.iter_records(self.tmp)), [])  # a directory -> OSError -> nothing

    def test_iter_records_bad_bytes_replaced(self):
        p = os.path.join(self.tmp, "b.jsonl")
        with open(p, "wb") as f:
            f.write(b'{"t": "caf\xe9"}\n')
        self.assertEqual(len(list(cct.iter_records(p))), 1)

    def test_iter_messages_role_and_sidechain(self):
        p = os.path.join(self.tmp, "m.jsonl")
        write_jsonl(p, [
            {"type": "user", "message": {"role": "user", "content": "hi"}},
            {"type": "assistant", "message": {"role": "assistant", "content": []}},
            {"type": "assistant", "isSidechain": True, "message": {"role": "assistant", "content": []}},
            {"type": "summary"},
            {"type": "user", "message": "stringy"},
        ])
        self.assertEqual(len(list(cct.iter_messages(p))), 3)
        self.assertEqual(len(list(cct.iter_messages(p, role="assistant"))), 2)
        self.assertEqual(len(list(cct.iter_messages(p, role="assistant", skip_sidechains=True))), 1)

    def test_iter_tool_uses(self):
        p = os.path.join(self.tmp, "t.jsonl")
        write_jsonl(p, [
            {"timestamp": "T1", "message": {"model": "opus", "content": [
                {"type": "text", "text": "x"},
                {"type": "tool_use", "id": "a", "name": "Task", "input": {"description": "d"}},
                {"type": "tool_use", "id": "b", "name": "Bash", "input": None}]}},
            {"timestamp": "T2", "message": {"content": [
                {"type": "tool_use", "id": "c", "name": "Workflow"}]}},
            {"message": {"content": "just text"}},
        ])
        allu = list(cct.iter_tool_uses(p))
        self.assertEqual([u.id for u in allu], ["a", "b", "c"])
        self.assertEqual(allu[0], cct.ToolUse("a", "T1", "opus", "Task", {"description": "d"}))
        self.assertEqual(allu[1].input, {})
        self.assertEqual(allu[2].model, "unknown")
        disp = list(cct.iter_tool_uses(p, cct.DISPATCH_TOOL_NAMES))
        self.assertEqual([u.name for u in disp], ["Task", "Workflow"])
        self.assertEqual(list(cct.iter_tool_uses(os.path.join(self.tmp, "none.jsonl"))), [])

    def test_cwd_helpers(self):
        a = os.path.join(self.root, "p", "old.jsonl")
        b = os.path.join(self.root, "p", "new.jsonl")
        write_jsonl(a, [{"x": 1}, {"cwd": "C:/old"}])
        write_jsonl(b, [{"cwd": "C:/new"}])
        set_mtime(a, time.time() - 1000)
        self.assertEqual(cct.session_cwd(a), "C:/old")
        self.assertIsNone(cct.session_cwd(os.path.join(self.tmp, "none.jsonl")))
        self.assertEqual(cct.project_cwd(os.path.join(self.root, "p"), newest_only=True), "C:/new")
        self.assertIn(cct.project_cwd(os.path.join(self.root, "p")), {"C:/old", "C:/new"})
        self.assertIsNone(cct.project_cwd(os.path.join(self.root, "empty")))

    def test_parse_timestamp_and_usage_tokens(self):
        dt = cct.parse_timestamp("2026-07-01T12:00:00.000Z")
        self.assertIsNotNone(dt.tzinfo)
        self.assertEqual(dt.hour, 12)
        for bad in (None, "", "nope", 5):
            self.assertIsNone(cct.parse_timestamp(bad))
        self.assertEqual(cct.usage_tokens({"input_tokens": 1, "output_tokens": None,
                                           "cache_read_input_tokens": 3}), (1, 0, 3, 0))
        self.assertEqual(cct.usage_tokens({}), (0, 0, 0, 0))


class TestText(unittest.TestCase):
    def test_first_and_all_text(self):
        blocks = [{"type": "tool_use"}, {"type": "text", "text": "one"}, {"type": "text", "text": "two"}]
        self.assertEqual(cct.first_text(blocks), "one")
        self.assertEqual(cct.all_text(blocks), "one\ntwo")
        self.assertEqual(cct.first_text("s"), "s")
        self.assertEqual(cct.all_text("s"), "s")
        self.assertEqual(cct.first_text(None), "")
        self.assertEqual(cct.all_text(None), "")

    def test_is_injected(self):
        self.assertTrue(cct.is_injected("  <System-Reminder> x"))
        self.assertTrue(cct.is_injected("This session is being continued from"))
        self.assertTrue(cct.is_injected("Base directory for this skill: x"))
        self.assertFalse(cct.is_injected("please fix the bug"))
        self.assertTrue(cct.is_injected("zzz hello", prefixes=("zzz",)))
        self.assertFalse(cct.is_injected("<system-reminder>", prefixes=("zzz",)))


class TestSubagents(Base):
    def make(self):
        proj = os.path.join(self.root, "proj-a")
        sess = os.path.join(proj, "sess1")
        direct = os.path.join(sess, "subagents", "agent-1.meta.json")
        inner1 = os.path.join(sess, "subagents", "workflows", "wf_run1", "agent-2.meta.json")
        inner2 = os.path.join(sess, "subagents", "workflows", "wf_run1", "agent-3.meta.json")
        other = os.path.join(self.root, "proj-b", "sess2", "subagents", "agent-9.meta.json")
        write_json(direct, {"agentType": "general-purpose", "toolUseId": "tu1", "model": "sonnet"})
        write_json(inner1, {"agentType": "workflow-subagent"})
        write_json(inner2, {"agentType": "workflow-subagent"})
        write_json(other, {"agentType": "x"})
        return direct, inner1, inner2, other

    def test_meta_paths_no_double_count_and_posix(self):
        self.make()
        paths = cct.subagent_meta_paths(self.root)
        self.assertEqual(len(paths), 4)           # gotcha 1: each file exactly once
        self.assertEqual(len(set(paths)), 4)
        self.assertTrue(all("\\" not in p for p in paths))

    def test_meta_paths_top_level_file_counted_once(self):
        direct, *_ = self.make()
        # top-level file in the globbed dir matched by ** (zero dirs) must not duplicate
        self.assertEqual(sum(1 for p in cct.subagent_meta_paths(self.root)
                             if p.endswith("agent-1.meta.json")), 1)

    def test_meta_paths_mtime_filter_uses_meta_not_parent(self):
        direct, inner1, inner2, other = self.make()
        now = time.time()
        for p in (direct, inner1, inner2, other):
            set_mtime(p, now - 10000)
        set_mtime(inner2, now - 10)
        # parent jsonl is absent (stale/missing parent) -> must still be found via meta mtime
        paths = cct.subagent_meta_paths(self.root, since=now - 100)
        self.assertEqual([os.path.basename(p) for p in paths], ["agent-3.meta.json"])

    def test_meta_paths_project_substring(self):
        self.make()
        paths = cct.subagent_meta_paths(self.root, project_substring="proj-b")
        self.assertEqual(len(paths), 1)
        self.assertEqual(cct.subagent_meta_paths(self.root, project_substring="projects"), [])

    def test_meta_paths_missing_root(self):
        self.assertEqual(cct.subagent_meta_paths(os.path.join(self.tmp, "nope")), [])

    def test_parse_meta_path(self):
        direct, inner1, _, _ = self.make()
        for root in (None, self.root):
            d = cct.parse_meta_path(cct.to_posix(direct), root=root)
            self.assertEqual((d["project"], d["session"], d["is_workflow_inner"], d["wf_dir"]),
                             ("proj-a", "sess1", False, None))
            self.assertEqual(d["project_dir"], cct.to_posix(os.path.join(self.root, "proj-a")))
            w = cct.parse_meta_path(cct.to_posix(inner1), root=root)
            self.assertEqual((w["project"], w["session"], w["is_workflow_inner"], w["wf_dir"]),
                             ("proj-a", "sess1", True, "wf_run1"))

    def test_parse_meta_path_works_when_root_has_no_projects_component(self):
        direct, *_ = self.make()
        self.assertNotIn("/projects/", cct.to_posix(direct).replace(cct.to_posix(self.root), ""))
        self.assertEqual(cct.parse_meta_path(direct)["session"], "sess1")

    def test_resume_from_run_id_attribution_by_wf_dir(self):
        # gotcha 2: two Workflow tool_use blocks, ONE wf_ run -> agents grouped by wf_dir once
        _, inner1, inner2, _ = self.make()
        jl = os.path.join(self.root, "proj-a", "sess1.jsonl")
        write_jsonl(jl, [{"message": {"content": [
            {"type": "tool_use", "id": "w1", "name": "Workflow", "input": {}}]}},
            {"message": {"content": [
                {"type": "tool_use", "id": "w2", "name": "Workflow",
                 "input": {"resumeFromRunId": "run1"}}]}}])
        blocks = [u for u in cct.iter_tool_uses(jl, ("Workflow",))]
        self.assertEqual(len(blocks), 2)
        runs = {}
        for p in cct.subagent_meta_paths(self.root):
            pm = cct.parse_meta_path(p, root=self.root)
            if pm["is_workflow_inner"]:
                runs.setdefault(pm["wf_dir"], []).append(p)
        self.assertEqual({k: len(v) for k, v in runs.items()}, {"wf_run1": 2})

    def test_load_json(self):
        direct, *_ = self.make()
        self.assertEqual(cct.load_json(direct)["toolUseId"], "tu1")
        self.assertIsNone(cct.load_json(os.path.join(self.tmp, "none.json")))
        bad = os.path.join(self.tmp, "bad.json")
        with open(bad, "w") as f:
            f.write("{oops")
        self.assertIsNone(cct.load_json(bad))


class TestWorktrees(Base):
    def test_slug_embedded_recovery_without_git(self):
        repo = os.path.join(self.tmp, "myrepo")
        os.makedirs(repo)
        main = cct.slugify(os.path.abspath(repo))
        write_jsonl(os.path.join(self.root, main, "a.jsonl"), [{"cwd": repo}])
        inrepo = main + "--worktrees-feat"
        sibling = main + "-wt-other"
        unrelated = "C--elsewhere--worktrees-x"
        for slug in (inrepo, sibling, unrelated):
            write_jsonl(os.path.join(self.root, slug, "a.jsonl"), [{"cwd": "C:/gone/" + slug}])
        got = cct.worktree_project_dirs(repo, self.root)
        self.assertEqual(got[main], os.path.abspath(repo))
        self.assertIn(inrepo, got)
        self.assertIn(sibling, got)
        self.assertEqual(got[inrepo], "C:/gone/" + inrepo)
        self.assertNotIn(unrelated, got)

    @unittest.skipUnless(shutil.which("git"), "git not available")
    def test_git_registered_worktree_in_shared_container(self):
        repo = os.path.join(self.tmp, "repo")
        os.makedirs(repo)
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL="t@t")

        def git(*a, cwd=repo):
            return subprocess.run(["git", *a], cwd=cwd, env=env, capture_output=True, text=True)

        git("init", "-q")
        git("commit", "--allow-empty", "-q", "-m", "init")
        wt = os.path.join(self.tmp, "container", "wt1")
        r = git("worktree", "add", "-q", wt, "-b", "wtbranch")
        if r.returncode != 0:
            self.skipTest("git worktree add failed: " + r.stderr)
        self.assertIn(os.path.abspath(wt), [os.path.abspath(p) for p in cct.registered_worktrees(repo)])
        self.assertEqual(cct.common_dir(repo), cct.common_dir(wt))
        got = cct.worktree_project_dirs(repo, self.root)
        self.assertIn(cct.slugify(os.path.abspath(wt)), got)


if __name__ == "__main__":
    unittest.main()
