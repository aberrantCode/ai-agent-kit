---
name: ship-to-dev
description: Use when the user wants to ship current working changes through a feature branch PR into the DEV branch — covers pulling latest, staging, committing, pushing, PR creation, merge, branch cleanup, and syncing DEV locally.
---

# Ship to DEV

Automates the full feature-branch → DEV merge workflow for this repository.
Run this whenever you have uncommitted work ready to integrate into DEV, **or**
when you already have a committed feature branch that just needs to be pushed,
PR'd, and merged.

---

## Prerequisites: Ensure DEV Exists

Before starting the main workflow, confirm `dev` exists on the remote.
If it does not, create it from `main` now:

```bash
# Check whether dev exists on origin
git ls-remote --heads origin dev

# If nothing was returned — create it:
git fetch origin main
git checkout -b dev origin/main
git push -u origin dev
git checkout main   # return to main (or wherever you were)
```

> If `dev` already exists, skip this block entirely.

---

## Timing Setup (run before Step 0)

Initialize the timing log before any other commands. Shell state does not persist
between Bash invocations, so timestamps are written to a temp file that accumulates
across the workflow:

```bash
mkdir -p /tmp
# Derive the timing log filename from the repo directory name so it is
# unique per project and not confused with artefacts from other solutions.
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
TIMING_TMP="/tmp/${REPO_NAME}_timing.log"
echo "" > "$TIMING_TMP"   # truncate/create for this run
echo "workflow_start $(date +%s%3N)" >> "$TIMING_TMP"
```

---

## Workflow

Follow every step in order. Do not skip steps, do not reorder them.

### Step 0 — Detect context and resolve the repo root

Before anything else, determine where you are and whether the work is already committed.

```bash
echo "step_detect_start $(date +%s%3N)" >> "$TIMING_TMP"
```

**Resolve the repo root** — all git/gh commands in Steps 5–9 must run from the repo root,
never from inside a worktree subdirectory:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
echo "Repo root: $REPO_ROOT"
```

**Check for an active worktree** — if the current directory is inside a git worktree that
is *not* the primary checkout, record the worktree path for cleanup in Step 9:

```bash
WORKTREE_PATH=$(git rev-parse --show-toplevel)
PRIMARY_ROOT=$(git worktree list --porcelain | awk 'NR==1{print $2}')
# If they differ, we are inside a secondary worktree
[ "$WORKTREE_PATH" != "$PRIMARY_ROOT" ] && IN_WORKTREE=true || IN_WORKTREE=false
echo "In secondary worktree: $IN_WORKTREE"
```

**Detect pre-committed branch** — if the current branch already has commits ahead of `dev`
and is not `dev` itself, the work is already committed. Skip Steps 1–4 (Ask for branch/commit info, Pull latest if behind, Stage all changes, Test suite and coverage gate) and jump to Step 5:

```bash
CURRENT_BRANCH=$(git branch --show-current)
AHEAD=$(git rev-list origin/dev..HEAD --count 2>/dev/null || echo 0)
echo "Current branch: $CURRENT_BRANCH  Commits ahead of dev: $AHEAD"
```

- If `$CURRENT_BRANCH` is not `dev` and `$AHEAD > 0` → set `$BRANCH=$CURRENT_BRANCH`,
  infer `$MSG` from the most recent commit subject (`git log -1 --format=%s`), then
  **skip Steps 1–3 (Ask for branch/commit info, Pull latest if behind, Stage all changes)**, jumping to Step 4 (still run the test/coverage gate before pushing).
- Otherwise → continue to Step 1 as normal.

**Dirty working-tree check** — count uncommitted files and surface them. In pre-committed
mode they would be silently left behind; in normal mode Step 3's `git add --all` would
sweep them in. Either way, the user must see what's there:

```bash
DIRTY_COUNT=$(git status --short | grep -c . || true)
if [ "$DIRTY_COUNT" -gt 0 ]; then
  echo ""
  echo "Working tree is dirty — $DIRTY_COUNT uncommitted file(s):"
  git status --short | head -20
  [ "$DIRTY_COUNT" -gt 20 ] && echo "  ... and $((DIRTY_COUNT - 20)) more"
  echo ""
fi
```

- **Pre-committed mode AND `$DIRTY_COUNT > 0`** → the dirty files would NOT ship. Use
  **AskUserQuestion** to confirm the user actually wants this:

  ```
  AskUserQuestion(
    questions: [{
      question: "Branch $CURRENT_BRANCH has $AHEAD commit(s) ahead of dev, and $DIRTY_COUNT uncommitted file(s) in the working tree. How should I proceed?",
      header: "Pre-committed",
      options: [
        { label: "Ship only the committed work", description: "Skip Steps 1–3; the dirty files stay behind on this branch" },
        { label: "Include the dirty files as a new commit", description: "Run Steps 1–3 first to add them to this branch before pushing" },
        { label: "Abort", description: "Stop the workflow — let me sort out the working tree first" }
      ]
    }]
  )
  ```

  - "Ship only" → continue with Step 4.
  - "Include" → un-set the pre-committed shortcut and continue with Step 1 as normal.
  - "Abort" → stop the workflow.

- **Normal mode AND `$DIRTY_COUNT > 0`** → defer the gate to Step 3, which will list
  the files and ask for confirmation when the count is high.

```bash
echo "step_detect_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 1 — Ask the user for a branch name and commit message

