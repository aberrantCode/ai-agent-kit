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

    Category assignment source: the seed map below was built once (T5) by taking the
    CATEGORIES dict that lived in generate-manifest.py and reconciling every entry
    against the pre-rewrite root README.md "Full skill list" table — the README won
    on every conflict (it was the newer, more granular source; see
    docs/requirements/canonical-repo.md D8 and the T5 PR description for the full
    reconciliation record). Skills present only in the README table, or only in the
    dict, were carried through as-is. The category *display order* below
    (CategoryOrder) mirrors the README's "Categories at a glance" table and is reused
    verbatim by generate-manifest.py's curated `categories` ordering.

    This script is re-runnable: any future skill added to claude/skills/ without a
    `category:` field will show up as either resolved (if its name happens to already
    be a key in the seed map below) or unresolved (reported for human assignment, and
    for a permanent addition to this file's seed map).

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -Name optionally scopes the sweep
        to a single skill; omitted, every skill under -TargetDir is swept. -TargetDir
        is the skills root to sweep (defaults to claude/skills relative to the repo
        root).
      - Safety: preview is the default — the script reports which SKILL.md files
        would gain a `category:` field and what value, without writing. -Force
        performs the write. Every SKILL.md that would be modified is backed up to a
        bounded temp directory before being overwritten — never a silent clobber.
        Resolved paths are canonicalized and containment-checked against -TargetDir
        before any write, rejecting a crafted -Name that would resolve outside it.
      - Portability: no Windows-only APIs; file output uses utf8NoBOM; the sweep
        processes skills in ordinal (culture-invariant) sorted order and the
        unresolved-skills report is likewise ordinal sorted. Each file's existing
        line-ending style (CRLF/LF) is detected and preserved — never normalized.

.PARAMETER Name
    Optional: scope the sweep to a single skill name instead of every skill under
    -TargetDir.

.PARAMETER TargetDir
    Skills root to sweep. Defaults to claude/skills relative to the repo root.

.PARAMETER Force
    Apply the sweep: write the resolved `category:` field into each qualifying
    SKILL.md, backing up each file (to a bounded temp directory) before it is
    overwritten. Without it, the script only reports what would change (preview
    default per the shared safety convention).

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

.EXAMPLE
    ./scripts/backfill-categories.ps1
    Preview: report what would change without writing anything.

.EXAMPLE
    ./scripts/backfill-categories.ps1 -Force
    Apply the sweep to every skill under claude/skills.

.EXAMPLE
    ./scripts/backfill-categories.ps1 -Name typescript -Force
    Apply the sweep to a single skill.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = 'claude/skills',

    [switch]$Force,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Seed mapping (T5 one-time reconciliation — see .DESCRIPTION above).
# ---------------------------------------------------------------------------
$script:CategorySeed = [ordered]@{
    'ac-logo' = 'UI & Design'
    'ac-opbta-ops' = 'Tooling & DevOps'
    'accumulated-feature-branch-workflow' = 'Foundations & Workflow'
    'add-feature' = 'Foundations & Workflow'
    'add-remote-installer' = 'Tooling & DevOps'
    'additive-merge-conflict-resolution' = 'Foundations & Workflow'
    'aeo-optimization' = 'SEO & Web Presence'
    'agentic-development' = 'AI & LLM'
    'ai-models' = 'AI & LLM'
    'analyze-conversations' = 'Foundations & Workflow'
    'android-java' = 'Mobile (Native)'
    'android-kotlin' = 'Mobile (Native)'
    'aws-aurora' = 'Databases & Storage'
    'aws-dynamodb' = 'Databases & Storage'
    'azure-cosmosdb' = 'Databases & Storage'
    'base' = 'Foundations & Workflow'
    'brand-token-extraction-and-documentation' = 'Frontend & UI'
    'chrome-extension-builder' = 'Frontend Frameworks'
    'cloudflare-d1' = 'Databases & Storage'
    'code-deduplication' = 'Foundations & Workflow'
    'code-review' = 'Code Quality'
    'codex-review' = 'Code Quality'
    'comment-harvesting' = 'Research & OSINT'
    'commit-hygiene' = 'Foundations & Workflow'
    'composition-patterns' = 'Frontend Frameworks'
    'content-aware-file-renaming' = 'Tooling & DevOps'
    'conversation-history-mining-for-domain-knowledge' = 'Foundations & Workflow'
    'credentials' = 'Security & Credentials'
    'crlf-gitattributes-normalization' = 'Code Quality'
    'css-variables-for-multi-theme-reskin' = 'Frontend & UI'
    'csv-driven-llm-pipeline' = 'AI & LLM'
    'database-schema' = 'Databases & Storage'
    'deploy-idempotency-two-pass-gate' = 'DevOps & Tooling'
    'deployment-driver-pin-rewrite-from-release-tag-source-of-truth' = 'DevOps & Tooling'
    'design-critique-to-safe-refactor' = 'Code Quality'
    'diagnostics-probe-design' = 'DevOps & Tooling'
    'doc-coauthoring' = 'UI & Design'
    'existing-repo' = 'Foundations & Workflow'
    'explain-code' = 'UI & Design'
    'extraction-reporting' = 'Research & OSINT'
    'feature-start' = 'Foundations & Workflow'
    'file-reconstruction' = 'Research & OSINT'
    'finishing-a-development-branch' = 'Foundations & Workflow'
    'firebase' = 'Databases & Storage'
    'firewall-alias-as-indirection' = 'DevOps & Tooling'
    'fix-start' = 'Foundations & Workflow'
    'fleet-cp1252-mojibake-fix' = 'DevOps & Tooling'
    'flutter' = 'Frontend Frameworks'
    'frame-content-recognition' = 'Research & OSINT'
    'frame-extraction' = 'Research & OSINT'
    'frontend-design' = 'UI & Design'
    'gemini-review' = 'Code Quality'
    'github' = 'Foundations & Workflow'
    'gpu-workload-placement-and-arbitration' = 'DevOps & Tooling'
    'grafana-dashboard-engineer' = 'DevOps & Tooling'
    'grafana-dashboard-workflow' = 'DevOps & Tooling'
    'graphify' = 'Tooling & DevOps'
    'guide-assistant' = 'Foundations & Workflow'
    'honcho' = 'AI & LLM'
    'honcho-deriver-queue-health-diagnostics' = 'DevOps & Tooling'
    'iterative-audit-gate-with-streak-reset' = 'Foundations & Workflow'
    'iterative-development' = 'Foundations & Workflow'
    'klaviyo' = 'Third-Party Integrations'
    'llm-patterns' = 'AI & LLM'
    'logo-restylizer' = 'UI & Design'
    'lvm-thin-pool-diagnostics-recovery' = 'DevOps & Tooling'
    'marko' = 'Languages & Runtimes'
    'medusa' = 'Commerce & Payments'
    'ms-teams-apps' = 'Third-Party Integrations'
    'multi-perspective-dns-diagnostic-ladder' = 'DevOps & Tooling'
    'nodejs-backend' = 'Languages & Runtimes'
    'parallel-subagent-fanout' = 'Foundations & Workflow'
    'playwright-testing' = 'Code Quality'
    'posthog-analytics' = 'Third-Party Integrations'
    'pre-pr' = 'Foundations & Workflow'
    'project-manager' = 'AI & LLM'
    'project-plan-task-reconciliation' = 'Foundations & Workflow'
    'project-tooling' = 'Tooling & DevOps'
    'pwa-development' = 'Frontend Frameworks'
    'python' = 'Languages & Runtimes'
    'react-best-practices' = 'Frontend Frameworks'
    'react-native' = 'Frontend Frameworks'
    'react-virtualization-with-jsdom-measurement' = 'Frontend & UI'
    'react-web' = 'Frontend Frameworks'
    'reactive-ui-state-with-delegated-event-routing' = 'Frontend & UI'
    'recursive-batch-handoff' = 'Foundations & Workflow'
    'reddit-ads' = 'Third-Party Integrations'
    'reddit-api' = 'Third-Party Integrations'
    'remote-installer' = 'Tooling & DevOps'
    'requesting-code-review' = 'Foundations & Workflow'
    'retro-fit-spec' = 'Foundations & Workflow'
    'scanner-plugin-integration' = 'Code Quality'
    'security' = 'Security & Credentials'
    'security-aware-persistence-design' = 'Code Quality'
    'self-contained-html-artifact-with-inline-assets' = 'Frontend & UI'
    'self-paced-loop-iteration' = 'Foundations & Workflow'
    'session-management' = 'Foundations & Workflow'
    'shell-helper-migration' = 'DevOps & Tooling'
    'shell-migration-skip-taxonomy' = 'DevOps & Tooling'
    'shopify-apps' = 'Commerce & Payments'
    'side-effect-free-helper-library' = 'DevOps & Tooling'
    'site-architecture' = 'SEO & Web Presence'
    'skills-manager' = 'Tooling & DevOps'
    'sops-secrets' = 'Security & Credentials'
    'spec-align' = 'Foundations & Workflow'
    'spec-consistency-doc-refactoring-pattern' = 'Foundations & Workflow'
    'stale-symbolic-ref-detection-and-repair' = 'Foundations & Workflow'
    'start-app' = 'Tooling & DevOps'
    'state-file-driven-multi-turn-resumption' = 'Foundations & Workflow'
    'subagent-driven-development' = 'Foundations & Workflow'
    'supabase' = 'Databases & Storage'
    'supabase-nextjs' = 'Databases & Storage'
    'supabase-node' = 'Databases & Storage'
    'supabase-python' = 'Databases & Storage'
    'tdd-workflow' = 'Code Quality'
    'team-coordination' = 'Foundations & Workflow'
    'transcript-acquisition' = 'Research & OSINT'
    'two-surface-observability-reconciliation' = 'DevOps & Tooling'
    'typescript' = 'Languages & Runtimes'
    'ui-mobile' = 'Mobile (Native)'
    'ui-redesign-with-snapshot-regeneration' = 'Frontend & UI'
    'ui-testing' = 'UI & Design'
    'ui-web' = 'UI & Design'
    'usage-limit-reducer' = 'Tooling & DevOps'
    'user-journeys' = 'UI & Design'
    'vercel-deploy-claimable' = 'Tooling & DevOps'
    'video-acquisition' = 'Research & OSINT'
    'visual-explainer' = 'UI & Design'
    'web-content' = 'SEO & Web Presence'
    'web-design-guidelines' = 'UI & Design'
    'web-payments' = 'Commerce & Payments'
    'what-next' = 'Foundations & Workflow'
    'woocommerce' = 'Commerce & Payments'
    'workspace' = 'Tooling & DevOps'
    'worldview-layer-scaffold' = 'Research & OSINT'
    'worldview-shader-preset' = 'Research & OSINT'
    'youtube-extraction' = 'Research & OSINT'
    'youtube-prd-forensics' = 'Research & OSINT'
}

# Curated category display order — mirrors the README "Categories at a glance" table
# and is reused verbatim by generate-manifest.py's CategoryOrder list.
$script:CategoryOrder = @(
    'Foundations & Workflow',
    'Languages & Runtimes',
    'Frontend Frameworks',
    'Frontend & UI',
    'Mobile (Native)',
    'UI & Design',
    'Databases & Storage',
    'Code Quality',
    'Security & Credentials',
    'AI & LLM',
    'Commerce & Payments',
    'Third-Party Integrations',
    'SEO & Web Presence',
    'Tooling & DevOps',
    'DevOps & Tooling',
    'Research & OSINT'
)

# Ordinal sort helper (culture-invariant determinism) — mirrors audit.ps1.
function Sort-Ordinal {
    param([string[]]$Items)
    $arr = @($Items)
    [Array]::Sort($arr, [System.StringComparer]::Ordinal)
    return $arr
}

$script:Findings = [ordered]@{
    AlreadyHadCategory = [System.Collections.Generic.List[string]]::new()
    Assigned           = [System.Collections.Generic.List[object]]::new()
    Unresolved         = [System.Collections.Generic.List[string]]::new()
    SkippedNoSkillMd   = [System.Collections.Generic.List[string]]::new()
}

$exitCode = 0
$script:ExecError = $null
$backupDir = $null

try {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

    $TargetDirFull = if ([System.IO.Path]::IsPathRooted($TargetDir)) {
        [System.IO.Path]::GetFullPath($TargetDir)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $TargetDir))
    }

    if (-not (Test-Path -LiteralPath $TargetDirFull -PathType Container)) {
        throw "TargetDir not found: $TargetDirFull"
    }

    # Determine the sweep set: -Name scopes to one skill (with a containment check
    # against -TargetDir to reject path traversal), otherwise every subdirectory.
    if ($Name) {
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $TargetDirFull $Name))
        $rootWithSep = $TargetDirFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $candidate.StartsWith($rootWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Resolved -Name path escapes -TargetDir (path traversal rejected): $Name"
        }
        $skillNames = @($Name)
    }
    else {
        $dirNames = @(Get-ChildItem -LiteralPath $TargetDirFull -Directory | ForEach-Object { $_.Name })
        $skillNames = Sort-Ordinal $dirNames
    }

    if ($Force) {
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) `
            ('ai-agent-kit-backfill-categories-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    foreach ($skillName in $skillNames) {
        $skillDir = Join-Path $TargetDirFull $skillName
        $skillMd = Join-Path $skillDir 'SKILL.md'

        if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
            if ($Name) {
                throw "SKILL.md not found for -Name '$Name': $skillMd"
            }
            $script:Findings.SkippedNoSkillMd.Add($skillName)
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($skillMd)
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        $usesCrlf = $content.Contains("`r`n")
        $eol = if ($usesCrlf) { "`r`n" } else { "`n" }
        $lines = [regex]::Split($content, "`r`n|`n")

        # Same naive frontmatter delimiter search generate-manifest.py uses (the one
        # parser this repo trusts) — a lone '---' line opens, the next lone '---'
        # line closes.
        if ($lines.Count -lt 2 -or $lines[0] -ne '---') {
            $script:Findings.Unresolved.Add($skillName)
            continue
        }
        $closeIdx = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq '---') { $closeIdx = $i; break }
        }
        if ($closeIdx -lt 0) {
            $script:Findings.Unresolved.Add($skillName)
            continue
        }

        $frontmatterLines = $lines[1..($closeIdx - 1)]
        $hasCategory = $false
        foreach ($fl in $frontmatterLines) {
            if ($fl -match '^category:\s*(\S.*)$') { $hasCategory = $true; break }
        }
        if ($hasCategory) {
            $script:Findings.AlreadyHadCategory.Add($skillName)
            continue
        }

        if (-not $script:CategorySeed.Contains($skillName)) {
            $script:Findings.Unresolved.Add($skillName)
            continue
        }

        $category = $script:CategorySeed[$skillName]
        $record = [pscustomobject]@{ Skill = $skillName; Category = $category; Applied = $false }
        $script:Findings.Assigned.Add($record)

        if ($Force -and $PSCmdlet.ShouldProcess($skillMd, "Add category: '$category'")) {
            # 'name:' is always the first frontmatter field in this archive (verified
            # across all 138 skills at T5 authoring time) — insert immediately after it.
            $nameLineIdx = 1
            if ($lines[$nameLineIdx] -notmatch '^name:\s*\S') {
                throw "Unexpected frontmatter shape in $skillMd — 'name:' is not the first field; refusing to write"
            }

            # Back up before overwrite (bounded temp dir, never inside the repo).
            $backupPath = Join-Path $backupDir "$skillName.SKILL.md.bak"
            [System.IO.File]::Copy($skillMd, $backupPath, $true)

            $newLines = New-Object System.Collections.Generic.List[string]
            $newLines.AddRange([string[]]$lines[0..$nameLineIdx])
            $newLines.Add("category: $category")
            if ($nameLineIdx + 1 -le $lines.Count - 1) {
                $newLines.AddRange([string[]]$lines[($nameLineIdx + 1)..($lines.Count - 1)])
            }

            $newContent = [string]::Join($eol, $newLines)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($skillMd, $newContent, $utf8NoBom)
            $record.Applied = $true
        }
    }
}
catch {
    $script:ExecError = $_
    $exitCode = 2
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if ($exitCode -ne 2) {
    $exitCode = if ($script:Findings.Unresolved.Count -gt 0) { 1 } else { 0 }
}

$unresolvedSorted = @(Sort-Ordinal @($script:Findings.Unresolved))
$alreadySorted = @(Sort-Ordinal @($script:Findings.AlreadyHadCategory))
$assignedSorted = @($script:Findings.Assigned | Sort-Object -Property Skill)

if ($Json) {
    [pscustomobject]@{
        summary = [pscustomobject]@{
            alreadyHadCategory = $alreadySorted.Count
            assigned           = $assignedSorted.Count
            unresolved         = $unresolvedSorted.Count
            skippedNoSkillMd   = $script:Findings.SkippedNoSkillMd.Count
            applied            = $Force.IsPresent
            exitCode           = $exitCode
            executionError     = if ($script:ExecError) { "$($script:ExecError)" } else { $null }
        }
        alreadyHadCategory = $alreadySorted
        assigned           = $assignedSorted
        unresolved         = $unresolvedSorted
        skippedNoSkillMd   = @(Sort-Ordinal @($script:Findings.SkippedNoSkillMd))
    } | ConvertTo-Json -Depth 6
}
else {
    $mode = if ($Force) { 'APPLY' } else { 'PREVIEW' }
    Write-Host "backfill-categories: mode=$mode"
    if ($assignedSorted.Count -gt 0) {
        Write-Host "`nAssigned:"
        $assignedSorted | Format-Table -AutoSize Skill, Category, Applied | Out-String -Width 200 | Write-Host
    }
    if ($alreadySorted.Count -gt 0) {
        Write-Host "Already had category: ($($alreadySorted.Count)) $($alreadySorted -join ', ')"
    }
    if ($unresolvedSorted.Count -gt 0) {
        Write-Host "`nUNRESOLVED (needs human assignment):"
        $unresolvedSorted | ForEach-Object { Write-Host "  - $_" }
    }
    Write-Host ("`nbackfill-categories: {0} already-had, {1} assigned, {2} unresolved; exit {3}" -f `
        $alreadySorted.Count, $assignedSorted.Count, $unresolvedSorted.Count, $exitCode)
    if ($exitCode -eq 2) {
        [Console]::Error.WriteLine("backfill-categories: execution failure: $($script:ExecError)")
    }
}

exit $exitCode
