$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..\..')).Path
$ledgerScript = Join-Path $root 'scripts\story-ledger.ps1'

Describe 'story-ledger.ps1' {
    BeforeEach {
        $testDir = Join-Path $env:TEMP ('agent-homebase-ledger-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        $ledger = Join-Path $testDir 'stories.json'
        @'
{
  "version": 1,
  "stories": [
    { "id": "S2", "title": "Second", "priority": 2, "status": "pending", "acceptance_criteria": ["check two"] },
    { "id": "S1", "title": "First", "priority": 1, "status": "pending", "acceptance_criteria": ["check one"] }
  ]
}
'@ | Set-Content -LiteralPath $ledger -Encoding UTF8
    }

    AfterEach {
        Write-Host "Fixtures retained: $testDir"
    }

    It 'selects the lowest-numbered pending priority' {
        $result = & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $ledger -Action next | ConvertFrom-Json

        $result.id | Should Be 'S1'
        $result.acceptance_criteria[0] | Should Be 'check one'
    }

    It 'refuses to complete a story without a successful verification exit code' {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $ledger -Action complete -StoryId S1 -VerificationExitCode 1 2>$null

        $LASTEXITCODE | Should Be 4
        ((Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json).stories | Where-Object id -eq 'S1').status | Should Be 'pending'
    }

    It 'persists completion with verification evidence' {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $ledger -Action complete -StoryId S1 -VerificationExitCode 0 -Evidence 'tests passed' | Out-Null

        $story = (Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json).stories | Where-Object id -eq 'S1'
        $story.status | Should Be 'complete'
        $story.verification.evidence | Should Be 'tests passed'
    }

    It 'distinguishes a blocked ledger from a completed ledger' {
        $data = Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json
        $data.stories | ForEach-Object { $_.status = 'blocked' }
        $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ledger -Encoding UTF8

        & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $ledger -Action next | Out-Null

        $LASTEXITCODE | Should Be 3
    }
}