Before touching git, collect `$BRANCH` and `$MSG`.

If the user has already provided both in their message, use those values directly — do not ask again.

Otherwise, infer up to two suggested values each from the staged/unstaged diff and recent commits, then use **AskUserQuestion** with those suggestions as options (the tool automatically appends an "Other" option for free-text input):

```
AskUserQuestion(
  questions: [
    {
      question: "What should the feature branch be called?",
      header: "Branch name",
      options: [
        { label: "fix/autologon-reboot-privacy-screen", description: "Inferred from changes" },
        { label: "feat/my-feature", description: "Alternative suggestion" }
      ]
    },
    {
      question: "What is the commit message?",
      header: "Commit msg",
      options: [
        { label: "fix: reboot instead of logoff and suppress OOBE privacy screen", description: "Inferred from changes" },
        { label: "feat: describe the change", description: "Alternative suggestion" }
      ]
    }
  ]
)
```

Branch format: `<type>/<short-slug>` — types mirror conventional commits (`feat`, `fix`, `refactor`, `docs`, `chore`).
Commit format: conventional commit (`feat:`, `fix:`, `refactor:`, etc.).

Store answers as `$BRANCH` and `$MSG` for the rest of the steps.

---

### Step 2 — Pull latest on the current branch (only if behind)

```bash
echo "step_pull_start $(date +%s%3N)" >> "$TIMING_TMP"
```

First fetch and check whether the current branch is behind its remote — skip the pull entirely if there is nothing to integrate:

```bash
git fetch origin
BEHIND=$(git rev-list HEAD..origin/$(git branch --show-current) --count 2>/dev/null || echo 0)
echo "Commits behind remote: $BEHIND"
```

**If `$BEHIND` is 0** — nothing to pull. Skip the rest of this step and continue to Step 3.

**If `$BEHIND` > 0** — stash everything (tracked and untracked), pull, then restore:

```bash
git stash --include-untracked
git pull --rebase
git stash pop
```

If rebase produces conflicts after the pull:
1. Show the conflicting files with `git status`.
2. Resolve obvious ones (whitespace, generated files) yourself. For non-obvious conflicts, use **AskUserQuestion**:
   ```
   AskUserQuestion(
     questions: [{
       question: "There are merge conflicts in <files>. How would you like to proceed?",
       header: "Conflicts",
       options: [
         { label: "I'll resolve manually", description: "Pause here — you fix the files, then tell me to continue" },
         { label: "Abort the rebase", description: "Run git rebase --abort and stop the workflow" }
       ]
     }]
   )
   ```
3. After resolution: `git add <resolved-files>` then `git rebase --continue`.
4. If the rebase is unresolvable, abort with `git rebase --abort` and stop.

```bash
echo "step_pull_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 3 — Stage changes (preview, then add)

```bash
echo "step_stage_start $(date +%s%3N)" >> "$TIMING_TMP"
```

**Never run `git add --all` blind.** The working tree often contains pre-existing WIP from
other sessions, debug edits, or unrelated branches — sweeping all of it into one commit is
the most destructive thing this workflow can do. Preview first, then decide.

**Preview what would be staged:**

```bash
git status --short
git diff --stat
TO_STAGE=$(git status --short | grep -c . || true)
echo "Would stage $TO_STAGE file(s)."
```

If `$TO_STAGE` is 0 → stop and tell the user there is nothing to ship.

**Decision:**

- **`$TO_STAGE` ≤ 10 AND the file list visibly relates to what was discussed in this
  session** → proceed with `git add --all`. State briefly which files are being staged
  and why they belong together.

- **`$TO_STAGE` > 10, OR the list contains files not touched in this session, OR you
  cannot account for any single path** → stop and use **AskUserQuestion**:

  ```
  AskUserQuestion(
    questions: [{
      question: "Staging would sweep $TO_STAGE file(s). Some may not belong to this PR. How should I proceed?",
      header: "Staging",
      options: [
        { label: "Stage everything (`git add --all`)", description: "All $TO_STAGE files go into one commit" },
        { label: "Stage a specific subset", description: "I'll tell you which paths/globs to add" },
        { label: "Abort — let me clean up the working tree first", description: "Stop the workflow" }
      ]
    }]
  )
  ```

  - "Stage everything" → `git add --all`.
  - "Stage subset" → ask the user for the path/glob list, then `git add <paths>`. Re-run
    `git status --short` and `git diff --cached --stat` so the user can confirm.
  - "Abort" → stop the workflow.

**After staging — final summary before commit:**

```bash
git status --short
git diff --cached --stat
```

If the staging area is empty after all that (e.g. user picked a subset that matched nothing),
stop and tell the user.

```bash
echo "step_stage_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 4 — Test suite and coverage gate

