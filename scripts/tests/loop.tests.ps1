$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..\..')).Path
$loop = Join-Path $root 'scripts\loop.ps1'

Describe 'loop.ps1 dry run' {
    It 'resumes the session started by pass one instead of the global last session' {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $loop -Loop repo-health -DryRun 2>&1

        $text = $output -join "`n"
        $text | Should Match '--json'
        $text | Should Match 'exec resume <session-id from pass 1>'
        $text | Should Not Match 'resume --last'
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
sandbox: workspace-write
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
            $text | Should Not Match 'exec resume'
        } finally {
            Remove-Item -LiteralPath $testDir -Recurse -Force
        }
    }
}

Describe 'sync.ps1 safety contract' {
    It 'preserves user files and shares skills across isolated Codex and Claude homes' {
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
