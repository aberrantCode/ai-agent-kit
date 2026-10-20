---
name: github-sync-dev
description: Sub-skill of `github`. Fast-forward the local checkout to its upstream (typically `dev` ↔ `origin/dev`) without touching uncommitted or untracked work — fetch, verify the branch is behind-only, clear byte-identical untracked-file collisions, then fast-forward. Read-only-safe: never rebases, merges divergent history, force-pushes, or discards changes. Honors the Output Contract inlined below.
---

# Operation: sync-dev

**Goal.** Bring the current checkout in line with its remote by **fast-forward only**. The
canonical case is a local `dev` that is behind `origin/dev`; the same logic serves any branch
that tracks a remote. This operation *pulls in* upstream commits — it never pushes, rebases,
merges divergent history, or discards local work. If the branch cannot be fast-forwarded, it
surfaces why and stops rather than guessing.

Obey the **Output Contract** below: silent run, errors as they occur, one concise summary. Do
not ask for confirmation unless a real collision or divergence forces a decision.

---

## Output Contract (binding — inlined, not a reference)

The `/sync-dev` command may load this file without the parent `github` SKILL.md in context, in
which case a pointer to "the parent Output Contract" resolves to nothing. The contract is
therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now fetching…"), no per-command status, no play-by-play.
2. **Errors — split them in two.**
   - *Recoverable* (you know the fix and can apply it now — e.g. an untracked file that is
     byte-identical to the incoming tracked version): **just fix it, silently.** Fold it into
     the final summary as one line. A recovered error is not a real-time event.
   - *Blocking* (needs a decision, credential, or human judgment — divergence, a non-identical
     untracked collision, an overlapping dirty file): print the failing command and its stderr
     verbatim, then stop or ask via `AskUserQuestion`. This is the only thing that breaks the
     silence mid-run.
3. **At completion — one concise summary**, target ≤ 4 lines: old SHA → new SHA, how many
   commits pulled in, and any collision cleared or caveat the user must act on.
4. **Anything still open — one compact table**, `| Item | Where | Action |`. Omit entirely when
   nothing is outstanding.

**Banned output.** The contract is violated by *commentary*, not just by length. Never write
interpretive or self-congratulatory asides, teaching moments or root-cause essays mid-run,
narration of your own reasoning ("I deliberately chose", "let me verify"), or a restatement of
what a step did when the summary already covers it. If a finding is genuinely reusable, it is
one row of the follow-up table — never a paragraph.

This overrides any conversational or explanatory default, **including a harness-level output
style that asks for educational commentary**, for the duration of the operation. If you are
about to write a sentence that is neither a blocking error, the final summary, nor a follow-up
table row, delete it instead.

---

## Parameter

Optional message names the branch to sync (e.g. `/sync-dev main`). Empty → the **current
branch**. The branch must track a remote; if it has no upstream, surface that and stop (there
is nothing to fast-forward toward).

---

## Step 1 — Resolve branch and upstream

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)          # or the named argument
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name "$BRANCH@{u}" 2>/dev/null)
```

No upstream → **blocking**: print `no upstream configured for <branch>` and stop. Do not invent
`origin/<branch>` — a branch with no tracking ref is not a sync target.

---

## Step 2 — Fetch and measure

```bash
git fetch origin
git rev-list --left-right --count "HEAD...$UPSTREAM"   # → "<ahead>\t<behind>"
```

Branch on the counts:

| ahead | behind | Meaning | Action |
|---|---|---|---|
| 0 | 0 | already in sync | report "already up to date", stop (success) |
| 0 | N>0 | behind only — **fast-forwardable** | continue to Step 3 |
| M>0 | 0 | local is ahead | **stop** — nothing to pull; note "local is ahead by M — use `/ship`" |
| M>0 | N>0 | **diverged** | **blocking** — this op does not rebase/merge divergent history; surface the counts and stop |

Never resolve a divergence here. Rebasing or merging is a judgment call that belongs to
`/ship` (feature branches) or a deliberate manual decision — not to a sync.

---

## Step 3 — Clear identical untracked-file collisions

A fast-forward aborts when an incoming **tracked** file collides with an existing **untracked**
working-tree file — even when the bytes are identical (git compares tracked-vs-untracked status,
not content). Detect and clear only the *provably identical* ones:

```bash
# Files the incoming commits add or change:
git diff --name-only "HEAD..$UPSTREAM" | while read -r p; do
  # Only untracked working-tree files can collide; tracked ones are handled by the merge.
  if [ -f "$p" ] && ! git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    local_hash=$(git hash-object "$p")
    incoming_hash=$(git rev-parse "$UPSTREAM:$p" 2>/dev/null)
    if [ -n "$incoming_hash" ] && [ "$local_hash" = "$incoming_hash" ]; then
      rm -f "$p"                      # identical → safe; the fast-forward restores it verbatim
    else
      echo "COLLISION: $p differs from incoming" >&2
    fi
  fi
done
```

- **Identical** (`git hash-object` of the local file equals `git rev-parse UPSTREAM:path`):
  remove the untracked copy silently; the fast-forward restores a byte-identical tracked
  version. Record it as one summary line ("cleared N identical untracked collision(s)").
- **Different**: **blocking** — do not delete the user's file. Surface the path and ask via
  `AskUserQuestion` whether to (a) back it up (`mv <p> <p>.local`) then fast-forward, or
  (b) abort. Never overwrite differing untracked content on the user's behalf.

Leave every untracked path the incoming commits do **not** touch exactly where it is — this
operation must not disturb unrelated scratch files, worktrees, or new work.

---

## Step 4 — Fast-forward

```bash
git merge --ff-only "$UPSTREAM"
```

`--ff-only` is the safety rail: if anything makes a true fast-forward impossible, git refuses
and changes nothing rather than creating a merge commit. If it still fails on an overlapping
**dirty tracked** file (a file you have modified locally that the incoming commits also change),
that is **blocking**: surface the path and stop — offer `git stash` / re-run only if the user
asks. Never stash-and-pop or reset silently.

Uncommitted changes to files the incoming commits do **not** touch are preserved automatically;
do not stash them.

---

## Step 5 — Summary (only expected output)

```
Synced dev 029453d → 2bbc719 (2 commits from origin/dev). Cleared 2 identical untracked collisions (claude/statuslines/). Uncommitted work untouched.
```