**This step is mandatory for both new and pre-committed branches. Never skip it.**

Before committing (or before pushing, for pre-committed branches), verify the full test
suite passes and that every changed source file has a corresponding test and meets 80 % coverage.

---

#### 4-A  Identify changed source files

For **uncommitted work** (arriving from Step 3 with `git add --all` already done):

```bash
CHANGED_FILES=$(git diff --cached --name-only)
```

For **pre-committed branches** (branch already ahead of `dev`):

```bash
CHANGED_FILES=$(git diff origin/dev...HEAD --name-only)
```

Categorise by stack — these patterns target a specific monorepo layout (`api/src/`,
`web/src/`, `extension/src/`). They are intentionally narrow; an empty result just means
"this repo isn't that layout, skip the per-stack gates":

```bash
API_SRC=$(echo "$CHANGED_FILES" | grep '^api/src/'       | grep '\.py$'        || true)
WEB_SRC=$(echo "$CHANGED_FILES" | grep '^web/src/'       | grep -E '\.[jt]sx?$' || true)
EXT_SRC=$(echo "$CHANGED_FILES" | grep '^extension/src/' | grep -E '\.[jt]sx?$' || true)
```

- If a stack variable is non-empty → run its per-stack checks (4-C, 4-D, 4-E sections).
- If **all three are empty** → the repo doesn't match this layout (e.g. it's an Ansible
  / infra / docs / tooling repo). Skip 4-C, 4-D, and the per-stack parts of 4-E. The
  whole-repo runner in 4-B is still mandatory and will pick the right tool for the repo.

---

#### 4-B  Run the project test runner

The runner is detected from the repo, not hardcoded. First match wins; later matches
are ignored. If nothing matches, the gate is skipped with a notice — explicit so the
user knows no automated check ran.

```bash
echo "step_tests_start $(date +%s%3N)" >> "$TIMING_TMP"

TEST_EXIT=0
RUNNER="(none detected)"

if [ -f "$REPO_ROOT/scripts/Start-Tests.ps1" ]; then
  RUNNER="pwsh Start-Tests.ps1"
  TIMING_LOG_PS=$(cygpath -w "$REPO_ROOT/logs/timing.jsonl" 2>/dev/null || echo "$REPO_ROOT/logs/timing.jsonl")
  pwsh -NonInteractive -File "$REPO_ROOT/scripts/Start-Tests.ps1" -NoPrompt -Parallel -SkipE2E -TimingLog "$TIMING_LOG_PS"
  TEST_EXIT=$?

elif [ -f "$REPO_ROOT/Makefile" ] && grep -qE '^test:' "$REPO_ROOT/Makefile"; then
  RUNNER="make test"
  ( cd "$REPO_ROOT" && make test )
  TEST_EXIT=$?

elif [ -f "$REPO_ROOT/package.json" ] && grep -qE '"test"[[:space:]]*:' "$REPO_ROOT/package.json"; then
  RUNNER="npm test"
  ( cd "$REPO_ROOT" && npm test )
  TEST_EXIT=$?

elif [ -d "$REPO_ROOT/playbooks" ] && command -v ansible-playbook >/dev/null 2>&1; then
  # Ansible / infra repo: syntax-check only the playbooks that changed in this branch.
  PLAYBOOKS_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^playbooks/.*\.ya?ml$' || true)
  if [ -n "$PLAYBOOKS_CHANGED" ]; then
    RUNNER="ansible-playbook --syntax-check (changed playbooks)"
    while IFS= read -r pb; do
      [ -z "$pb" ] && continue
      ( cd "$REPO_ROOT" && ansible-playbook --syntax-check "$pb" ) || TEST_EXIT=$?
    done <<< "$PLAYBOOKS_CHANGED"
  else
    RUNNER="ansible repo, no playbooks changed — nothing to check"
  fi

elif command -v pytest >/dev/null 2>&1 && { [ -f "$REPO_ROOT/pytest.ini" ] || [ -f "$REPO_ROOT/pyproject.toml" ] || [ -d "$REPO_ROOT/tests" ]; }; then
  RUNNER="pytest"
  ( cd "$REPO_ROOT" && pytest )
  TEST_EXIT=$?

else
  echo "[Step 4-B] No recognized test runner — skipping the test gate."
  echo "  Looked for, in order:"
  echo "    scripts/Start-Tests.ps1"
  echo "    Makefile with a 'test:' target"
  echo "    package.json with a 'test' script"
  echo "    playbooks/ + ansible-playbook on PATH"
  echo "    pytest + (pytest.ini | pyproject.toml | tests/)"
  echo "  If this repo has tests run a different way, add a Makefile 'test:' target"
  echo "  or a 'test' script in package.json so this gate can find them."
fi

echo "step_tests_end $(date +%s%3N)" >> "$TIMING_TMP"
echo "[Step 4-B] runner: $RUNNER  exit: $TEST_EXIT"
[ $TEST_EXIT -ne 0 ] && exit $TEST_EXIT
```

