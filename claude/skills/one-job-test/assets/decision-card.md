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
