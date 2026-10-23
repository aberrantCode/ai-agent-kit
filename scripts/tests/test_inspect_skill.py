"""Regression guard for the `github` skill's `inspect` operation (stdlib unittest only).

These assertions lock the invariants introduced by the /repo-status usage analysis
(docs/reports/repo-status-usage-analysis.md). Each test maps to a report finding so a future
edit that silently removes one is caught.

Run from the repo root:
    python -m unittest discover -s scripts/tests -p "test_*.py"
"""
from __future__ import annotations

import os
import re
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INSPECT = os.path.join(REPO, "claude", "skills", "github", "sub-skills", "inspect", "SKILL.md")


def read_inspect() -> str:
    with open(INSPECT, encoding="utf-8") as f:
        return f.read()


class InspectSkillInvariants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = read_inspect()
        cls.lower = cls.text.lower()

    # F1 — the self-cancelling gather-preamble is a named banned phrase
    def test_f1_gather_preamble_is_banned(self):
        self.assertIn("i'll gather silently", self.lower,
                      "Banned-output list must name the 'I'll gather silently' preamble (F1).")

    # F2 — two-phase gathering is documented and && chaining is forbidden
    def test_f2_gathering_discipline_present(self):
        self.assertIn("gathering discipline", self.lower,
                      "A 'Gathering discipline' section must document the two-phase gather (F2).")
        self.assertRegex(self.text, r"[Nn]ever chain gathering probes with `&&`",
                         "The separator rule must forbid chaining gathering probes with && (F2).")
        self.assertIn("snapshot", self.lower)
        self.assertIn("drill-down", self.lower)

    # F3 — Step 5 fetches mergeable in the single list call; no per-PR drill-down
    def test_f3_pr_list_includes_mergeable(self):
        m = re.search(r"gh pr list --json ([^\n`]+)", self.text)
        self.assertIsNotNone(m, "Step 5 must contain a `gh pr list --json ...` command (F3).")
        fields = m.group(1)
        self.assertIn("mergeable", fields,
                      "Step 5's `gh pr list --json` must request `mergeable` (F3).")
        # scope guard: inspect must discourage per-PR gh pr view / gh pr checks drill-downs
        self.assertIn("gh pr view", self.lower,
                      "Step 5 must mention (to forbid) per-PR `gh pr view` drill-downs (F3).")
        self.assertIn("gh pr checks", self.lower,
                      "Step 5 must mention (to exclude) `gh pr checks` as out of scope (F3).")

    # F4 — worktree dirty probe is resilient to dubious-ownership
    def test_f4_worktree_probe_safe_directory(self):
        self.assertRegex(
            self.text,
            r"git -C <path> -c safe\.directory='\*' status --porcelain",
            "Step 4's worktree dirty probe must use `-c safe.directory='*'` (F4).")
        self.assertIn("dubious ownership", self.lower,
                      "Step 4 must name the dubious-ownership degraded path (F4).")

    # F5 — guidance against auto re-inspecting after a launched mutation
    def test_f5_no_reinspect_after_op(self):
        self.assertRegex(self.text, r"[Dd]o not re-inspect after a launched op",
                         "Step 8 must warn against auto re-inspecting after a launched op (F5).")

    # Scope guard — the read-only guarantee must survive every edit above
    def test_readonly_guarantee_preserved(self):
        self.assertRegex(
            self.text,
            r"never stages, commits, pushes, merges,\s*branches, deletes, prunes",
            "The read-only guarantee statement must remain intact.")


if __name__ == "__main__":
    unittest.main()
