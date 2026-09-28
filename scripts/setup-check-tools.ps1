# Install pinned verification tools locally; no global modules or PATH changes.
[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $root 'tools-lock.json') -Raw | ConvertFrom-Json
foreach ($name in @('PSScriptAnalyzer', 'gitleaks')) {
    $tool = $lock.$name
    $destination = Join-Path $root "logs\tools\$name\$($tool.version)"
    $marker = Join-Path $destination '.verified'
    if (Test-Path -LiteralPath $marker) {
        if ((Get-Content -LiteralPath $marker -Raw).Trim() -ne $tool.sha256) { throw "Tool hash changed: $name" }
        Write-Host "OK $name $($tool.version)"
        continue
    }
    if (Test-Path -LiteralPath $destination) { throw "Incomplete install retained at $destination; inspect it before retrying." }
    if ($DryRun) { Write-Host "Would install $name $($tool.version) into $destination"; continue }
    $downloadDir = Join-Path $root ('logs\downloads\' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    $archive = Join-Path $downloadDir "$name.zip"
    Invoke-WebRequest -UseBasicParsing -Uri $tool.url -OutFile $archive
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $tool.sha256) { throw "Checksum mismatch: $archive" }
    Expand-Archive -LiteralPath $archive -DestinationPath $destination
    Set-Content -LiteralPath $marker -Value $tool.sha256 -Encoding ASCII
    Write-Host "Installed $name $($tool.version)"
}
