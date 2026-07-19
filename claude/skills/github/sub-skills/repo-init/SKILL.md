---
name: github-repo-init
description: >
  Sub-skill of `github`. Bring a repository's configuration up to the Repo-Configuration
  Standard — protected `main`/`dev` via rulesets, immutable release tags, merge-commit-only
  policy, secret-scanning push protection, a versioned local hook gate, and the standard
  artifact set. Idempotent and re-runnable: it diffs live state against the standard, shows
  the drift grouped by domain, and applies only what the operator confirms. Triggers on
  "init the repo", "initialize this repo", "repo init", "harden this repo", "set up branch
  protection", "why can I push straight to dev", "apply the repo standard", "check this repo
  against the standard", and similar phrasings. Auto-invokes `publish` when the repo has no
  GitHub remote. Honors the parent Output Contract.
---

# Operation: repo-init

**Goal.** Bring the current repo into conformance with the **Repo-Configuration Standard**
below. Obey the parent **Output Contract**: silent run, errors as they occur, one concise
summary. Read-only until the operator confirms. Idempotent — a conformant repo is a no-op.

`repo-init` is to repository *configuration* what `release-init` is to release *automation*:
a provisioning-and-repair pass that owns one standard and can be re-run forever.

---

## The Principle

**Desired state lives in the standard; the repo is a cache of it.** A repo is never assumed
conformant because it was configured once — settings get changed in the GitHub UI, hooks
stop being active after a fresh clone, and the standard itself evolves. Every run re-derives
desired state and re-probes live state. Nothing is applied without a diff the operator saw.

**Corollary — never destroy working configuration to match a cosmetic preference.** Where
the standard cares about an *outcome* (hooks are active) and a repo achieves it a different
way (`scripts/git-hooks/` instead of `.githooks/`), the repo's choice wins and is recorded
in the manifest. Only genuine gaps are drift.

---

## The Standard

Local-first: **CI runs on this workstation via git hooks, not GitHub Actions.** Actions are
permitted for release automation only. The one server-side exception is secret-scanning push
protection, because a pushed secret is the only failure in this list that cannot be undone.

### Group 1 — Protection (rulesets, not classic branch protection)

Three rulesets. Rulesets are used over the legacy `/branches/*/protection` API because they
work on private repos without a paid plan, support bypass actors, and cover tags.

A repo may carry **both** mechanisms at once — a ruleset on one branch and classic protection
on another — and GitHub ANDs them together, so the effective policy is neither of the two you
can see in isolation. That is drift even when each half looks reasonable. Migrate classic
protection to a ruleset and **delete the classic rule afterwards**; leaving it in place is the
whole problem.

| Ruleset | Target | Rules |
|---|---|---|
| `Protect main` | `refs/heads/main` | `deletion`, `non_fast_forward`, `pull_request` (0 approvals, `allowed_merge_methods: ["merge"]`) |
| `Protect dev` | `refs/heads/dev` | `deletion`, `non_fast_forward`, `pull_request` (0 approvals, `allowed_merge_methods: ["merge"]`) |
| `Protect release tags` | `refs/tags/v*` | `deletion`, `non_fast_forward` |

**Zero required approvals is deliberate,** not an oversight: these are solo-operator repos
and `/ship` self-merges. The PR requirement is what blocks direct pushes; the approval count
is not load-bearing. Do not raise it without being asked.

**No required status checks.** Local-first CI means there is no server-side check to require.
If the repo has a genuine reason for one, that is a per-repo decision recorded in the
manifest — `repo-init` never adds one on its own.

Templates: `./templates/ruleset-branch.json`, `./templates/ruleset-tags.json`.

### Group 2 — Merge policy

```
mergeCommitAllowed:  true
squashMergeAllowed:  false
rebaseMergeAllowed:  false
deleteBranchOnMerge: true
allowAutoMerge:      true
```

Squash and rebase are disabled at the repo level so the UI is physically unable to violate
the bundle's merge-commit rule. `deleteBranchOnMerge` complements `/prune`.

### Group 3 — Security

| Setting | Desired | Degrade |
|---|---|---|
| Vulnerability (Dependabot) alerts | enabled | — |
| Secret scanning | enabled | private repo without GHAS → offer a **waiver**, skip |
| Secret-scanning **push protection** | enabled | private repo without GHAS → offer a **waiver**, skip |
| `.github/dependabot.yml` | present, ecosystems auto-detected | — |

