<#
.SYNOPSIS
Checks that every project in the Projects workspace is wired to agent-homebase. Read-only.

.DESCRIPTION
Finds projects directly under the workspace root and inside group folders (folders that hold only
folders, such as finance\ or personal\). Hidden entries and names starting with '.' are skipped;
junctions are followed and de-duplicated by target. For each project it reports:

  - AGENTS.md exists and points at PROJECT-WORKFLOW.md,
  - CLAUDE.md imports @AGENTS.md (claude),
  - a Codex trust entry exists in config.toml (codex),
  - the workspace README.md links to it,
  - whether it is a Git repository (WARN only).

It also checks that the workspace CLAUDE.md imports PROJECT-WORKFLOW.md and that the file exists.

Like doctor.ps1, it avoids .NET type literals and dot-sourcing so it stays runnable from a loop.

Exit code 0 = clean, 1 = something needs attention.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\projects-doctor.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectsRoot = 'E:\workspace\Projects',
    [ValidateSet('codex', 'claude', 'all')][string]$Target = 'all'
)

$root      = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workflow  = Join-Path $root 'PROJECT-WORKFLOW.md'
$codexHome = $env:CODEX_HOME
if (-not $codexHome) { $codexHome = Join-Path $env:USERPROFILE '.codex' }
$checkCodex  = ($Target -eq 'codex' -or $Target -eq 'all')
$checkClaude = ($Target -eq 'claude' -or $Target -eq 'all')
$findings    = New-Object System.Collections.ArrayList

function Add-Finding {
    param([string]$Project, [string]$Check, [string]$Status, [string]$Detail)
    [void]$findings.Add([pscustomobject]@{ Project = $Project; Check = $Check; Status = $Status; Detail = $Detail })
}

function Test-Skipped {
    param($Item)
    return ($Item.Name -like '.*' -or $Item.Attributes.ToString() -match 'Hidden')
}

