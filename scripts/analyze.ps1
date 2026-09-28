[CmdletBinding()]
param([string]$Path)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $root 'tools-lock.json') -Raw | ConvertFrom-Json
$module = Join-Path $root "logs\tools\PSScriptAnalyzer\$($lock.PSScriptAnalyzer.version)\PSScriptAnalyzer.psd1"
if (-not (Test-Path -LiteralPath $module)) { throw 'Run scripts/setup-check-tools.ps1 first.' }
Import-Module $module -Force
$settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
if ($Path) { $files = @(Get-Item -LiteralPath $Path) }
else { $files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter '*.ps1' -File) }
$findings = @($files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings })
if ($findings.Count -gt 0) {
    $findings | Format-Table ScriptName, Line, RuleName, Message -Wrap
    exit 1
}
Write-Host "PowerShell analysis passed: $($files.Count) scripts."
exit 0
