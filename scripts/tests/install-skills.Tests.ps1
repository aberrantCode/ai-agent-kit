#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Unit tests for the bundle-deploy helpers in the root install-skills.ps1.
# The installer runs its interactive flow at load time, so the functions under test are
# lifted out of the file's AST and defined here; network calls are mocked.
#
#   pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests"

BeforeAll {
    $installer = Join-Path $PSScriptRoot '..\..\install-skills.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
    foreach ($fn in $functions) { . ([scriptblock]::Create($fn.Extent.Text)) }

    $Branch  = 'main'
    $ApiBase = 'https://api.github.com/repos/o/r'
    $RawBase = 'https://raw.githubusercontent.com/o/r/main'

    # Fake archive: every blob path maps to its content.
    $script:Files = [ordered]@{
        'claude/skills/demo/SKILL.md'                  = "---`nname: demo`n---`nbody`n"
        'claude/skills/demo/diagram.html'              = '<html></html>'
        'claude/skills/demo/commands/demo-cmd.md'      = "---`ndescription: run demo`n---`n"
        'claude/skills/demo/commands/notes.txt'        = 'not a command'
        'claude/skills/demo/sub-skills/part/SKILL.md'  = "---`nname: part`n---`n"
        'claude/skills/demo/references/ref.md'         = 'ref'
        'claude/skills/demo/assets/run.sh'             = 'echo hi'
        'claude/skills/demo-extra/SKILL.md'            = "---`nname: demo-extra`n---`n"
    }
    $script:Truncated = $false

    function New-TreeResponse {
        $entries = foreach ($p in $script:Files.Keys) { [pscustomobject]@{ path = $p; type = 'blob' } }
        [pscustomobject]@{ truncated = $script:Truncated; tree = @($entries) }
    }
}

Describe 'Resolve-BundleTarget' {
    BeforeAll {
        $skillDir    = Join-Path $TestDrive 'skills\demo'
        $commandsDir = Join-Path $TestDrive 'commands'
    }

    It 'nests ordinary members under the skill directory' {
        Resolve-BundleTarget -RelPath 'references/ref.md' -SkillDir $skillDir -CommandsDir $commandsDir |
            Should -Be (Join-Path $skillDir 'references\ref.md')
        Resolve-BundleTarget -RelPath 'sub-skills/part/SKILL.md' -SkillDir $skillDir -CommandsDir $commandsDir |
            Should -Be (Join-Path $skillDir 'sub-skills\part\SKILL.md')
    }

    It 'relocates top-level companion commands to the commands directory' {
        Resolve-BundleTarget -RelPath 'commands/demo-cmd.md' -SkillDir $skillDir -CommandsDir $commandsDir |
            Should -Be (Join-Path $commandsDir 'demo-cmd.md')
    }

    It 'skips diagram.html and non-command files under commands/' {
        Resolve-BundleTarget -RelPath 'diagram.html' -SkillDir $skillDir -CommandsDir $commandsDir | Should -BeNullOrEmpty
        Resolve-BundleTarget -RelPath 'commands/notes.txt' -SkillDir $skillDir -CommandsDir $commandsDir | Should -BeNullOrEmpty
    }
}

Describe 'Add-Provenance' {
    It 'stamps once after the opening fence and is idempotent' {
        $path = Join-Path $TestDrive 'SKILL.md'
        Set-Content -LiteralPath $path -Value "---`nname: x`n---`n" -NoNewline
        Add-Provenance $path
        Add-Provenance $path
        $text = Get-Content -LiteralPath $path -Raw
        $text | Should -Match '^---\r?\ninstalled-from: ai-agent-kit\nname: x'
        ([regex]::Matches($text, 'installed-from:')).Count | Should -Be 1
    }

    It 'leaves a file without frontmatter alone' {
        $path = Join-Path $TestDrive 'plain.md'
        Set-Content -LiteralPath $path -Value 'no frontmatter' -NoNewline
        Add-Provenance $path
        Get-Content -LiteralPath $path -Raw | Should -Be 'no frontmatter'
    }
}