Push protection is the deliberate exception to local-first: it is a server-side block that
needs no workflow and no runner.

**Expect the waiver path on private repos — it is the common case, not the edge case.**
Secret scanning and push protection require GitHub Advanced Security, which private repos do
not get by default. Do not treat the 403/422 as an error to retry or work around: offer to
record the waiver once, and the repo stops being asked forever. On a waived repo the
`pre-commit` gitleaks hook is the *only* secrets gate, so never leave Group 5 unaddressed
when Group 3 is waived — say so explicitly in the summary.

### Group 4 — Actions policy

```
default_workflow_permissions:     read
can_approve_pull_request_reviews: false
```

Workflow content: `.github/workflows/release.yml` (tag-triggered, owned by `release-init`) is
**allowed**. Any workflow triggered by `push` or `pull_request` is **flagged as drift** —
report it and ask whether to migrate its checks into the local hook gate. Never delete a
workflow without confirmation.

### Group 5 — Local hook gate

The outcome the standard requires: **hooks are committed to the repo and active in this
clone.** Two independent facts, both checked:

1. A versioned hooks directory exists with the standard hooks in it.
2. `git config --local core.hooksPath` points at that directory.

Fact 2 is the one that silently rots — `core.hooksPath` is local config and is **never
cloned**, so a fresh clone of a perfectly hooked repo runs zero hooks. Always verify it
independently of fact 1.

**Directory name is discovered, not imposed.** Resolution order:

1. Current `core.hooksPath` value, if set and the directory exists → that is the repo's dir.
2. Otherwise the first existing of `.githooks/`, `scripts/git-hooks/`, `.git-hooks/`.
3. Otherwise create `.githooks/`.

Standard hook set — **overridable per repo** via `hooks.set` in the manifest:

| Hook | Contract | Default |
|---|---|---|
| `pre-commit` | `gitleaks protect --staged --redact`; then the repo's validate script if one exists | on |
| `pre-push` | full validation (`scripts/validate.ps1`, `scripts/validate.sh`, or the detected equivalent) | on |
| `commit-msg` | conventional-commit format check | off |
| `post-checkout` / `post-rewrite` | regeneration of generated files | off |

Each hook is a thin wrapper that **degrades to a warning when its tool is absent** — a hook
that hard-fails because `gitleaks` isn't installed makes every commit impossible on a fresh
machine. Templates: `./templates/hooks/`.

**Interaction with the global git-push-opens-Zed hook.** That hook is a Claude Code
`PreToolUse` hook on the harness side; `pre-push` here is a git hook. They fire at different
layers and do not conflict, but an unattended run will see both. Note it in the summary the
first time `pre-push` is installed in a repo.

### Group 6 — Artifacts

| Artifact | Rule |
|---|---|
| `.gitignore` | present and non-trivial; must cover secrets (`.env*`, `*.pem`, `*.key`, `*.p12`, `credentials.json`, `*.token`), OS cruft, editor dirs, build output, and the worktree block below. Stack-aware additions from detected ecosystems. **Never rewritten** — only missing lines are proposed, as an append. |
| `.gitattributes` | present; `* text=auto eol=lf`, CRLF for `*.bat`/`*.cmd`/`*.ps1`, `binary` for media/archive/db/encrypted extensions. Existing merge drivers and `eol` rules are preserved verbatim. |
| `.gitleaks.toml` | present if the `pre-commit` hook is on |
| `.github/PULL_REQUEST_TEMPLATE.md` | present, matching the Summary + Test Plan format |
| `.github/ISSUE_TEMPLATE/` | present (bug + feature) |
| `SECURITY.md` | present |
| `CONTRIBUTING.md` | present |
| `LICENSE` | **public repos only** — ask which license; never guess |
| `CODEOWNERS` | **only when the repo has >1 collaborator** — a CODEOWNERS naming one person on a solo repo is pure ceremony and, combined with `require_code_owner_review`, is a self-lockout risk |

Templates: `./templates/artifacts/`.

#### Worktree ignore entries — required, but never created

`repo-init` **does not create a worktree directory.** Per charter §4 the worktree lifecycle is
owned by `worktree-task-lifecycle`, and its canonical location is the **sibling**
`<repo>-wt/.worktrees/<task>` — deliberately outside the repo, which is precisely why a
correctly-placed worktree needs no ignore rule at all.

