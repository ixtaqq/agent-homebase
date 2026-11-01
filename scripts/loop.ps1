<#
.SYNOPSIS
Runs a agent-homebase loop definition headlessly against `claude -p`, pass by pass, until it reports
done, reports blocked, or hits its iteration budget.

.DESCRIPTION
Reads loops/<name>.loop.md (see loops/_schema.md). Pass 1 starts a session under an ID the runner
chooses; later passes resume that exact session so context carries. Every pass returns JSON matching
schemas/loop-status.schema.json; the runner stops on status = done or blocked.

Output goes to logs/<loop>/<timestamp>/: iter-N.json per pass, plus run.log.

Exit codes: 0 done, 2 budget exhausted, 3 blocked, 1 runner error.

.EXAMPLE
powershell -NoProfile -File scripts\loop.ps1 -Loop repo-health -DryRun

.EXAMPLE
powershell -NoProfile -File scripts\loop.ps1 -Loop repo-health -MaxIterations 3
#>
[CmdletBinding()]
param(
    # Loop name (file basename without .loop.md), or a path to a .loop.md file.
    [Parameter(Mandatory)][string]$Loop,
    # Override max_iterations from the loop file.
    [int]$MaxIterations = 0,
    # Override interval_seconds from the loop file.
    [int]$IntervalSeconds = -1,
    # Print the commands that would run, then exit.
    [switch]$DryRun
)

. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Stop'

$root   = Get-OsRoot
$schema = Join-Path $root 'scripts\schemas\loop-status.schema.json'

# --- resolve the loop definition ---------------------------------------------------------------

if (Test-Path -LiteralPath $Loop -PathType Leaf) {
    $loopFile = (Resolve-Path $Loop).Path
} else {
    $loopFile = Join-Path $root ('loops\' + ($Loop -replace '\.loop\.md$', '') + '.loop.md')
}
if (-not (Test-Path -LiteralPath $loopFile)) {
    Write-Error "Loop definition not found: $loopFile"
    exit 1
}

$parsed = Read-FrontMatterFile $loopFile
$meta   = $parsed.Meta
$prompt = $parsed.Body

$loopName = Get-MetaValue $meta 'name' ([IO.Path]::GetFileNameWithoutExtension($loopFile) -replace '\.loop$', '')
$cwd      = Get-MetaValue $meta 'cwd' $root
$permissionMode = Get-MetaValue $meta 'permission_mode' 'acceptEdits'
$allowedTools = Get-MetaValue $meta 'allowed_tools' $null
$model    = Get-MetaValue $meta 'model' $null
$exitWhen = Get-MetaValue $meta 'exit_when' '(not stated)'
$storyLedger = Get-MetaValue $meta 'story_ledger' $null
$verificationCommand = Get-MetaValue $meta 'verification_command' $null
$freshContextValue = Get-MetaValue $meta 'fresh_context_per_iteration' 'false'
$freshContext = ($freshContextValue -eq 'true')

$maxIter = [int](Get-MetaValue $meta 'max_iterations' 5)
if ($MaxIterations -gt 0) { $maxIter = $MaxIterations }

$interval = [int](Get-MetaValue $meta 'interval_seconds' 0)
if ($IntervalSeconds -ge 0) { $interval = $IntervalSeconds }

if (-not $prompt) { Write-Error "Loop '$loopName' has an empty prompt body."; exit 1 }
if (-not (Test-Path -LiteralPath $cwd)) { Write-Error "Loop '$loopName' cwd does not exist: $cwd"; exit 1 }
if ($permissionMode -notin @('plan', 'dontAsk', 'acceptEdits', 'auto', 'default')) {
    Write-Error "Loop '$loopName' has invalid permission_mode '$permissionMode'. The runner never bypasses permissions."; exit 1
}

if ($storyLedger) {
    if (-not [IO.Path]::IsPathRooted($storyLedger)) { $storyLedger = Join-Path $cwd $storyLedger }
    if (-not (Test-Path -LiteralPath $storyLedger -PathType Leaf)) {
        Write-Error "Loop '$loopName' story ledger does not exist: $storyLedger"; exit 1
    }
    if (-not $verificationCommand) {
        Write-Error "Loop '$loopName' uses story_ledger but has no verification_command."; exit 1
    }
    $freshContext = $true
}

$claude = Get-ClaudeExe
$ledgerScript = Join-Path $root 'scripts\story-ledger.ps1'
$schemaArg = ConvertTo-NativeArgument ((Get-Content -LiteralPath $schema -Raw -Encoding UTF8) | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress)

# --- run directory -----------------------------------------------------------------------------

$stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$runDir = Join-Path $root ('logs\' + $loopName + '\' + $stamp)
if (-not $DryRun) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }
$runLog = Join-Path $runDir 'run.log'
$sessionFile = Join-Path $runDir 'session-id.txt'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    if (-not $DryRun) { Add-Content -LiteralPath $runLog -Value $line -Encoding UTF8 }
}

