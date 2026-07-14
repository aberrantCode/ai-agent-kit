# scripts/

All lifecycle automation for the archive — installation, deployment, sync, catalog
generation, and (in a later PR) validation — as real scripts, so the archive's
deploy/install/overlay/integration lifecycle no longer depends solely on LLM-driven
slash commands (G3, `docs/requirements/canonical-repo.md`).

Two trees hold scripts today: `claude/skills/skills-manager` implements the
interactive, chat-driven slash-command surface (`/install-skill`,
`/audit-skills`, `/push-skill`, `/update-skill`, ...); this directory holds
the deterministic, non-interactive PowerShell/Python equivalents that the
slash commands are expected to grow into or call out to. Nothing here changes
what a *deployed* skill does at runtime (N4) — this is archive tooling only.

## Script inventory

| Script | State | Contract summary |
|---|---|---|
| `generate-manifest.py` | modified (T5) | Generates `manifest.json` from skill/instruction frontmatter. Accepts `--output PATH` (default unchanged: repo-root `manifest.json`) and `--validate --json` (read-only; emits parsed frontmatter + per-skill validation records — including the `categorySource` marker — for `audit.ps1` to consume, so there is one frontmatter parser for the whole repo). `category:` frontmatter is now the sole per-skill source of truth (D8) — the old hardcoded skill→category dict is gone; `categorySource` reports `frontmatter`. Mirrors (`codex`, `gemini`) have no `category:` frontmatter of their own and inherit their source Claude skill's category by name. The curated category **display order** (15 entries, not alphabetical) remains an explicit list in the script and populates `manifest.json`'s `categories` array. Manifest output also gains a top-level `schemaVersion` field (see "manifest.json shape" below). |
| `audit.ps1` | implemented | Read-only archive health check: frontmatter validity + name/dir match, missing `category:` (severity keyed off the generator's `categorySource` marker — now `frontmatter`, so a missing category is `error`), `installed-from:` presence in the archive, secret-shaped content under `shared/`, manifest freshness (timestamp-excluded), CATALOG parity (both directions, when `CATALOG.md` exists), Claude↔Codex mirror gap, missing `diagram.html`. Delegates all YAML parsing to `generate-manifest.py --validate --json`. Console table + `-Json`. See `docs/requirements/canonical-repo.md` §6 for the full check list and severities. |
| `install-to-project.ps1` | stub | Copies a skill bundle (SKILL.md + sub-skills/ + commands/ + references/ + rules/) into a target project's `.claude/`, stamping `installed-from: ai-agent-kit`. |
| `push-to-profile.ps1` | stub | Deploys a bundle to `~/.claude/skills/` (or the vendor equivalent), stamping provenance. |
| `sync-installed.ps1` | stub | Scans a project (or fleet root) for stamped installed copies, diffs against the archive; report-only by default, `-Force` writes with backup-before-overwrite. |
| `generate-catalog.ps1` | implemented (T6) | Renders `CATALOG.md` from `manifest.json`: per-vendor skill tables (grouped by the curated category order, ordinal-sorted within category), per-vendor instruction tables (incl. Codex/Gemini — OQ4), a global-commands table, and per-class `shared/` asset listings. Byte-stable output (ordinal sort via `[System.StringComparer]::Ordinal`, `utf8NoBOM`, explicit LF, pinned via `.gitattributes`) — verified identical across repeated runs and under `tr-TR` culture / `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`. `-Json` emits the underlying data model instead of markdown; default is preview-only, `-Force` writes. |
| `backfill-categories.ps1` | **implemented — executed** (T5) | Injected `category:` frontmatter into all 138 Claude `SKILL.md` files in one sweep (seed mapping: the old `generate-manifest.py` `CATEGORIES` dict reconciled against the pre-rewrite root `README.md` skill table, README winning on conflict). Skips any file with a non-empty `category:` already set (idempotent — safe to re-run for future skills); preview by default, explicit `-Force` to write, backs up each modified file to a bounded temp dir first; reports unresolvable skills for human assignment (none were unresolved in the T5 run). |
| `validate.ps1` | not yet present — planned (T8) | Local validation gate: regenerates `CATALOG.md` from the committed manifest and fails on `git diff --exit-code`, checks manifest staleness via `audit.ps1`'s timestamp-excluded freshness check, runs `audit.ps1` (fails the gate on exit 1/2). |
| `install-hooks.ps1` | not yet present — planned (T8) | Opt-in installer for a repo-local `core.hooksPath` `pre-push` hook that runs `validate.ps1`. |
| `install-skills.ps1` (repo root, not in this directory) | implemented — grandfathered exception | The published remote-bootstrap one-liner. Stays at PowerShell 5.1 (see "Grandfathered exception" below) and at the repo root (see "Root-installer URL contract" below). Not moved into `scripts/` — its location *is* its contract (D5). |

"Stub" here means the binding definition from `docs/requirements/canonical-repo.md`
§6: the file exists, comment-based help documents purpose/parameters/exit
codes/intended behavior, and the body is `throw "TODO: not implemented"` — so
accidental execution fails loudly (exit code ≠ 0) instead of doing nothing or doing
the wrong thing silently.

Every task that flips a script from stub to implemented updates the **State** column
above in the same PR (binding rule from the canonical-repo plan).

## PowerShell 7 floor, and the grandfathered exception

Every script in this directory declares `#Requires -Version 7.0` and is written to be
cross-platform — no Windows-only APIs, `utf8NoBOM` output encoding, ordinal
(culture-invariant) sorting — per D3. This keeps a future Python port (OQ2) and a
future hosted-CI mirror of the local validation gate cheap, even though today's gate
runs locally only.

`install-skills.ps1` at the repo root is the **one intentional exception**: it stays
on `#Requires -Version 5.1` because it is the target of a raw-GitHub remote-bootstrap
one-liner (see below) and Windows ships PowerShell 5.1 out of the box with no install
step, while PowerShell 7 is an opt-in install. Lowering the floor there maximizes the
chance the one-liner works on an unmodified Windows machine. This is a deliberate,
narrow carve-out for that one script — it does not license a 5.1 floor anywhere else
in this repository.

## Shared conventions (all lifecycle scripts)

Binding for every script in this directory (`docs/requirements/canonical-repo.md` §6):

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

## Root-installer URL contract (D5)

`install-skills.ps1` lives at the repo root, not in `scripts/`, because its path is a
**published contract**: the remote one-liner

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
   publishes a SHA256 for `install-skills.ps1` (P3, `docs/requirements/canonical-repo.md`
   §7). Fetch the tagged copy, compute its SHA256 locally, and compare against the
   published value before executing it:
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

## `manifest.json` shape (P1)

`manifest.json` is the single machine-readable source of truth (P1,
`docs/requirements/canonical-repo.md` §7) — generated by `python
scripts/generate-manifest.py`, never hand-edited. Top-level shape:

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
          "category": "...",          // from SKILL.md `category:` frontmatter (D8) — "Other" only if unresolved
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

Category resolution (D8, landed in T5): every Claude `SKILL.md` carries its own
`category:` frontmatter field, backfilled once by `scripts/backfill-categories.ps1`
and read directly by the generator — there is no hardcoded skill→category mapping
left in `generate-manifest.py`. `codex` and `gemini` skills carry no `category:` of
their own; the generator looks up their category from the Claude skill of the same
name (mirrors inherit, per D8). The `categories` array's **order** is still curated
by hand in the generator (`CATEGORY_ORDER`) so `CATALOG.md` and any other rendering
keeps a stable, non-alphabetical reading order — this is a display-order list only,
never a source of per-skill category truth.

`--validate --json` emits a parallel, more detailed payload (parsed frontmatter +
per-skill validation records, including a top-level `categorySource` marker —
`frontmatter` once T5 landed, previously `legacy-dict`) for `audit.ps1` to consume;
see that script's `.SYNOPSIS` for its exact shape.

## Regeneration rule

`manifest.json` and `CATALOG.md` are **generated, never hand-edited** (G5; charter §6
"Parity Follow-Through," step 2). Concretely:

- Any change to skill/instruction frontmatter, category assignment, or bundle
  composition is followed by `python scripts/generate-manifest.py` before commit.
- Any manifest change is followed by `./scripts/generate-catalog.ps1 -Force` before
  commit (implemented T6).
- `audit.ps1` (T4) is the mechanical check that both stayed in sync — it regenerates
  a manifest to a temp path and diffs it against the committed one (excluding the
  volatile `generated` timestamp field), and checks `CATALOG.md` parity if the file
  exists. Every reorg deletion PR must leave both regenerated and in sync — this is
  the concrete enforcement point for charter §6's parity rule.
- Until the local validation gate (`validate.ps1`, T8) ships, this rule is
  soft-enforced: run `audit.ps1` manually before opening a PR.

## Cross-links

- [`shared/README.md`](../shared/README.md) — the vendor-neutral asset tree
  (`prompts/`, `workflows/`, `configs/`, `plugins/`). Assets under `shared/` carry no
  vendor-specific frontmatter, so they are covered by the same manifest/catalog
  regeneration duty as vendor skills whenever `generate-manifest.py` is extended to
  index them.
- [`claude/README.md`](../claude/README.md) — canonical authoring surface;
  `category:` frontmatter (D8) that `backfill-categories.ps1` writes and
  `generate-manifest.py` reads is documented there.
- [`codex/README.md`](../codex/README.md) — on-demand mirror; `push-to-profile.ps1`'s
  "or vendor equivalent" destination and `sync-installed.ps1`'s drift scan both apply
  here once implemented.
- [`gemini/README.md`](../gemini/README.md) — frozen mirror; same applicability note
  as `codex/README.md`.

This is the concrete PR2 → PR3 dependency: T1/T2 established the `shared/` tree and
vendor-tree READMEs this directory's scripts operate against and cross-link.
