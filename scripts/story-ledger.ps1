<#
.SYNOPSIS
Reads and updates a deterministic JSON story ledger for Agent Homebase loops.

.DESCRIPTION
Actions:
- next: prints the highest-priority pending story as JSON; exits 2 when none remain.
- complete: marks one pending story complete only when VerificationExitCode is zero.
- status: prints a compact ledger summary as JSON.

Exit codes: 0 success, 2 no pending stories, 4 verification failed, 1 invalid input.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][ValidateSet('next', 'complete', 'status')][string]$Action,
    [string]$StoryId,
    [int]$VerificationExitCode = -1,
    [string]$Evidence = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Ledger -PathType Leaf)) {
    Write-Error "Story ledger not found: $Ledger"
    exit 1
}

try {
    $data = Get-Content -LiteralPath $Ledger -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Error "Story ledger is not valid JSON: $Ledger"
    exit 1
}

if ($data.version -ne 1 -or $null -eq $data.stories) {
    Write-Error 'Story ledger must have version 1 and a stories array.'
    exit 1
}

$ids = @($data.stories | ForEach-Object { $_.id })
if (@($ids | Sort-Object -Unique).Count -ne $ids.Count -or @($ids | Where-Object { -not $_ }).Count -gt 0) {
    Write-Error 'Every story must have a unique, non-empty id.'
    exit 1
}

switch ($Action) {
    'next' {
        $story = $data.stories |
            Where-Object { $_.status -eq 'pending' } |
            Sort-Object @{ Expression = { if ($null -eq $_.priority) { 999999 } else { [int]$_.priority } } }, id |
            Select-Object -First 1
        if ($null -eq $story) {
            if (@($data.stories | Where-Object { $_.status -ne 'complete' }).Count -gt 0) { exit 3 }
            exit 2
        }
        $story | ConvertTo-Json -Depth 10
        exit 0
    }
    'complete' {
        if (-not $StoryId) { Write-Error 'StoryId is required for complete.'; exit 1 }
        if ($VerificationExitCode -ne 0) {
            Write-Warning "Verification failed with exit code $VerificationExitCode; story remains pending."
            exit 4
        }
        $story = $data.stories | Where-Object { $_.id -eq $StoryId } | Select-Object -First 1
        if ($null -eq $story) { Write-Error "Story not found: $StoryId"; exit 1 }
        if ($story.status -ne 'pending') { Write-Error "Story is not pending: $StoryId"; exit 1 }

        $story.status = 'complete'
        $verification = [pscustomobject]@{
            checked_at = (Get-Date).ToString('o')
            exit_code = 0
            evidence = $Evidence
        }
        $story | Add-Member -NotePropertyName verification -NotePropertyValue $verification -Force
        $data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Ledger -Encoding UTF8
        $story | ConvertTo-Json -Depth 10
        exit 0
    }
    'status' {
        [pscustomobject]@{
            total = @($data.stories).Count
            pending = @($data.stories | Where-Object status -eq 'pending').Count
            complete = @($data.stories | Where-Object status -eq 'complete').Count
            blocked = @($data.stories | Where-Object status -eq 'blocked').Count
        } | ConvertTo-Json
        exit 0
    }
}
