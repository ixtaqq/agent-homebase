<#
.SYNOPSIS
Validates agent-homebase repository structure and metadata. Read-only.

.DESCRIPTION
Checks required files, skill frontmatter, enabled vendor entries, loop definitions,
the plugin manifest, and forbidden runtime files. It does not inspect or change ~/.codex.
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Stop'

$root = Get-OsRoot
$errors = New-Object System.Collections.ArrayList

function Add-ValidationError {
    param([string]$Message)
    [void]$errors.Add($Message)
    Write-Error $Message -ErrorAction Continue
}

function Test-RequiredFile {
    param([string]$RelativePath)
    if (-not (Test-Path -LiteralPath (Join-Path $root $RelativePath) -PathType Leaf)) {
        Add-ValidationError "missing required file: $RelativePath"
    }
}

$requiredFiles = @(
    'AGENTS.md', 'README.md', 'SPEC.md', 'ROADMAP.md', 'TASKS.md',
    '.codex-plugin\plugin.json', 'global\AGENTS.md', 'global\CLAUDE.md', 'CLAUDE.md', 'vendor\enabled.txt',
    'scripts\doctor.ps1', 'scripts\loop.ps1', 'scripts\sync.ps1',
    'scripts\validate.ps1', 'scripts\schemas\loop-status.schema.json',
    'codex-home\agents\explorer.toml', 'codex-home\agents\reviewer.toml',
    'codex-home\agents\docs-researcher.toml', 'templates\project\CLAUDE.md',
    'claude-home\agents\os-explorer.md', 'claude-home\agents\os-reviewer.md',
    'claude-home\agents\os-docs-researcher.md'
)
foreach ($file in $requiredFiles) { Test-RequiredFile $file }

$pluginPath = Join-Path $root '.codex-plugin\plugin.json'
if (Test-Path -LiteralPath $pluginPath -PathType Leaf) {
    try {
        $plugin = Get-Content -LiteralPath $pluginPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $plugin.name -or -not $plugin.skills) { Add-ValidationError 'plugin manifest needs name and skills' }
    } catch {
        Add-ValidationError "invalid plugin manifest: $($_.Exception.Message)"
    }
}

$claimedSkills = @{}
$skillsRoot = Join-Path $root 'skills'
foreach ($skill in (Get-ChildItem -LiteralPath $skillsRoot -Directory -ErrorAction SilentlyContinue)) {
    $skillFile = Join-Path $skill.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-ValidationError "skill missing SKILL.md: $($skill.Name)"
        continue
    }
    $frontmatter = Read-FrontMatterFile $skillFile
    if (-not $frontmatter.Meta.ContainsKey('name') -or -not $frontmatter.Meta.ContainsKey('description')) {
        Add-ValidationError "skill frontmatter needs name and description: $($skill.Name)"
    } elseif ($frontmatter.Meta['name'] -ne $skill.Name) {
        Add-ValidationError "skill name does not match directory: $($skill.Name)"
    }
    $claimedSkills[$skill.Name] = $true
}

$enabledFile = Join-Path $root 'vendor\enabled.txt'
if (Test-Path -LiteralPath $enabledFile -PathType Leaf) {
    foreach ($line in (Get-Content -LiteralPath $enabledFile -Encoding UTF8)) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith('#')) { continue }
        $source = Join-Path (Join-Path $root 'vendor') ($entry -replace '/', '\')
        $skillFile = Join-Path $source 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-ValidationError "enabled vendor skill missing SKILL.md: $entry"
            continue
        }
        $frontmatter = Read-FrontMatterFile $skillFile
        $name = Get-MetaValue $frontmatter.Meta 'name' (Split-Path $source -Leaf)
        if ($claimedSkills.ContainsKey($name)) { Add-ValidationError "skill name collision: $name" }
        $claimedSkills[$name] = $true
    }
}

$loopsRoot = Join-Path $root 'loops'
foreach ($loop in (Get-ChildItem -LiteralPath $loopsRoot -Filter '*.loop.md' -File -ErrorAction SilentlyContinue)) {
    $parsed = Read-FrontMatterFile $loop.FullName
    if (-not $parsed.Body) { Add-ValidationError "loop has empty prompt body: $($loop.Name)" }
    if (-not $parsed.Meta.ContainsKey('exit_when')) { Add-ValidationError "loop has no exit_when: $($loop.Name)" }
    $cwd = Get-MetaValue $parsed.Meta 'cwd' $root
    if (-not (Test-Path -LiteralPath $cwd -PathType Container)) { Add-ValidationError "loop cwd does not exist: $($loop.Name)" }
}

$repoFiles = @(& git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate repository files with git.' }
foreach ($relativePath in ($repoFiles | Sort-Object -Unique)) {
    $name = Split-Path $relativePath -Leaf
    if ($name -match '^(auth\.json|history\.jsonl|installation_id|(?:state|goals|memories)_\d+\.sqlite(?:-wal|-shm)?)$') {
        Add-ValidationError "runtime or credential file must not be tracked: $relativePath"
    }
    if ($relativePath -like 'vendor/*' -or $relativePath -notlike '*.ps1') { continue }
    $scriptPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { continue }
    if (@([IO.File]::ReadAllBytes($scriptPath) | Where-Object { $_ -gt 127 }).Count -gt 0) {
        Add-ValidationError "PowerShell script must be ASCII-only: $relativePath"
    }
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) { Add-ValidationError "${relativePath}: $($parseError.Message)" }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\bootstrap-vendor.ps1') -Check
if ($LASTEXITCODE -ne 0) { Add-ValidationError 'vendor revisions differ from vendor-lock.json' }

if ($errors.Count -gt 0) {
    Write-Warning ("Validation failed with {0} error(s)." -f $errors.Count)
    exit 1
}

Write-Host ("Validation passed: {0} local/vendor skills and {1} loop(s) checked." -f $claimedSkills.Count, @((Get-ChildItem -LiteralPath $loopsRoot -Filter '*.loop.md' -File -ErrorAction SilentlyContinue)).Count) -ForegroundColor Green
exit 0
