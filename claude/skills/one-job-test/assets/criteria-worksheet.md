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