Describe 'Install-SkillBundle' {
    BeforeEach {
        $script:RepoTree = $null
        $script:Truncated = $false
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $skillsDir   = Join-Path $root 'skills'
        $commandsDir = Join-Path $root 'commands'

        Mock Invoke-RestMethod { New-TreeResponse } -ParameterFilter { $Uri -like '*/git/trees/*' }
        Mock Invoke-RestMethod {
            $prefix = ($Uri -replace '^.*/contents/', '') -replace '\?.*$', ''
            $seen = @{}
            foreach ($p in $script:Files.Keys) {
                if (-not $p.StartsWith("$prefix/")) { continue }
                $rest = $p.Substring($prefix.Length + 1)
                $head = $rest.Split('/')[0]
                if ($seen[$head]) { continue }
                $seen[$head] = $true
                if ($rest.Contains('/')) {
                    [pscustomobject]@{ name = $head; type = 'dir'; path = "$prefix/$head" }
                } else {
                    [pscustomobject]@{ name = $head; type = 'file'; path = $p }
                }
            }
        } -ParameterFilter { $Uri -like '*/contents/*' }
        Mock Invoke-WebRequest {
            $rel = [uri]::UnescapeDataString(($Uri -replace '^https://raw\.githubusercontent\.com/o/r/main/', ''))
            [System.IO.File]::WriteAllText($OutFile, $script:Files[$rel])
        }
    }

    It 'deploys the whole bundle with commands relocated and SKILL.md files stamped' {
        Install-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir | Should -BeTrue

        $skill = Join-Path $skillsDir 'demo'
        Join-Path $skill 'references\ref.md' | Should -Exist
        Join-Path $skill 'assets\run.sh'     | Should -Exist
        Join-Path $skill 'diagram.html'      | Should -Not -Exist
        Join-Path $skill 'commands'          | Should -Not -Exist
        Join-Path $commandsDir 'demo-cmd.md' | Should -Exist
        Join-Path $commandsDir 'notes.txt'   | Should -Not -Exist

        Get-Content (Join-Path $skill 'SKILL.md') -Raw                  | Should -Match 'installed-from: ai-agent-kit'
        Get-Content (Join-Path $skill 'sub-skills\part\SKILL.md') -Raw  | Should -Match 'installed-from: ai-agent-kit'
        Get-Content (Join-Path $commandsDir 'demo-cmd.md') -Raw         | Should -Not -Match 'installed-from'
    }

    It 'does not pick up files from a skill whose name shares the prefix' {
        Install-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir | Should -BeTrue
        Join-Path $skillsDir 'demo-extra' | Should -Not -Exist
        Get-Content (Join-Path $skillsDir 'demo\SKILL.md') -Raw | Should -Match 'name: demo\n'
    }

    It 'reads the repo tree once across several installs' {
        Install-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir | Out-Null
        Install-SkillBundle -SkillName 'demo-extra' -Platform 'claude' -InstallDir $skillsDir | Out-Null
        Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -like '*/git/trees/*' } -Times 1 -Exactly
    }

    It 'falls back to the contents API when the tree is truncated' {
        $script:Truncated = $true
        Install-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir | Should -BeTrue
        Join-Path $skillsDir 'demo\sub-skills\part\SKILL.md' | Should -Exist
        Join-Path $commandsDir 'demo-cmd.md' | Should -Exist
        Should -Invoke Invoke-RestMethod -ParameterFilter { $Uri -like '*/contents/*' }
    }

    It 'records the deployed commands with their hashes, in the push-to-profile format' {
        Install-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir | Should -BeTrue
        $record = Get-Content (Join-Path $skillsDir 'demo\.deployed-commands.json') -Raw | ConvertFrom-Json
        @($record.commands.PSObject.Properties.Name) | Should -Be @('demo-cmd.md')
        $record.commands.'demo-cmd.md' | Should -Be (Get-FileHash (Join-Path $commandsDir 'demo-cmd.md') -Algorithm SHA256).Hash
    }

    It 'returns false and writes nothing when the bundle has no SKILL.md' {
        Install-SkillBundle -SkillName 'missing' -Platform 'claude' -InstallDir $skillsDir -WarningAction SilentlyContinue |
            Should -BeFalse
        Join-Path $skillsDir 'missing' | Should -Not -Exist
    }
}

Describe 'Remove-SkillBundle' {
    It 'removes the bundle and its relocated commands, leaving other commands' {
        $script:RepoTree = $null
        $script:Truncated = $false
        Mock Invoke-RestMethod { New-TreeResponse } -ParameterFilter { $Uri -like '*/git/trees/*' }

        $root = Join-Path $TestDrive 'remove'
        $skillsDir   = Join-Path $root 'skills'
        $commandsDir = Join-Path $root 'commands'
        New-Item -ItemType Directory -Force (Join-Path $skillsDir 'demo'), $commandsDir | Out-Null
        Set-Content (Join-Path $skillsDir 'demo\SKILL.md') 'x'
        Set-Content (Join-Path $commandsDir 'demo-cmd.md') 'x'
        Set-Content (Join-Path $commandsDir 'other.md') 'x'

        Remove-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir

        Join-Path $skillsDir 'demo'          | Should -Not -Exist
        Join-Path $commandsDir 'demo-cmd.md' | Should -Not -Exist
        Join-Path $commandsDir 'other.md'    | Should -Exist
    }

    It 'also removes recorded commands the archive no longer ships, unless edited since' {
        $script:RepoTree = $null
        $script:Truncated = $false
        Mock Invoke-RestMethod { New-TreeResponse } -ParameterFilter { $Uri -like '*/git/trees/*' }

        $root = Join-Path $TestDrive 'remove-recorded'
        $skillsDir   = Join-Path $root 'skills'
        $commandsDir = Join-Path $root 'commands'
        New-Item -ItemType Directory -Force (Join-Path $skillsDir 'demo'), $commandsDir | Out-Null
        Set-Content (Join-Path $skillsDir 'demo\SKILL.md') 'x'
        Set-Content (Join-Path $commandsDir 'dropped.md') 'old'
        Set-Content (Join-Path $commandsDir 'edited.md') 'old'
        $record = [ordered]@{ commands = [ordered]@{
            'dropped.md' = (Get-FileHash (Join-Path $commandsDir 'dropped.md') -Algorithm SHA256).Hash
            'edited.md'  = (Get-FileHash (Join-Path $commandsDir 'edited.md') -Algorithm SHA256).Hash } }
        Set-Content (Join-Path $skillsDir 'demo\.deployed-commands.json') ($record | ConvertTo-Json)
        Add-Content (Join-Path $commandsDir 'edited.md') 'local change'

        Remove-SkillBundle -SkillName 'demo' -Platform 'claude' -InstallDir $skillsDir

        Join-Path $commandsDir 'dropped.md' | Should -Not -Exist
        Join-Path $commandsDir 'edited.md'  | Should -Exist
    }
}