**If `$TEST_EXIT` is non-zero — STOP.** Do not proceed. Echo the runner output to the
user and ask them to fix the failures before retrying `/ship-to-dev`.

**If the runner was skipped ("none detected") — proceed, but state explicitly that
no automated test gate ran for this repo.** The user can then decide whether to ship
without one.

---

#### 4-C  Verify test files exist for every changed source file

For each file in `$API_SRC`, `$WEB_SRC`, and `$EXT_SRC`, check that at least one
corresponding test file exists. Apply these mapping rules:

| Stack | Source path pattern | Expected test location(s) |
|---|---|---|
| API (Python) | `api/src/<pkg>/<module>.py` | `api/tests/unit/<pkg>/test_<module>.py` **or** `api/tests/unit/test_<module>.py` |
| Web (TS) | `web/src/<path>/<Component>.tsx` | `web/src/__tests__/<Component>.test.tsx` **or** `web/src/<path>/__tests__/<Component>.test.tsx` |
| Extension (TS) | `extension/src/<path>/<file>.ts` | `extension/src/__tests__/<file>.test.ts` **or** `extension/src/<path>/__tests__/<file>.test.ts` |

Check each file with `test -f <expected-path>` (or equivalent). Collect every source
file that has **no matching test file** into `$MISSING_TESTS`.

If `$MISSING_TESTS` is non-empty — **STOP.** List the missing test files and tell the
user they must be created before shipping:

```
MISSING TEST FILES — create these before proceeding:
  api/tests/unit/foo/test_bar.py  ←  covers api/src/foo/bar.py
  web/src/__tests__/MyComponent.test.tsx  ←  covers web/src/components/MyComponent.tsx
```

---

#### 4-D  Verify ≥ 80 % coverage for changed source files

```bash
echo "step_coverage_start $(date +%s%3N)" >> "$TIMING_TMP"
```

Run targeted coverage checks only for the stacks that have changed source files.
Do **not** re-run the entire test suite — use focused runs against only the relevant
test directories.

**Python (API) — if `$API_SRC` is non-empty:**

```bash
cd "$REPO_ROOT/api"

# Build --cov flags for changed source files (convert file paths to module paths)
COV_FLAGS=$(echo "$API_SRC" | sed 's|api/||;s|/|.|g;s|\.py$||' | xargs -I{} echo "--cov={}")

uv run pytest tests/unit tests/integration \
  $COV_FLAGS \
  --cov-report=json \
  --cov-fail-under=0 \
  -q 2>&1

# Parse coverage.json for per-file percentages
python - "$API_SRC" <<'PYEOF'
import json, sys, os

with open('coverage.json') as f:
    data = json.load(f)

# Build a normalised lookup: absolute path → percent_covered
lookup = {}
for fpath, fdata in data['files'].items():
    lookup[os.path.normpath(fpath)] = fdata['summary']['percent_covered']

failures = []
for src_file in sys.argv[1].split():
    src_file = src_file.strip()
    if not src_file:
        continue
    # coverage.json keys are relative to the api/ dir
    rel = src_file.replace('api/', '', 1)
    pct = lookup.get(os.path.normpath(rel), None)
    if pct is None:
        print(f"  WARN: {src_file} not found in coverage report")
    elif pct < 80:
        failures.append((src_file, pct))
    else:
        print(f"  OK  {src_file}: {pct:.1f}%")

if failures:
    for f, p in failures:
        print(f"  FAIL {f}: {p:.1f}%  (need >= 80%)")
    sys.exit(1)
PYEOF
COV_EXIT=$?
```

If `$COV_EXIT` is non-zero — **STOP.** List the under-covered files and tell the user
to add tests before retrying.

**TypeScript — Web (if `$WEB_SRC` non-empty) and Extension (if `$EXT_SRC` non-empty):**

Run each separately from its own directory:

```bash
# Web
cd "$REPO_ROOT/web"
npx vitest run --coverage --reporter=verbose 2>&1 | tee /tmp/web-coverage.txt

# Extension
cd "$REPO_ROOT/extension"
npx vitest run --coverage --reporter=verbose 2>&1 | tee /tmp/ext-coverage.txt
```

After each run, inspect the coverage summary table printed to stdout. Lines look like:

```
 % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s
   85.71 |    75.00 |   100.0 |   85.71 | 12-14
```

For each file in `$WEB_SRC` / `$EXT_SRC`, find its entry in the summary. If the
**Statements** percentage is below 80 — **STOP** and list the under-covered files.

If vitest generates a `coverage/coverage-summary.json` (Istanbul/v8 reporter), parse
it directly:

```bash
python - "$WEB_SRC" "$EXT_SRC" <<'PYEOF'
import json, sys, os

def check_file(summary_path, src_files):
    if not os.path.exists(summary_path):
        return []
    with open(summary_path) as f:
        data = json.load(f)
    failures = []
    for src in src_files.split():
        src = src.strip()
        if not src:
            continue
        for key in data:
            if key.endswith(src.lstrip('/')):
                pct = data[key]['statements']['pct']
                if pct < 80:
                    failures.append((src, pct))
                else:
                    print(f"  OK  {src}: {pct:.1f}%")
                break
        else:
            print(f"  WARN: {src} not found in coverage summary")
    return failures

web_failures = check_file('web/coverage/coverage-summary.json', sys.argv[1])
ext_failures = check_file('extension/coverage/coverage-summary.json', sys.argv[2])
all_failures = web_failures + ext_failures

if all_failures:
    for f, p in all_failures:
        print(f"  FAIL {f}: {p:.1f}%  (need >= 80%)")
    sys.exit(1)
PYEOF
```

If any TS files are below 80 % — **STOP** and require tests before proceeding.

---

#### 4-E  Clean build gate — lint, type-check, and build warnings

```bash
echo "step_coverage_end $(date +%s%3N)" >> "$TIMING_TMP"
echo "step_lint_start $(date +%s%3N)" >> "$TIMING_TMP"
```

**This sub-step runs for every changed stack, no exceptions.**

The goal is to confirm that the branch introduces **zero new lint errors, zero new type errors outside generated code, and no new build warnings** beyond the pre-existing baseline documented in `CLAUDE.md`.

---

**Python (API) — if `$API_SRC` is non-empty:**

```bash
cd "$REPO_ROOT"

# Ruff: must be zero errors
uv run ruff check api/src
RUFF_EXIT=$?

# Mypy: zero errors outside generated code
uv run mypy api/src --exclude api/src/generated
MYPY_EXIT=$?
```

If `$RUFF_EXIT` is non-zero — **STOP.** Show the ruff output and require the errors to be fixed.

If `$MYPY_EXIT` is non-zero — check whether every error path is in `api/src/generated/`. If any error is outside `generated/`, **STOP** and require a fix. Errors strictly inside `generated/` are pre-existing (see CLAUDE.md) and do not block shipping.

---

**Web (TypeScript + ESLint + build) — if `$WEB_SRC` is non-empty:**

```bash
cd "$REPO_ROOT/web"

# ESLint: zero errors (warnings are checked against pre-existing list)
npm run lint 2>&1 | tee /tmp/web-lint.txt
LINT_EXIT=$?

# TypeScript
npm run type-check 2>&1 | tee /tmp/web-typecheck.txt
TSC_EXIT=$?

# Production build (captures Vite warnings)
npm run build 2>&1 | tee /tmp/web-build.txt
BUILD_EXIT=$?
```

**If `$LINT_EXIT` is non-zero** — inspect `/tmp/web-lint.txt`. For each error or warning:
- If the file is NOT in the pre-existing debt list in `CLAUDE.md` → **STOP**, require a fix.
- If the file IS in the pre-existing list and the issue is the same known one → acceptable, note it but continue.
- If the file is in the pre-existing list but the issue is NEW → **STOP**, require a fix.

**If `$TSC_EXIT` is non-zero** — **STOP.** TypeScript errors must be resolved before shipping.

**If `$BUILD_EXIT` is non-zero** — **STOP.** A failing build cannot ship.

**For Vite warnings in `/tmp/web-build.txt`** — check each warning:
- `[INEFFECTIVE_DYNAMIC_IMPORT]` on `auth.ts` → pre-existing (W2 in CLAUDE.md), acceptable.
- Chunk size warning on the main bundle → pre-existing (W3 in CLAUDE.md), acceptable.
- **Any other warning** → **STOP**, require a fix before shipping.

```bash
# Quick check: fail if any Vite warning is NOT in the known pre-existing list
grep -E '^\[.*\] Warning:' /tmp/web-build.txt | grep -v 'INEFFECTIVE_DYNAMIC_IMPORT\|Some chunks are larger' && {
  echo "NEW Vite build warning detected — must be resolved before shipping"
  exit 1
} || true
```

---

**Extension (TypeScript) — if `$EXT_SRC` is non-empty:**

```bash
cd "$REPO_ROOT/extension"

npm run type-check 2>&1 | tee /tmp/ext-typecheck.txt
EXT_TSC_EXIT=$?

npm test -- --run 2>&1 | tee /tmp/ext-test.txt
EXT_TEST_EXIT=$?
```

**If `$EXT_TSC_EXIT` is non-zero** — **STOP.** Fix TypeScript errors before shipping.

For stderr output from tests (`/tmp/ext-test.txt`): the `document is not defined` warning from `rating-panel.ts` is pre-existing (W5 in CLAUDE.md). Any other `ReferenceError` or uncaught exception → **STOP**, require investigation.

---

**Shrink the debt list when you fix something:**
If during any of the above checks you observe that a pre-existing issue from the CLAUDE.md debt table is now gone, remove that row from the table as part of your commit.

---

**All checks passed?** Continue to Step 5.

