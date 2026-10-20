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
