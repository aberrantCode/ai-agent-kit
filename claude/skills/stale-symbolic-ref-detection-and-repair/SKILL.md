---
name: stale-symbolic-ref-detection-and-repair
category: Foundations & Workflow
description: Use when a script, agent, or session is about to act on a remembered reference — a git default branch, a cached IP/credential, an "SSH is broken" note in memory — before any destructive or high-stakes operation. Verifies the reference against live state instead of trusting the cache.
status: active
version: 2026-07-05
---

# Stale Symbolic Ref Detection and Repair

## When to use

Any time you are about to rely on a previously-recorded pointer to "the truth" — a git
remote's default branch, a session-memory note about network/auth state, a cached
credential location — and the action that follows is destructive or hard to undo
(a release, a force-push, a delete, a migration). Cached references rot silently:
branches get deleted, IPs change, credentials get rotated, SSH configs get fixed.
Treat any such reference as a hypothesis to verify, not a fact to act on.

## Method

1. **Identify the reference being trusted.** Examples: `git symbolic-ref refs/remotes/origin/HEAD`
   (which branch is "default"), a MEMORY.md line like "SSH is unauthorized, use XPipe",
   a hardcoded IP or credential path noted in an earlier session.

2. **Verify against live state before acting**, using an empirical check that doesn't
   depend on the cached claim:
   - Git default branch: confirm the branch actually exists remotely with
     `git ls-remote --heads origin <branch>`. Don't trust `symbolic-ref` output alone —
     it can point to a branch that was since deleted.
   - Network/auth claims ("SSH is unauthorized"): re-derive the answer from primary
     sources instead of the note — check whether the key is actually present in
     `authorized_keys`, attempt the SSH connection empirically from the workstation,
     and read the `sshd` logs for the real refusal reason (could be `StrictModes`,
     could be IP allowlisting, could be nothing — it may just work now).

3. **If the reference is wrong, repair it at the source, not just in the moment:**
   - Git: `git remote set-head origin -a` to auto-detect the correct default branch,
     or `git remote set-head origin <branch>` to set it explicitly.
   - Memory files: update `MEMORY.md` (or equivalent) immediately with the verified
     ground truth, replacing the stale claim rather than leaving both versions to
     conflict later.

4. **Gate destructive operations on verification having happened.** For releases,
   force-pushes, or bulk deletes, treat "detected branch/target exists and matches
   live state" as a precondition, not an assumption. If detection returns something
   that doesn't verify, stop and repair before proceeding — never guess-continue.

## Gotchas

- `symbolic-ref` and similar caches can silently point at a deleted or renamed target;
  the command succeeding does not mean the target is valid.
- Session memory is a snapshot of a moment in time — it goes stale the instant the
  underlying system changes (key rotated, branch deleted, firewall rule edited).
  A note being old is reason enough to re-verify, not reason to distrust it outright.
- Verification must use a different information channel than the one that produced
  the stale claim (e.g., don't re-read the same memory file as "proof" — hit the live
  system: `ls-remote`, an actual SSH attempt, `sshd` logs).
- Once verified (right or wrong), write the ground truth back immediately. An
  unresolved discrepancy between memory and reality is a blocker for any subsequent
  destructive step, not a minor inconsistency to shrug off.

## Diagram

[View diagram](diagram.html)
