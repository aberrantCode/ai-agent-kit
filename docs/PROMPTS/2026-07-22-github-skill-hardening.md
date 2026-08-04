# Handoff: Implement the GitHub-skill hardening proposal (all 15 change-units)

You are a fresh Claude Code session. Your job is to **implement every change-unit** in a
completed audit proposal for the `github` skill bundle, landing them as a sequence of small
PRs into `dev`. The analysis is already done — do not re-run it. Your work is implementation.

---

## 0. Orientation — read these first, follow them exactly

- This repo's `CLAUDE.md` (root) and `C:\Users\erik.OPBTA\.claude\CLAUDE.md` + `~/.claude/rules/*`
  are the source of truth for git workflow, commit format, output discipline, and coding style.
  **Follow them exactly. Do not restate or reinterpret their conventions** — read them and comply.
- The **source of truth for what to build** is these two files (read them in full before touching code):
  - `docs/reports/github-skill-audit-2026-07-22/PROPOSAL.md` — 15 change-units (CU-1..CU-15),
    each with exact target file + section, the concrete edit, why-it's-safe, and a verification
    command. **Part 4 (line ~420) has the PR batching and land order.**
  - `docs/reports/github-skill-audit-2026-07-22/REPORT.md` — the findings behind each CU, plus an
    **"Already-Fixed — Verify Deployment, Don't Re-Solve"** table. For those items you add a
    *check*, you do not re-implement the fix.
  - `partials/` in that dir has verbatim transcript quotes if you need to trace a finding's intent.

The `github` skill you are modifying: `claude/skills/github/` (orchestrator `SKILL.md`,
`sub-skills/{commit,ship,merge,prune,release,release-init,repo-init,publish,worktree-task-lifecycle}/SKILL.md`,
`commands/*.md`, and `sub-skills/*/templates/`). Codex mirror: `codex/skills/github/`.

---

## 1. HARD CONSTRAINTS (this session runs with --dangerously-skip-permissions — this section is the only guardrail)

1. **Never commit directly to `dev` or `main`; never push to them directly; never delete them.**
   Every batch lands as a feature branch → PR → `dev`. Use the repo's own `/ship` (or `/merge`)
   flow. **Merge commits only — never squash a feature branch.**
2. **Work in the worktree that already exists** — do NOT create another one:
   - Worktree: `C:\development\ai-agent-kit\.worktrees\github-skill-hardening`
   - Starting branch: `chore/github-skill-hardening` (branched from `origin/dev @ 3db7166`)
   - The work splits into independently-reviewable PRs (see §3), so you WILL create additional
     branches — but all from inside this one worktree checkout. Do not make a second worktree.
3. **Read every target file before editing it.** The proposal cites exact sections; confirm they
   still read as described before applying an edit. Do not edit from assumption.
4. **Run `pwsh ./scripts/validate.ps1` before opening any PR and abort that PR if it exits non-zero.**
   This is the repo's local validation gate (the `/ship` contract). Fix the cause, re-run.
5. **Keep each PR under 400 lines changed** (repo warns at 400, hard-limits at 800). The batching
   in §3 already respects this — if a batch grows past 400, split it and say so.
6. **Do not delete this prompt file** (`docs/PROMPTS/2026-07-22-github-skill-hardening.md`). Its
   retirement is a separate human-gated step you cannot run on your own behalf.
7. **If a task appears to require a forbidden or destructive action, STOP and report it** in your
   decision list rather than improvising around the constraint. A blocked batch is fine — skip it,
   record why, and continue with the independent batches.

---

## 2. STATE ALREADY ESTABLISHED (verified this session — do not redo)

- The audit is **complete**: 87 transcripts (last 7 days) → 40 findings → 12 themes → 15 CUs → 10 PRs.
  Do not re-scan transcripts.
- `scripts/validate.ps1` and `scripts/audit.ps1` **exist**; the proposal targets their real structure
  (`Add-Finding` helper, exit-code contract, existing 8 audit checks; audit Check 7 currently
  compares mirrored-skill *names* only). Read them before extending.
- `scripts/push-to-profile.ps1` is a **live `throw` stub** — that is the confirmed root cause of the
  global profile's `github` skill having no `sub-skills/` (finding F-KO-05). CU-7a implements it for real.
