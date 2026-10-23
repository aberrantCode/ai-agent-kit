# Handoff efficiency analysis — 2026-10-23

**Corpus:** 92 `docs/PROMPTS/*.md` prompts across 8 repos (git-identity discovery over 12 repo
roots); a raw cross-repo grep independently counted 98 unique main-checkout prompt files. `[V]`
**Registry:** `~/.claude/telemetry/handoffs.jsonl` — 91 rows (90 forensic + 1 live); 4 of 93
handoff_ids joined to a child (4.3%). `[V]`
**Tuner run:** rubric **v1**; `mine_handoffs.py` + `score_rubric.py` + `measure_churn.py` (all
read-only, forensic join computed in memory). **Session model:** Opus (reasoning-heavy meta-work;
mechanical fan-out and refutation delegated to `sonnet` verifier subagents).
**Produced by:** the new `handoff-tuner` sub-skill, run against its own dispatch (dogfood).

---

## Coverage first (do not bury this)

Join **precision is high** but **coverage is ~4%**. These are different questions and only the first
is good news.

| Coverage metric | Value | Tag |
|---|---|---|
| Handoffs discovered (registry ids ∪ prompt-frontmatter ids) | 93 | `[V]` |
| — joined to a child via the registry | 1 | `[V]` |
| — joined to a child via forensic launcher-opener (in-memory) | 3 | `[V]` |
| — unjoined | 89 | `[V]` |
| Child transcripts present on disk (dynamic-measurable, **K**) | 4 | `[V]` |
| Join precision on the joinable set (all 4 land at conf 0.95; one — `d2-tuner-26a` — is **this** session, verified against `$CLAUDE_CODE_SESSION_ID`) | 100% | `[V]` |

**Why coverage is ~4%, not ≥70%:** the Phase-A expectation of "≥70% join" is **contradicted** by the
data, and the reason is structural, not a join bug. 89 of 93 handoffs have no joinable child because
they **predate the launcher/registry** (the opener-based launcher and `handoffs.jsonl` are days old;
the corpus spans months), were **copy-mode** prompts a human pasted (no launcher opener was ever
written), or their **child transcripts were pruned**. Among the handful dispatched through the
current launcher, the join is reliable. The dynamic half of this analysis therefore runs on **K=4**
children — a sample too small to generalize; every dynamic result below is reported as such.

**Unjoined ≠ clean.** The 89 unjoined handoffs are *unmeasured*, not *efficient*.

---

## Headline findings

| # | Finding | Signal | Confidence | Survived refutation? |
|---|---|---|---|---|
| **F1** | Handoff↔child correlation **coverage is ~4%** (4/93); all real joins are forensic, not live | 89/93 unjoined | `[V]` | — (coverage math) |
| **F2** | **0 of 92** prompts contain a Correlation self-report section — including all 4 modern launcher-era prompts — so children never self-report their `child_sid` | 0/92 (0/98 raw grep) | `[V]` | **yes** — independent verifier, not refuted |
| **F3** | **Live correlation completes zero joins.** The one live row is an orphan: synthetic `handoff_id` `lv-aak-handoff-tuner-…` (not the frontmatter `d2-tuner-26a`), `child_sid: null` | 1 live row, 0 completed live joins | `[V]` | **yes** — not refuted |
| **F4** | The `[V]`/`[?]` tagging rule is widely violated: **76 of 92** prompts carry ≥1 untagged state claim | 76/92 | `[V]` | **yes** — not refuted; check actually *under*-counts |
| **F5** | On the 4 measurable children, **no** churn failure modes fired (0 duplicate-worktrees, 0 unattended questions, 0 ledger escalations) | K=4 | `[V]` | — (small-N, descriptive) |
| **F6** | The v1 composite is dominated (~33% of weight) by three post-convention checks that ≈100% of prompts fail, so it largely measures prompt **recency**, not craft | correlation 92/92, frontmatter 88/92, dead-ends 88/92 | `[V]` | — (calibration, see self-tune) |

**The single most important sentence:** the correlation backbone *works when exercised* (forensic
join is provably correct — it matched this very session), but it is **almost never exercised live**,
because the prompts that handoff generates don't tell the child to self-report (F2) and the live
dispatch didn't pass the frontmatter id (F3). Fixing those two is the highest-leverage change
available, and both live inside the `handoff` sub-skill's control.

---

## Static rubric findings (all 92 prompts, rubric v1)

Average composite **40.6**; bands **poor=78, weak=10, adequate=4**. The 4 adequate prompts (81–86)
are exactly the 4 modern launcher-era prompts (`d1-corr`, `d2-tuner`, `rs-usage`, `cmd-opps`) — so
the rubric is faithful: the prompts that follow the current convention score highest.

