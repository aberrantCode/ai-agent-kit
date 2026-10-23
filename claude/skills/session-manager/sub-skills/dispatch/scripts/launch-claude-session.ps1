<#
.SYNOPSIS
    Launch a fresh Claude Code session in a new Windows Terminal tab with a prompt file injected.

.DESCRIPTION
    A thin Claude-specific specialization over the generic spawn-terminal.ps1 launcher (in the
    `spawn-terminal` bundle). This script owns everything that is specific to spawning *Claude*:

      - the default environment a headless Claude session needs ($script:DefaultEnvironment),
      - the --dangerously-skip-permissions default and the -NoSkipPermissions opt-out,
      - pointing the new session at the prompt file rather than inlining its contents (inlining a
        large, command-heavy prompt as a CLI argument trips Windows Defender's command-line/AMSI
        heuristic -> `claude.exe ... Access is denied`, and a single space in a title likewise makes
        `wt` swallow the rest of the line; passing a short file pointer removes both classes of
        failure),
      - verifying that a `claude` process actually came up.

    Everything generic — the Windows Terminal invocation, per-repo tab color, the pwsh-console
    fallback, and launch verification — is delegated to spawn-terminal.ps1. This script's public
    parameters are unchanged from when it did that work itself.

.PARAMETER PromptPath
    Path to the markdown prompt file. The new session is told, via a short pointer argument, to read
    and follow this file as its first action — the contents are NOT inlined onto claude's command
    line (see the runner note in the body for why: Defender's command-line heuristic).

.PARAMETER WorkingDirectory
    Directory the new session starts in. Defaults to the current location.

.PARAMETER Title
    Tab title. Hyphenate it — spaces are the documented failure above.

.PARAMETER NoSkipPermissions
    Runs without --dangerously-skip-permissions. Spawned sessions pass it by default: nobody is
    sitting in the new tab to answer approval prompts, and a session blocked on a dialog is a
    stalled session. Opt out for a run you intend to babysit.

    With the flag on, the prompt's hard-constraints section is the only thing preventing an
    irreversible action, so it has to be written as the last line of defence.

.PARAMETER SetEnv
    Environment variables for the new session, as KEY=VALUE strings. Merged over the defaults in
    $script:DefaultEnvironment: a key overrides that default, and a bare KEY= drops it. The merged
    set is handed to spawn-terminal.ps1, which sets it inside the runner script so claude inherits
    it as a child process.

    KEY=VALUE rather than a hashtable because `pwsh -File` passes every argument as a string, so a
    hashtable literal fails type conversion at the parameter binder.

.PARAMETER TabColor
    Windows Terminal tab color as #RGB or #RRGGBB. Omit it to let spawn-terminal.ps1 auto-resolve a
    stable per-repo color. Pass a value to override for a single launch.

.PARAMETER ColorScheme
    Windows Terminal color scheme name for the tab (must already be defined in your WT settings),
    e.g. 'AC Phosphor'. Optional.

.PARAMETER DryRun
    Print the claude runner and the delegated launch plan without launching anything.

.PARAMETER HandoffId
    The handoff's correlation id (see the generated prompt's own frontmatter — the `handoff`
    sub-skill mints this once and reuses it everywhere). Written into the dispatch-time row this
    script appends to the handoff registry. If omitted (a launch outside the `handoff` sub-skill
    flow), one is generated so the registry row is never left without a join key.

.PARAMETER RegistryPath
    Override for the handoff registry JSONL path. Defaults to
    `~/.claude/telemetry/handoffs.jsonl`. Exists mainly so tests can point this at a scratch file.

.PARAMETER NoRegistry
    Skip appending the dispatch-time registry row. For callers that manage their own correlation
    (none today) or a launch that should not be tracked.

.EXAMPLE
    pwsh -File launch-claude-session.ps1 -PromptPath C:\repo\docs\PROMPTS\task.md `
        -WorkingDirectory C:\repo\.worktrees\my-task -Title repo-my-task -HandoffId d1-corr-26a

.EXAMPLE
    pwsh -File launch-claude-session.ps1 -PromptPath C:\repo\prompt.md `
        -SetEnv 'ANTHROPIC_LOG=debug', 'FORCE_COLOR='
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PromptPath,
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$Title = 'claude-session',
    [switch]$NoSkipPermissions,
    [string[]]$SetEnv = @(),
    [string]$TabColor,
    [string]$ColorScheme,
    [switch]$DryRun,
    [string]$HandoffId,
    [string]$RegistryPath = (Join-Path $env:USERPROFILE '.claude\telemetry\handoffs.jsonl'),
    [switch]$NoRegistry
)

# Captured before anything below touches $env: — this process IS the parent session (the launch
# happens from inside it), and $script:InheritedSessionVariables is only cleared for the CHILD's
# copy of the environment (via spawn-terminal's -ClearEnv), never for this process's own. Reading
# it later would still work today, but capturing it up front removes any dependency on that not
# changing.
$script:ParentSessionId = $env:CLAUDE_CODE_SESSION_ID