- **F-KO-19 (CRLF hook shebangs) is ALREADY FIXED** — the root `.gitattributes` pins both Claude and
  Codex `templates/hooks/*` to `eol=lf`. Do NOT re-fix; CU-14 only adds a *standing lint* for it.
- The Codex `release` mirror (`codex/skills/github/sub-skills/release/SKILL.md`) is **confirmed still
  stale** — missing Step 4b, Step 6b, and 3 Error-Recovery rows the Claude copy has. CU-7b is a
  net-new port, not a verify item.
- Everything in REPORT.md's "Already-Fixed" table is deployed in the *archive* already — for those,
  your job is the **verification check** the proposal describes (e.g. a lint / audit check), NOT a re-fix.

### Three design decisions the user has already made — encode these, do not re-litigate:

- **CU-13 (Codex↔Claude body-diff in audit.ps1): severity = `warn`.** Surfaces on every
  `/audit-skills`, never fails an archive PR. Match the existing warn-only mirror-gap philosophy.
- **CU-15 (template deploy-and-run smoke test): `-IncludeSmoke` opt-in flag on `validate.ps1`.**
  Default OFF locally (keep the pre-PR gate under its ~60s target), ON in the tag-release CI carve-out.
  It needs a scratch git repo + `pwsh`/`gh`.
