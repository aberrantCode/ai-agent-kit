# The One-Job Test — complete bundle

A reconstruction of the agent-skill evaluation method outlined in Nate's Newsletter,
"Agent Skills: How to Test One Before You Keep It" (Aug 1, 2026).

The post's body is paywalled; this was built from the public preview, which describes a
seven-step test ending in keep/fork/delete, a nine-line test record, and a section on the
cost of a crowded skill library. The steps, lines, and worksheets below are a
reconstruction, not a copy.

## Contents

| File | Use at |
|------|--------|
| `SKILL.md` | The seven-step test |
| `references/test-record-template.md` | Line-by-line notes and a worked example |
| `references/library-audit.md` | Triage method and overlap resolution |
| `assets/criteria-worksheet.md` | Steps 2 and 3 |
| `assets/scorecard.csv` | Step 6 |
| `assets/decision-card.md` | Step 7 |
| `assets/test-record-blank.md` | After the verdict |
| `assets/library-inventory.csv` | Library audit |

---

<!-- ===== FILE: skill-one-job-test/SKILL.md ===== -->

> **File:** `SKILL.md`

---
name: skill-one-job-test
description: Test an installed agent skill against one real job to decide whether to keep it, fork it, or delete it. Use this whenever the user mentions installing, evaluating, auditing, trusting, pruning, or being disappointed by a skill — including phrasings like "is this skill actually helping", "my output still looks the same", "should I keep this skill", "I have too many skills", or when they share a skill folder or marketplace link and ask what you think. Also use before recommending that the user install any third-party skill.
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

---

<!-- ===== FILE: skill-one-job-test/references/test-record-template.md ===== -->

> **File:** `references/test-record-template.md`

# The nine-line test record

Purpose: turn "this feels better" into evidence that is still checkable six months from now. Nine lines, no prose padding. If a line does not have a real answer, the test is not finished.

## Template

Copy this verbatim and fill it in.

```markdown
# Skill test: <skill-name>

1. **Date tested:** YYYY-MM-DD
2. **Skill + source:** <name>, from <url / marketplace / colleague>, version or commit <ref>
3. **The one job:** <the prompt, verbatim, in a code block>
4. **What good looks like:** <3-5 criteria, each one able to fail>
5. **Baseline result:** <which criteria passed without the skill>
6. **With-skill result:** <which criteria passed with the skill>
7. **Where its judgment differed from mine:** <the decision lines from step 3 that conflicted>
8. **Verdict:** keep | fork | delete — <one sentence of why>
9. **What changed + recheck:** <edits made if forked, and the date to retest>
```

## Line notes

**Line 2 — source and version.** Skills get updated upstream. Without a commit or version, a future retest cannot tell "the skill changed" from "I judged it differently."

**Line 3 — verbatim prompt.** The exact string, not a description of it. Retests are worthless if the prompt drifted.

**Line 4 — falsifiable criteria.** Each must be able to come out false. If every criterion passed both runs, they were too soft, and the test proved nothing.

**Lines 5 and 6 — results, not feelings.** Which criteria passed. Not "better" or "cleaner."

**Line 7 — the real payload.** This is the line that ages well. It records what the skill's author believed that the user does not, which is what predicts the *next* disappointment with that skill.

**Line 8 — one of three words.** Not "keep for now" or "maybe fork later." An undecided test is a test that will be rerun from scratch.

**Line 9 — the recheck date.** Skills rot: upstream changes, model changes, the user's taste changes. Ninety days is a reasonable default for kept skills. For deleted ones, write "n/a — removed."

## Worked example

```markdown
# Skill test: frontend-design

1. **Date tested:** 2026-08-01
2. **Skill + source:** frontend-design, from github.com/<author>/skills, commit 4a91c02
3. **The one job:**
   ```
   Build the pricing page for my invoicing app. Three tiers (Solo $9,
   Team $29, Business $79), monthly/annual toggle, dark theme.
   ```
4. **What good looks like:**
   - Palette is not warm-neutral/terracotta/maroon
   - Genuinely dark theme, not light with a dark header
   - Annual toggle recalculates prices, not decorative
   - Readable at 375px
   - No dependencies installed without asking
5. **Baseline result:** passed 3/5 — failed the palette criterion (came out terracotta anyway) and 375px
6. **With-skill result:** passed 3/5 — fixed 375px, still terracotta, and added two npm packages unprompted
7. **Where its judgment differed from mine:**
   - Decides: warm neutral palette with a single accent — the exact thing I was trying to escape
   - Decides: "done" means it renders — I expect responsive
   - Decides: installs component libraries without asking — I want to approve dependencies
8. **Verdict:** fork — the responsive and layout mechanics are good; the palette and dependency rules are not mine
9. **What changed + recheck:** forked to `frontend-design-mine`; replaced the palette section with my three approved palettes, added a rule to propose dependencies before installing. Reran the job: 5/5. Recheck 2026-11-01.
```