$contract = @"

---
Loop control (mandatory):
- Exit condition for this loop: $exitWhen
- Do ONE increment of work this pass, then run the check that proves progress.
- Reply with ONLY a JSON object matching the provided output schema.
- status=done only if the exit condition verifiably holds -- you must have run the check this pass.
- status=blocked if you need a decision, credential, or fix outside this loop, or if the same
  failure repeated with no new information. Do not retry a command that failed the same way twice.
- Otherwise status=continue, and put the single next increment in next_action.
"@

Write-Log "loop=$loopName cwd=$cwd permission_mode=$permissionMode max=$maxIter interval=${interval}s"
if ($allowedTools) { Write-Log "allowed_tools: $allowedTools" }
Write-Log "exit_when: $exitWhen"
if ($storyLedger) { Write-Log "story_ledger: $storyLedger"; Write-Log "verification_command: $verificationCommand" }

$finalStatus = 'continue'
$threadId = $null

for ($i = 1; $i -le $maxIter; $i++) {

    $currentStory = $null
    if ($storyLedger) {
        $storyRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $storyLedger -Action next
        $storyCode = $LASTEXITCODE
        if ($storyCode -eq 2) { $finalStatus = 'done'; Write-Log 'all ledger stories are complete'; break }
        if ($storyCode -eq 3) { $finalStatus = 'blocked'; Write-Log 'story ledger has no pending work but contains blocked or invalid stories'; break }
        if ($storyCode -ne 0) { $finalStatus = 'blocked'; Write-Log 'story ledger could not select a pending story'; break }
        try { $currentStory = $storyRaw | ConvertFrom-Json } catch {
            $finalStatus = 'blocked'; Write-Log 'story ledger returned invalid JSON'; break
        }
        Write-Log "pass $i/$maxIter -- story=$($currentStory.id) :: $($currentStory.title)"
    }

    $iterFile = Join-Path $runDir ('iter-{0}.json' -f $i)

    # The runner picks the session ID up front, so resuming never depends on parsing output.
    if ($i -eq 1 -or $freshContext) { $threadId = [guid]::NewGuid().ToString() }

    $cmdArgs = New-Object System.Collections.ArrayList
    [void]$cmdArgs.Add('-p')
    if ($i -gt 1 -and -not $freshContext) { [void]$cmdArgs.AddRange(@('--resume', $threadId)) }
    else { [void]$cmdArgs.AddRange(@('--session-id', $threadId)) }
    [void]$cmdArgs.AddRange(@('--permission-mode', $permissionMode))
    # --allowedTools takes several values, so it must be followed by another flag, not the prompt.
    if ($allowedTools) { [void]$cmdArgs.AddRange(@('--allowedTools', (ConvertTo-NativeArgument $allowedTools))) }
    [void]$cmdArgs.AddRange(@('--output-format', 'json', '--json-schema', $schemaArg))
    if ($model)   { [void]$cmdArgs.AddRange(@('--model', $model)) }

    if ($storyLedger) {
        $storyContract = @"

---
Current story (complete this story only):
$($currentStory | ConvertTo-Json -Depth 10)

Deterministic verification gate owned by the runner:
- verification_command: $verificationCommand
- Do not edit the story ledger directly.
- Do not commit or push. The runner never authorizes git publication.
- status=done means this story is ready for the runner to verify; it does not mark completion itself.
"@
        $passPrompt = $prompt + $storyContract + $contract
    } elseif ($freshContext) {
        $passPrompt = $prompt + "`nThis is fresh-context pass $i of $maxIter." + $contract
    } elseif ($i -eq 1) {
        $passPrompt = $prompt + $contract
    } else {
        $passPrompt = "Continue the loop. Pass $i of $maxIter." + $contract
    }

    $argLine = $cmdArgs -join ' '
    if ($DryRun) {
        Write-Host "`n--- pass $i ---" -ForegroundColor Yellow
        Write-Host ('cd "{0}"; <prompt> | "{1}" {2}' -f $cwd, $claude, $argLine)
        continue
    }

    Write-Log "pass $i/$maxIter -- running"
    $outFile = Join-Path $runDir ("pass-$i.out")
    $errFile = Join-Path $runDir ("pass-$i.err")

    # The prompt goes in on stdin: a multi-line argument does not survive a claude.cmd shim.
    $code = Invoke-NativeCapture -FilePath $claude -ArgumentLine $argLine -WorkingDirectory $cwd `
        -InputText $passPrompt -OutFile $outFile -ErrFile $errFile

    if ($code -ne 0) {
        Write-Log "pass $i -- claude exited $code; treating as blocked."
        $finalStatus = 'blocked'
        break
    }

    if ($i -eq 1 -and -not $freshContext) {
        Set-Content -LiteralPath $sessionFile -Value $threadId -Encoding UTF8
        Write-Log "pass 1 -- session=$threadId"
    }

    $status = 'continue'; $summary = ''; $next = ''
    $raw = (Get-Content -LiteralPath $outFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
    $obj = $null
    if ($raw) { try { $obj = $raw.Trim() | ConvertFrom-Json } catch { $obj = $null } }
    if ($null -eq $obj) {
        Write-Log "pass $i -- could not parse claude JSON output; treating as blocked."
        $status = 'blocked'; $summary = 'unparseable claude output'
    } elseif ($obj.is_error -or -not $obj.PSObject.Properties['structured_output'] -or $null -eq $obj.structured_output) {
        Write-Log "pass $i -- no structured status in output; treating as blocked. Result: $($obj.result)"
        $status = 'blocked'; $summary = 'claude returned no structured status'
    } else {
        $obj.structured_output | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $iterFile -Encoding UTF8
        $status  = $obj.structured_output.status
        $summary = $obj.structured_output.summary
        $next    = $obj.structured_output.next_action
    }

    Write-Log "pass $i -- status=$status :: $summary"
    if ($next) { Write-Log "pass $i -- next: $next" }
    $finalStatus = $status

    if ($storyLedger -and $status -eq 'done') {
        Write-Log "pass $i -- verifying story $($currentStory.id)"
        $verifyOut = Join-Path $runDir ("verify-$i.out")
        $verifyErr = Join-Path $runDir ("verify-$i.err")
        Push-Location $cwd
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            & powershell -NoProfile -ExecutionPolicy Bypass -Command $verificationCommand 1> $verifyOut 2> $verifyErr
            $verifyCode = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
        } finally {
            Pop-Location
        }

        if ($verifyCode -ne 0) {
            Write-Log "pass $i -- verification failed with exit $verifyCode; story remains pending"
            $finalStatus = 'continue'
        } else {
            $evidence = "verification_command passed in loop pass $i; output: $verifyOut"
            & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $storyLedger -Action complete -StoryId $currentStory.id -VerificationExitCode 0 -Evidence $evidence | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Log "pass $i -- verification passed but ledger update failed"
                $finalStatus = 'blocked'
            } else {
                Write-Log "pass $i -- story $($currentStory.id) completed with verification evidence"
                & powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Ledger $storyLedger -Action next | Out-Null
                $nextStoryCode = $LASTEXITCODE
                if ($nextStoryCode -eq 2) { $finalStatus = 'done' }
                elseif ($nextStoryCode -eq 3) { $finalStatus = 'blocked' }
                else { $finalStatus = 'continue' }
            }
        }
    }

    if (-not $storyLedger -and $status -eq 'done') { break }
    if ($storyLedger -and $finalStatus -eq 'done') { break }
    if ($finalStatus -eq 'blocked') { break }
    if ($i -lt $maxIter -and $interval -gt 0) {
        Write-Log "sleeping ${interval}s"
        Start-Sleep -Seconds $interval
    }
}

if ($DryRun) { Write-Host "`nDry run -- nothing was executed." -ForegroundColor Yellow; exit 0 }

switch ($finalStatus) {
    'done'    { Write-Log "loop finished: DONE";    Write-Host "`nlogs: $runDir" -ForegroundColor Green;  exit 0 }
    'blocked' { Write-Log "loop finished: BLOCKED"; Write-Host "`nlogs: $runDir" -ForegroundColor Red;    exit 3 }
    default   { Write-Log "loop finished: BUDGET EXHAUSTED after $maxIter passes"
                Write-Host "`nlogs: $runDir" -ForegroundColor Yellow; exit 2 }
}
