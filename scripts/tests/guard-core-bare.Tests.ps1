#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Execution tests for guard-core-bare.ps1. The guard's whole value is a git side effect (detect a
# wrongly-bare working repo, log the flip, repair it), so it is exercised against a throwaway git
# repo rather than by lifting a pure function.
#
#   pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests"

BeforeAll {
    $script:Guard = Join-Path $PSScriptRoot '..\..\claude\skills\session-manager\sub-skills\dispatch\scripts\guard-core-bare.ps1'

    function New-TempRepo {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("guard-cb-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & git -C $dir init -q
        & git -C $dir config user.email t@t.t
        & git -C $dir config user.name test
        Set-Content -LiteralPath (Join-Path $dir 'f.txt') -Value 'x'
        & git -C $dir add f.txt
        & git -C $dir commit -qm init
        return $dir
    }
}

Describe 'guard-core-bare.ps1' {
    It 'repairs a wrongly-bare working repo and logs one event' {
        $repo = New-TempRepo
        $log = Join-Path $repo 'events.jsonl'
        try {
            & git -C $repo config core.bare true
            $r = & $script:Guard -RepoPath $repo -Op 'test' -Phase 'post' -LogPath $log

            $r.WasBare   | Should -BeTrue
            $r.Repaired  | Should -BeTrue
            (& git -C $repo config --get core.bare) | Should -Be 'false'

            Test-Path $log | Should -BeTrue
            $lines = @(Get-Content $log)   # @() so a single-line file is still an array, not a char-indexable string
            $lines.Count | Should -Be 1
            $evt = $lines[0] | ConvertFrom-Json
            $evt.op       | Should -Be 'test'
            $evt.phase    | Should -Be 'post'
            $evt.detected | Should -Be 'core.bare=true'
        }
        finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'is a no-op (no repair, no log) when core.bare is already false' {
        $repo = New-TempRepo
        $log = Join-Path $repo 'events.jsonl'
        try {
            $r = & $script:Guard -RepoPath $repo -Op 'test' -Phase 'pre' -LogPath $log
            $r.WasBare  | Should -BeFalse
            $r.Repaired | Should -BeFalse
            Test-Path $log | Should -BeFalse -Because 'nothing should be logged when the repo is healthy'
        }
        finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'logs but does NOT repair when -NoRepair is passed' {
        $repo = New-TempRepo
        $log = Join-Path $repo 'events.jsonl'
        try {
            & git -C $repo config core.bare true
            $r = & $script:Guard -RepoPath $repo -Op 'test' -Phase 'post' -LogPath $log -NoRepair
            $r.WasBare  | Should -BeTrue
            $r.Repaired | Should -BeFalse
            (& git -C $repo config --get core.bare) | Should -Be 'true'
            (Get-Content $log).Count | Should -Be 1
        }
        finally { Remove-Item $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
