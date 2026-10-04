[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $root 'tools-lock.json') -Raw | ConvertFrom-Json
$vale = Join-Path $root "logs\tools\vale\$($lock.vale.version)\vale.exe"
if (-not (Test-Path -LiteralPath $vale)) { throw 'Run scripts/setup-check-tools.ps1 first.' }
$target = (Resolve-Path -LiteralPath $Path).Path
$config = Join-Path $root 'writing-quality\.vale.ini'
& $vale "--config=$config" --output=JSON $target
exit $LASTEXITCODE