The ignore entries are nonetheless required, because they are **defensive**: they cover
in-repo worktree paths created by *other* tooling. Claude Code's `EnterWorktree` creates
`.claude/worktrees/` inside the repo, and ad-hoc `git worktree add .worktrees/x` is common.
Without these lines, a worktree created by either route shows up as a mountain of untracked
files in `git status` and can be swept into a commit by `git add -A`.

Ensure this block exists in `.gitignore`, comment included — the comment is what stops a
future reader from "cleaning up" entries whose purpose isn't obvious:

```gitignore
# Git worktrees. The canonical location is the SIBLING <repo>-wt/.worktrees/
# (outside this repo). These entries are defensive: Claude Code's EnterWorktree
# creates .claude/worktrees/ in-repo, and ad-hoc `git worktree add .worktrees/x`
# is common. Without them a worktree becomes untracked noise in git status.
.worktrees/
.claude/worktrees/
```

### Group 7 — Repo metadata

`description` non-empty, `topics` non-empty, `homepageUrl` set if the project has a site.
Wiki and Projects disabled unless in use (they are enabled by default and are unused attack
and confusion surface). Ask for values — never invent a description.

### Group 8 — CLAUDE.md managed block

Agents reading `CLAUDE.md` must learn the repo's branch model, worktree location, and — most
importantly — that **the hook gate needs one-time local activation after a clone**. None of
that is discoverable from the code.

`CLAUDE.md` is contested ground: the built-in `/init` scaffolds it, `claude-md-management`
audits it, and the workstation's `doc-blocker` `PreToolUse` hook guards markdown creation.
`repo-init` is therefore a **delimited-block writer only**:

```markdown
<!-- repo-init:begin managed block - do not edit by hand -->
...
<!-- repo-init:end -->
```

Rules, all load-bearing:

- **Only the text between the markers is ever read or written.** Everything outside is opaque
  and preserved byte-for-byte. This is what makes a third writer on a shared file safe.
- **Absent markers → append the block at the end.** Never restructure or reorder the file.
- **Markers present → replace the span between them.** Never append a second block.
- **A hand-edited block is drift, not a conflict.** Report the diff and let the operator
  choose; do not silently overwrite someone's edit.
- **This group always confirms separately** from Group 6, even when both are selected. A file
  three tools write to does not get modified as a side effect of ticking "artifacts".
- **No `CLAUDE.md` in the repo → offer to create one containing only the block.** Do not
  scaffold a full `CLAUDE.md`; that is the built-in `/init`'s job, and duplicating it here
  would produce two competing scaffolds.

Content of the block (`./templates/artifacts/claude-md-block.md`) covers the branch model,
merge strategy, the sibling worktree location, and hook activation.

### Group 9 — Large assets (detect only)

Scan for blobs over 10 MB in the working tree and in tracked history
(`git rev-list --objects --all` + `git cat-file --batch-check`). If any are found, **report
them and stop there**. Per charter §4 the big-binary / large-asset policy is owned by
`github large-asset-vendoring`; `repo-init` detects and routes, it does not decide. If that
sub-skill is not present, offer plain `git lfs track` on the detected patterns and state
plainly that migrating **existing** history requires `git lfs migrate`, is a history rewrite,
and is out of scope for this operation.

---

## The Manifest — `.github/repo-standard.yml`

Written on first successful apply, updated on every subsequent one. It is the record of what
was applied and the place where a repo declares deliberate deviations.

```yaml
standardVersion: 1.0.0        # the standard this repo was last reconciled against
appliedAt: 2026-07-19
appliedBy: repo-init

protection:
  model: rulesets
  branches: [main, dev]
  approvals: 0
  tags: "v*"
  requiredStatusChecks: []    # local-first CI: intentionally empty

merge:
  commit: true
  squash: false
  rebase: false
  deleteBranchOnMerge: true

security:
  vulnerabilityAlerts: true
  secretScanning: true
  pushProtection: true

actions:
  policy: release-only
  defaultWorkflowPermissions: read

hooks:
  path: .githooks              # discovered, not imposed
  set: [pre-commit, pre-push]  # overridable per repo

artifacts: [gitignore, gitattributes, gitleaks, pr-template, issue-templates, security, contributing]

claudeMd:
  managedBlock: true          # the repo-init:begin/end span is maintained here
  blockVersion: 1.0.0

# Deliberate deviations from the standard. Each MUST carry a reason.
# repo-init reports these as "waived", never as drift.
waivers:
  - key: security.secretScanning
    reason: private repo, no GHAS entitlement
```

