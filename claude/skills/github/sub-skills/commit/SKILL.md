---
name: github-commit
description: Sub-skill of `github`. Stage all changes, pull latest (resolving conflicts), commit with a conventional-commit message, and push. Honors the parent Output Contract.
---

# Operation: commit

**Goal.** Stage, pull, commit, push on the current branch. Obey the parent **Output Contract**:
silent run, errors as they occur, one concise summary. Do not ask for confirmation unless a
merge conflict or a sensitive-file warning forces a decision.

---

## Step 1 — Stage

```bash
git status --short
git add -A
```

If any staged path looks sensitive (`.env`, credentials, keys, tokens), **stop** and confirm
via `AskUserQuestion` before continuing.

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
