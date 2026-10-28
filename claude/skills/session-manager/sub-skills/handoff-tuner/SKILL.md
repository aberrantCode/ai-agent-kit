---
name: sm-handoff-tuner
description: >
  Sub-skill of `session-manager`. Measure how well past handoff prompts actually worked and tune the
  `handoff` sub-skill from the evidence — "tune the handoff skill", "how efficient are our handoffs",
  "analyze handoff token cost / new-session churn", "which handoff prompts caused the child to
  re-derive / stall / spawn a second worktree", "score our handoff prompts against the rubric",
  "/tune-handoff". Mines the handoff registry (registry-first, forensic launcher-opener fallback),
  scores each prompt against a versioned rubric, measures churn/token burn on the joined child
  sessions, writes an evidence-tagged report, and proposes handoff/SKILL.md enhancements plus a
  versioned rubric/metrics refinement — all as a reviewed PR, never an autonomous self-edit.
---

# handoff-tuner — measure handoffs, then tune the handoff skill from evidence

The `handoff` sub-skill writes the prompt for the next session. This sub-skill closes the loop: it
reads what those prompts *did* — did the child re-derive facts the prompt already stated, stall on a
question an unattended session couldn't answer, spawn a second worktree, burn tokens re-orienting —
and turns the pattern into sharper handoff rules. It is the recursive, self-improving half of the
pair: every run proposes a change to `handoff/SKILL.md` **and** a refinement to its own rubric, both
as a reviewed diff.

**This is a measurement-and-proposal tool, not an autonomous rewriter.** See Hard constraints.

## When to use

- You want to know whether handoffs are actually efficient — token cost, new-session churn, join
  reliability — with real numbers, not an impression.
- You want to improve the `handoff` sub-skill and want each change justified by a finding, not taste.
- A handoff relapse keeps happening (children re-deriving, stalling, double-worktree-ing) and you
  want it caught by a rule + a regression eval.

Not for: writing a handoff (that is [`handoff`](../handoff/SKILL.md)); auditing a policy across
sessions (that is [`audit`](../audit/SKILL.md)); general token reports ([`usage`](../usage/SKILL.md)).

## Hard constraints (read before running)

1. **Read-only on history.** Transcripts (`~/.claude/projects/**`), the handoff registry
   (`~/.claude/telemetry/handoffs.jsonl`) and the delegation ledger
   (`~/.claude/telemetry/delegation-outcomes.jsonl`) are **read-only**. The forensic join is computed
   **in memory**; never append or rewrite registry/ledger rows as part of a tuning run.
2. **No autonomous self-rewriting.** "Self-improvement" means the run emits a versioned rubric/metrics
   update and a tuning-log entry **as proposed diffs that land through a normal reviewed PR**. Never
   rewrite this SKILL.md's control flow, and never apply a rubric/metric change outside the
   worktree/PR, without human review.
3. **Enhancements preserve handoff's structure and intent.** Add or sharpen rules in
   `handoff/SKILL.md`; justify each with a report finding. Do not gut it.
4. **Never state a metric you did not compute.** Tag every claim `[V]`/`[?]`. A wrong churn/token
   number poisons every future tuning cycle's comparison against the baseline.
5. If a step seems to require violating the above, stop and ask.

## The loop

```
mine → measure (static + dynamic) → report → propose+apply handoff enhancements → self-tune
```

Each stage consumes the prior's output; run them in order.

| Stage | Script (run with its absolute path) | Output |
|---|---|---|
| **mine** | [`scripts/mine_handoffs.py`](scripts/mine_handoffs.py) | per-handoff resolution: prompt, child session, ledger rows, token usage; coverage stats |
| **measure (static)** | [`scripts/score_rubric.py`](scripts/score_rubric.py) | per-prompt rubric score + itemized failures, read from [`references/rubric.json`](references/rubric.json) |
| **measure (dynamic)** | [`scripts/measure_churn.py`](scripts/measure_churn.py) | per joined child: duplicate-worktree, unattended questions, ledger escalations, early-orientation reads `[?]`, tokens |
| **report** | (you, Opus) | `docs/reports/handoff-efficiency-analysis.md` per [`references/report-template.md`](references/report-template.md) |
| **enhance** | (you, Opus) | reviewed edits to `handoff/SKILL.md` + its `evals/evals.json`, each traced to a finding |
| **self-tune** | (you, Opus) | `references/rubric.vN+1.md` / bumped `rubric.json` + a newest-on-top [`references/tuning-log.md`](references/tuning-log.md) entry |

