#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only health check for the ai-agent-kit archive.

.DESCRIPTION
    Runs a battery of read-only checks over the archive and reports findings, each
    with a severity of error, warn, or info (requirements canonical-repo.md §6):

      * Frontmatter validity + name/dir match .................. [error]
      * Missing category: (severity keyed off the generator's
        categorySource marker — legacy-dict => warn, frontmatter => error) [warn|error]
      * installed-from: present inside the archive ............. [error]
      * Secret-shaped content anywhere under shared/ .......... [error]
      * manifest.json freshness (regenerate to a temp path and
        diff, excluding the volatile `generated` timestamp) .... [error]
      * CATALOG.md parity, both directions, if CATALOG.md exists  [error]
      * Claude<->Codex mirror gap ............................. [info]
      * Missing diagram.html ................................. [info]

    Frontmatter parsing is delegated entirely to
    `generate-manifest.py --validate --json` — one parser for the whole repo, two
    consumers. This script never re-implements YAML parsing.

    The script writes nothing outside a bounded temp location; it is safe to run at
    any point and leaves the working tree untouched.

.PARAMETER RepoRoot
    Archive root to audit. Defaults to the parent of the directory holding this script.

.PARAMETER Json
    Emit findings + summary as a JSON document to stdout instead of a console table.

.OUTPUTS
    Console table (default) or JSON (-Json). Findings are also reflected in the exit code.

.NOTES
    Exit codes (requirements §6, audit refinement):
      0  clean, or warnings/info only (no error-severity findings)
      1  at least one error-severity finding
      2  execution failure (could not complete the audit)

    Portability: #Requires -Version 7.0, no Windows-only APIs, utf8NoBOM, ordinal
    (culture-invariant) sorting. Subprocess calls use an explicit interpreter and an
    argument array (no shell string interpolation) and a bounded, non-predictable
    temp path.

.EXAMPLE
    ./scripts/audit.ps1

.EXAMPLE
    ./scripts/audit.ps1 -Json
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$script:Findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [ValidateSet('error', 'warn', 'info')][string]$Severity,
        [string]$Check,
        [string]$Target,
        [string]$Message
    )
    $script:Findings.Add([pscustomobject]@{
        Severity = $Severity
        Check    = $Check
        Target   = $Target
        Message  = $Message
    })
}

# Ordinal sort helper (culture-invariant determinism).
function Sort-Ordinal {
    param([string[]]$Items)
    $arr = @($Items)
    [Array]::Sort($arr, [System.StringComparer]::Ordinal)
    return $arr
}

# Safely enumerate property (skill) names from a ConvertFrom-Json object. The
# `.PSObject.Properties.Name` shortcut throws under Set-StrictMode when the object
# has zero properties (e.g. an empty platform), so iterate explicitly.
function Get-PropertyNames {
    param($Object)
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $Object.PSObject.Properties) { $names.Add($p.Name) }
    return $names.ToArray()
}