if (-not $HandoffId) {
    # Launch invoked outside the `handoff` sub-skill's frontmatter flow (e.g. a manual run) — mint
    # an id so the registry row this script writes is never without a join key.
    $HandoffId = "lv-$($Title)-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
}

# Pulled out as a pure function (no I/O) so it can be unit-tested by lifting it out of this
# script's AST, the same way scripts/tests/install-skills.Tests.ps1 tests install-skills.ps1 --
# this script has mandatory top-level parameters, so it cannot be dot-sourced directly in a test.
function New-HandoffRegistryRecord {
    param(
        [Parameter(Mandatory = $true)][string]$HandoffId,
        [string]$ParentSessionId,
        [Parameter(Mandatory = $true)][string]$PromptPath,
        [string]$Branch,
        [string]$Repo,
        [datetime]$Timestamp = (Get-Date)
    )
    # Dispatch-time row: child_sid is unknowable here (the CLI assigns it once the child's own
    # transcript exists) -- never guessed. The Correlation section of the generated prompt
    # instructs the child to append the completing row itself on its first turn (see
    # handoff/references/handoff-registry.md).
    [ordered]@{
        handoff_id = $HandoffId
        ts         = $Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        parent_sid = if ($ParentSessionId) { $ParentSessionId } else { $null }
        child_sid  = $null
        prompt     = $PromptPath
        branch     = $Branch
        repo       = $Repo
        source     = 'live'
        confidence = 1.0
    }
}

# Defaults for a session that nobody is sitting in front of. A spawned session inherits nothing
# from the interactive shell, so anything that matters has to be stated here.
#
# Every name below was verified against the installed claude binary rather than taken from
# documentation, because several are easy to get subtly wrong (the stall timeout is
# ..._TIMEOUT_MS, not ..._TIMEOUT).
$script:DefaultEnvironment = @{
    # Terminal capability: without these the tab can degrade to 16-colour output even though
    # Windows Terminal renders 24-bit fine.
    COLORTERM                                = 'truecolor'
    FORCE_COLOR                              = '1'

    # Return to the project root after each bash call. Repos that keep code in worktrees and
    # data/credentials in the main checkout make silent cwd drift a real hazard.
    CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = '1'

    # The 2-minute default kills foreground work that legitimately takes longer — full-account
    # walks, re-encodes, bulk rebuilds. Raise the floor, and the ceiling for the deliberate ones.
    BASH_DEFAULT_TIMEOUT_MS                  = '300000'
    BASH_MAX_TIMEOUT_MS                      = '900000'

    # Fan-out work on long tasks otherwise trips the 10-minute subagent stall timeout.
    CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS      = '900000'

    # One switch covering telemetry, error reporting, surveys, and marketplace calls.
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'

    # Don't throw browser windows at someone who is working in a different window.
    CLAUDE_CODE_ARTIFACT_AUTO_OPEN           = '0'
}

# Identity of the session doing the launching. A new wt window inherits the launcher's environment,
# so without clearing these the spawned claude starts up believing it is a child of the session that
# handed off — sharing its session id and messaging socket instead of being a session of its own.
# Cleared inside the runner (via spawn-terminal -ClearEnv) before claude starts.
$script:InheritedSessionVariables = @(
    'CLAUDE_CODE_CHILD_SESSION'
    'CLAUDE_CODE_SESSION_ID'
    'CLAUDE_CODE_MESSAGING_SOCKET'
    'CLAUDE_CODE_MESSAGING_TOKEN'
    'CLAUDE_PID'
    'CLAUDECODE'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PromptPath)) {
    throw "Prompt file not found: $PromptPath"
}
if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    throw "Working directory not found: $WorkingDirectory"
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw 'claude CLI not found on PATH.'
}

$PromptPath = (Resolve-Path -LiteralPath $PromptPath).Path
$WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$Title = $Title -replace '\s+', '-'

# Locate the generic launcher. The installed global profile mirrors the archive's directory layout
# — spawn-terminal and session-manager are siblings under skills/ in both — so one $PSScriptRoot-
# relative path resolves in dev and in production alike (scripts -> dispatch -> sub-skills -> session-manager -> skills: four levels up).
$spawnTerminal = Join-Path $PSScriptRoot '..\..\..\..\spawn-terminal\scripts\spawn-terminal.ps1'
if (-not (Test-Path -LiteralPath $spawnTerminal)) {
    throw "spawn-terminal.ps1 not found at '$spawnTerminal'. The 'spawn-terminal' skill must be " +
    "installed alongside this bundle (globally: ~/.claude/skills/spawn-terminal/)."
}
$spawnTerminal = (Resolve-Path -LiteralPath $spawnTerminal).Path