Note what the example demonstrates: a raw tally of 3/5 versus 3/5 looked like a wash, and the skill was still worth keeping in forked form. The scorecard is an input to the verdict, not the verdict itself.

---

<!-- ===== FILE: skill-one-job-test/references/library-audit.md ===== -->

> **File:** `references/library-audit.md`

# Auditing a crowded skill library

Read this when the user has more skills than they have examined, and wants the library under control without one-job-testing every folder.

The full seven-step test costs two runs and a scorecard. Do not spend that on twenty skills. Triage first, then test the top few.

## The triage pass

Inventory every installed skill. For each one, record four things — all cheap to determine by reading the SKILL.md frontmatter and skimming the body:

| Field | How to fill it |
|---|---|
| **Last used** | When did it visibly change an output? "Never noticed it fire" is the most common and most informative answer. |
| **Carries judgment?** | Does the body encode taste, business rules, approval boundaries, or a definition of done? Yes/no. |
| **Description overlap** | Does its description compete with another skill's for the same trigger phrases? Name the collisions. |
| **Cost of being wrong** | If it silently does the wrong thing, is that a cosmetic annoyance or a real problem (data written, money spent, message sent, dependency installed)? |

## Ranking what to test

Test in this order:

1. **Judgment + high cost of being wrong.** These decide things on the user's behalf that are expensive to undo. Test first, always.
2. **Judgment + used often.** Quietly shaping a lot of work.
3. **Overlapping descriptions.** Two skills competing for the same trigger means at least one fires when it should not. Test whichever is newer — it is usually the redundant one.
4. **Never noticed it fire.** Do not test these. See the next section.

Mechanical, low-cost, rarely-used skills come last, and often never — the test would cost more than the skill risks.

## The default verdict for unused skills

A skill the user cannot remember ever helping is a delete candidate on that basis alone. It is consuming a slot in the list the agent sees, and its description is competing for triggers, in exchange for benefit nobody has observed.

Two exceptions worth honoring:

- It is genuinely seasonal — a quarterly-close skill, a conference-prep skill. Keep, and note why.
- It has never fired because its *description* is bad, not because it is useless. If reading the body reveals something the user wants, the fix is a rewritten description, not deletion. This is a fork, and it should get a test record like any other.

Everything else: delete. The user can reinstall in thirty seconds if they were wrong.

## Overlap resolution

When two skills collide on triggers, the choice is not always "delete one." Three options:

- **Merge** — one skill, one description, the union of the bodies. Best when they genuinely do the same job.
- **Narrow** — rewrite both descriptions so the boundary between them is explicit ("use for X, not Y — for Y use Z"). Best when both are wanted and the domains are actually distinct.
- **Delete the redundant one** — best when one is strictly better and the other was installed and forgotten.

Whichever is chosen, rerun a representative job afterward to confirm the right skill now fires.

## Closing the audit

Produce two artifacts for the user:

1. The inventory table with a verdict column — keep / fork / delete / test-later.
2. A count: how many skills before, how many after.

Then run the full one-job test on whatever landed in "test-later," one at a time, in the ranked order above. Do not batch them — each needs its own baseline and its own record.

---

<!-- ===== FILE: skill-one-job-test/assets/criteria-worksheet.md ===== -->

> **File:** `assets/criteria-worksheet.md`

# Criteria worksheet

Complete Part A **before** running anything. Complete Part B while reading the skill, still before running anything.

---

## Part A — What good looks like (step 2)

Write 3–5 criteria in your own words. The test for each: **could this come out false?** If not, rewrite it.

| # | Criterion | Could it fail? | Axis |
|---|-----------|----------------|------|
| 1 | | ☐ yes | |
| 2 | | ☐ yes | |
| 3 | | ☐ yes | |
| 4 | | ☐ yes | |
| 5 | | ☐ yes | |

**Axes to check if you are stuck** — hidden disagreement usually hides in one of these:

- **Taste** — palette, voice, density, formality
- **Scope** — how much it does without being asked
- **Done** — tests written? edge cases handled? deployed?
- **Tools** — which libraries or services it may reach for
- **Boundaries** — what it must ask before doing

Rejected phrasings, for calibration:

| Too soft | Falsifiable version |
|----------|---------------------|
| Looks professional | Palette avoids terracotta / maroon / warm neutrals |
| Well written | No sentence over 30 words; no em-dash lists |
| Production ready | Handles empty input and 500 responses without crashing |
| Doesn't overreach | Adds no npm dependency without asking first |

---

## Part B — What the skill decides for me (step 3)

Read the skill's `SKILL.md` and any bundled references. Hunt for what it **decides**, not what it does. One line each.