# Resolve a Python interpreter explicitly (cross-platform).
function Get-PythonExe {
    foreach ($candidate in 'python3', 'python') {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "No Python interpreter found on PATH (tried python3, python)."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$exitCode = 0
$tempManifest = $null
$script:ExecError = $null
try {
    $generator = Join-Path $RepoRoot 'scripts/generate-manifest.py'
    if (-not (Test-Path -LiteralPath $generator)) {
        throw "generator not found: $generator"
    }
    $pythonExe = Get-PythonExe

    # --- Frontmatter validation payload (the one and only YAML parse) ---------
    $validateJson = & $pythonExe @($generator, '--validate', '--json')
    if ($LASTEXITCODE -ne 0) {
        throw "generate-manifest.py --validate --json failed (exit $LASTEXITCODE)."
    }
    $validation = $validateJson | ConvertFrom-Json
    $categorySource = $validation.categorySource
    $categorySeverity = if ($categorySource -eq 'frontmatter') { 'error' } else { 'warn' }

    # Convenience: ordered claude/codex skill-name lists.
    $claudeSkills = $validation.platforms.claude.skills
    $codexSkills  = $validation.platforms.codex.skills
    $claudeNames  = Sort-Ordinal (Get-PropertyNames $claudeSkills)
    $codexNames   = Sort-Ordinal (Get-PropertyNames $codexSkills)

    # --- CHECK 1: frontmatter validity + name/dir match [error] ---------------
    # --- CHECK 2: missing category [warn|error] -------------------------------
    # --- CHECK 3: installed-from present in archive [error] -------------------
    # --- CHECK 8: missing diagram.html [info] ---------------------------------
    foreach ($platform in 'claude', 'codex', 'gemini') {
        $skills = $validation.platforms.$platform.skills
        $names = Sort-Ordinal (Get-PropertyNames $skills)
        foreach ($name in $names) {
            $s = $skills.$name

            if ($s.frontmatterStatus -ne 'ok') {
                Add-Finding error 'frontmatter' $s.path `
                    "frontmatter is $($s.frontmatterStatus) (no valid YAML block)"
            }
            elseif (-not $s.nameMatchesDir) {
                $found = if ($null -ne $s.name) { $s.name } else { '(none)' }
                Add-Finding error 'name-dir-match' $s.path `
                    "frontmatter name '$found' does not match directory '$name'"
            }

            if ($s.installedFrom) {
                Add-Finding error 'installed-from' $s.path `
                    "installed-from '$($s.installedFrom)' present inside the archive"
            }
        }
    }

    # Category + diagram checks are scoped to the claude authoring surface:
    # category: is authored on claude and mirrors inherit (D8); diagram.html is a
    # claude skill standard.
    foreach ($name in $claudeNames) {
        $s = $claudeSkills.$name
        if ($s.isOther) {
            Add-Finding $categorySeverity 'category' $s.path `
                "no category assignment (resolves to Other; categorySource=$categorySource)"
        }
        if (-not $s.hasDiagram) {
            Add-Finding info 'diagram' $s.path 'missing diagram.html'
        }
    }

    # --- CHECK 4: secret-shaped content under shared/ [error] -----------------
    $sharedDir = Join-Path $RepoRoot 'shared'
    if (Test-Path -LiteralPath $sharedDir) {
        $secretPatterns = @(
            @{ Label = 'openai-key';      Rx = 'sk-[A-Za-z0-9]{16,}' }
            @{ Label = 'aws-access-key';  Rx = 'AKIA[0-9A-Z]{16}' }
            @{ Label = 'github-token';    Rx = '(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}' }
            @{ Label = 'github-pat';      Rx = 'github_pat_[A-Za-z0-9_]{40,}' }
            @{ Label = 'slack-token';     Rx = 'xox[baprs]-[A-Za-z0-9-]{10,}' }
            @{ Label = 'google-key';      Rx = 'AIza[0-9A-Za-z_\-]{35}' }
            @{ Label = 'jwt';             Rx = 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' }
            @{ Label = 'private-key';     Rx = '-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----' }
            @{ Label = 'conn-string';     Rx = '(?i)\b(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|redis|amqps?|https?)://[^\s:/@]+:[^\s:/@]+@' }
            @{ Label = 'assigned-secret'; Rx = '(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd)\s*[:=]\s*["''][^"''\s]{12,}["'']' }
        )
        $sharedFiles = Get-ChildItem -LiteralPath $sharedDir -Recurse -File -ErrorAction SilentlyContinue
        foreach ($file in $sharedFiles) {
            $lineNo = 0
            foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
                $lineNo++
                foreach ($p in $secretPatterns) {
                    if ($line -match $p.Rx) {
                        $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName).Replace('\', '/')
                        Add-Finding error 'shared-secret' "${rel}:${lineNo}" `
                            "secret-shaped content matched pattern '$($p.Label)'"
                    }
                }
            }
        }
    }

    # --- CHECK 5: manifest freshness [error] ----------------------------------
    $committedManifestPath = Join-Path $RepoRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $committedManifestPath)) {
        Add-Finding error 'manifest-freshness' 'manifest.json' 'manifest.json is missing'
    }
    else {
        $tempManifest = Join-Path ([System.IO.Path]::GetTempPath()) `
            ("aak-audit-" + [guid]::NewGuid().ToString('N') + ".json")
        & $pythonExe @($generator, '--output', $tempManifest) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "generate-manifest.py --output failed (exit $LASTEXITCODE)."
        }
        $committed = Get-Content -LiteralPath $committedManifestPath -Raw | ConvertFrom-Json
        $fresh     = Get-Content -LiteralPath $tempManifest -Raw | ConvertFrom-Json
        # Exclude the volatile `generated` timestamp — a raw diff false-positives on
        # day rollover.
        $committed.PSObject.Properties.Remove('generated')
        $fresh.PSObject.Properties.Remove('generated')
        $committedCanon = $committed | ConvertTo-Json -Depth 50 -Compress
        $freshCanon     = $fresh | ConvertTo-Json -Depth 50 -Compress
        if ($committedCanon -ne $freshCanon) {
            Add-Finding error 'manifest-freshness' 'manifest.json' `
                'manifest.json is stale — run: python scripts/generate-manifest.py'
        }
    }

    # --- CHECK 6: CATALOG parity, both directions, if CATALOG.md exists [error]
    $catalogPath = Join-Path $RepoRoot 'CATALOG.md'
    if (Test-Path -LiteralPath $catalogPath) {
        $catalogText = Get-Content -LiteralPath $catalogPath -Raw
        # Forward: every claude skill in the manifest must appear in CATALOG.md.
        # Match the precise backtick-wrapped slug (the generated-table form) rather
        # than a raw substring — a raw substring false-negatives on names that are
        # substrings of others (e.g. `base` inside `firebase`). NOTE: CATALOG.md's
        # exact format is owned by generate-catalog.ps1 (T6); this matcher assumes the
        # backtick-wrapped-slug convention and T6 re-verifies parity against the live
        # catalog. Until then this branch is exercised via fixture only.
        foreach ($name in $claudeNames) {
            $needle = '`' + $name + '`'
            if (-not $catalogText.Contains($needle)) {
                Add-Finding error 'catalog-parity' 'CATALOG.md' `
                    "skill '$name' present in the archive but missing from CATALOG.md"
            }
        }
        # Reverse: every backtick-wrapped slug in CATALOG.md that looks like a skill
        # name must exist in the manifest (claude or codex).
        $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($n in $claudeNames) { [void]$known.Add($n) }
        foreach ($n in $codexNames)  { [void]$known.Add($n) }
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($m in [regex]::Matches($catalogText, '`([a-z0-9][a-z0-9-]{2,})`')) {
            $slug = $m.Groups[1].Value
            if ($seen.Add($slug) -and -not $known.Contains($slug)) {
                Add-Finding error 'catalog-parity' 'CATALOG.md' `
                    "entry '$slug' present in CATALOG.md but absent from the archive"
            }
        }
    }

    # --- CHECK 7: Claude<->Codex mirror gap [info] ----------------------------
    $codexSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($n in $codexNames) { [void]$codexSet.Add($n) }
    $claudeSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($n in $claudeNames) { [void]$claudeSet.Add($n) }
    foreach ($name in $claudeNames) {
        if (-not $codexSet.Contains($name)) {
            Add-Finding info 'mirror-gap' $name 'present in claude but not mirrored in codex'
        }
    }
    foreach ($name in $codexNames) {
        if (-not $claudeSet.Contains($name)) {
            Add-Finding info 'mirror-gap' $name 'present in codex but absent from claude'
        }
    }
}
catch {
    # Capture and defer: Write-Error is terminating under $ErrorActionPreference=Stop,
    # which would bubble out of the catch and force exit 1 instead of the intended 2.
    $script:ExecError = $_
    $exitCode = 2
}
finally {
    if ($tempManifest -and (Test-Path -LiteralPath $tempManifest)) {
        Remove-Item -LiteralPath $tempManifest -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
$errorCount = @($script:Findings | Where-Object Severity -eq 'error').Count
$warnCount  = @($script:Findings | Where-Object Severity -eq 'warn').Count
$infoCount  = @($script:Findings | Where-Object Severity -eq 'info').Count

if ($exitCode -ne 2) {
    $exitCode = if ($errorCount -gt 0) { 1 } else { 0 }
}

# Stable ordering: error, warn, info; then by check, then target.
$sevRank = @{ error = 0; warn = 1; info = 2 }
$ordered = $script:Findings |
    Sort-Object @{ Expression = { $sevRank[$_.Severity] } }, Check, Target

if ($Json) {
    [pscustomobject]@{
        summary = [pscustomobject]@{
            errors        = $errorCount
            warnings      = $warnCount
            info          = $infoCount
            exitCode      = $exitCode
            executionError = if ($script:ExecError) { "$($script:ExecError)" } else { $null }
        }
        findings = @($ordered)
    } | ConvertTo-Json -Depth 6
}
else {
    if ($ordered) {
        $ordered | Format-Table -AutoSize Severity, Check, Target, Message | Out-String -Width 200 | Write-Host
    }
    Write-Host ("audit: {0} error(s), {1} warning(s), {2} info; exit {3}" -f `
        $errorCount, $warnCount, $infoCount, $exitCode)
    if ($exitCode -eq 2) {
        [Console]::Error.WriteLine("audit: execution failure - results incomplete: $($script:ExecError)")
    }
}

exit $exitCode
