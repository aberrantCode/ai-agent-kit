---
name: github-commit
description: >
  Sub-skill of `github`. Stage all changes, pull latest (resolving conflicts), commit with a
  conventional-commit message, and push. Triggers on "commit this", "commit and push", "save my
  changes". Honors the Output Contract inlined below.
---

# Operation: commit

**Goal.** Stage, pull, commit, push on the current branch. Obey the **Output Contract** below:
silent run, errors as they occur, one concise summary. Do not ask for confirmation unless a
merge conflict or a sensitive-file warning forces a decision.

---

## Output Contract (binding — inlined, not a reference)

The `/commit` command may load this file without the parent `github` SKILL.md in
context, in which case a pointer to "the parent Output Contract" resolves to
nothing. The contract is therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now committing…"), no per-command status, no play-by-play.
2. **Errors — split them in two.**
   - *Recoverable* (you know the fix and can apply it now): **just fix it, silently.** Fold it
     into the final summary as one line. A recovered error is not a real-time event.
   - *Blocking* (needs a decision, credential, or human judgment): print the failing command
     and its stderr verbatim, then stop or ask via `AskUserQuestion`. This is the only thing
     that breaks the silence mid-run.
3. **At completion — one concise summary**, target <= 4 lines: what landed, where (PR #, SHA,
   tag, branch), and any caveat the user must act on.
4. **Anything still open — one compact table**, `| Item | Where | Action |`. Omit entirely when
   nothing is outstanding.

**Banned output.** The contract is violated by *commentary*, not just by length. Never write
interpretive or self-congratulatory asides ("the gate earned its keep", "exactly as predicted",
"worth noting", "the interesting part is"), teaching moments or root-cause essays mid-run,
narration of your own reasoning ("I deliberately chose", "my prediction was", "let me verify"),
or a restatement of what a step did when the summary already covers it. If a finding is
genuinely reusable, it is one row of the follow-up table — never a paragraph.

This overrides any conversational or explanatory default, **including a harness-level output
style that asks for educational commentary**, for the duration of the operation. If you are
about to write a sentence that is neither a blocking error, the final summary, nor a
follow-up table row, delete it instead.

---

## Step 1 — Stage

```bash
git status --short
git add -A
```

If any staged path looks sensitive (`.env`, credentials, keys, tokens), **stop** and confirm
with the user — ask a plain, concise question and wait for the answer — before continuing.

---

## Step 2 — Pull latest

```bash
git pull --no-rebase
```

On merge conflict: list conflicted files (`git diff --diff-filter=U`), read each, resolve
keeping the most complete/correct version (prefer incoming for new features, local for
in-progress work), `git add` the resolved files. On any other pull failure (no remote, diverged
history), surface the error and stop — never force-push or reset.

---

## Step 3 — Commit

Draft a conventional-commit message from the staged diff (`type: subject`, subject < 72 chars,
optional 2–4 bullet body). Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`.

```bash
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```

---

## Step 4 — Push

```bash
git push
```

If rejected as non-fast-forward, surface the error and stop — do not force-push.

---

## Step 5 — Summary (only expected output)

```
Committed abc1234 "fix: …" and pushed. 4 files, 1 conflict resolved.
```
