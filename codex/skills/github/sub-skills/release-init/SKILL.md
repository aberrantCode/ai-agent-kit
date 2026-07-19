---
name: github-release-init
description: >
  Sub-skill of `github`. Provision or repair a repo's release automation to the
  Release-Automation Standard — a persistent changelog generator plus a tag-triggered workflow
  that regenerates release notes from git at tag time. Detects missing artifacts, the
  stale-changelog anti-pattern, and unrolled [Unreleased] blocks, then installs or repairs
  idempotently. Triggers on "set up releases", "release init", "provision release workflow",
  "fix changelog automation". Honors the Output Contract inlined below.
---

# Operation: release-init

**Goal.** Bring the current repo into conformance with the **Release-Automation Standard**.
Obey the **Output Contract** below: silent run, errors as they occur, one concise summary.
Confirm before writing anything; stay silent otherwise. Idempotent — a conformant repo is a
no-op.

---

## Output Contract (binding — inlined, not a reference)

The `/release-init` command may load this file without the parent `github` SKILL.md in
context, in which case a pointer to "the parent Output Contract" resolves to
nothing. The contract is therefore restated here in full and is binding either way.

Your terminal output for this operation is exactly these things and nothing else:

1. **During execution — stay silent.** No preamble, no step announcements ("Let me check…",
   "Now provisioning…"), no per-command status, no play-by-play.
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

## The Principle

Tag-triggered release automation **MUST regenerate release notes from git at tag time**. A
committed `CHANGELOG.md` is a cache, never the source of truth. A workflow that greps notes
out of a hand-committed changelog only says what someone last remembered to generate — it will
eventually publish stale notes. (Real failure this standard exists to prevent: a release
shipped changelog entries from months earlier because nobody re-ran the generator before
tagging.)

---

## The Standard — two artifacts

| Artifact | Location | Contract |
|---|---|---|
| Changelog generator | `scripts/Generate-Changelog.ps1` (or stack equivalent) | Deterministic full rebuild of `CHANGELOG.md` from git: `[Unreleased]` = `latestTag..HEAD` (entire history if untagged), each version = `prevTag..tag`, conventional-commit grouping, skips `release:` bump commits. Re-runnable at any time. |
| Release workflow | `.github/workflows/release.yml` | On `push: tags: ['v*']`: checkout with `fetch-depth: 0`, **regenerate** the changelog at tag time, extract the `## [<version>]` section, `gh release create` with those notes. A missing section degrades to a placeholder — **never** to `[Unreleased]`. |

Codex skills carry no bundled assets. The canonical deployable templates live in the archive's
Claude bundle at `claude/skills/github/sub-skills/release-init/templates/`
(`Generate-Changelog.ps1`, `release.yml`); when that bundle is not reachable, generate
equivalent files directly from the contracts above.

### Language-agnostic fallback

The standard is "notes derived from git at tag time", not the specific tool. Detect the repo's
stack and pick the fitting generator; the PowerShell template is the default only for
PowerShell repos:

| Stack signal | Generator |
|---|---|
| PowerShell (`*.ps1` / `*.psm1` dominant) | the `Generate-Changelog.ps1` template |
| Node (`package.json`) | conventional-changelog or release-please |
| Rust, or any repo happy with `cliff.toml` | git-cliff |
| Anything, minimal footprint | `gh release create --generate-notes` in the workflow (no generator file at all) |

Whatever the tool, the workflow contract is identical: full-history checkout, notes derived
from the tag's git range at tag time, no stale fallback.

---

## Step 0 — Preflight

```bash
git rev-parse --show-toplevel   # not a repo → STOP
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
```

---

## Step 1 — Detect state (read-only)

```bash
ls scripts/Generate-Changelog.ps1 cliff.toml .release-please-config.json 2>/dev/null
ls .github/workflows/release.yml 2>/dev/null
grep -n 'fetch-depth: 0' .github/workflows/release.yml 2>/dev/null
grep -n 'Unreleased' .github/workflows/release.yml CHANGELOG.md 2>/dev/null
```

