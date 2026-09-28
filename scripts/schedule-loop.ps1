<#
.SYNOPSIS
Registers, lists, or removes Windows Task Scheduler entries that run agent-homebase loops.

.DESCRIPTION
Tasks are created under the \AgentHomebase\ folder and named "AgentHomebase-<loop>", so they are easy to find
in Task Scheduler and easy to clean up. Each task runs:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\loop.ps1 -Loop <name>

Registering a scheduled task may require an elevated shell depending on your policy.

.EXAMPLE
powershell -NoProfile -File scripts\schedule-loop.ps1 -Loop repo-health -Daily 09:00

.EXAMPLE
powershell -NoProfile -File scripts\schedule-loop.ps1 -Loop repo-health -EveryMinutes 30

.EXAMPLE
powershell -NoProfile -File scripts\schedule-loop.ps1 -List
#>
[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(ParameterSetName = 'Daily', Mandatory)]
    [Parameter(ParameterSetName = 'Interval', Mandatory)]
    [Parameter(ParameterSetName = 'Logon', Mandatory)]
    [Parameter(ParameterSetName = 'Remove', Mandatory)]
    [string]$Loop,

    # Run once a day at HH:mm.
    [Parameter(ParameterSetName = 'Daily', Mandatory)][string]$Daily,
    # Repeat every N minutes, indefinitely, starting now.
    [Parameter(ParameterSetName = 'Interval', Mandatory)][int]$EveryMinutes,
    # Run at user logon.
    [Parameter(ParameterSetName = 'Logon', Mandatory)][switch]$AtLogon,
    # Unregister the task for this loop.
    [Parameter(ParameterSetName = 'Remove', Mandatory)][switch]$Remove,
    # Show registered agent-homebase tasks.
    [Parameter(ParameterSetName = 'List')][switch]$List
)

. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Stop'

$root       = Get-OsRoot
$taskFolder = '\AgentHomebase\'

if ($PSCmdlet.ParameterSetName -eq 'List') {
    $tasks = @(Get-ScheduledTask -TaskPath $taskFolder -ErrorAction SilentlyContinue)
    if ($tasks.Count -eq 0) { Write-Host "No agent-homebase loops are scheduled."; exit 0 }
    $tasks | ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo
        [pscustomobject]@{
            Task     = $_.TaskName
            State    = $_.State
            LastRun  = $info.LastRunTime
            LastCode = $info.LastTaskResult
            NextRun  = $info.NextRunTime
        }
    } | Format-Table -AutoSize
    exit 0
}

$loopName = $Loop -replace '\.loop\.md$', ''
$taskName = "AgentHomebase-$loopName"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskFolder -Confirm:$false
    Write-Host "Removed scheduled task $taskName." -ForegroundColor Green
    exit 0
}

$loopFile = Join-Path $root ("loops\$loopName.loop.md")
if (-not (Test-Path -LiteralPath $loopFile)) {
    Write-Error "Loop definition not found: $loopFile"
    exit 1
}

$runner = Join-Path $root 'scripts\loop.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Loop {1}' -f $runner, $loopName) `
    -WorkingDirectory $root

switch ($PSCmdlet.ParameterSetName) {
    'Daily' {
        $trigger = New-ScheduledTaskTrigger -Daily -At $Daily
        $desc = "daily at $Daily"
    }
    'Interval' {
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
            -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
        $desc = "every $EveryMinutes min"
    }
    'Logon' {
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $desc = "at logon"
    }
}

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $taskName -TaskPath $taskFolder -Action $action `
    -Trigger $trigger -Settings $settings -Description "agent-homebase loop '$loopName' ($desc)" -Force | Out-Null

Write-Host "Scheduled '$loopName' $desc as $taskFolder$taskName." -ForegroundColor Green
Write-Host "Logs: $root\logs\$loopName\"
