---
name: crlf-gitattributes-normalization
category: Code Quality
description: Use when a Windows/Linux-mixed repo shows spurious linter "Delete ␍" warnings, gofmt/prettier flags files as unformatted after a clean rebase, or golden-fixture tests fail on byte-exact CRLF-vs-LF comparisons — normalizes line endings via .gitattributes rather than reformatting or skipping tests.
status: active
version: 2026-07-05
---

# CRLF / .gitattributes Normalization

## When to use

- Linters (prettier, eslint, gofmt) report line-ending diffs ("Delete ␍" or "file not formatted") even though the file looks clean.
- A test does a byte-exact comparison against a golden fixture and fails only on Windows, or only after a fresh checkout.
- You're about to "fix" a formatting warning by re-running a formatter or skipping/guarding a test — stop and check whether it's actually a line-ending artifact first.

## Method

**1. Understand the mechanism.** Git stores blobs as LF internally. When `core.autocrlf=true` (common default on Windows), git rewrites LF → CRLF in the *working tree* on checkout. Linters and formatters that expect LF then see a working-tree file with CRLF and flag it — even though the committed blob is fine. This is a working-tree artifact, not a real content problem.

**2. Diagnose before "fixing."** Confirm the committed content is actually clean: `git show <file> | file -` should report the blob as ASCII/UTF-8 text with no CRLF mention (i.e., LF). If the blob is clean, the linter/formatter warning is harmless noise from the checked-out copy — do not reformat the file or add a test skip guard to appease it; that treats the symptom and leaves the root cause for the next person.

**3. Fix at the repo level with `.gitattributes`, not per-developer git config.**
- General source normalization, root-level `.gitattributes`:
  ```
  * text=auto eol=lf
  ```
- For golden/fixture files that must be byte-exact across platforms regardless of any local git config:
  ```
  **/**/testdata/**/*.txt text eol=lf
  ```
  This pins fixtures to LF explicitly, independent of `core.autocrlf`, so the fix is config-agnostic and lives in the repo (not in each contributor's global git config).

**4. Re-normalize the working tree after adding/changing the rule.**
- For a general normalization pass: `git checkout HEAD -- .` — this re-checks-out tracked files under the new `.gitattributes` rule, flipping CRLF back to LF in the working tree where applicable.
- For targeted fixture normalization: `git add --renormalize .` — restages files so their working-tree line endings match the newly declared attribute.
- Then re-run the linter/formatter/test to confirm it's now clean.

**5. Confirm idempotency.** This fix only touches the working tree, never the stored blobs (which were already LF). Re-running the checkout/renormalize step on an already-normalized tree is a safe no-op — verify this before considering the change "done" so CI re-runs don't churn.

## Gotchas

- Don't reformat a file or add a test skip/guard to work around a CRLF-vs-LF mismatch — check `git show <file> | file -` first; if the blob is already LF, the fix belongs in `.gitattributes`, not in the file or test.
- `* text=auto eol=lf` is a good general default but won't retroactively fix already-checked-out files — you must still re-checkout (`git checkout HEAD -- .`) or renormalize (`git add --renormalize .`) to apply it to the working tree.
- Fixture/golden-file tests need their own explicit `eol=lf` rule scoped to the fixture path — the general root-level rule may not be specific enough if fixtures live under a directory with different existing attributes.
- This is a repo-level, config-agnostic fix — avoid solving it via per-machine `git config core.autocrlf=false`, since that only fixes it for the one contributor who changes their config.

## Diagram

[View diagram](diagram.html)
