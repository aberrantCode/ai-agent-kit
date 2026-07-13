#Requires -Version 7.0

<#
.SYNOPSIS
    One-time sweep to inject `category:` frontmatter into every Claude SKILL.md.

.DESCRIPTION
    Walks claude/skills/<name>/SKILL.md and, for each skill whose frontmatter has no
    non-empty `category:` field, assigns one and writes it back — implementing D8's
    move from generate-manifest.py's hardcoded skill-to-category dictionary to
    frontmatter as the source of truth. Any skill that already carries a non-empty
    `category:` is left untouched (protects hand assignments); any skill this script
    cannot confidently resolve to a category is left unmodified and reported for
    human assignment rather than guessed.

    STATUS: documented stub (docs/requirements/canonical-repo.md §6). This file exists
    so the automation surface is enumerated before it is implemented; invoking it
    throws and exits non-zero. Per the plan it runs once, in T5, then remains in the
    repo as a re-runnable sweep for any future skill added without a category.

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -Name optionally scopes the sweep
        to a single skill; omitted, every skill under -TargetDir is swept. -TargetDir
        is the skills root to sweep (defaults to claude/skills relative to the repo
        root).
      - Safety: -WhatIf-equivalent preview is the default — the script reports which
        SKILL.md files would gain a `category:` field and what value, without writing.
        -Force performs the write. Every SKILL.md that is modified is backed up
        (or the write refuses) before being overwritten — never a silent clobber.
        Resolved paths are canonicalized and containment-checked against -TargetDir
        before any write, rejecting a crafted -Name that would resolve outside it.
      - Portability: no Windows-only APIs; file output uses utf8NoBOM; the sweep
        processes skills in ordinal (culture-invariant) sorted order and the
        unresolved-skills report is likewise ordinal sorted.

.PARAMETER Name
    Optional: scope the sweep to a single skill name instead of every skill under
    -TargetDir.

.PARAMETER TargetDir
    Skills root to sweep. Defaults to claude/skills relative to the repo root.

.PARAMETER Force
    Apply the sweep: write the resolved `category:` field into each qualifying
    SKILL.md, backing up each file before it is overwritten. Without it, the script
    only reports what would change (preview/report-only default per the shared
    safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — lists the files that would be
    modified without writing them.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console report (default) or JSON object (-Json) listing: skills that already had
    a category (skipped), skills assigned a category (or that would be, without
    -Force), and skills left unresolved for human assignment.

.NOTES
    Exit codes:
      0 = success — sweep complete, no unresolved skills remain
      1 = findings — one or more skills could not be resolved to a category and need
          human assignment
      2 = execution error — unexpected exception (I/O failure, malformed SKILL.md, etc.)

    Currently unimplemented: this stub always throws (exit code 2) regardless of
    parameters, so accidental execution fails loudly.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = 'claude/skills',

    [switch]$Force,

    [switch]$Json
)

throw "TODO: not implemented"