Classify — a repo can match several states at once; handle every one that applies:

| State | Detected when | Repair |
|---|---|---|
| **CONFORMANT** | generator present, workflow tag-triggered with `fetch-depth: 0` + a regenerate step (or `--generate-notes`), no `[Unreleased]` fallback | none — report and stop |
| **MISSING** | no generator and/or no tag-triggered release workflow | Step 3A |
| **ANTI-PATTERN** | release.yml extracts notes from the committed `CHANGELOG.md` with an `[Unreleased]` fallback, and/or has no regenerate step, and/or checks out shallow | Step 3B |
| **STALE CHANGELOG** | `$LATEST_TAG` exists but `CHANGELOG.md` has no `## [<version>]` section for it — already-released content still sits under `[Unreleased]` | Step 3C |

---

## Step 2 — Confirm

Ask the user one plain, concise question listing the detected state(s) and every file about to
be written or edited (install / repair / roll), and wait for the answer. On decline, stop with
zero changes made.

---

## Step 3A — MISSING → install

```bash
mkdir -p scripts .github/workflows
```

- Install the stack-appropriate generator (default template: `Generate-Changelog.ps1` →
  `scripts/`).
- Install the `release.yml` template → `.github/workflows/release.yml`; if a non-PowerShell
  generator was chosen, swap the regenerate step for that tool's invocation.
- Seed `CHANGELOG.md` if absent: run the generator (it handles the no-tag case by emitting
  everything under `[Unreleased]`).

---

## Step 3B — ANTI-PATTERN → repair the workflow

Minimal edits, in place:

1. Ensure `fetch-depth: 0` on the checkout step — without full history the generator cannot
   walk tag ranges.
2. Insert a regenerate step (run the generator) before the notes-extraction step — or switch
   extraction to a git-range / `gh release create --generate-notes` approach.
3. Delete any `[Unreleased]` fallback: a missing `## [<version>]` section degrades to a
   placeholder line, never to stale notes.

If the existing workflow is too customized to patch safely, ask the user whether to replace it
wholesale with the `release.yml` template.

---

## Step 3C — STALE CHANGELOG → roll `[Unreleased]`

Preferred repair: the generator is a deterministic rebuild — run it. The stale block rolls
into `## [<version>] - <date>` automatically, splitting at the tag boundary (commits after
`$LATEST_TAG` open the fresh `[Unreleased]`).

Manual roll only when the changelog carries hand-curated prose a rebuild would lose: move the
`[Unreleased]` entries for commits reachable from `$LATEST_TAG` into a new
`## [<version>] - <tag date>` section, keep entries from `git log $LATEST_TAG..HEAD` under a
fresh `[Unreleased]`, and never leave `[Unreleased]` holding released content.

---

## Step 4 — Land

Do **not** commit here. Provisioned/repaired files stay in the working tree; the summary
points at the ship operation to land them through the normal feature-branch flow.

---

## Step 5 — Summary (only expected output)

```
Release automation provisioned — installed scripts/Generate-Changelog.ps1 + .github/workflows/release.yml, seeded CHANGELOG.md. Ship it to land.
```

or, for repairs: what was repaired and why (`release.yml regenerates at tag time now; stale
[Unreleased] rolled into v1.4.0`). For a conformant repo:

```
Release automation already conformant — no changes.
```

---

## Error Recovery

| Situation | Recovery |
|---|---|
| Not a git repo | **STOP** — tell the user |
| Generator run fails | Surface stderr verbatim; seed `CHANGELOG.md` with header + empty `[Unreleased]` and say so |
| Workflow too customized to patch | Ask the user: minimal patch / replace with template / abort |
| `CHANGELOG.md` is hand-curated (not generator-formatted) | Ask the user before any rewrite — never silently discard curated prose |
| User declines at Step 2 | Stop — zero changes |
