---
name: claim-discipline
category: Foundations & Workflow
description: Use when about to state a checkable claim as fact — a file path, a line number, a count ("appears N times", "2 stale branches"), a quote ("the rule says X"), or "file Y contains / lacks Z". Verify it with a tool call in the same turn, or hedge it ("I believe", "likely") or omit it — never assert it flat. Separates verifiable facts from judgment calls so assertions about a user's own config, code, or repo state are not fabricated. Triggers whenever a response cites a location, count, or quote the user could check.
status: active
version: 2026-07-28
---

# Claim Discipline

## When to use

Any time a response is about to assert something as fact that a tool call could
confirm or refute — most dangerously, a claim about the user's own files, config,
counts, or repo state. This is the class of error that reads as authoritative
("your rules say this twice, in `hooks.md` and `performance.md`") while being
false, because the claim *names its own verification target* and still skipped the
check. A wrong citation about someone's own setup erodes trust in every other
claim in the response.

Use it before citing a path, a line number, a count, a quotation, or a
presence/absence ("file X contains Y"), and before escalating a "conflict" or
"blocker" to the user.

## Method

1. **Spot the checkable claim.** A claim is *checkable* when a single tool call
   this turn could confirm or refute it: a file path, a line number, a count
   ("appears N times", "2 branches"), a quote ("the rule says X"), or "file Y
   contains / lacks Z". If it names a location, count, or quotation, it is
   checkable — the claim points at its own test.

2. **Run the check before asserting.** Use `grep` / `read` / `glob` (or the
   stack's equivalent) to confirm it. The cost of one grep is lower than the cost
   of one false citation. Verify through the primary source, not a second copy of
   the same claim (don't re-read a memory note as "proof" of itself — hit the live
   file, the live remote, the live count).

3. **Separate fact from judgment.** "The rules mention this twice" is a *fact* —
   verify it. "This is a genuine conflict, your call" is a *judgment* — label it
   as your read, and first check whether the artifact already resolves the tension
   before escalating. A `read` of the thing you're calling contradictory often
   shows it isn't.

4. **State, hedge, or drop.** Verified → state it plainly. Not verified and you
   won't/can't check → either omit it or mark it explicitly unverified ("I
   believe", "likely", "unconfirmed"). Never state an unchecked checkable claim in
   the flat, confident register reserved for verified facts.

## Gotchas

- **The tell is self-identifying.** If you can name the file, line, count, or
  quote, you can open it. "I'd have to check" is the signal to check, not to
  assert-and-hope.
- **Counts are the sharpest trap.** "2 stale branches", "mentioned twice",
  "three callers" — a number invites precision it may not have. Verify the number
  or omit it; never round-guess a count into a factual sentence.
- **Judgment laundered as fact.** Escalating "there's a genuine conflict / your
  call, not mine" *feels* like deference, but if a `read` would have shown the
  artifact resolves itself, the escalation was a fabricated conflict. Check the
  source before handing the user a decision that isn't real.
- **No hook can enforce this.** The harness gates tool *calls*; it cannot evaluate
  whether a sentence is true. "Appears twice" has no signature a matcher can catch.
  This is a behavioral discipline, not something to delegate to automation.
- **Verify through a different channel than produced the claim.** A stale note and
  a stale cache agree with each other; only the live system is authoritative.
  (Shared boundary with `stale-symbolic-ref-detection-and-repair`, which applies
  the same rule to remembered references before destructive operations.)

## Diagram

[View diagram](diagram.html)
