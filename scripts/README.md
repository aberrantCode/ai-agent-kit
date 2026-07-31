# scripts/

All lifecycle automation for the archive — installation, deployment, sync, catalog
generation, and (in a later PR) validation — as real scripts, so the archive's
deploy/install/overlay/integration lifecycle no longer depends solely on LLM-driven
slash commands (a [core goal of the repo standard](../docs/requirements/canonical-repo.md)).

Two trees hold scripts today: [`claude/skills/skills-manager`](../claude/skills/skills-manager)
implements the interactive, chat-driven slash-command surface (`/install-skill`,
`/audit-skills`, `/push-skill`, `/update-skill`, ...); this directory holds
the deterministic, non-interactive PowerShell/Python equivalents that the
slash commands are expected to grow into or call out to. Nothing here changes
what a *deployed* skill does at runtime — that boundary is held firmly in the
[repo standard](../docs/requirements/canonical-repo.md) — this is archive tooling only.

## Script inventory

| Script | State | Contract summary |
|---|---|---|
| [`generate-manifest.py`](generate-manifest.py) | implemented | Generates `manifest.json` from skill/instruction frontmatter. Flags: `--output PATH` (default: repo-root `manifest.json`), `--validate --json` (read-only; emits parsed frontmatter plus per-skill validation records, including a `categorySource` marker, for [`audit.ps1`](audit.ps1) to consume — one frontmatter parser for the whole repo). `category:` frontmatter is the sole per-skill source of truth (see the [category-resolution rule](../docs/requirements/canonical-repo.md)); `codex` and `gemini` mirrors carry no `category:` of their own and inherit it from the source Claude skill by name. The 15-entry curated category display order is hardcoded in the script and populates `manifest.json`'s `categories` array. Also emits a top-level `schemaVersion` field — see [`manifest.json` shape](#manifestjson-shape) below. |
| [`audit.ps1`](audit.ps1) | implemented | Read-only archive health check: frontmatter validity + name/dir match; missing `category:` (error severity); `installed-from:` presence in the archive; secret-shaped content under `shared/`; manifest freshness (timestamp excluded); `CATALOG.md` parity in both directions; Claude↔Codex mirror gaps; missing `diagram.html`. Delegates all YAML parsing to `generate-manifest.py --validate --json`. Console table, or `-Json`. Full check list and severities: [repo standard §6](../docs/requirements/canonical-repo.md). |
| [`install-to-project.ps1`](install-to-project.ps1) | stub | Copies a skill bundle (`SKILL.md` + `sub-skills/` + `commands/` + `references/` + `rules/`) into a target project's `.claude/`, stamping `installed-from: ai-agent-kit`. |
| [`push-to-profile.ps1`](push-to-profile.ps1) | implemented | Deploys a named bundle from `<Vendor>/skills/<Name>` to the vendor profile (`~/.<vendor>` by default; `-TargetDir` overrides the skills root, `-Vendor` selects claude/codex/gemini). Mirrors the archive's nested layout: parent `SKILL.md` + `sub-skills/**` + `references/**` + `rules/**` + `scripts/**` under `<skillsRoot>/<Name>/`; companion commands go to the sibling `commands/` (the discoverable slash-command location — never nested, which would leave `/<cmd>` unreachable). Sub-skills must stay nested — a loose top-level copy shadows the bundle's own sub-skill, a regression [`audit.ps1`](audit.ps1) checks for and this script now prevents. Every `SKILL.md` (parent + nested sub-skills) is stamped `installed-from: ai-agent-kit`; other files copy verbatim. `status: draft` bundles are skipped. Preview-only by default; `-Force` writes and first backs up any existing bundle to a sibling `<skillsRoot>-backups/<Name>.bak-<stamp>` (outside the scanned skills root, so the backup is never picked up as a duplicate). Paths are canonicalized and containment-checked; `-Name` is restricted to a bare directory name. Console summary, or `-Json`. Exit `0` success/preview/draft-skip, `1` validation failure, `2` execution error. |
| [`sync-installed.ps1`](sync-installed.ps1) | stub | Scans a project (or fleet root) for stamped installed copies, diffs against the archive; report-only by default, `-Force` writes with backup-before-overwrite. |
| [`generate-catalog.ps1`](generate-catalog.ps1) | implemented | Renders `CATALOG.md` from `manifest.json`: per-vendor skill tables (grouped by the curated category order, ordinal-sorted within category), per-vendor instruction tables (including Codex/Gemini — a scope question the [repo standard](../docs/requirements/canonical-repo.md) settles), a global-commands table, and per-class `shared/` asset listings. Byte-stable output (ordinal sort, `utf8NoBOM`, explicit LF, pinned via `.gitattributes`) — identical across repeated runs regardless of locale/culture settings. `-Json` emits the underlying data model instead of markdown; default is preview-only, `-Force` writes. |
| [`backfill-categories.ps1`](backfill-categories.ps1) | implemented | One-time, idempotent injector of `category:` frontmatter into any Claude `SKILL.md` that doesn't already have one — safe to re-run for future skills. Preview by default; `-Force` writes and backs up each modified file first to a bounded temp dir; reports any skill it can't resolve, for manual assignment. |
| [`validate.ps1`](validate.ps1) | implemented | The local pre-PR validation gate: regenerates and byte-diffs `CATALOG.md`, runs `audit.ps1`, and checks `CHANGELOG.md` tag coverage. Console summary, or `-Json`. Exit `0` clean, `1` findings, `2` execution failure. Full contract: [Validation pipeline](#validation-pipeline) below. |
| [`Generate-Changelog.ps1`](Generate-Changelog.ps1) | implemented | Deterministic full rebuild of `CHANGELOG.md` from `git log`: `[Unreleased]` = `latestTag..HEAD`, each version section = `prevTag..tag`, grouped by conventional-commit prefix into Keep-a-Changelog sections. Skips `release:` bump commits and scaffolding commits (unparseable subject *and* a `.gitkeep`-only diff — the file check only runs once the subject fails to parse, so well-formed commits cost no extra `git show`). Pins `[Console]::OutputEncoding` to UTF-8 before invoking git, so an em-dash in a commit subject round-trips correctly even under a non-interactive invocation. Installed verbatim from [`claude/skills/github/sub-skills/release-init/templates/`](../claude/skills/github/sub-skills/release-init/templates/) — the template is the source of truth, so fixes land there and are copied down (see [Validation pipeline](#validation-pipeline)). |
| [`install-hooks.ps1`](install-hooks.ps1) | implemented | Opt-in, idempotent installer that points this repo's local `core.hooksPath` at the committed [`scripts/git-hooks/`](git-hooks/) directory (repo-local git config only, never global). Preview by default; `-Force` applies. Re-running once installed is a reported no-op. See [Validation pipeline](#validation-pipeline) below for the Zed-hook interaction note. |
| [`install-skills.ps1`](../install-skills.ps1) (repo root, not in this directory) | implemented — grandfathered exception | The published remote-bootstrap one-liner. Stays on PowerShell 5.1 (see [below](#powershell-7-floor-and-the-grandfathered-exception)) and at the repo root, because its location is itself part of its [published contract](#root-installer-url-contract) — not moved into `scripts/`. |

"Stub" here means the definition in the [repo standard §6](../docs/requirements/canonical-repo.md):
the file exists, comment-based help documents purpose/parameters/exit
codes/intended behavior, and the body is `throw "TODO: not implemented"` — so
accidental execution fails loudly (exit code ≠ 0) instead of doing nothing or doing
the wrong thing silently.

Every task that flips a script from stub to implemented updates the **State** column
above in the same PR, per the binding rule in the [implementation plan](../docs/plans/canonical-repo-plan.md).

## PowerShell 7 floor, and the grandfathered exception

Every script in this directory declares `#Requires -Version 7.0` and is written to be
cross-platform — no Windows-only APIs, `utf8NoBOM` output encoding, ordinal
(culture-invariant) sorting — per the [repo standard's portability requirement](../docs/requirements/canonical-repo.md).
This keeps a future Python port (an [open question tracked in the repo standard](../docs/requirements/canonical-repo.md))
and a future hosted-CI mirror of the local validation gate cheap, even though today's
gate runs locally only.

`install-skills.ps1` at the repo root is the **one intentional exception**: it stays
on `#Requires -Version 5.1` because it is the target of a raw-GitHub remote-bootstrap
one-liner (see [Root-installer URL contract](#root-installer-url-contract) below) and
Windows ships PowerShell 5.1 out of the box with no install step, while PowerShell 7
is an opt-in install. Lowering the floor there maximizes the chance the one-liner
works on an unmodified Windows machine. This is a deliberate, narrow carve-out for
that one script — it does not license a 5.1 floor anywhere else in this repository.

## Shared conventions (all lifecycle scripts)

Binding for every script in this directory (see the [repo standard §6](../docs/requirements/canonical-repo.md)):

| Convention | Requirement |
|---|---|
| Parameters | Common surface: `-Name <skill>`, `-TargetDir <path>`, `-Force`, `-WhatIf`, `-Json`. Scripts add script-specific parameters but never repurpose the meaning of these five. |
| Exit codes | `0` success/clean; `1` findings or validation failure; `2` execution error. `audit.ps1` refines this further: exit `1` only on error-severity findings — warnings alone exit `0`. |
| Safety | Mutating scripts default to preview (`-WhatIf` semantics or report-only) and require explicit `-Force` to write. Before overwriting an existing file: back it up or refuse — never a silent clobber. All target paths are canonicalized and containment-checked against the intended root, rejecting path traversal via a crafted `-Name` or `-TargetDir`. |
| Subprocess | Calls to `python` use an explicit interpreter + argument array (no shell string interpolation) and a bounded temp location. |
| Portability | `#Requires -Version 7.0`; no Windows-only APIs; output encoding `utf8NoBOM`; ordinal (culture-invariant) sorting. |

Each stub's comment-based help documents how it will honor these conventions once
implemented — see `.DESCRIPTION` and `.NOTES` in each `.ps1` file, or run
`Get-Help ./scripts/<script>.ps1 -Full`.

## Root-installer URL contract

`install-skills.ps1` lives at the repo root, not in `scripts/`, because its path is a
**published contract**, per the [repo standard](../docs/requirements/canonical-repo.md):
the remote one-liner

```powershell
irm 'https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/main/install-skills.ps1' | iex
```

fetches whatever is currently on the `main` branch's HEAD and executes it, unreviewed,
as the invoking user. Moving the file would silently break every copy of that one-liner
anyone has saved.

**Trust model, stated plainly:** `irm | iex` against a mutable branch ref (`main`)
means you are trusting (a) that this repository's `main` branch has not been
compromised, (b) that GitHub's raw-content CDN has not been tampered with in transit,
and (c) that whatever is on `main` *right now* — which can change at any time,
independent of when you last read the script — is what actually runs on your machine.
There is no version pinning and no integrity check in the one-liner above.

**Integrity-conscious alternatives**, in increasing order of assurance:

1. **Clone and inspect.** `git clone` the repo, read `install-skills.ps1`, then run it
   locally (`./install-skills.ps1`). No blind execution of remote content.
2. **Pin to a commit SHA.** Replace `main` in the raw URL with a specific commit SHA
   so the fetched content cannot change out from under you:
   `https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/<commit-sha>/install-skills.ps1`.
3. **Pin to a release tag and verify a published checksum.** Each tagged release
   publishes a SHA256 for `install-skills.ps1` (a [release-integrity requirement](../docs/requirements/canonical-repo.md)
   in the repo standard). Fetch the tagged copy, compute its SHA256 locally, and
   compare against the published value before executing it:
   ```powershell
   $expected = '<sha256-from-release-notes>'
   Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/v<version>/install-skills.ps1' -OutFile install-skills.ps1
   $actual = (Get-FileHash install-skills.ps1 -Algorithm SHA256).Hash
   if ($actual -ne $expected) { throw "checksum mismatch — do not run this file" }
   ./install-skills.ps1
   ```

The `main`-HEAD one-liner remains the documented quick-start precisely because it is
the lowest-friction path; the alternatives above exist for anyone who wants to reduce
the trust they're extending before executing remote code.

## `manifest.json` shape

`manifest.json` is the single machine-readable source of truth (per the
[repo standard](../docs/requirements/canonical-repo.md)) — generated by
`python scripts/generate-manifest.py`, never hand-edited. Top-level shape:

```jsonc
{
  "schemaVersion": 1,          // bump on any breaking change to this shape
  "generated": "2026-07-13",   // ISO date; excluded from audit.ps1's freshness diff
  "standard_skills": ["code-review", "..."],   // curated, hand-maintained list
  "categories": ["Foundations & Workflow", "..."],  // curated display order, 15 entries — NOT alphabetical, NOT derived from skill data
  "platforms": {
    "claude": {
      "skills": {
        "<skill-name>": {
          "description": "...",       // from SKILL.md frontmatter
          "category": "...",          // from SKILL.md category: frontmatter — "Other" only if unresolved
          "has_commands": true,       // present only if a commands/ subdir exists
          "has_sub_skills": true      // present only if a sub-skills/ subdir exists
        }
      },
      "instructions": {
        "<instruction-name>": {
          "description": "...",
          "model": "opus"             // present only if the instruction's frontmatter sets one
        }
      }
    },
    "codex": { "skills": { "...": { "...": "same shape; category inherited from the claude skill of the same name" } }, "instructions": {} },
    "gemini": { "skills": { "...": {} }, "instructions": {} }
  }
}
```

Category resolution: see the [repo standard's category-frontmatter rule](../docs/requirements/canonical-repo.md).

## Validation pipeline

> **▣ Diagram —** The regeneration pipeline: frontmatter → `generate-manifest.py` →
> `manifest.json` → `generate-catalog.ps1` → `CATALOG.md`, with `audit.ps1` /
> `validate.ps1` verifying each arrow *(type: flow)*

`manifest.json` and `CATALOG.md` are **generated, never hand-edited** — a core rule of
the [repo standard](../docs/requirements/canonical-repo.md), reinforced by the
[reorg charter's parity-follow-through step](../docs/reorg/charter.md). Concretely:

- Any change to skill/instruction frontmatter, category assignment, or bundle
  composition is followed by `python scripts/generate-manifest.py` before commit.
- Any manifest change is followed by `./scripts/generate-catalog.ps1 -Force` before
  commit.
- [`audit.ps1`](audit.ps1) is the mechanical check that both stayed in sync — it
  regenerates a manifest to a temp path and diffs it against the committed one
  (excluding the volatile `generated` timestamp field), and checks `CATALOG.md`
  parity if the file exists. Every reorg deletion PR must leave both regenerated and
  in sync.
- [`validate.ps1`](validate.ps1) is the hard enforcement point: it wraps `audit.ps1`
  plus its own `CATALOG.md` byte-staleness check into a single pass/fail gate.

The gate for this repo runs **locally**, not in hosted CI — a deliberate, approved
deviation from the [repo standard's default](../docs/requirements/canonical-repo.md).
Two pieces:

- **`validate.ps1`** — the gate itself. Regenerates `CATALOG.md` from the manifest.json
  currently on disk and byte-diffs it against the committed file, restoring the
  original bytes afterward regardless of outcome (verified live: a clean repo stays
  bit-for-bit clean after a run, and a deliberately-dirtied repo is restored to that
  same dirty state, not silently cleaned). Then runs `audit.ps1` as a child process
  and folds its exit code in. Mirror-gap and missing-diagram findings stay
  info-severity (per the [reorg charter](../docs/reorg/charter.md)) and never fail
  the gate — only `audit.ps1`'s error-severity findings do. Also asserts that every
  `v*` tag has a matching `## [<version>]` section in `CHANGELOG.md` — a presence
  check, not a byte-diff, because `CHANGELOG.md` derives from `HEAD` rather than a
  committed input (byte-equality would be unsatisfiable — every commit, including the
  one that refreshes it, invalidates it); only tagged sections are checked, the
  volatile `[Unreleased]` block is ignored. Console summary table, or `-Json`. Exit
  `0` clean, `1` findings (stale catalog, a missing changelog section, and/or audit
  errors), `2` execution failure. Measured runtime on the live repo: ~5s (target
  <60s).
- **`install-hooks.ps1`** — opt-in, idempotent installer. Points this repo's *local*
  `core.hooksPath` git config (never global — nothing outside this repo is affected)
  at the committed [`scripts/git-hooks/`](git-hooks/) directory, whose `pre-push`
  hook runs `validate.ps1` and rejects the push on nonzero exit. Preview by default;
  `-Force` applies. Re-running it, installed or not, is always a safe no-op.
  Uninstall with `git config --unset core.hooksPath`. The hook reads git's stdin ref
  list and skips the gate when a push carries no commits — `git push --delete
  <branch>` sends an all-zeros local oid, and there is no new state to validate. This
  keeps batched `/prune` cleanups from paying the gate per deleted branch. A push
  mixing deletions with real commits is still gated.
- The repo `CLAUDE.md` also wires `/ship` to run `validate.ps1` before opening any PR
  and abort on failure — so the gate applies whether or not a contributor has
  installed the git hook.

> **▣ Diagram —** The Zed PreToolUse hook (client-side) vs the `pre-push` git hook
> (git-side) firing in sequence on a push *(type: sequence)*

**Interaction with the global "git-push-opens-Zed" hook** (every hook-interaction
case in this repo gets documented, not assumed — a precedent set in the
[reorg charter](../docs/reorg/charter.md)): that hook is **client-side** — it lives
in `~/.claude/settings.json` and fires only inside Claude Code, before Claude Code's
own `git push` tool call, opening Zed for a human diff review. The `pre-push` git
hook installed by `install-hooks.ps1` is **git-side** — once `core.hooksPath` points
at `scripts/git-hooks`, it fires for *every* `git push` against this repo from *any*
client (a bare terminal, Claude Code, VS Code's Source Control panel, another agent),
because `core.hooksPath` is git config, not an editor setting. The two are
independent and additive: a push from Claude Code trips the Zed review first (a
human looks at the diff), then git invokes this `pre-push` hook as part of the push
operation itself — if `validate.ps1` fails here, git aborts the push regardless of
what happened in Zed. A plain `git push` from a terminal has no Zed review but still
goes through this gate once the hook is installed. See
[`scripts/git-hooks/pre-push`](git-hooks/pre-push)'s header comment for the same
explanation in the file the hook mechanism actually lives in.

**Backlog, not scheduled:** a hosted-CI mirror of this same gate is recorded (not
implemented) in the [implementation plan's backlog](../docs/plans/canonical-repo-plan.md),
per erik's explicit direction to reduce reliance on GitHub Actions for this effort.

## Cross-links

- [`shared/README.md`](../shared/README.md) — the vendor-neutral asset tree
  (`prompts/`, `workflows/`, `configs/`, `plugins/`). Assets under `shared/` carry no
  vendor-specific frontmatter, so they are covered by the same manifest/catalog
  regeneration duty as vendor skills whenever `generate-manifest.py` is extended to
  index them.
- [`claude/README.md`](../claude/README.md) — canonical authoring surface; the
  `category:` frontmatter that `backfill-categories.ps1` writes and
  `generate-manifest.py` reads is documented there (see also the
  [repo standard](../docs/requirements/canonical-repo.md)).
- [`codex/README.md`](../codex/README.md) — on-demand mirror; `push-to-profile.ps1`'s
  "or vendor equivalent" destination and `sync-installed.ps1`'s drift scan both apply
  here once implemented.
- [`gemini/README.md`](../gemini/README.md) — frozen mirror; same applicability note
  as `codex/README.md`.