function Get-RealPath {
    param($Item)
    $target = $Item.Target
    if ($target -is [array]) { $target = $target[0] }
    if ($Item.LinkType -and $target) { return $target.TrimEnd('\') }
    return $Item.FullName.TrimEnd('\')
}

function Test-ProjectFolder {
    param([string]$Path)
    return [bool](Get-ChildItem -LiteralPath $Path -Force -File -ErrorAction SilentlyContinue |
                  Where-Object { -not (Test-Skipped $_) } | Select-Object -First 1)
}

if (-not (Test-Path -LiteralPath $ProjectsRoot -PathType Container)) {
    Write-Error "Projects root not found: $ProjectsRoot"
    exit 1
}
$ProjectsRoot = (Resolve-Path -LiteralPath $ProjectsRoot).Path.TrimEnd('\')

# --- discover projects -------------------------------------------------------------------------

$projects = New-Object System.Collections.ArrayList
$seen = @{}

function Add-Project {
    param($Item, [string]$Relative)
    $real = Get-RealPath $Item
    if ($seen.ContainsKey($real.ToLower())) { return }
    $seen[$real.ToLower()] = $true
    [void]$projects.Add([pscustomobject]@{ Name = $Relative; Path = $Item.FullName; Real = $real })
}

foreach ($entry in (Get-ChildItem -LiteralPath $ProjectsRoot -Directory -Force | Sort-Object Name)) {
    if (Test-Skipped $entry) { continue }
    if (Test-ProjectFolder (Get-RealPath $entry)) {
        Add-Project $entry $entry.Name
        continue
    }
    foreach ($child in (Get-ChildItem -LiteralPath $entry.FullName -Directory -Force | Sort-Object Name)) {
        if (Test-Skipped $child) { continue }
        Add-Project $child ($entry.Name + '/' + $child.Name)
    }
}

# --- shared inputs -----------------------------------------------------------------------------

$trusted = @{}
$codexConfig = Join-Path $codexHome 'config.toml'
if ($checkCodex -and (Test-Path -LiteralPath $codexConfig -PathType Leaf)) {
    $section = $null
    foreach ($line in (Get-Content -LiteralPath $codexConfig -Encoding UTF8)) {
        if ($line -match '^\s*\[projects\.(?:''([^'']+)''|"([^"]+)")\]\s*$') {
            $section = $matches[1]
            if (-not $section) { $section = $matches[2] -replace '\\\\', '\' }
        } elseif ($line -match '^\s*\[') {
            $section = $null
        } elseif ($section -and $line -match '^\s*trust_level\s*=\s*"trusted"') {
            $trusted[$section.TrimEnd('\').ToLower()] = $true
        }
    }
}

$readmePath = Join-Path $ProjectsRoot 'README.md'
$readme = ''
if (Test-Path -LiteralPath $readmePath -PathType Leaf) { $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8 }

# --- workspace ---------------------------------------------------------------------------------

if (Test-Path -LiteralPath $workflow -PathType Leaf) { Add-Finding '(workspace)' 'PROJECT-WORKFLOW.md' 'OK' $workflow }
else { Add-Finding '(workspace)' 'PROJECT-WORKFLOW.md' 'FAIL' "missing: $workflow" }

if ($checkClaude) {
    $workspaceClaude = Join-Path $ProjectsRoot 'CLAUDE.md'
    $imports = @(Get-Content -LiteralPath $workspaceClaude -Encoding UTF8 -ErrorAction SilentlyContinue |
                 Where-Object { $_ -match '^@.*PROJECT-WORKFLOW\.md\s*$' })
    if ($imports.Count -gt 0) { Add-Finding '(workspace)' 'CLAUDE.md import' 'OK' $imports[0].Trim() }
    else { Add-Finding '(workspace)' 'CLAUDE.md import' 'MISSING' 'add @<path>\PROJECT-WORKFLOW.md' }
}

if (-not $readme) { Add-Finding '(workspace)' 'README.md' 'MISSING' "no index at $readmePath" }

# --- per project -------------------------------------------------------------------------------

foreach ($project in $projects) {
    $name = $project.Name
    $agents = Join-Path $project.Path 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $agents -PathType Leaf)) {
        Add-Finding $name 'AGENTS.md' 'MISSING' 'run project-bootstrap'
    } elseif (Select-String -LiteralPath $agents -SimpleMatch 'PROJECT-WORKFLOW.md' -Quiet) {
        Add-Finding $name 'AGENTS.md' 'OK' 'links shared workflow'
    } else {
        Add-Finding $name 'AGENTS.md' 'MISSING' 'no PROJECT-WORKFLOW.md pointer'
    }

    if ($checkClaude) {
        $claude = Join-Path $project.Path 'CLAUDE.md'
        if (-not (Test-Path -LiteralPath $claude -PathType Leaf)) {
            Add-Finding $name 'CLAUDE.md' 'MISSING' 'add a file containing @AGENTS.md'
        } elseif (Select-String -LiteralPath $claude -Pattern '^@AGENTS\.md\s*$' -Quiet) {
            Add-Finding $name 'CLAUDE.md' 'OK' 'imports @AGENTS.md'
        } else {
            Add-Finding $name 'CLAUDE.md' 'MISSING' 'no @AGENTS.md import'
        }
    }

    if ($checkCodex) {
        if ($trusted.ContainsKey($project.Path.TrimEnd('\').ToLower()) -or $trusted.ContainsKey($project.Real.ToLower())) {
            Add-Finding $name 'Codex trust' 'OK' 'trusted'
        } else {
            Add-Finding $name 'Codex trust' 'MISSING' ("no [projects.'{0}'] entry" -f $project.Real.ToLower())
        }
    }

    if ($readme) {
        if ($readme.Contains('(' + $name + '/)') -or $readme.Contains('(<' + $name + '/>)')) {
            Add-Finding $name 'README row' 'OK' 'listed'
        } else {
            Add-Finding $name 'README row' 'MISSING' "not linked from $readmePath"
        }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $project.Real '.git'))) {
        Add-Finding $name 'git' 'WARN' 'not a Git repository'
    }
}

# --- report ------------------------------------------------------------------------------------

if ($projects.Count -eq 0) { Add-Finding '(workspace)' 'projects' 'WARN' "no projects found under $ProjectsRoot" }

$findings | Format-Table -AutoSize

$bad = @($findings | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'WARN' })
if ($bad.Count -gt 0) {
    Write-Warning ("{0} item(s) need attention." -f $bad.Count)
    exit 1
}
Write-Host ("All checks passed: {0} project(s)." -f $projects.Count) -ForegroundColor Green
exit 0
