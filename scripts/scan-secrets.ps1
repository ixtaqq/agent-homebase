[CmdletBinding()]
param([string]$Path)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $root 'tools-lock.json') -Raw | ConvertFrom-Json
$scanner = Join-Path $root "logs\tools\gitleaks\$($lock.gitleaks.version)\gitleaks.exe"
if (-not (Test-Path -LiteralPath $scanner)) { throw 'Run scripts/setup-check-tools.ps1 first.' }
$config = Join-Path $root '.gitleaks.toml'
if ($Path) {
    & $scanner dir $Path --config $config --redact=100 --no-banner
    exit $LASTEXITCODE
}

& $scanner git $root --config $config --redact=100 --no-banner
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Include uncommitted source without traversing vendor clones or generated tool downloads.
$files = @(& git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate source files.' }
$snapshot = Join-Path $root ('logs\secret-scan\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
foreach ($file in ($files | Sort-Object -Unique)) {
    $source = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $destination = Join-Path $snapshot $file
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}
& $scanner dir $snapshot --config $config --redact=100 --no-banner
exit $LASTEXITCODE
