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
      * Profile skill shadowing a bundle sub-skill ............ [warn]
      * Output Contract inlined in every sub-skill (no dangling
        pointer) .............................................. [error]
      * Command "sub-skills/<x>" path resolution + github
        op-dir shadow ......................................... [error]
      * Template *.ps1 non-ASCII bytes ...................... [error]
      * Template *.ps1 PSScriptAnalyzer (degrades if absent) . [warn|info]
      * Command-file frontmatter YAML validity .............. [error]
      * templates/hooks/** pinned eol=lf in .gitattributes .. [error]

    The profile-shadowing check is the one check that reads outside the archive. A
    loose top-level skill in `~/.claude/skills/<name>` whose name matches a sub-skill
    of an installed bundle wins name resolution over the bundle's copy, so `/<name>`
    silently runs the stale loose file instead of the maintained bundle sub-skill.
    Severity is `warn`, never `error`: this is a condition of one developer's profile,
    and validate.ps1 gates pull requests on this script's exit code — an archive PR
    must never fail because of unrelated local state. The check no-ops when the
    profile directory does not exist (CI, fresh clones).

    Frontmatter parsing is delegated entirely to
    `generate-manifest.py --validate --json` — one parser for the whole repo, two
    consumers. This script never re-implements YAML parsing.

    The script writes nothing outside a bounded temp location; it is safe to run at
    any point and leaves the working tree untouched.

.PARAMETER RepoRoot
    Archive root to audit. Defaults to the parent of the directory holding this script.

.PARAMETER Json
    Emit findings + summary as a JSON document to stdout instead of a console table.

.PARAMETER ProfileRoot
    Installed-skills directory to check for bundle shadowing. Defaults to
    `~/.claude/skills`. Ignored when the path does not exist.

.PARAMETER SkipProfile
    Skip the profile-shadowing check entirely (archive-only audit).

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
    [switch]$Json,
    [string]$ProfileRoot,
    [switch]$SkipProfile
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

    # --- CHECK 8: profile skill shadowing a bundle sub-skill [warn] -----------
    # A loose top-level skill whose name matches a sub-skill of an INSTALLED bundle
    # wins name resolution, so /<name> runs the stale loose copy and the bundle's
    # maintained sub-skill never loads. This is how /merge and /release silently
    # resolved to six stale standalone skills until 2026-07-19.
    #
    # Reads outside the archive by design, so it is guarded three ways: it is
    # skippable, it no-ops when the profile is absent, and it can only ever emit
    # `warn` - an archive PR must not fail on one developer's local state.
    if (-not $SkipProfile) {
        if (-not $ProfileRoot) {
            $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
            if ($homeDir) { $ProfileRoot = Join-Path $homeDir '.claude/skills' }
        }

        if ($ProfileRoot -and (Test-Path -LiteralPath $ProfileRoot)) {
            $installed = @(Get-ChildItem -LiteralPath $ProfileRoot -Directory -ErrorAction SilentlyContinue)

            # sub-skill name -> owning bundle name
            $subSkillOwner = @{}
            foreach ($bundle in $installed) {
                $subDir = Join-Path $bundle.FullName 'sub-skills'
                if (-not (Test-Path -LiteralPath $subDir)) { continue }
                foreach ($sub in @(Get-ChildItem -LiteralPath $subDir -Directory -ErrorAction SilentlyContinue)) {
                    # First bundle wins; a name owned by two bundles is reported against
                    # the first encountered, which is enough to surface the collision.
                    if (-not $subSkillOwner.ContainsKey($sub.Name)) {
                        $subSkillOwner[$sub.Name] = $bundle.Name
                    }
                }
            }

            foreach ($top in $installed) {
                if (-not $subSkillOwner.ContainsKey($top.Name)) { continue }
                # A bundle is not a shadow of its own sub-skill namespace.
                if ($subSkillOwner[$top.Name] -eq $top.Name) { continue }

                $owner = $subSkillOwner[$top.Name]
                $hasSkillMd = Test-Path -LiteralPath (Join-Path $top.FullName 'SKILL.md')
                $detail = if ($hasSkillMd) { 'loose SKILL.md' } else { 'empty stub directory' }

                Add-Finding warn 'profile-shadowing' $top.Name (
                    "$detail in the profile shadows sub-skill '$($top.Name)' of bundle " +
                    "'$owner' - /$($top.Name) resolves to the loose copy, not the bundle. " +
                    "Import anything unique to the archive, then delete " +
                    "$(Join-Path $ProfileRoot $top.Name)")
            }
        }
    }

    # -----------------------------------------------------------------------
    # Bundle-hardening lints (github-skill audit 2026-07-22, T12). These read
    # skill/command/template files on disk directly rather than through the
    # manifest; each Test-Path-guards its roots so it no-ops on partial trees.
    # -----------------------------------------------------------------------
    $platformSkillRoots = @(
        (Join-Path $RepoRoot 'claude/skills')
        (Join-Path $RepoRoot 'codex/skills')
    ) | Where-Object { Test-Path -LiteralPath $_ }

    # --- CHECK 9: pointer-only Output-Contract lint [error] (CU-11 / F-KO-04) --
    # A sub-skill can load standalone, so a bare "obey the parent Output Contract"
    # pointer resolves to nothing. Every sub-skill that references an Output
    # Contract must inline its own "## Output Contract" section. Files that never
    # mention the contract are not contract-bearing and are skipped; keying on the
    # section heading (not a bundle-specific marker string) lets bundles use their
    # own contract wording while still catching the dangling-pointer regression.
    $subSkillFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($root in $platformSkillRoots) {
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue) {
            if ($f.FullName.Replace('\', '/') -match '/sub-skills/[^/]+/SKILL\.md$') {
                $subSkillFiles.Add($f.FullName)
            }
        }
    }
    foreach ($file in $subSkillFiles) {
        $text = Get-Content -LiteralPath $file -Raw
        if ([string]::IsNullOrEmpty($text)) { continue }
        if ($text -notmatch 'Output Contract') { continue }
        if ($text -notmatch '(?m)^#{2,}\s+Output Contract') {
            $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $file).Replace('\', '/')
            Add-Finding error 'output-contract' $rel `
                'references an Output Contract but inlines no "## Output Contract" section (dangling pointer - F-KO-04)'
        }
    }

    # --- CHECK 10: sub-skill path resolution + github op-dir shadow [error] ----
    # (CU-12) 10a: every "sub-skills/<x>" a command references must resolve to a
    # real SKILL.md in that bundle - a renamed sub-skill otherwise 404s silently.
    foreach ($root in $platformSkillRoots) {
        foreach ($cmd in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue) {
            $norm = $cmd.FullName.Replace('\', '/')
            if ($norm -notmatch '/commands/[^/]+\.md$') { continue }
            $bundleRoot = $norm -replace '/commands/[^/]+\.md$', ''
            $body = Get-Content -LiteralPath $cmd.FullName -Raw
            if ([string]::IsNullOrEmpty($body)) { continue }
            $seenRef = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($m in [regex]::Matches($body, 'sub-skills/([a-z0-9][a-z0-9-]*)')) {
                $sub = $m.Groups[1].Value
                if (-not $seenRef.Add($sub)) { continue }
                if (-not (Test-Path -LiteralPath (Join-Path $bundleRoot "sub-skills/$sub/SKILL.md"))) {
                    $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $cmd.FullName).Replace('\', '/')
                    Add-Finding error 'subskill-path' $rel `
                        "references sub-skills/$sub but that sub-skill's SKILL.md does not exist in the bundle"
                }
            }
        }
    }
    # 10b: no top-level skill may shadow a github bundle sub-skill (the F-KO-05
    # class - how /merge silently resolved to a stale loose copy). Scoped to the
    # github bundle on purpose: youtube-extraction and project-manager deliberately
    # dual-publish some sub-skills as top-level skills, so an archive-wide rule
    # would false-fail on accepted state.
    foreach ($platform in 'claude', 'codex') {
        $ghSub = Join-Path $RepoRoot "$platform/skills/github/sub-skills"
        $skillsRoot = Join-Path $RepoRoot "$platform/skills"
        if (-not (Test-Path -LiteralPath $ghSub)) { continue }
        foreach ($sub in Get-ChildItem -LiteralPath $ghSub -Directory -ErrorAction SilentlyContinue) {
            if (Test-Path -LiteralPath (Join-Path $skillsRoot $sub.Name)) {
                Add-Finding error 'op-dir-shadow' "$platform/skills/$($sub.Name)" `
                    "top-level skill shadows github sub-skill '$($sub.Name)' - /$($sub.Name) would resolve to the loose copy, not the bundle (F-KO-05)"
            }
        }
    }

    # --- CHECK 11+12: template .ps1 hygiene [error | warn] (CU-14a/b) ----------
    $templatePs1 = [System.Collections.Generic.List[string]]::new()
    foreach ($root in $platformSkillRoots) {
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue) {
            if ($f.FullName.Replace('\', '/') -match '/templates/') { $templatePs1.Add($f.FullName) }
        }
    }
    # 11: non-ASCII bytes (the mojibake class, F-KO-10). Byte scan; first offender.
    foreach ($file in $templatePs1) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $line = 1
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -eq 10) { $line++ }
            elseif ($bytes[$i] -gt 127) {
                $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $file).Replace('\', '/')
                Add-Finding error 'template-nonascii' "${rel}:${line}" `
                    'non-ASCII byte in a template .ps1 (mojibake class - F-KO-10); use ASCII glyphs'
                break
            }
        }
    }
    # 12: PSScriptAnalyzer (unapproved verbs, Write-Host; F-KO-11). Degrade to a
    # skipped note when the module is absent (mirrors the gitleaks-absent pattern).
    if ($templatePs1.Count -gt 0) {
        if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
            foreach ($file in $templatePs1) {
                $diags = Invoke-ScriptAnalyzer -Path $file -Severity Warning, Error -ErrorAction SilentlyContinue
                foreach ($d in $diags) {
                    $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $file).Replace('\', '/')
                    Add-Finding warn 'template-lint' "${rel}:$($d.Line)" "$($d.RuleName): $($d.Message)"
                }
            }
        }
        else {
            Add-Finding info 'template-lint' 'templates/**/*.ps1' `
                'PSScriptAnalyzer not installed - template lint skipped (Install-Module PSScriptAnalyzer)'
        }
    }

    # --- CHECK 13: command frontmatter YAML validity [error] (CU-14c / F-KO-16)
    # audit already validates SKILL.md frontmatter via generate-manifest.py;
    # command files are the uncovered gap. A present leading `---` block must parse
    # as YAML (a colon-space once broke init-repo.md's frontmatter and the harness
    # silently used the body as the description). Real YAML parse via PyYAML - never
    # a hand-rolled split. Files with no `---` block carry no frontmatter and are
    # skipped. Degrades to an info note when PyYAML is absent.
    $cmdYamlPy = @'