**Corpus composition** `[V]`: 80 of 92 prompts have handoff-template structure (a "State already
established"-style section); 12 are non-handoff docs (specs, plans, generic task prompts) that the
scorer neutral-passes rather than force-scoring.

**Floor checks (≈100% fail — a universal gap, NOT a prompt ranking):**

| Check | Fails | Reading |
|---|--:|---|
| `correlation` | 92/92 | the section is newer than almost the entire corpus (F2) |
| `handoff_id`/`title`/`model`/`base_branch`/`branch`/`repo` + `frontmatter_complete` | 88/92 | YAML frontmatter is a recent convention; only the 4 modern prompts have it |
| `dead_ends` | 88/92 | the "What we tried / dead ends" section is also recent |

These three flag real universal gaps but do not discriminate one prompt from another — they are
reported once, loudly, and down-weighted in rubric v2 (see self-tune).

**Discriminating checks (vary across prompts — this is the craft signal):**

| Check | Fails | Note |
|---|--:|---|
| `state_claims_tagged` | 76/92 | F4 — the single biggest craft gap; verifier confirms it under-counts |
| `delegation_logging` | 65/92 | most prompts never instruct the end-of-run delegation tally |
| `model_note` | 60/92 | no pinned-model rationale |
| `tasks_in_order` | 29/92 | tasks present but no ordering rationale |
| `reporting` | 23/92 | no terse/decision-list reporting instruction |
| `finishing` | 22/92 | no explicit merge/report/stop |
| `worktree_already_exists_warning` | 17/92 | risk of the child spawning a second worktree |
| `no_bare_cross_bundle_script_paths` | 13/92 | **borderline** `[?]` — see caveat |
| `orientation` / `state_established` / `delegation` / `hard_constraints` | 10–12 each | |

**Borderline `[?]`:** the `no_bare_cross_bundle_script_paths` check flags the 4 modern prompts for
referencing `…/sub-skills/.../cc_transcripts.py` without an absolute root. For a handoff **into the
ai-agent-kit archive itself**, those scripts are repo-local and resolve fine — so this is a likely
false positive for archive-targeted handoffs. Scoped out in rubric v2; **not** promoted to a handoff
rule change this run.

---

## Dynamic churn findings (joined children only, K=4)

| handoff_id | first-turn ctx | total output | turns | dup-worktree | unattended Q | early-orient reads `[?]` | ledger esc. |
|---|--:|--:|--:|--:|--:|--:|--:|
| `cmd-opps-26a` | 53,567 | 130,115 | 56 | 0 | 0 | 5 | 0 |
| `d1-corr-26a` | 64,359 | 227,674 | 240 | 0 | 0 | 9 | 0 |
| `d2-tuner-26a` (this session, mid-run) | 53,760 | 197,073+ | 132+ | 0 | 0 | 4 | 0 |
| `rs-usage-26a` | 53,464 | 311,688 | 135 | 0 | 0 | 7 | 0 |

- **No churn failure modes fired** on the measurable set `[V]`. That is encouraging but K=4 and all
  four are *recent, well-formed* prompts — it says the modern prompts execute cleanly, **not** that
  the 89 unjoined ones did.
- `early_orientation_reads` is a `[?]` proxy (Read/Grep/Glob/git-inspect in the first 15 turns); 4–9
  is modest and expected — no evidence of heavy re-derivation on these four.

## Token & cost

First-turn context clusters at **53–64K** `[V]` — consistent with the measured ai-agent-kit startup
baseline (~49K) plus the prompt itself. Total output per child ranges **130K–312K** `[V]`. Any claim
that a high burn was *caused by* re-derivation churn would be `[?]` and the churn metrics do **not**
support it for these four — so no such attribution is made. The real cost lever this run surfaces is
not per-session churn but **lost measurability**: 89/93 handoffs produce no joinable transcript, so
their cost is invisible.

---

## What became a handoff-enhancement (traceability)

| Finding | Edit to `handoff/SKILL.md` | Regression eval |
|---|---|---|
| F2 (0/92 Correlation sections) | Make the Correlation self-report an **unmissable required element** with a concrete template snippet and a pre-dispatch self-check | handoff evals #6 |
| F3 (live row orphaned by synthetic id) | Step 4: **explicitly instruct passing the frontmatter `handoff_id` to dispatch** (`-HandoffId`), so the live dispatch row carries the real id | handoff evals #6 |
| F4 (76/92 untagged claims) | Add a concrete **pre-finish self-check** of the State section for `[V]`/`[?]` tags | handoff evals #7 |

Findings with **no** proposed handoff change: F5 (clean, descriptive), F6 and the borderline
script-path check (tuner-side calibration, handled in self-tune, not handoff's control).

---

## Coverage caps & honest gaps

- **89/93 handoffs unjoined** — unmeasured, not clean. Dynamic metrics ran on K=4 only.
- **Forensic join is in-memory** this run (read-only); 3 of the 4 joins are not persisted to the
  registry. Persisting them is the backfill script's job (`--apply`), deliberately not done here.
- **Denominator wobble:** scorer discovery found 92 prompts (git-identity over 12 repos), raw grep
  found 98 main-checkout files (incl. 2 `.review.md`). Either way the F2 count is **0**.
- **Pruned transcripts** for older handoffs cannot be recovered; those handoffs are permanently
  unmeasurable.

## Confirmation (read-only)

- [x] No transcript, registry, or ledger **record was modified** by this analysis.
- [x] Forensic joins were computed **in memory**; no rows appended to `handoffs.jsonl`.
- [x] No prompt file was deleted or edited; no merge/push/PR performed by the analysis step.
- [x] All `~/.claude/**` reads were read-only.
- [x] Top findings F2/F3/F4 were each put to an independent adversarial verifier subagent instructed
      to refute; none were refuted.