| Decision the skill makes | vs. my criteria |
|--------------------------|-----------------|
| Decides: | ☐ agrees ☐ conflicts ☐ unclear |
| Decides: | ☐ agrees ☐ conflicts ☐ unclear |
| Decides: | ☐ agrees ☐ conflicts ☐ unclear |
| Decides: | ☐ agrees ☐ conflicts ☐ unclear |
| Decides: | ☐ agrees ☐ conflicts ☐ unclear |

**Early exit:** if a decision hard-conflicts with the exact thing you installed the skill to fix, you already have your answer. Skip to the verdict and fork or delete.

**Judgment weight:** count the lines above that encode preference rather than procedure.

- Mostly procedure → mechanical skill, expect a short test
- Several preferences → judgment-carrying skill, run the full seven steps

---

<!-- ===== FILE: skill-one-job-test/assets/scorecard.csv ===== -->

> **File:** `assets/scorecard.csv`

```csv
criterion,axis,baseline_pass,with_skill_pass,notes
"<criterion 1 from worksheet Part A>",taste,,,
"<criterion 2>",scope,,,
"<criterion 3>",done,,,
"<criterion 4>",tools,,,
"<criterion 5>",boundaries,,,
```

---

<!-- ===== FILE: skill-one-job-test/assets/decision-card.md ===== -->

> **File:** `assets/decision-card.md`

# Verdict card — keep, fork, delete

Exactly one. Not "keep for now." An undecided test gets rerun from scratch later.

---

## KEEP

Both true:

- It won on criteria you care about
- It lost on **no** boundary criterion (tools, scope, what it does without asking)

Then: nothing further. Set a 90-day recheck on line 9.

---

## FORK

The usual outcome for judgment-carrying skills. Signal: the **mechanics** are good, the **taste** is not yours.

1. Copy the folder, rename it (`<name>-mine`) so upstream updates cannot collide
2. Rewrite only the Part B decision lines marked *conflicts* — keep the procedure, replace the preference
3. **Rerun the job against the fork and rescore.** A fork that has not been rerun is a hypothesis, not a fix
4. Record both the edits and the rerun score on line 9

---

## DELETE

Any of:

- It won on nothing you care about
- It lost a boundary criterion and the fix would not survive a rewrite
- You cannot remember it ever helping

Then: remove it. Reinstalling takes thirty seconds if you were wrong.

Delete is a **result**, not a failure of the test. A skill kept "just in case" still occupies a slot in the list the agent sees and still competes for triggers.

---

## Reading a mixed scorecard

Do not average it into a vibe. Which criteria moved matters more than how many.

| Pattern | Read |
|---------|------|
| Wins cosmetics, breaks a boundary | Worse trade than the tally suggests → fork or delete |
| Ties on count, fixes mechanics, misses taste | Classic fork |
| Wins everything | Keep |
| Every criterion passed in **both** runs | Criteria were too soft — rewrite Part A and rerun; this test proved nothing |
| Loses to the baseline outright | Delete |

---

## The loop to avoid

Installing another skill to fix bad output is the loop that produced the bad output.

Runtimes cap how much of the skill list the model sees and trim as it grows. Past roughly a dozen or two, descriptions compete, instructions get averaged, and the work gets duller than it was with a handful. Nothing warns you when this starts.

---

<!-- ===== FILE: skill-one-job-test/assets/test-record-blank.md ===== -->

> **File:** `assets/test-record-blank.md`

# Skill test: <skill-name>

<!--
Fill every line. A blank line means the test is not finished.
Save as skill-tests/<skill-name>-YYYY-MM-DD.md
-->

**1. Date tested:**

**2. Skill + source:**
<!-- name, where it came from, version or commit ref -->

**3. The one job:**

```
<the prompt, verbatim — the same string used for both runs>
```

**4. What good looks like:**
<!-- 3-5 criteria. Each must be able to come out FALSE. Written BEFORE any run. -->

- [ ]
- [ ]
- [ ]
- [ ]
- [ ]

**5. Baseline result (no skill):**
<!-- which criteria passed -->

**6. With-skill result:**
<!-- which criteria passed -->

**7. Where its judgment differed from mine:**
<!-- the decision lines from step 3 that conflicted with line 4 -->

-
-
-

**8. Verdict:** ☐ keep ☐ fork ☐ delete

<!-- one sentence of why -->

**9. What changed + recheck:**
<!-- edits made if forked, and the date to retest (90 days is a reasonable default;
     "n/a — removed" for deletes) -->

---

<!-- ===== FILE: skill-one-job-test/assets/library-inventory.csv ===== -->

> **File:** `assets/library-inventory.csv`

```csv
skill_name,source,last_used,carries_judgment,description_overlap,cost_if_wrong,test_priority,verdict
"<skill>","<url or marketplace>","never noticed it fire",yes/no,"<colliding skill names>",cosmetic/real,1-4,keep/fork/delete/test-later
```

---
