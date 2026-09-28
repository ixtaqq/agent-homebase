# Restore missing vendor repositories at the recorded revisions. Existing folders are read-only.
[CmdletBinding()]
param(
    [string]$Manifest,
    [string]$Destination,
    [switch]$Check,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $Manifest) { $Manifest = Join-Path $PSScriptRoot '..\vendor-lock.json' }
if (-not $Destination) { $Destination = Join-Path $PSScriptRoot '..\vendor' }
$lock = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
if ($lock.version -ne 1 -or -not $lock.repositories) { throw 'Invalid vendor lock manifest.' }
$seen = @{}
foreach ($repo in $lock.repositories) {
    if ($repo.name -notmatch '^[A-Za-z0-9_-]+$' -or $repo.commit -notmatch '^[a-f0-9]{40}$' -or -not $repo.url -or $repo.url.StartsWith('-')) {
        throw 'Invalid vendor name, URL or commit.'
    }
    if ($seen.ContainsKey($repo.name)) { throw "Duplicate vendor: $($repo.name)" }
    $seen[$repo.name] = $true
}

$problems = 0
foreach ($repo in $lock.repositories) {
    $target = Join-Path $Destination $repo.name
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
            Write-Warning "CONFLICT $target is not a vendor checkout."
            $problems++
            continue
        }
        $head = & git -C $target rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw "Could not read $target revision." }
        $origin = & git -C $target remote get-url origin
        if ($LASTEXITCODE -ne 0) { throw "Could not read $target origin." }
        $changes = & git -C $target status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect $target." }
        if ($head -ne $repo.commit -or $origin -ne $repo.url -or $changes) {
            Write-Warning "DRIFT $($repo.name): expected $($repo.commit) from $($repo.url); checkout left untouched."
            $problems++
        } else { Write-Host "OK $($repo.name) $head" }
        continue
    }
    if ($Check) { Write-Warning "MISSING $target"; $problems++; continue }
    if ($DryRun) { Write-Host "Would clone $($repo.url) at $($repo.commit) into $target"; continue }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    & git init $target | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize $target." }
    & git -C $target remote add origin $repo.url
    if ($LASTEXITCODE -ne 0) { throw "Could not set origin for $target." }
    & git -C $target fetch --depth 1 --filter=blob:none origin $repo.commit
    if ($LASTEXITCODE -ne 0) { throw "Could not fetch pinned revision for $target. Partial checkout retained." }
    if ($repo.PSObject.Properties['sparse'] -and $repo.sparse.Count -gt 0) {
        & git -C $target sparse-checkout set @($repo.sparse)
        if ($LASTEXITCODE -ne 0) { throw "Could not configure sparse checkout for $target." }
    }
    & git -C $target checkout --detach $repo.commit
    if ($LASTEXITCODE -ne 0) { throw "Could not check out pinned revision for $target." }
    Write-Host "Installed $($repo.name) at $($repo.commit)"
}
if ($problems -gt 0) { exit 1 }
exit 0
