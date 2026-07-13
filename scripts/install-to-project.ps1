#Requires -Version 7.0

<#
.SYNOPSIS
    Install a skill bundle from the ai-agent-kit archive into a target project.

.DESCRIPTION
    Copies a named skill bundle (SKILL.md + sub-skills/ + commands/ + references/ +
    rules/, whichever are present) from claude/skills/<Name> into a target project's
    .claude/skills/<Name>/, stamping the copy with `installed-from: ai-agent-kit`
    frontmatter so later `sync-installed.ps1` runs and /audit-skills can recognize it
    as a managed install.

    STATUS: documented stub (docs/requirements/canonical-repo.md §6). This file exists
    so the automation surface is enumerated before it is implemented; invoking it
    throws and exits non-zero.

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning.
      - Safety: default behavior is preview-only (report what would be copied);
        -Force is required to actually write files. Before overwriting an existing
        file, the implementation must back it up or refuse — never a silent clobber.
        All resolved paths (skill source dir, project .claude/skills/<Name> dest) must
        be canonicalized and containment-checked against their respective roots before
        any write, to reject path traversal via a crafted -Name or -TargetDir.
      - Portability: no Windows-only APIs; file output uses utf8NoBOM; any directory
        or file enumeration used for output is ordinal (culture-invariant) sorted.

.PARAMETER Name
    Name of the skill bundle to install, matching its directory under claude/skills/.

.PARAMETER TargetDir
    Root of the target project. The bundle is installed under
    <TargetDir>/.claude/skills/<Name>/. Defaults to the current directory.

.PARAMETER Force
    Required to actually write files. Without it, the script only reports what would
    be copied (preview/report-only default per the shared safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — lists the files that would be
    written without writing them.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console report (default) or JSON object (-Json) describing the bundle members
    that were, or would be, copied and the frontmatter stamp applied.

.NOTES
    Exit codes:
      0 = success — bundle installed (or, in preview mode, nothing prevented preview)
      1 = validation failure — e.g. -Name not found under claude/skills/, target path
          fails containment check
      2 = execution error — unexpected exception (I/O failure, malformed SKILL.md, etc.)

    Currently unimplemented: this stub always throws (exit code 2) regardless of
    parameters, so accidental execution fails loudly. Behavior it will absorb:
    .claude/commands/install-skill.md -> skills-manager /install-skill operation.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = '.',

    [switch]$Force,

    [switch]$Json
)

throw "TODO: not implemented"
