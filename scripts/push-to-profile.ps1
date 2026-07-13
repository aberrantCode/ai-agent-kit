#Requires -Version 7.0

<#
.SYNOPSIS
    Push a skill bundle from the ai-agent-kit archive to a global vendor profile.

.DESCRIPTION
    Deploys a named skill bundle (SKILL.md + sub-skills/ + commands/ + references/ +
    rules/, whichever are present) to a vendor's global skills profile directory —
    e.g. ~/.claude/skills/<Name>/ for Claude, or the Codex/Gemini equivalent —
    stamping the copy with `installed-from: ai-agent-kit` provenance so it is
    recognized as archive-managed rather than a hand-authored profile skill.

    STATUS: documented stub (docs/requirements/canonical-repo.md §6). This file exists
    so the automation surface is enumerated before it is implemented; invoking it
    throws and exits non-zero.

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -TargetDir overrides the vendor
        profile default (e.g. to push into a non-default profile location); when
        omitted the implementation resolves the platform-appropriate default
        (~/.claude/skills, ~/.codex/skills, ~/.gemini/skills).
      - Safety: default behavior is preview-only; -Force is required to actually
        write files. Before overwriting an existing profile skill, the implementation
        must back it up or refuse — never a silent clobber. Resolved source and
        destination paths must be canonicalized and containment-checked against the
        archive root and the profile root respectively before any write.
      - Portability: no Windows-only APIs (profile root resolution must not assume
        $env:USERPROFILE — use a cross-platform home-directory resolution); file
        output uses utf8NoBOM; any enumeration used for output is ordinal sorted.

.PARAMETER Name
    Name of the skill bundle to push, matching its directory under claude/skills/
    (or the corresponding vendor tree).

.PARAMETER TargetDir
    Destination profile root. Defaults to the platform-appropriate global skills
    directory for the bundle's vendor when omitted.

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
    that were, or would be, copied and the provenance stamp applied.

.NOTES
    Exit codes:
      0 = success — bundle pushed (or, in preview mode, nothing prevented preview)
      1 = validation failure — e.g. -Name not found, destination path fails
          containment check
      2 = execution error — unexpected exception (I/O failure, malformed SKILL.md, etc.)

    Currently unimplemented: this stub always throws (exit code 2) regardless of
    parameters, so accidental execution fails loudly. Behavior it will absorb:
    /push-skill (skills-manager operation referenced by ai-agent-kit's management
    command surface).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = '',

    [switch]$Force,

    [switch]$Json
)

throw "TODO: not implemented"
