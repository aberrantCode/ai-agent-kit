# Handoff-tuner tuning log

Newest entry on top. Each entry records one `handoff-tuner` run: the metrics it used, the findings
it produced, what it changed in `handoff/SKILL.md`, and what it changed in the tuner's own
rubric/metrics — with rationale. This log is the audit trail of the recursion: every change below
landed as a reviewed PR, never an autonomous self-edit.

---

## 2026-10-23 — Run 1 (rubric v1 → v2)

**Branch:** `feat/handoff-tuner-subskill` · **Handoff:** `d2-tuner-26a` · **Session model:** Opus
(mechanical fan-out + finding refutation delegated to `sonnet` subagents).
**Report:** [`docs/reports/handoff-efficiency-analysis.md`](../../../../../../docs/reports/handoff-efficiency-analysis.md).

### Metrics used

- **Mining** (`mine_handoffs.py`): registry-first join + in-memory forensic launcher-opener fallback.
  93 handoffs discovered; **4 joined (4.3%)** — 1 via registry, 3 via forensic; 4 child transcripts
  on disk.
- **Static** (`score_rubric.py` vs rubric v1): 92 prompts, avg composite **40.6**, bands
  poor=78/weak=10/adequate=4.
- **Dynamic** (`measure_churn.py`, K=4): duplicate-worktree, unattended `AskUserQuestion`, ledger
  escalations, early-orientation reads `[?]`, first-turn-context + output tokens.

### Findings (all `[V]`; top three each survived an independent adversarial `sonnet` verifier)

- **F1** join coverage ~4% (89/93 unjoined; historical prompts predate the launcher/registry or were
  copy-mode). Precision on the joinable set is 100% (one join is this very session, id-verified).
- **F2** 0/92 prompts contain a Correlation self-report section — including all 4 modern prompts.
- **F3** live correlation completes 0 joins: the one live row is an orphan with a synthesized
  `lv-…` `handoff_id` and `child_sid: null`, because the dispatch didn't pass `-HandoffId`.
- **F4** 76/92 prompts carry ≥1 untagged state claim; the check *under*-counts (confirmed).
- **F5** on K=4, no churn failure modes fired (0 dup-worktree, 0 unattended Q, 0 ledger esc.) — small-N.
- **F6** the v1 composite was ~33% floor weight → it measured recency, not craft.

### Changed in `handoff/SKILL.md` (each tied to a finding; structure preserved)

| Finding | Change | Regression eval |
|---|---|---|
| F2 | Correlation section elevated to an unmissable required element with a concrete self-report snippet + a pre-dispatch self-check | handoff evals #6 |
| F3 | Step 4 now explicitly passes the frontmatter `handoff_id` to dispatch (`-HandoffId`), with the orphan-row evidence | handoff evals #6 |
| F4 | Added a pre-finish line-by-line `[V]`/`[?]` self-check of the State section | handoff evals #7 |

### Changed in the tuner's own rubric/metrics (rubric v1 → v2)

- **Floor marking.** `correlation`, `dead_ends`, all frontmatter fields, and `frontmatter_complete`
  marked `floor: true` (≈100%-fail → universal gaps, not a ranking). Composite is now computed over
  non-floor weight; a `convention_composite` keeps the v1 number. Floor failures reported separately
  as `floor_gaps`. **Effect:** avg composite 40.6 → **65.8**; bands poor=78/weak=10/adequate=4 →
  **poor=13/weak=44/adequate=31/strong=4** (a usable craft ranking).
- **Scope fix.** `no_bare_cross_bundle_script_paths` gains `skip_if_home_repo` + `home_repo_markers`,
  removing the false positive on the 4 archive-targeted prompts (they now score craft=100 with no
  spurious failure). Limitation documented in `rubric.v2.md`.

### What discriminated signal from noise

The three floor checks and the home-repo script false positive were **noise for ranking** (they
flagged recency or a non-defect). The discriminating craft signal was `state_claims_tagged` (76),
`delegation_logging` (65), `model_note` (60), `tasks_in_order` (29) — these vary across prompts and
are where craft actually differs. v2 is built to let those drive the score.

### Dogfood note

This run measured its own dispatch. It found `d2-tuner-26a` had no Correlation section (F2) and its
live row was orphaned (F3) — the two gaps the handoff enhancements now close. The tool caught the
flaw in the prompt that launched it.

### Carry-forward for Run 2

- Re-check floor adoption: once >50% of *recent* prompts carry frontmatter/Correlation/dead-ends,
  drop those `floor` flags so they rank again.
- Coverage will stay low until handoffs are routinely launched through the opener/registry path with
  `-HandoffId`; Run 2 should re-measure join coverage after the F2/F3 fixes have been in use, to see
  whether live joins start completing.
- Dynamic metrics need K to grow; K=4 cannot support corpus-level churn claims.