**`standardVersion` is what makes re-runs meaningful.** On a re-run, compare it against the
standard's current version: if the repo's stamp is older, the diff distinguishes *repo drift*
(the repo moved) from *standard evolution* (the standard moved) and labels each group
accordingly. Without the stamp, a newly-added rule is indistinguishable from someone having
turned an old rule off.

**Waivers are first-class.** A repo that genuinely cannot satisfy a rule records a waiver and
stops being nagged about it forever. Never write a waiver without the operator saying so, and
never write one with an empty `reason`.

---

## Step 0 — Preflight

```bash
git rev-parse --show-toplevel        # not a repo → offer git init, or STOP
gh --version && gh auth status       # missing/unauthed → install/login, else STOP
gitleaks version                     # missing → note it; hook degrades to a warning
```

Run from the **primary checkout**, not a secondary worktree
(`cd "$(git rev-parse --show-toplevel)"`).

---

## Step 1 — Route on publication state

```bash
git remote get-url origin 2>/dev/null
gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null
```

| State | Action |
|---|---|
| No `origin`, or `origin` is not a reachable GitHub repo | **Invoke `sub-skills/publish` first.** It creates the repo and pushes `main` + `dev`, then returns here. Do not duplicate its work. |
| `origin` exists but `dev` does not | Create `dev` from `main` and push it, then continue |
| Published, `main` + `dev` present | Continue to Step 2 |

`publish` and `repo-init` are two entry points onto one standard: `publish` owns repo
*creation*, `repo-init` owns repo *configuration*. Either path converges here.

**Re-entrancy.** `publish` invokes `repo-init` at its end. Guard against a loop: when
`repo-init` invoked `publish`, `publish` returns control rather than calling back.

---

## Step 2 — Probe live state (read-only, no writes)

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

gh repo view --json visibility,defaultBranchRef,description,homepageUrl,repositoryTopics,\
hasWikiEnabled,hasProjectsEnabled,deleteBranchOnMerge,mergeCommitAllowed,squashMergeAllowed,\
rebaseMergeAllowed,autoMergeAllowed
gh api "/repos/$REPO/rulesets"
gh api "/repos/$REPO/actions/permissions/workflow"
gh api "/repos/$REPO" --jq '.security_and_analysis'
gh api "/repos/$REPO/vulnerability-alerts" -i | head -1     # 204 enabled / 404 disabled
gh api "/repos/$REPO/collaborators" --jq 'length'           # gates CODEOWNERS
git config --local core.hooksPath
ls .githooks scripts/git-hooks .git-hooks 2>/dev/null
ls .github/workflows/ 2>/dev/null
cat .github/repo-standard.yml 2>/dev/null                   # prior manifest, if any
```

Read the manifest **first** if it exists — its `waivers` suppress drift and its `hooks.set`
and `hooks.path` override the defaults for this repo.

---

## Step 3 — Diff and classify

Build the drift list group by group (Groups 1–9). Each item is one of:

| Class | Meaning | Shown as |
|---|---|---|
| **conformant** | live matches desired | omitted from the diff |
| **waived** | a manifest waiver covers it | listed once, dimmed, not actionable |
| **drift** | repo moved away from the standard | actionable |
| **new-in-standard** | repo's `standardVersion` predates this rule | actionable, labelled `(new)` |
| **blocked** | cannot be applied here (plan/permission) | reported with the reason, not offered |

Fully conformant → print the conformance summary and **stop without asking anything**.

---

## Step 4 — Confirm (grouped, per-group opt-in)

One `AskUserQuestion`, `multiSelect: true`, one option per drifted *group* — never per item;
a badly drifted repo would otherwise become an interrogation. Each option's description lists
that group's concrete changes. Groups with no drift are not offered.

```
DRIFT — aberrantCode/AC_OPBTA  (standardVersion 0.9.0 → 1.0.0)

[ ] protection   dev on classic protection → migrate to ruleset;
                 no tag ruleset (new)
