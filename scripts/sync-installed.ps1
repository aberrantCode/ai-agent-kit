#Requires -Version 7.0

<#
.SYNOPSIS
    Diff archive-installed skill copies in a project (or fleet root) against the
    ai-agent-kit archive.

.DESCRIPTION
    Scans a target directory tree for skill bundles stamped `installed-from:
    ai-agent-kit` (or the legacy `installed-from: llm_skills`), compares each against
    its source under claude/skills/<Name> (or the corresponding vendor tree), and
    reports drift: missing files, content differences, and stale bundles.

    Report-only by default. Writing changes back to installed copies requires
    -Force, and any overwrite backs up the existing file first (no silent clobber).

    STATUS: documented stub (docs/requirements/canonical-repo.md §6). This file exists
    so the automation surface is enumerated before it is implemented; invoking it
    throws and exits non-zero.

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -Name optionally scopes the scan
        to a single skill; omitted, all stamped installs under -TargetDir are scanned.
        -TargetDir is the project or fleet root to scan (defaults to the current
        directory).
      - Safety: -Force is the explicit write/apply switch called out in the §6
        contract table ("report-only by default, -Apply writes with
        backup-before-overwrite") — this script uses the shared -Force parameter to
        satisfy that same "explicit apply" semantics rather than introducing a
        separate -Apply flag, per the binding common parameter surface. Every write
        under -Force backs up the existing file before overwriting it. All scanned
        and written paths are canonicalized and containment-checked against
        -TargetDir before any write (no path traversal via a crafted installed-copy
        path).
      - Portability: no Windows-only APIs; file output uses utf8NoBOM; the drift
        report is ordinal (culture-invariant) sorted by skill name.

.PARAMETER Name
    Optional: scope the scan to a single skill name instead of every stamped install
    found under -TargetDir.

.PARAMETER TargetDir
    Project or fleet root to scan for archive-installed skill copies. Defaults to the
    current directory.

.PARAMETER Force
    Apply the diff: write archive content over drifted installed copies, backing up
    each file before it is overwritten. Without it, the script only reports drift
    (report-only default per the shared safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — lists the files that would be
    written without writing them.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console drift report (default) or JSON object (-Json) listing each stamped
    installed copy, its drift status, and (under -Force) which files were backed up
    and rewritten.

.NOTES
    Exit codes:
      0 = success — scan clean, no drift found (or, under -Force, drift resolved)
      1 = findings — drift detected and not resolved (report-only run, or -Force run
          that could not resolve every finding)
      2 = execution error — unexpected exception (I/O failure, malformed SKILL.md, etc.)

    Currently unimplemented: this stub always throws (exit code 2) regardless of
    parameters, so accidental execution fails loudly. Behavior it will absorb:
    /update-skill (skills-manager operation referenced by ai-agent-kit's management
    command surface).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = '.',

    [switch]$Force,

    [switch]$Json
)

throw "TODO: not implemented"