### Running the scripts

All three import the shared `cc_transcripts` library and the `handoff` forensic-join module — do not
re-derive transcript discovery, iteration, counting, or the launcher-opener join (every counting
trap is already solved there; reintroducing one yields plausible-but-wrong numbers). Run each with
its **absolute** path (globally installed:
`~/.claude/skills/session-manager/sub-skills/handoff-tuner/scripts/<name>.py`).

```bash
python <TUNER>/scripts/mine_handoffs.py   --format md
python <TUNER>/scripts/score_rubric.py    --all --format md
python <TUNER>/scripts/measure_churn.py   --format md
```

Flags: `--repo-substring <s>` to scope; `--since "YYYY-MM-DD HH:MM:SS"` (mine/churn) to window by
prompt mtime; `--format json` for machine output; `--early-turns N` (churn) to size the
orientation-read window. Phase the first run: Phase A on recent main-checkout prompts to confirm the
join and that metrics are sane, then Phase B on the full corpus including worktrees.

### Measure what, exactly

- **Static (prompt text).** Each required frontmatter field and section present and non-empty; state
  claims tagged `[V]`/`[?]`; cross-bundle script paths absolute; the "your worktree already exists"
  warning present. The rubric is **data** (`rubric.json`) — the scorer never hard-codes it, so a
  rule change is a one-file edit + a version bump.
- **Dynamic (what the child did).** On joined children only: duplicate-worktree creation and
  unattended `AskUserQuestion`s (hard `[V]` signals), ledger escalations/redos under the handoff_id
  `[V]`, early-orientation reads (a `[?]` proxy for re-derivation), and first-turn-context + total
  token burn from the child's own usage records.

### Join coverage is the first thing to report

Separate **precision** (given a child transcript, is the join correct) from **coverage** (what
fraction of handoffs have a joinable child). Most historical prompts predate the registry/launcher or
were copy-mode, so coverage is low even when precision is high. Dynamic metrics run only on the
joined few — report that K explicitly and never read a small-K result as representative. Log every
coverage cap; do not present unjoined prompts as "clean" — they are unmeasured.

## Self-tune (the recursive step)

After the report and the handoff enhancements, refine the tuner itself — as a reviewed diff:

1. **Decide what discriminated signal from noise this run.** A check that ≈100% of prompts fail is a
   *floor* (flags a universal gap once; does not rank prompts) — consider down-weighting or scoping
   it. A check that never fires, or fires on false positives, is noise — tighten or retire it.
2. **Bump the rubric.** Edit `rubric.json` (`version`), write a sibling `references/rubric.vN+1.md`
   documenting the change and its evidence. Never silently retune — a changed threshold must be
   explainable against the prior baseline.
3. **Append a tuning-log entry** (newest on top) to [`references/tuning-log.md`](references/tuning-log.md):
   metrics used, findings, what changed in `handoff/SKILL.md`, what changed in the rubric/metrics,
   and the rationale. This log is the audit trail of the recursion.

## Delegation

Dispatch `model: "haiku"` subagents (explicitly) for mechanical fan-out — per-repo prompt scoring,
ledger extraction, token tallies — in parallel. Keep in the main (Opus) loop: metric/rubric
**design**, the enhancement **synthesis** (which finding becomes which rule), and any adversarial
judgement. Spawn an adversarial verifier to try to **refute** each top finding before it reaches the
report; a finding that survives refutation is reportable. Log every escalation/redo and a
per-category totals row with the `delegation-ledger` scripts, tagged `-HandoffId` — the tuner's own
run is itself data for the next run.

## Dogfooding note

This sub-skill measures handoffs, so its own run is a handoff being measured. If its findings say
"prompts omit the Correlation section," check that the prompt that dispatched *this* run didn't too —
the sharpest evidence is often the run looking at itself.
