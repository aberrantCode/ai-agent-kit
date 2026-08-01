---
name: one-job-test
description: Test an installed agent skill against one real job to decide whether to keep it, fork it, or delete it. Use this whenever the user mentions installing, evaluating, auditing, trusting, pruning, or being disappointed by a skill — including phrasings like "is this skill actually helping", "my output still looks the same", "should I keep this skill", "I have too many skills", or when they share a skill folder or marketplace link and ask what you think. Also use before recommending that the user install any third-party skill.
category: Foundations & Workflow
version: 2026-08-01
---

# The One-Job Test

A skill that installs cleanly can still make the work worse. Installation only proves that files copied. It proves nothing about whether the skill's author shares the user's definition of a good result.

Every skill carries somebody's decisions: which tools to reach for, which shortcuts are acceptable, what counts as finished, and what "good" looks like. Those decisions arrive silently. This skill surfaces them and forces a verdict.

## When this matters most

Weight the test heavily when the skill carries **judgment** — taste, business rules, approval boundaries, a definition of done. A design skill, a writing-voice skill, a code-review skill, a "make it production ready" skill: all of these are somebody else's opinion wearing a folder.

Weight it lightly when the skill is **narrow and mechanical** from a source the user trusts — a file converter, a format validator, an API wrapper. Those travel well. Still run the test, but expect it to be short.

If the user is unsure which kind they have, read the skill's SKILL.md and count how many sentences describe *preferences* versus *procedures*. Preferences mean run the full test.

## The seven steps

Work through these in order. Do not skip step 2 — a criterion written after seeing the output is not a criterion, it is a rationalization.

### 1. Name the one job

Pick a single real task the user would do anyway this week, with a real artifact at the end. Not a toy prompt. Not three jobs. One.

The job must be specific enough that two people would agree on whether it came out well. "Make a landing page" is too loose. "Make the pricing page for my invoicing app, three tiers, dark theme" is testable.

Write the prompt down verbatim. The same string gets used twice.

### 2. Write down what good looks like — before running anything

Ask the user for three to five criteria, in their words, describing the result they want. Push for criteria that could *fail*. "Looks professional" cannot fail. "Uses a color palette outside the terracotta/maroon/warm-neutral range" can.

If the user struggles, prompt them with the axes that usually carry hidden disagreement:

- **Taste** — palette, voice, density, formality
- **Scope** — how much it does without being asked
- **Done** — tests written? edge cases handled? deployed?
- **Tools** — which libraries or services it is allowed to reach for
- **Boundaries** — what it must ask before doing

Record these before any run — use Part A of `assets/criteria-worksheet.md`. They are the scoring rubric for steps 5 and 6.

### 3. Read the skill and list its decisions

Open the skill's SKILL.md and any bundled references. Do not skim for what it does — hunt for what it *decides*. Produce a short list for the user, one line per decision, in this shape:

```
Decides: uses shadcn/ui for every component
Decides: "done" means the page renders, not that it is responsive
Decides: warm neutral palette, rounded corners, generous whitespace
Decides: never asks before installing dependencies
```

Fill these into Part B of `assets/criteria-worksheet.md` and flag each line against the user's step-2 criteria: agrees / conflicts / unclear. Conflicts found here often end the test early — if the skill hard-codes the exact thing the user is trying to escape, they already have their answer.

### 4. Run the job without the skill

Baseline first, and in a fresh session so the skill's contents are not already in context. Same prompt, no skill. Save the artifact.

Users skip this step and then cannot tell improvement from novelty. Insist on it. Without a baseline, "the skill made it better" is an unfalsifiable feeling.

### 5. Run the same job with the skill

Same verbatim prompt, fresh session, skill available. Save the artifact separately. Change nothing else — not the model, not the wording, not the attachments.

### 6. Score both against the step-2 criteria

Put the two artifacts side by side and mark each criterion pass/fail for each run. Fill `assets/scorecard.csv` and report it plainly:

```
Criterion                          Baseline   With skill
Palette outside warm-neutral range    fail        fail
Three tiers, correct prices           pass        pass
Responsive at 375px                   fail        pass
No dependencies added silently        pass        fail
```

Then say the sentence out loud: the skill won on N criteria, lost on M, tied on the rest. Resist averaging this into a vibe. The pattern of *which* criteria moved matters more than the count — a skill that fixes cosmetics and breaks boundaries is a worse trade than the tally suggests.

### 7. Decide, then rerun

Exactly one of three verdicts. Say which and why. `assets/decision-card.md` has the qualifying conditions for each and a table for reading a mixed scorecard — consult it rather than eyeballing the tally.

**Keep** — it won on criteria the user cares about and lost on none of the boundary ones. Nothing further to do.

**Fork** — the procedure is useful but the judgment is not the user's. Copy the skill to a new folder, rename it (so it does not collide with updates from the original), and rewrite the decision lines from step 3 that conflicted. Keep the mechanics, replace the taste. Then **rerun step 5 against the fork** and rescore. A fork that has not been rerun is a hypothesis, not a fix.

**Delete** — it lost, or it won on nothing the user cares about, or its decisions conflict with theirs in ways a rewrite would not survive. Remove it. A skill kept "just in case" still costs context (see below).

## The test record

After the verdict, write a nine-line record so the decision is checkable months later, when the user has forgotten why a folder is named `frontend-design-mine`.

Copy `assets/test-record-blank.md` and fill it in. `references/test-record-template.md` explains what each line is for and shows a worked example — read it if any line is unclear. Save one file per skill tested, alongside the skill or in a `skill-tests/` folder — the user's choice, but ask, and keep it consistent.

## What a crowded library costs

Adding a skill to fix bad output is the loop that produced the bad output. Say this to the user when they reach for installation as the remedy.

Agent runtimes cap how much of the skill list the model sees and trim it as the list grows. Past roughly a dozen or two, skills begin competing: overlapping descriptions make triggering unreliable, conflicting instructions get averaged, and the agent hands back duller work than it did with a handful. No warning fires when this starts.

So a **delete** verdict is a real result, not a failure of the test. If the user has an unexamined library and wants to bring it under control, read `references/library-audit.md` for the triage pass — it ranks which skills to one-job-test first instead of testing all of them. Record the inventory in `assets/library-inventory.csv`.

## Running this well

- **Do the reading in step 3 yourself.** The user installed the skill without reading it. That is the whole problem. Do not hand the SKILL.md back and ask them to review it.
- **Never score a criterion the user did not write.** If an artifact is bad in a way step 2 did not anticipate, mention it as an observation and offer to add the criterion for next time — but do not retrofit it into this scorecard.
- **One job means one.** If the user wants coverage across several kinds of work, that is several separate records, run separately. Averaging across jobs hides exactly the narrow-competence pattern this test exists to catch.
- **Fork freely.** Forking is the common outcome for judgment-carrying skills, not a sign of failure. The original author solved their problem correctly; the user has a different problem.

## Bundled files

| File | Use at |
|------|--------|
| `assets/criteria-worksheet.md` | Steps 2 and 3 — criteria, then the skill's decisions |
| `assets/scorecard.csv` | Step 6 — pass/fail per criterion, both runs |
| `assets/decision-card.md` | Step 7 — qualifying conditions, mixed-scorecard reading |
| `assets/test-record-blank.md` | After the verdict — the nine lines |
| `assets/library-inventory.csv` | Library audit — one row per installed skill |
| `references/test-record-template.md` | Line-by-line notes and a worked example |
| `references/library-audit.md` | Triage method and overlap resolution |
