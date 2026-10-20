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