```bash
echo "step_lint_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 5 — Create the feature branch and commit

```bash
echo "step_commit_start $(date +%s%3N)" >> "$TIMING_TMP"
```

```bash
git checkout -b $BRANCH
git commit -m "$MSG"
```

Verify the commit was created:

```bash
git log --oneline -1
echo "step_commit_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 6 — Push the feature branch to origin

```bash
echo "step_push_start $(date +%s%3N)" >> "$TIMING_TMP"
git push -u origin $BRANCH
echo "step_push_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 7 — Create a PR targeting DEV

```bash
echo "step_pr_create_start $(date +%s%3N)" >> "$TIMING_TMP"
```

Capture both stdout and stderr so we can detect "already exists" gracefully.

**Before creating the PR, extract all capability IDs referenced in the branch commits** and include them in the PR body.

```bash
# --- Build capability ID section from branch commits ---
# Structured CAP-IDs: Refs: XX-CAP-NN
REFS_CAPS=$(git log "origin/dev..HEAD" --format='%b' 2>/dev/null \
  | grep -E '^\s*Refs:\s+[A-Za-z]{2,5}-CAP-[0-9]+' \
  | sed 's/.*Refs:[[:space:]]*//' \
  | sort -u | tr -d '\r')

# Spec-file refs: Refs: foo.md#...
REFS_SPECS=$(git log "origin/dev..HEAD" --format='%b' 2>/dev/null \
  | grep -E '^\s*Refs:\s+[a-z][a-z0-9-]+\.md' \
  | sed 's/.*Refs:[[:space:]]*//' \
  | sort -u | tr -d '\r')

# Determine primary action type from commit message prefix
if echo "$MSG" | grep -qiE '^feat'; then PR_ACTION="Implemented"
elif echo "$MSG" | grep -qiE '^fix'; then PR_ACTION="Bug Fix"
elif echo "$MSG" | grep -qiE '^test'; then PR_ACTION="Tested"
elif echo "$MSG" | grep -qiE '^refactor'; then PR_ACTION="Refactored"
elif echo "$MSG" | grep -qiE '^chore'; then PR_ACTION="Maintenance"
elif echo "$MSG" | grep -qiE '^docs'; then PR_ACTION="Documented"
else PR_ACTION="Updated"
fi