import sys, glob, os
root = sys.argv[1]
try:
    import yaml
except ImportError:
    print("__NO_YAML__"); sys.exit(0)
pats = ['claude/skills/**/commands/*.md', 'codex/skills/**/commands/*.md',
        'claude/commands/*.md', 'codex/commands/*.md']
seen = set()
for pat in pats:
    for p in glob.glob(os.path.join(root, pat), recursive=True):
        rp = os.path.normpath(p)
        if rp in seen:
            continue
        seen.add(rp)
        try:
            t = open(p, encoding='utf-8').read()
        except Exception as e:
            print(f"{p}\t{str(e).splitlines()[0]}"); continue
        if not t.startswith('---'):
            continue
        end = t.find('\n---', 3)
        if end == -1:
            print(f"{p}\tunterminated frontmatter block (opening --- has no closing ---)"); continue
        try:
            yaml.safe_load(t[3:end])
        except Exception as e:
            print(f"{p}\t{str(e).splitlines()[0]}")
'@
    $yamlRaw = & $pythonExe @('-c', $cmdYamlPy, $RepoRoot)
    if ($LASTEXITCODE -eq 0 -and $yamlRaw) {
        foreach ($ln in $yamlRaw) {
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            if ($ln.Trim() -eq '__NO_YAML__') {
                Add-Finding info 'command-frontmatter' 'commands/*.md' `
                    'PyYAML not installed - command frontmatter validation skipped'
                continue
            }
            $parts = $ln -split "`t", 2
            $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $parts[0]).Replace('\', '/')
            $msg = if ($parts.Count -gt 1) { $parts[1] } else { 'invalid YAML frontmatter' }
            Add-Finding error 'command-frontmatter' $rel "invalid YAML frontmatter: $msg"
        }
    }

    # --- CHECK 14: hook-template LF coverage [error] (CU-14d / F-KO-19) --------
    # Every templates/hooks/** file must be pinned eol=lf in .gitattributes - a
    # CRLF shebang is a broken interpreter path on POSIX sh (incl. Git-for-Windows'
    # bundled sh.exe). git check-attr is the authoritative evaluator, so no
    # .gitattributes glob matching is re-implemented here.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        foreach ($root in $platformSkillRoots) {
            foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue) {
                if ($f.FullName.Replace('\', '/') -notmatch '/templates/hooks/[^/]+$') { continue }
                $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $f.FullName).Replace('\', '/')
                $attr = & git -C $RepoRoot check-attr eol -- $rel 2>$null
                if (($attr -join "`n") -notmatch 'eol:\s*lf') {
                    Add-Finding error 'hook-eol' $rel `
                        'not pinned eol=lf in .gitattributes (CRLF-shebang hazard - F-KO-19)'
                }
            }
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
