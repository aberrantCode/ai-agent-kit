# `/what-next` Evaluation Harness

Reusable infrastructure for measuring whether changes to the skill make it
better or worse. Any future iteration of `SKILL.md` or `references/*.md` should
be re-graded here before being considered done.

---

## Layout

```
evals/
├── README.md          # this file
├── evals.json         # canonical test definitions (prompts + assertions)
├── fixtures/          # synthetic repos, one per eval
│   ├── eval-1-returning-user-vague/
│   ├── eval-2-project-manager-present/
│   ├── eval-3-bare-repo-bootstrap/
│   └── eval-4-update-flow/
├── benchmarks/        # historical pass-rate/time/token summaries
│   ├── iteration-1.json / .md
│   └── iteration-2.json / .md
└── harness/           # reusable scripts
    ├── setup_iteration.py
    ├── save_timing.py
    ├── grade.py
    └── migrate_layout.py
```

Generated workspaces live at `claude/skills/what-next-workspace/iteration-<N>/`,
sibling to the skill. Those directories are **gitignored** — only the
`benchmarks/` summaries are kept in history.

---

## Eval philosophy

- **Assertions are the contract.** `evals.json` holds the assertion texts;
  `harness/grade.py` keys off those texts to score each run. When an assertion
  changes, change it in both files together.
- **Fixtures capture the *scenario*, not the output.** Each fixture directory is
  a synthetic repo tailored to exercise one branch of the skill's decision flow.
  The skill's outputs (backlog.md, docs/what-next.md, etc.) are produced by the
  test subagents; the fixtures themselves never contain those.
- **Baseline is always "no skill".** Every iteration runs the same prompts
  through a second set of subagents with no skill access. This measures whether
  the skill actually earns its token cost on top of what a generalist agent
  does naively.
- **Human review is the tiebreaker.** The quantitative benchmark tells you
  pass rates; the qualitative review (opened via `generate_review.py`) tells
  you whether the skill *feels right*. Iteration-2 was driven by qualitative
  feedback — "the baseline was better than the skill" on eval 2 — that the
  numbers alone missed.

---

## Running a new iteration

The full loop takes roughly 10 minutes with subagents running in parallel.

### 1. Clone fixtures into a fresh workspace

```bash
cd claude/skills/what-next
python evals/harness/setup_iteration.py 3
```

Creates `claude/skills/what-next-workspace/iteration-3/` with one eval dir per
entry in `evals.json`, each with `with_skill/fixtures/`, `without_skill/fixtures/`,
empty `outputs/` dirs, and an `eval_metadata.json`.

### 2. Spawn subagents — 4 with-skill + 4 baseline

In the same Claude Code turn, spawn 8 `general-purpose` subagents in parallel.
Each with-skill agent is pointed at
`C:/development/llm_skills/claude/skills/what-next/SKILL.md` and the fixture
dir for its eval; each baseline agent gets only the fixture and the prompt.

See the prompts used for iterations 1 and 2 in the git history (search for
`"Skill path to use"` in messages).

Every subagent writes to its `outputs/` dir:
- `transcript.md` — narrative
- `questions-asked.md` — every `AskUserQuestion` it would have called
  (subagents can't actually invoke that tool, so they write the simulated
  question + chosen default)
- `summary.json` — structured summary used by the grader
- Any files the skill would have created (backlog.md, docs/what-next.md, etc.)
  saved **inside `outputs/`**, never into the fixture

### 3. Capture timing from the Agent tool's completion notifications

Each subagent completion includes `total_tokens` and `duration_ms`. These are
*only* available via the notification — not persisted elsewhere. Record them
immediately:

```bash
python evals/harness/save_timing.py 3 \
  --eval 1 --kind with_skill    --tokens 54815 --duration-ms 125490 \
  --eval 1 --kind without_skill --tokens 39579 --duration-ms 79302 \
  ... (repeat for all 8 runs)
```

Or build a `timings.json` manifest and pass `--from-json`.

### 4. Grade against assertions

```bash
python evals/harness/grade.py 3
```

Writes `grading.json` next to each `outputs/` dir. Each grader in
`harness/grade.py` is keyed on `eval_id` — to add a new eval, add a new entry
to `evals.json` and a new `grade_eval_N` function to `EVALUATORS`.

### 5. Migrate to the aggregator's expected layout

```bash
python evals/harness/migrate_layout.py 3
```

Wraps `grading.json` and `timing.json` under `run-1/` subdirectories, which is
the layout `skill-creator/scripts/aggregate_benchmark.py` expects.

### 6. Aggregate and generate the review viewer

```bash
cd "$HOME/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator"
python -m scripts.aggregate_benchmark \
  /path/to/what-next-workspace/iteration-3 \
  --skill-name what-next \
  --skill-path /path/to/what-next
```

Produces `benchmark.json` and `benchmark.md`. Copy these into
`evals/benchmarks/iteration-3.{json,md}` to preserve the history.

```bash
python eval-viewer/generate_review.py \
  /path/to/what-next-workspace/iteration-3 \
  --skill-name what-next \
  --benchmark /path/to/what-next-workspace/iteration-3/benchmark.json \
  --previous-workspace /path/to/what-next-workspace/iteration-2 \
  --static /path/to/what-next-workspace/iteration-3/review.html
```

Open `review.html` in a browser. The viewer shows:
- **Outputs** tab — per-eval transcripts, produced files, grading marks,
  previous iteration's outputs + feedback (if `--previous-workspace` provided)
- **Benchmark** tab — pass-rate / time / token comparison with means ± stddevs

### 7. Capture user feedback + iterate

After reviewing, click "Submit All Reviews" in the viewer. Downloads
`feedback.json`. Empty feedback fields = satisfied; non-empty = direction for
the next iteration.

---

## Adding a new eval

1. Pick an unused `id` and a descriptive `name` (kebab-case).
2. Add an entry to `evals.json` with `prompt`, `expected_output`, `fixture_root`,
   and an `assertions` array. Assertion texts should be objectively verifiable
   — "skill did X" or "skill did NOT do Y".
3. Create `fixtures/eval-<id>-<name>/` with whatever synthetic repo the eval
   needs.
4. Add a `grade_eval_<id>(outputs, assertions)` function to
   `harness/grade.py` that returns one signal per assertion, in order. Register
   it in the `EVALUATORS` dict.

That's it — `setup_iteration.py`, `save_timing.py`, and `migrate_layout.py`
pick up the new eval automatically.

---

## Benchmark history

See `benchmarks/iteration-N.md` for the human-readable summary of each run.

| Iteration | With-skill pass rate | Baseline | Delta | Key change |
|----------:|:-------------------:|:--------:|:-----:|------------|
| 1         | 100% (21/21)        | 19%      | +81   | Initial skill + 4 evals |
| 2         | 100% (24/24)        | 29%      | +71   | Implicit-blocked + stale penalties; delegation preview; infra observations |

(Totals differ between iterations because assertions were tightened in iter-2.)
