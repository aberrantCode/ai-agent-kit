# Handoff prompt rubric — v1

The static half of the handoff-tuner score. It is the machine-checkable projection of the
**Required frontmatter** and **Required sections** rubric in
[`../../handoff/SKILL.md`](../../handoff/SKILL.md) — that file is the source of truth; this is its
testable shadow. The scorer ([`../scripts/score_rubric.py`](../scripts/score_rubric.py)) reads
[`rubric.json`](rubric.json), never a hard-coded copy, so a rule change is a one-file edit plus a
version bump here.

**Versioning.** `rubric.json`'s `version` and this file move together. When a run shows a check
discriminates nothing (every prompt passes it) or misfires (flags prompts a human would pass), bump
to `rubric.v2.md`, change `rubric.json`, and record the rationale in
[`tuning-log.md`](tuning-log.md). Never silently retune: a wrong threshold poisons every future
cycle's comparison against this baseline.

## What it measures (and what it does not)

The static score is a **coverage** proxy: is each load-bearing section *present and non-empty*, are
state claims tagged, are cross-bundle script paths absolute? It does **not** judge whether the prose
is *correct* — a prompt can score 100 and still mis-sequence its tasks. Correctness is the dynamic
half (churn/token measurement on the joined child) and human review. Read the composite as "did the
author fill in the load-bearing slots," not "is this a good handoff."

## Frontmatter fields (weight)

| Field | w | Why it is load-bearing |
|---|---|---|
| `handoff_id` | 2 | registry join key; missing ⇒ the handoff cannot correlate to its child at all |
| `model` | 2 | pinned model; drives `dispatch -SetEnv` and the child's `/model` decision |
| `title` | 1 | human label |
| `base_branch` | 1 | dispatch reads it for the worktree base |
| `branch` | 1 | dispatch reads it for the worktree branch |
| `repo` | 1 | dispatch reads it for the repo path |

## Required sections (weight)

A section earns its weight when its **heading** is present **and** at least one `body_pattern`
matches (sections with no body pattern earn on heading presence alone).

| Section | w | Earns when |
|---|---|---|
| Hard constraints | 3 | heading + a stop-and-ask / guardrail / never phrase |
| Correlation | 3 | heading + a `handoffs.jsonl` / self-report / `child_sid` / registry phrase |
| Dead ends / what we tried | 3 | heading present (even "None — first attempt") |
| Orientation | 2 | heading + a `CLAUDE.md` / `AGENTS.md` reference |
| State already established | 2 | heading present |
| Tasks, in order | 2 | heading + an order/rationale/before phrase |
| Finishing | 2 | heading + a PR/merge/rebase/report phrase |
| Delegation logging | 2 | heading + a `log-delegation-outcome` / `-HandoffId` / `-Category` phrase |
| Model note | 2 | heading + a model id / "pinned" phrase |
| Delegation | 1 | heading + a `haiku`/subagent/`model:` phrase |
| Reporting | 1 | heading + a terse / numbered / decision-list phrase |

## Cross-cutting checks (weight)

| Check | w | Fails when |
|---|---|---|
| `state_claims_tagged` | 4 | a numeric/factual line inside the State section carries **no** `[V]` or `[?]` tag |
| `frontmatter_complete` | 3 | any required frontmatter field is absent |
| `no_bare_cross_bundle_script_paths` | 3 | a reference to a sibling-bundle script (`log-delegation-outcome.ps1`, `cc_transcripts.py`, …) is written **without** an absolute/`~` root |
| `worktree_already_exists_warning` | 2 | no phrase telling the child its worktree/branch **already exists** (so it does not create a second) |

## Composite

`composite = 100 × earned_weight / total_weight`, over sections + checks + frontmatter.

| Band | Composite |
|---|---|
| strong | ≥ 90 |
| adequate | 70–89 |
| weak | 50–69 |
| poor | < 50 |

The band is a triage signal, not a grade: a "weak" prompt is where to look first, not proof the
handoff failed.
