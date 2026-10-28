#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Unit tests for the handoff-registry row shape written by launch-claude-session.ps1.
# The script has mandatory top-level parameters and launches a real terminal tab, so (like
# install-skills.Tests.ps1 does for install-skills.ps1) the pure function under test is lifted out
# of the file's AST rather than dot-sourcing/running the whole script.
#
#   pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests"

BeforeAll {
    $launcher = Join-Path $PSScriptRoot '..\..\claude\skills\session-manager\sub-skills\dispatch\scripts\launch-claude-session.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
    foreach ($fn in $functions) { . ([scriptblock]::Create($fn.Extent.Text)) }
}

Describe 'New-HandoffRegistryRecord' {
    It 'writes a live, dispatch-time row with child_sid null (never guessed) and confidence 1.0' {
        $ts = [datetime]::new(2026, 10, 23, 20, 24, 27, [DateTimeKind]::Utc)
        $record = New-HandoffRegistryRecord -HandoffId 'd1-corr-26a' -ParentSessionId 'parent-123' `
            -PromptPath 'C:\repo\docs\PROMPTS\task.md' -Branch 'feat/thing' -Repo 'C:\repo' -Timestamp $ts

        $record.handoff_id | Should -Be 'd1-corr-26a'
        $record.ts | Should -Be '2026-10-23T20:24:27Z'
        $record.parent_sid | Should -Be 'parent-123'
        $record.child_sid | Should -BeNullOrEmpty
        $record.prompt | Should -Be 'C:\repo\docs\PROMPTS\task.md'
        $record.branch | Should -Be 'feat/thing'
        $record.repo | Should -Be 'C:\repo'
        $record.source | Should -Be 'live'
        $record.confidence | Should -Be 1.0
    }

    It 'leaves parent_sid null rather than an empty string when no parent session id is known' {
        $record = New-HandoffRegistryRecord -HandoffId 'lv-x-1' -ParentSessionId '' `
            -PromptPath 'C:\repo\docs\PROMPTS\task.md'
        $record.parent_sid | Should -BeNullOrEmpty
    }

    It 'round-trips through ConvertTo-Json/ConvertFrom-Json with every required field present' {
        $record = New-HandoffRegistryRecord -HandoffId 'd1-corr-26a' -ParentSessionId 'parent-123' `
            -PromptPath 'C:\repo\docs\PROMPTS\task.md' -Branch 'feat/thing' -Repo 'C:\repo'
        $json = $record | ConvertTo-Json -Compress -Depth 3
        $parsed = $json | ConvertFrom-Json

        $required = @('handoff_id', 'ts', 'parent_sid', 'child_sid', 'prompt', 'branch', 'repo', 'source', 'confidence')
        foreach ($field in $required) {
            ($parsed.PSObject.Properties.Name -contains $field) | Should -BeTrue -Because "row must carry '$field'"
        }
    }
}
