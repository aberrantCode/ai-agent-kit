# Handoff-efficiency report template

The tuner's report is written for a skimmer: lead with the coverage line and the headline table,
back every number with a `[V]`/`[?]` tag and a citation, and never state a churn/token figure the
scripts did not compute. Follow this section order. Save to the repo's `docs/reports/` as
`handoff-efficiency-analysis.md` (committed, reviewed through the PR — unlike the audit sub-skill's
`~/.agent/reports/*.review.md`, this report is a repo deliverable).

```markdown
# Handoff efficiency analysis — <date>

**Corpus:** <N prompts across M repos> · **Window:** <phase A / phase B scope>
**Registry:** `~/.claude/telemetry/handoffs.jsonl` (<rows>, <joined>/<total> handoffs joined)
**Tuner run:** rubric v<X>; scripts <mine_handoffs/score_rubric/measure_churn> · **Session model:** <model + why>

## Coverage first (do not bury this)

State the join coverage and WHY it is what it is before any finding that depends on it. If dynamic
measurement ran on only K joined children of N handoffs, say so here — a reader must not read a
small-N dynamic result as representative. Name every coverage cap: unjoined prompts, pruned
transcripts, copy-mode handoffs that never launched, prompts that predate the registry/launcher.

| Coverage metric | Value | Tag |
|---|---|---|
| Handoffs discovered | N | [V] |
| — joined to a child (registry) | n | [V] |
| — joined to a child (forensic launcher-opener) | n | [V] |
| — unjoined | n | [V] |
| Children with a transcript on disk (dynamic-measurable) | K | [V] |

## Headline findings

| # | Finding | Signal | Confidence |
|---|---|---|---|
| F1 | <one line> | <the number> | [V]/[?] |

**<The single most important sentence: does the evidence support or contradict the premise that
prompted this run?>** If a trigger number (e.g. "join should be ≥70%") turned out false, say so
plainly here, not in prose below.

## Static rubric findings (all prompts)

Per recurring failure, not per prompt. For each: which rubric check, how many prompts, example
citations (file + the offending line), and whether the check DISCRIMINATES (varies across prompts)
or is a FLOOR (≈100% fail — flags a universal gap but does not rank). A floor finding is reported
once, loudly; it is not evidence that one prompt is worse than another.

## Dynamic churn findings (joined children only)

Only the K children with a transcript. Per metric (duplicate-worktree creation, unattended
user-questions, ledger escalations/redos, early-orientation reads [?], token burn): the measured
value, the child it came from, and the `[V]`/`[?]` tag. If K is small, repeat that the sample is
small — do not generalise a clean or dirty result from K=4 to the whole corpus.

## Token & cost

First-turn context and total output per joined child [V]. Any inference about what DROVE a high
burn (e.g. "re-derivation churn") is [?] unless a specific metric supports it — do not attribute
cost to churn you did not measure.

## What became a handoff-enhancement (traceability)

Table: finding → the exact edit proposed to `handoff/SKILL.md` and/or its `evals/evals.json` → the
regression eval that will catch a relapse. A finding with no proposed change is fine; say why
(borderline, low signal, out of handoff's control).

## Coverage caps & honest gaps

Everything not measured and why. Unjoined prompts are not "clean" — they are unmeasured. Say it.

## Confirmation (read-only)

Checklist: no transcript, registry, or ledger record was modified; no prompt file deleted; all
registry/ledger reads were read-only; forensic joins were computed in memory, not written.
```

## Rationale notes (keep out of the rendered report)

- The **coverage-first** rule is specific to this report: the handoff corpus is dominated by prompts
  that predate the registry, so a naive "join rate" reads as failure when the real story is "most
  prompts were never launched through the opener/registry path." Separate *precision* (given a
  child, is the join correct) from *coverage* (what fraction have a joinable child) explicitly.
- The **floor vs discriminating** distinction stops a ≈100%-fail check (e.g. a brand-new required
  section no old prompt has) from being read as "these prompts are uniquely bad." It is the same
  signal-vs-noise call the self-tune step uses to decide which checks to reweight.