# Caller -SetEnv wins over defaults; a bare KEY= drops a default entirely. `pwsh -File` delivers
# `-SetEnv A=1,B=2` as one string with commas intact, so split on commas that introduce a new KEY=.
$pairs = foreach ($raw in $SetEnv) {
    ($raw -replace '"', '') -split ',(?=[^=,]+=)' | Where-Object { $_.Trim() }
}
$environment = $script:DefaultEnvironment.Clone()
foreach ($pair in $pairs) {
    # See spawn-terminal.ps1: a quoted-array `-SetEnv 'K=V','K2=V2'` can arrive with surrounding
    # single quotes still attached to each pair. Strip one matched surrounding pair so the key is
    # not corrupted (which would later serialize into an invalid `$env:'KEY = ...` line).
    $p = $pair.Trim()
    if ($p.Length -ge 2 -and $p[0] -eq "'" -and $p[-1] -eq "'") {
        $p = $p.Substring(1, $p.Length - 2)
    }
    if ($p -notmatch '^([^=]+)=(.*)$') {
        throw "Invalid -SetEnv entry '$pair'. Expected KEY=VALUE (or KEY= to unset)."
    }
    $key, $value = $Matches[1].Trim(), $Matches[2]
    if ([string]::IsNullOrEmpty($value)) { $environment.Remove($key) }
    else { $environment[$key] = $value }
}
# Serialize the merged, unset-applied set back to KEY=VALUE for spawn-terminal. Every value here is
# non-empty (unsets already removed), so passing them as a native array keeps commas-in-values safe.
$mergedSetEnv = $environment.Keys | Sort-Object | ForEach-Object { "$_=$($environment[$_])" }

# The claude runner is what the new tab ultimately executes. spawn-terminal.ps1 sets the working
# directory and environment around it, then dot-invokes it in-process. It passes claude a SHORT
# pointer to the prompt file (see below) — never the prompt's contents — so no large, command-heavy
# argument crosses either a shell parser or Defender's command-line heuristic.
$flags = if ($NoSkipPermissions) { '' } else { '--dangerously-skip-permissions' }
$claudeRunner = Join-Path ([System.IO.Path]::GetTempPath()) "claude-session-$Title-$PID.ps1"
# Pass a short pointer to the prompt file rather than inlining its contents. Windows Defender's
# AMSI/command-line heuristic blocks CreateProcess when a process is spawned with a large argument
# full of shell-command text (icacls/git/Start-Process/[Environment]::…), surfacing as
# "claude.exe … Access is denied" — a command-heavy handoff prompt reliably trips it. Passing the
# path keeps the command line short; the session reads the file itself as its first action, which is
# exactly what a docs/PROMPTS handoff prompt is for.
$promptRef = $PromptPath -replace "'", "''"
@"
claude $flags 'Read and follow the instructions in the file at $promptRef exactly. Its full contents are your task; treat them as your first message.'
"@ | Set-Content -LiteralPath $claudeRunner -Encoding UTF8

# Build the delegated call. Only pass color flags the caller actually supplied, so an omitted
# -TabColor still lets spawn-terminal auto-resolve the per-repo color.
$spawnParams = @{
    ScriptPath       = $claudeRunner
    WorkingDirectory = $WorkingDirectory
    Title            = $Title
    SetEnv           = $mergedSetEnv
    ClearEnv         = $script:InheritedSessionVariables
    VerifyProcess    = 'claude'
}
if ($TabColor) { $spawnParams.TabColor = $TabColor }
if ($ColorScheme) { $spawnParams.ColorScheme = $ColorScheme }
if ($DryRun) { $spawnParams.DryRun = $true }

if ($DryRun) {
    Write-Host "Claude runner (not launched): $claudeRunner"
    Get-Content -LiteralPath $claudeRunner | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
}

& $spawnTerminal @spawnParams

if (-not $DryRun) {
    Write-Host "Prompt: $PromptPath"

    if (-not $NoRegistry) {
        # Branch/repo come from git, not a caller-supplied string: WorkingDirectory is the
        # worktree dispatch just launched into, and its checked-out branch plus its common dir's
        # parent (the MAIN checkout, not this worktree) are ground truth — see
        # cc_transcripts.common_dir for the same git-authoritative pattern on the read side.
        $branch = (& git -C $WorkingDirectory rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) { $branch = $null }
        $repo = $null
        $commonDir = (& git -C $WorkingDirectory rev-parse --git-common-dir 2>$null)
        if ($LASTEXITCODE -eq 0 -and $commonDir) {
            if (-not [System.IO.Path]::IsPathRooted($commonDir)) {
                $commonDir = Join-Path $WorkingDirectory $commonDir
            }
            $repo = Split-Path -Parent (Resolve-Path -LiteralPath $commonDir).Path
        }

        $registryRecord = New-HandoffRegistryRecord -HandoffId $HandoffId `
            -ParentSessionId $script:ParentSessionId -PromptPath $PromptPath `
            -Branch $branch -Repo $repo
        $registryDir = Split-Path -Parent $RegistryPath
        if (-not (Test-Path -LiteralPath $registryDir)) {
            New-Item -ItemType Directory -Path $registryDir -Force | Out-Null
        }
        ($registryRecord | ConvertTo-Json -Compress -Depth 3) |
            Add-Content -LiteralPath $RegistryPath -Encoding UTF8
        Write-Host "Handoff registry: $HandoffId -> $RegistryPath (child_sid pending child self-report)"
    }
}