- **CU-2 / CU-10 (auto-merge): READ-ONLY, per-repo choice — NOT drift.** `repo-init` may *surface*
  the repo-level "Allow auto-merge" setting but must **not** flag it as fixable drift or auto-enable it.
  Consequently the merge/ship **preflight must CHECK whether auto-merge is enabled before reaching
  for `gh pr merge --auto`** (fall back to watch-to-green if it's disabled) — it must not assume it.

### Wholesale-accepted (the user said "implement all") — build as the proposal specifies:

- **CU-7a:** implement `scripts/push-to-profile.ps1` as a full working script.
- **CU-6:** use the proposed `generatedCommitted` manifest schema (`path` + `regen` command) with the
  **local-only** merge-driver registration (GitHub server-side merge ignores `.gitattributes`).
- **CU-7b:** port the Codex `release` variant (Step 4b, Step 6b, 3 Error-Recovery rows).
- **F-KO-04 dangling-vs-duplication tension:** the proposal resolves it with an explicit **two-tier
  rule** — Tier-A one-line invariant in `SKILL.md` Cross-Operation Principles, Tier-B executable step
  in each standalone-loaded sub-skill. Preserve that structure; do not paste full blocks into 8 files.

---

## 3. TASKS — implement in this order (land order matters; rationale below)

Do the batches in the order below. **Rationale you must hold to:** PR-A ships the audit/validate
lints *first* so they guard every content PR that follows (a template-hygiene or contract-pointer
regression in a later PR gets caught the moment it's introduced). PR-B (preflight + ref-hygiene) is
the highest-value behaviour change and several later CUs reference its shared rules. C/D/E are
independent of each other. F (profile push) precedes G (which relies on mirrors being deployable). Do
not reorder to chase whatever looks quickest — a later batch that lands before its guard PR reproduces
the very bug the guard catches.

For **each** batch: create the branch from freshly-fetched `origin/dev`
(`git fetch origin && git checkout -b <branch> origin/dev`) — except PR-A, which can use the existing
`chore/github-skill-hardening` branch you start on. Implement the CUs, run `pwsh ./scripts/validate.ps1`,
then `/ship` it. "Done" for a batch = its PR is merged into `dev` and validate passed.

| Order | Branch | Batch | CUs (see PROPOSAL.md) |
|---|---|---|---|
| 1 | `chore/github-skill-hardening` | PR-A | CU-11, CU-12, CU-14 (audit.ps1 static lints) + CU-1 (anti-bypass docs in SKILL.md) |
| 2 | `feat/merge-ship-preflight` | PR-B | CU-2 (shared merge/ship preflight — draft/UNKNOWN/checks/**auto-merge-check**) + CU-3 (forced `fetch --prune` + already-gone deletes) |
| 3 | `fix/worktree-robustness` | PR-C | CU-4 (worktree add-verify, live-process lock recovery, concurrent-prune detection, orphan cleanup) |
| 4 | `fix/windows-gitbash-hazards` | PR-D | CU-5 (MSYS_NO_PATHCONV for `gh api`, plain-`-m` commit on Windows, pwsh-retry on Cygwin fork, + Tier-A bullets) |
| 5 | `feat/generated-doc-merge-policy` | PR-E | CU-6 (repo-init `generatedCommitted` manifest + merge-driver read path) |
| 6 | `feat/push-to-profile-impl` | PR-F | CU-7a (implement `push-to-profile.ps1`) |
| 7 | `fix/codex-release-port-bodydiff` | PR-G | CU-7b (Codex `release` port) + CU-13 (body-diff check, severity **warn**) |
| 8 | `fix/commit-integrity-repo-init` | PR-H | CU-8 (ship commit-integrity HEAD check) + CU-10 (repo-init hooksPath shim; auto-merge **read-only surface only**) |
| 9 | `feat/release-init-staleness-gate` | PR-I | CU-9 (release-init changelog-staleness-gate provisioned artifact) |
| 10 | `test/template-smoke-test` | PR-J | CU-15 (`-IncludeSmoke` opt-in smoke test on validate.ps1) |

C/D/E are mutually independent — if one blocks, proceed to the next and record the blocker.

**Per-task reporting:** after each batch, state the PR number, whether validate passed, and any CU
you couldn't apply as written (with the reason). At the very end, give a single table of all 10
batches: landed / blocked / skipped, and PR numbers.

---

## 4. DELEGATION (cheap-by-default, logged)

Spawn subagents for mechanical work and **pass `model: "haiku"` explicitly** (an unset model
silently inherits this session's expensive model). Good candidates in THIS work:
- Grepping every sub-skill/command for `git`/`gh` call sites that a shared rule must cover.
- Byte-scanning `templates/*.ps1` and `templates/hooks/*` for non-ASCII / CRLF (CU-14 lint input).
- Reading a sub-skill and extracting exactly where a Tier-B step should reference the Tier-A invariant.
- Drafting the YAML-frontmatter-validity lint and the sub-skill-path-resolution lint (CU-11/CU-12).
- Diffing Codex vs Claude `release` sub-skill bodies to enumerate what CU-7b must port.
Dispatch independent lookups **in parallel in one message**.

**Keep in the main session (do NOT fan out to a small model):** the two-tier contract design, the
shared preflight logic (CU-2/CU-3), the Codex-port judgment, sequencing, and anything adversarial.

**Delegation logging is REQUIRED (`scripts/log-delegation-outcome.ps1`):**
- Log every escalation (haiku → stronger), every time you redo a subagent's work yourself, and every
  dropped subagent task — with `-Category`, a `-FailureMode` from the fixed vocabulary, and one line
  of concrete `-Evidence`. Log it even if you recovered in seconds.
- **As your final step before reporting finished**, log the totals: `-Outcome ok -Dispatches N` per
  category, **each tagged `-PromptPath 'C:\development\ai-agent-kit\docs\PROMPTS\2026-07-22-github-skill-hardening.md'`**.
  This is the denominator the retirement gate requires; a session that skips it blocks its own cleanup.

---

## 5. MODEL

This session is pinned to **Opus** (`ANTHROPIC_MODEL=claude-opus-4-8`) because the hardest tasks —
authoring the shared preflight, the two-tier output-contract rule, and the Codex `release` port —
need frontier reasoning. Delegate the mechanical stretches to `model: "haiku"` subagents (§4) rather
than switching the main loop down. You may `/model` down only if the remaining work is purely
mechanical.

---

## 6. FINISHING

When all reachable batches are landed (or blocked-and-recorded):
1. Ensure local `dev` matches `origin/dev` (`git fetch origin && git checkout dev && git pull`).
2. Log the end-of-session delegation totals (§4) — **required, do this before reporting finished.**
3. Report a terse final summary + the 10-batch status table, then **stop**. Do NOT delete this prompt
   file and do NOT run the retirement gate — a human reviews the work and runs `complete-task-session.ps1`.

**Reporting discipline (every turn):** terse, lead with the action/answer, end with a single numbered
list of items needing a decision. Verify counts before stating them; if you state "N PRs landed," it is
exactly N. Correct any earlier wrong claim in one line and move on.

---

## 7. POLLING

Most work is synchronous. If a `/ship` merge stalls waiting on PR CI checks, use `/loop` with a short
interval to poll it to completion (`/loop 3m <check the PR merge state>`); otherwise `/loop` is not
needed — backgrounded commands notify on their own.
