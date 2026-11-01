$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..\..')).Path
$loop = Join-Path $root 'scripts\loop.ps1'
# Dry runs only print commands; a placeholder lets them run where the claude CLI is not installed.
if (-not $env:CLAUDE_EXE) { $env:CLAUDE_EXE = 'claude' }

Describe 'loop.ps1 dry run' {
    It 'resumes the session started by pass one instead of the most recent session' {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $loop -Loop repo-health -DryRun 2>&1

        $text = $output -join "`n"
        $text | Should Match '--output-format json --json-schema'
        $text -match '--session-id ([0-9a-f-]{36})' | Should Be $true
        $text | Should Match ('--resume ' + $matches[1])
        $text | Should Not Match '--continue'
    }

    It 'uses one ledger story per fresh pass and exposes the deterministic verification gate' {
        $testDir = Join-Path $env:TEMP ('agent-homebase-loop-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        try {
            $ledger = Join-Path $testDir 'stories.json'
            $definition = Join-Path $testDir 'ledger.loop.md'
            @'
{"version":1,"stories":[{"id":"S1","title":"First story","priority":1,"status":"pending","acceptance_criteria":["tests pass"]}]}
'@ | Set-Content -LiteralPath $ledger -Encoding UTF8
            @"
---
name: ledger-test
cwd: $testDir
permission_mode: acceptEdits
max_iterations: 2
exit_when: all ledger stories are complete
story_ledger: $ledger
verification_command: exit 0
fresh_context_per_iteration: true
---
Implement the current story only.
"@ | Set-Content -LiteralPath $definition -Encoding UTF8

            $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $loop -Loop $definition -DryRun 2>&1
            $text = $output -join "`n"

            $text | Should Match 'story=S1'
            $text | Should Match 'verification_command: exit 0'
            $text | Should Not Match '--resume'
        } finally { Write-Host "Fixtures retained: $testDir" }
    }
}

Describe 'sync.ps1 safety contract' {
    It 'preserves user files and links skills into an isolated Claude home' {
        & node (Join-Path $root 'scripts\tests\sync.test.js')
        $LASTEXITCODE | Should Be 0
    }
}

Describe 'validate.ps1' {
    It 'accepts the current repository structure' {
        $validate = Join-Path $root 'scripts\validate.ps1'
        & powershell -NoProfile -ExecutionPolicy Bypass -File $validate
        $LASTEXITCODE | Should Be 0
    }
}
