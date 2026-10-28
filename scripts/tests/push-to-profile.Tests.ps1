#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Integration tests for scripts/push-to-profile.ps1 dependency handling (`requires:`).
# The script resolves its archive from its own location, so each test copies it into a
# disposable fake archive under $TestDrive and pushes into a fake profile there.
#
#   pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests"

BeforeAll {
    $script:Source = Join-Path $PSScriptRoot '..\push-to-profile.ps1'
    $script:Pwsh   = (Get-Process -Id $PID).Path

    function New-FakeArchive {
        param([hashtable]$Skills)
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        Copy-Item -LiteralPath $script:Source -Destination (Join-Path $root 'scripts\push-to-profile.ps1')
        foreach ($name in $Skills.Keys) {
            $dir = Join-Path $root "claude\skills\$name"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dir 'SKILL.md'), "---`nname: $name`n$($Skills[$name])---`nbody`n")
        }
        return $root
    }

    function Invoke-Push {
        param([string]$Root, [string[]]$Arguments)
        $target = Join-Path $Root 'profile\skills'
        $out = & $script:Pwsh -NoProfile -File (Join-Path $Root 'scripts\push-to-profile.ps1') -TargetDir $target -Json @Arguments 2>&1 | Out-String
        [pscustomobject]@{ Code = $LASTEXITCODE; Result = ($out | ConvertFrom-Json); Target = $target }
    }
}

Describe 'push-to-profile requires: handling' {
    It 'pushes a declared dependency alongside the requested skill' {
        $root = New-FakeArchive @{ app = "requires: [dep]`n"; dep = '' }
        $r = Invoke-Push $root @('-Name', 'app', '-Force')
        $r.Code | Should -Be 0
        Test-Path (Join-Path $r.Target 'app\SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $r.Target 'dep\SKILL.md') | Should -BeTrue
        @($r.Result.dependencies.name) | Should -Be @('dep')
    }

    It 'expands requires: transitively, dependencies first, and survives a cycle' {
        $root = New-FakeArchive @{ app = "requires:`n  - mid`n"; mid = "requires: [leaf, app]`n"; leaf = '' }
        $r = Invoke-Push $root @('-Name', 'app', '-Force')
        $r.Code | Should -Be 0
        @($r.Result.dependencies.name) | Should -Be @('leaf', 'mid')
        foreach ($n in 'app', 'mid', 'leaf') { Test-Path (Join-Path $r.Target "$n\SKILL.md") | Should -BeTrue }
    }

    It 'previews dependencies without writing anything' {
        $root = New-FakeArchive @{ app = "requires: [dep]`n"; dep = '' }
        $r = Invoke-Push $root @('-Name', 'app')
        $r.Code | Should -Be 0
        @($r.Result.dependencies.name) | Should -Be @('dep')
        $r.Result.dependencies[0].message | Should -Match '^Would push'
        Test-Path $r.Target | Should -BeFalse
    }

    It 'skips dependencies under -NoDeps' {
        $root = New-FakeArchive @{ app = "requires: [dep]`n"; dep = '' }
        $r = Invoke-Push $root @('-Name', 'app', '-Force', '-NoDeps')
        $r.Code | Should -Be 0
        @($r.Result.dependencies).Count | Should -Be 0
        Test-Path (Join-Path $r.Target 'dep') | Should -BeFalse
    }

    It 'fails validation and writes nothing when a dependency is not in the archive' {
        $root = New-FakeArchive @{ app = "requires: [ghost]`n" }
        $r = Invoke-Push $root @('-Name', 'app', '-Force')
        $r.Code | Should -Be 1
        $r.Result.message | Should -Match 'ghost'
        Test-Path $r.Target | Should -BeFalse
    }

    It 'pushes a skill with no requires: exactly as before' {
        $root = New-FakeArchive @{ solo = '' }
        $r = Invoke-Push $root @('-Name', 'solo', '-Force')
        $r.Code | Should -Be 0
        @($r.Result.dependencies).Count | Should -Be 0
        Test-Path (Join-Path $r.Target 'solo\SKILL.md') | Should -BeTrue
    }
}