[ ] merge        squash+rebase enabled → disable; deleteBranchOnMerge off → on
[ ] security     push protection disabled → enable; no dependabot.yml
[ ] hooks        .githooks/ present but core.hooksPath UNSET — hooks inactive
[ ] actions      docs-contract.yml triggers on pull_request (local-first violation)
[ ] artifacts    SECURITY.md, PR template missing;
                 .gitignore lacks .worktrees/, .claude/worktrees/
[ ] claude-md    managed block absent (worktree + hook-activation guidance)
[ ] metadata     description empty; wiki+projects enabled but unused

waived  security.secretScanning — private repo, no GHAS entitlement
```

Destructive or judgment-dependent items are **never** bundled into a group; they get their
own follow-up question: deleting/migrating a workflow, choosing a LICENSE, writing a
`description`, the CLAUDE.md managed block (Group 8), and anything touching Group 9.

Operator selects nothing → stop, zero changes.

---

## Step 5 — Apply (only the confirmed groups)

Order matters — cheapest and most reversible first, so a mid-run failure leaves the least mess:

1. **Local files** (artifacts, hooks) — working-tree only, trivially revertable
2. **Local git config** (`core.hooksPath`)
3. **Repo settings** (`gh repo edit`, Actions permissions, security toggles)
4. **Rulesets** (last — the thing that can lock you out)

Rulesets are applied by name: `PUT` when a ruleset with that name exists (preserving its id),
`POST` when it does not. Never blind-`POST` — that creates a duplicate ruleset with the same
name, and the two then AND together into rules nobody wrote.

**Self-lockout guard.** Before applying a branch ruleset, confirm the authenticated user has
admin on the repo (`gh api "/repos/$REPO" --jq '.permissions.admin'`). Without admin, a
ruleset can be created that the operator cannot subsequently edit or bypass.

---

## Step 6 — Write the manifest

Write/update `.github/repo-standard.yml` with the applied state, the current
`standardVersion`, and any waivers. Record `hooks.path` as the **discovered** directory.

Skipped groups are **not** recorded as applied, and are **not** silently converted to
waivers — a skipped group must still show as drift on the next run. Only an explicit
operator waiver suppresses an item.

---

## Step 7 — Land

Do **not** commit. Provisioned files stay in the working tree; the summary points at `/ship`.

Repo-level settings (rulesets, merge policy, security toggles) are applied to GitHub
immediately and are **not** part of the commit — say so explicitly, since a rolled-back PR
does not roll them back.

---

## Step 8 — Summary (only expected output)

```
Repo standard applied to aberrantCode/AC_OPBTA (v1.0.0) — dev migrated to ruleset, tag
ruleset added, squash/rebase disabled, push protection on, core.hooksPath set to .githooks
(was unset — hooks were inactive). Skipped: actions. Files staged: SECURITY.md,
.github/PULL_REQUEST_TEMPLATE.md, .github/repo-standard.yml. Run /ship to land them.
GitHub settings already live and not covered by the PR.
```

Conformant repo:

```
Repo already conformant with standard v1.0.0 — no changes. (1 waiver: security.secretScanning)
```

---

## Error Reference

| Situation | Action |
|---|---|
| Not a git repo | Offer `git init`; if declined, **STOP** |
| No `origin` / unpublished | Invoke `sub-skills/publish`, then resume at Step 2 |
| Ruleset API 403 | Not admin on the repo → report, skip Group 1, give the manual UI steps |
| Secret scanning 403 / 422 | Private repo without GHAS → offer to record a **waiver**, don't retry |
| Ruleset name already exists | `PUT` by id — never `POST` a duplicate |
| `core.hooksPath` set to a **missing** directory | Real breakage, not drift: report loudly; hooks are silently disabled today |
| Repo has >1 collaborator | Offer CODEOWNERS; do **not** enable `require_code_owner_review` without confirmation (lockout risk) |
| Existing `.gitignore` / `.gitattributes` | Append-only; never rewrite. Show the proposed lines |
| Workflow flagged as CI | Ask: migrate to hooks / keep as documented exception / delete. Never auto-delete |
| Large files found | Route to `large-asset-vendoring`; if absent, offer `git lfs track` and state that existing history needs `git lfs migrate` (out of scope) |
| `gitleaks` not installed | Install hooks anyway — they warn instead of failing. Note it in the summary |
| Manifest exists but is unparseable | Treat as absent, back it up to `.github/repo-standard.yml.bak`, say so |
| Operator declines at Step 4 | Stop — zero changes |