CAPS_TABLE=""
if [ -n "$REFS_CAPS" ]; then
  while IFS= read -r cap_id; do
    cap_id=$(echo "$cap_id" | tr -d ' \r\n')
    [ -z "$cap_id" ] && continue
    # Look up description in feature specs, strip markdown formatting
    desc=$(grep -rh "\[$cap_id\]" "$REPO_ROOT/docs/features/" 2>/dev/null \
      | grep -v '^\s*-\s*\[\s*\]\|Refs:' \
      | sed "s/.*\[$cap_id\][[:space:]]*//" \
      | sed 's/^\*\*\[P[0-9]\]\*\*[[:space:]]*//' \
      | sed 's/\*\*//g;s/|.*//' \
      | head -1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$desc" ] && desc="—"
    desc=$(echo "$desc" | cut -c1-120)
    CAPS_TABLE="${CAPS_TABLE}
| \`${cap_id}\` | ${desc} | ${PR_ACTION} |"
  done <<< "$REFS_CAPS"
fi
if [ -n "$REFS_SPECS" ]; then
  while IFS= read -r spec_ref; do
    spec_ref=$(echo "$spec_ref" | tr -d ' \r\n')
    [ -z "$spec_ref" ] && continue
    CAPS_TABLE="${CAPS_TABLE}
| — | See \`docs/features/${spec_ref}\` | ${PR_ACTION} |"
  done <<< "$REFS_SPECS"
fi

if [ -n "$CAPS_TABLE" ]; then
  PR_BODY="## Summary
Automated feature branch PR targeting DEV.

## Changes
See commit diff for details.

## Test plan
- [ ] Smoke-tested locally before shipping

## Capabilities

| ID | Description | Action |
|----|-------------|--------|${CAPS_TABLE}"
else
  PR_BODY="## Summary
Automated feature branch PR targeting DEV.

## Changes
See commit diff for details.

## Test plan
- [ ] Smoke-tested locally before shipping"
fi
```

```bash
PR_OUTPUT=$(gh pr create \
  --base dev \
  --head $BRANCH \
  --title "$MSG" \
  --body "$PR_BODY" 2>&1)
PR_EXIT=$?

if [ $PR_EXIT -eq 0 ]; then
  PR_URL="$PR_OUTPUT"
  echo "PR created: $PR_URL"
elif echo "$PR_OUTPUT" | grep -qi "already exists"; then
  # Extract the URL from the error message:
  #   "a pull request for branch ... already exists: https://github.com/..."
  PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://github\.com[^[:space:]]+')
  echo "PR already exists — reusing: $PR_URL"
else
  echo "PR creation failed:"
  echo "$PR_OUTPUT"
  exit 1
fi
```

`$PR_URL` is now set either way. Display it to the user and continue.

```bash
echo "step_pr_create_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Step 8 — Merge the PR (merge commit)

**Important:** `gh pr merge` will attempt to switch the local working tree to `dev`
after merging. Two things can block that checkout:
1. If `dev` is already checked out in a primary worktree and you are running from a
   secondary worktree, you get `fatal: 'dev' is already used by worktree`.
2. If any post-commit hooks (e.g. Prettier, TypeScript checker) modified files after
   the commit, those uncommitted changes cause `error: Your local changes would be
   overwritten by checkout`. The PR merges on GitHub but the local switch fails,
   leaving the working tree on the feature branch with a dirty state.

```bash
echo "step_merge_start $(date +%s%3N)" >> "$TIMING_TMP"
```

Always run this command from `$REPO_ROOT` and **always stash the working tree first**:

```bash
cd "$REPO_ROOT"

# Stash any working-tree changes (e.g. from post-commit hooks) so the branch
# switch after merge is not blocked by "local changes would be overwritten".
STASH_NEEDED=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash --include-untracked
  STASH_NEEDED=true
fi

# If the feature branch is checked out in a secondary worktree, gh pr merge
# --delete-branch will fail with "cannot delete branch '…' used by worktree".
# Remove the worktree NOW — before the merge — so the deletion succeeds.
if [ "$IN_WORKTREE" = "true" ]; then
  git worktree prune
  [ -d "$WORKTREE_PATH" ] && rm -rf "$WORKTREE_PATH" && echo "Worktree removed ahead of merge: $WORKTREE_PATH"
  IN_WORKTREE=false   # mark handled so Steps 9 & 10 skip the block
fi

gh pr merge $BRANCH \
  --merge \
  --delete-branch \
  --subject "$MSG"
```

`--delete-branch` removes the **remote** feature branch automatically.
Wait for the merge to complete — confirm with:

```bash
gh pr view $BRANCH --json state --jq '.state'
# Expected: "MERGED"
echo "step_merge_end $(date +%s%3N)" >> "$TIMING_TMP"
```

---

### Steps 9 & 10 — Cleanup and sync DEV

```bash
echo "step_cleanup_start $(date +%s%3N)" >> "$TIMING_TMP"
```

All cleanup runs from `$REPO_ROOT`. `gh pr merge --merge` may have already switched
the local working tree to `dev` and deleted the local feature branch; both operations
must be **conditional** to avoid errors:

```bash
cd "$REPO_ROOT"

# Switch to dev only if not already there
CURRENT=$(git branch --show-current)
[ "$CURRENT" != "dev" ] && git checkout dev

# Delete local branch only if it still exists
git branch --list "$BRANCH" | grep -q . && git branch -d "$BRANCH"
```

If `-d` refuses with "not fully merged", use `-D` only after confirming the remote
PR state in Step 8 returned `"MERGED"`.

**Worktree cleanup** — if `$IN_WORKTREE` was `true` in Step 0, the worktree directory
must be removed. Run from `$REPO_ROOT`:

```bash
if [ "$IN_WORKTREE" = "true" ]; then
  # Prune stale worktree refs (handles the case where the directory is already gone)
  git worktree prune

  # Remove the physical directory if it still exists
  [ -d "$WORKTREE_PATH" ] && rm -rf "$WORKTREE_PATH" && echo "Worktree directory removed: $WORKTREE_PATH"
fi
```

**Sync dev:**

```bash
git pull origin dev
git log --oneline -5
```

**Restore stashed changes** — if working-tree changes were stashed in Step 8, pop them now:

```bash
if [ "$STASH_NEEDED" = "true" ]; then
  git stash pop
fi
echo "step_cleanup_end $(date +%s%3N)" >> "$TIMING_TMP"
```

**Timing report** — parse the temp file, print a summary, and append a JSONL entry to the repo log:

```bash
TIMING_LOG="$(git rev-parse --show-toplevel)/logs/timing.jsonl"
mkdir -p "$(dirname "$TIMING_LOG")"
python - "$BRANCH" "$TIMING_LOG" "$TIMING_TMP" <<'PYEOF'
import sys, json, os
from datetime import datetime, timezone

branch = sys.argv[1]
log_path = sys.argv[2]
tmp_path = sys.argv[3]

# Parse temp file: lines like "step_detect_start 1711619400123"
data = {}
with open(tmp_path) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        parts = line.split()
        if len(parts) == 2:
            data[parts[0]] = int(parts[1])

def dur(name):
    s = data.get(f'step_{name}_start', 0)
    e = data.get(f'step_{name}_end', 0)
    return max(0, e - s) if s and e else 0

steps_order = ['detect','pull','stage','tests','coverage','lint','commit','push','pr_create','merge','cleanup']
steps = {s: dur(s) for s in steps_order}

workflow_start = data.get('workflow_start', 0)
workflow_end   = data.get('step_cleanup_end', 0)
total_ms = max(0, workflow_end - workflow_start) if workflow_start and workflow_end else 0

print("")
print("============================================")
print("  ship-to-dev Timing")
print("============================================")
for s, ms in steps.items():
    if ms > 0:
        print(f"  {s:<18}  {ms/1000:>6.1f}s")
    else:
        print(f"  {s:<18}     ---")
print(f"  {'':18}  {total_ms/1000:>6.1f}s  TOTAL")
print("============================================")

entry = {
    'ts': datetime.now(timezone.utc).isoformat(),
    'source': 'ship-to-dev',
    'branch': branch,
    'total_ms': total_ms,
    'steps': steps
}
os.makedirs(os.path.dirname(log_path), exist_ok=True)
with open(log_path, 'a') as f:
    f.write(json.dumps(entry) + '\n')
print(f"  [TIMING] Entry appended to {log_path}")
PYEOF
```

---

## Quick Reference

```
0.      Detect context (worktree? pre-committed? dirty tree?)
                                                 git rev-parse --show-toplevel; git branch; git rev-list;
                                                 git status --short → AskUserQuestion if pre-committed AND dirty
1.      Ask for $BRANCH and $MSG (skip if already committed on feature branch)
2.      Fetch + pull only if behind             git fetch origin && [check BEHIND count] && git stash / pull / pop
3.      Preview, then stage                     git status --short → AskUserQuestion if >10 files OR unrelated;
                                                 git add --all (or subset)
4.      Test + coverage + clean-build gate       4-A categorise (api/web/extension; empty = skip per-stack);
                                                 4-B project runner (Start-Tests.ps1 → make test → npm test →
                                                     ansible syntax-check → pytest → skip with notice);
                                                 4-C/4-D/4-E run only for non-empty stacks
5.      Create feature branch + commit           git checkout -b $BRANCH && git commit
6.      Push                                     git push -u origin $BRANCH
7.      Open PR into DEV                         gh pr create --base dev
8.      Merge PR (merge commit) from REPO_ROOT    cd $REPO_ROOT; [stash if dirty]; gh pr merge --merge --delete-branch
9 & 10. Conditional cleanup + sync DEV           [if not on dev] checkout dev; [if branch exists] branch -d;
                                                 [if worktree] git worktree prune && rm -rf $WORKTREE_PATH;
                                                 git pull origin dev; [if stashed] git stash pop
```

---

## Error Recovery

| Situation | Recovery |
|---|---|
| Rebase conflict can't be resolved | `git rebase --abort` — stop and tell user |
| Push rejected (non-fast-forward) | `git pull --rebase origin $BRANCH` then retry push |
| PR merge fails (status checks) | Show failure reason with `gh pr checks $BRANCH` — do not force merge |
| `gh` not authenticated | `gh auth login` — pause workflow until authenticated |
| Feature branch already exists | Use **AskUserQuestion**: options "Reuse existing branch" / "Choose a different name" — if "different name", loop back to Step 1 |
| Tests fail at Step 4 | Fix the failing tests/code before continuing — do not skip or bypass the gate |
| Missing test file at Step 4 | Create the missing test file covering the changed source file, re-run the gate |
| Coverage below 80% at Step 4 | Add tests for uncovered lines, re-run `pwsh Start-Tests.ps1 -NoPrompt -Parallel -SkipE2E`, re-check coverage |
| `fatal: 'dev' is already used by worktree` | `cd $REPO_ROOT` before running `gh pr merge` — never merge from inside a secondary worktree |
| `cannot delete branch '…' used by worktree` | Step 8 now removes the worktree automatically before `gh pr merge --delete-branch`. If the error still occurs, run manually: `git worktree prune && rm -rf $WORKTREE_PATH && git branch -d $BRANCH` |
| `local changes would be overwritten by checkout` | Stash before `gh pr merge` (Step 8 now does this automatically); the PR may have already merged on GitHub even if the command errored — check with `gh pr view` before retrying |
| PR already merged (second `gh pr merge` attempt) | Verify with `gh pr view $BRANCH --json state --jq '.state'`; if `"MERGED"`, skip to cleanup |
| `gh pr create` exits 1: "already exists" | Step 7 detects this automatically, extracts the existing PR URL, and continues to Step 8 — no manual intervention needed |
| Pre-committed branch + dirty working tree | Step 0 surfaces the dirty count and uses **AskUserQuestion** to choose: ship only the committed work, include the dirty files as a new commit, or abort. Never silently drop the dirty files |
| Step 3 about to sweep unrelated WIP into one commit | Pre-existing modified files in the working tree get swept by `git add --all`. Step 3 now previews `git status --short` and uses **AskUserQuestion** when the count is high or any file looks unrelated. Choose "Stage subset" to add only the paths that belong to this PR |
| Step 4-B: no recognized test runner in this repo | The detection chain (Start-Tests.ps1 → Makefile → npm → ansible-playbook → pytest) found nothing. Step 4-B prints which paths it looked for and continues. To make tests run on the next ship, add a `test:` target to `Makefile` or a `"test"` script to `package.json` |

## Diagram

[View diagram](diagram.html)
