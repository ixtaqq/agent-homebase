<#
.SYNOPSIS
Wires agent-homebase into Codex and/or Claude Code with shared skill junctions.

.DESCRIPTION
Idempotent. Junctions are live, so editing a SKILL.md here takes effect in the next thread with no
re-sync. Re-run only after adding a skill folder or editing global/AGENTS.md.

Never deletes a real directory. A real directory sitting where a junction should go is reported and
skipped -- resolve it by hand.

.EXAMPLE
powershell -NoProfile -File scripts\sync.ps1 -DryRun

.EXAMPLE
powershell -NoProfile -File scripts\sync.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('codex', 'claude', 'all')][string]$Target = 'codex',
    # Preview actions without changing anything.
    [switch]$DryRun,
    # Re-point junctions whose target has drifted, unlink stale vendor junctions, or overwrite a
    # modified ~/.codex/AGENTS.md after backing it up.
    [switch]$Force
)

. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Stop'

if ($Target -eq 'all') {
    $exitCode = 0
    foreach ($agentTarget in @('codex', 'claude')) {
        Write-Host "Syncing $agentTarget"
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Target', $agentTarget)
        if ($DryRun) { $childArgs += '-DryRun' }
        if ($Force) { $childArgs += '-Force' }
        & powershell @childArgs
        if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
    }
    exit $exitCode
}

$root       = Get-OsRoot
$agentHome  = Get-CodexHome
$guidanceName = 'AGENTS.md'
if ($Target -eq 'claude') {
    $agentHome = Get-ClaudeHome
    $guidanceName = 'CLAUDE.md'
}
$skillsSrc  = Join-Path $root 'skills'
$skillsDest = Join-Path $agentHome 'skills'
$results    = New-Object System.Collections.ArrayList

function Add-Result {
    param([string]$Item, [string]$Action, [string]$Detail)
    [void]$results.Add([pscustomobject]@{ Item = $Item; Action = $Action; Detail = $Detail })
}

if (-not (Test-Path -LiteralPath $agentHome)) {
    if ($Target -eq 'codex') { throw "CODEX_HOME not found at '$agentHome'. Is Codex installed for this user?" }
    if ($DryRun) { Add-Result 'config/' 'would create' $agentHome }
    else { New-Item -ItemType Directory -Path $agentHome | Out-Null }
}
if (-not (Test-Path $skillsDest)) {
    if ($DryRun) {
        Add-Result 'skills/' 'would create' $skillsDest
    } else {
        New-Item -ItemType Directory -Path $skillsDest -Force | Out-Null
    }
}

# --- skills: one junction per folder -----------------------------------------------------------

foreach ($skill in (Get-ChildItem -Path $skillsSrc -Directory -ErrorAction SilentlyContinue)) {
    if ($skill.Name -like '.*') { continue }

    $link = Join-Path $skillsDest $skill.Name

    if (-not (Test-Path (Join-Path $skill.FullName 'SKILL.md'))) {
        Add-Result $skill.Name 'skipped' 'no SKILL.md'
        continue
    }

    if (-not (Test-Path -LiteralPath $link)) {
        if ($DryRun) {
            Add-Result $skill.Name 'would link' $link
        } else {
            New-Item -ItemType Junction -Path $link -Value $skill.FullName | Out-Null
            Add-Result $skill.Name 'linked' $link
        }
        continue
    }

    if (Test-IsLink $link) {
        $linkTarget = Get-LinkTarget $link
        if ($linkTarget -and ($linkTarget.TrimEnd('\') -ieq $skill.FullName.TrimEnd('\'))) {
            Add-Result $skill.Name 'ok' 'junction current'
        } elseif ($Force) {
            if ($DryRun) {
                Add-Result $skill.Name 'would re-point' "$linkTarget -> $($skill.FullName)"
            } else {
                Remove-Link $link
                New-Item -ItemType Junction -Path $link -Value $skill.FullName | Out-Null
                Add-Result $skill.Name 're-pointed' "was: $linkTarget"
            }
        } else {
            Add-Result $skill.Name 'DRIFT' "points at '$linkTarget' -- re-run with -Force"
        }
        continue
    }

    Add-Result $skill.Name 'CONFLICT' "real directory exists at '$link' -- move or delete it yourself"
}

# --- vendor skills: enabled entries from vendor/enabled.txt --------------------------------------

$vendorRoot    = Join-Path $root 'vendor'
$enabledFile   = Join-Path $vendorRoot 'enabled.txt'
$vendorWanted  = @{}   # link name -> source folder

if (Test-Path -LiteralPath $enabledFile) {
    foreach ($line in (Get-Content -LiteralPath $enabledFile -Encoding UTF8)) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith('#')) { continue }

        $srcDir = Join-Path $vendorRoot ($entry -replace '/', '\')
        if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) {
            Add-Result $entry 'MISSING SRC' 'no such folder under vendor/'
            continue
        }

        $skillMd = Join-Path $srcDir 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillMd)) {
            Add-Result $entry 'skipped' 'no SKILL.md'
            continue
        }

        # The frontmatter name wins over the folder name: several upstream folders disagree with
        # their own SKILL.md, and Codex keys the skill on the declared name.
        $linkName = Get-MetaValue (Read-FrontMatterFile $skillMd).Meta 'name' (Split-Path $srcDir -Leaf)

        if ($vendorWanted.ContainsKey($linkName) -or (Test-Path -LiteralPath (Join-Path $skillsSrc $linkName))) {
            Add-Result $linkName 'COLLISION' "another local or vendor skill claims this name; '$entry' ignored"
            continue
        }
        $vendorWanted[$linkName] = (Resolve-Path $srcDir).Path
    }
}

foreach ($linkName in ($vendorWanted.Keys | Sort-Object)) {
    $srcDir = $vendorWanted[$linkName]
    $link   = Join-Path $skillsDest $linkName

    if (-not (Test-Path -LiteralPath $link)) {
        if ($DryRun) {
            Add-Result $linkName 'would link' 'vendor'
        } else {
            New-Item -ItemType Junction -Path $link -Value $srcDir | Out-Null
            Add-Result $linkName 'linked' 'vendor'
        }
        continue
    }

    if (Test-IsLink $link) {
        $linkTarget = Get-LinkTarget $link
        if ($linkTarget -and ($linkTarget.TrimEnd('\') -ieq $srcDir.TrimEnd('\'))) {
            Add-Result $linkName 'ok' 'vendor junction current'
        } elseif ($Force) {
            if ($DryRun) {
                Add-Result $linkName 'would re-point' "$linkTarget -> $srcDir"
            } else {
                Remove-Link $link
                New-Item -ItemType Junction -Path $link -Value $srcDir | Out-Null
                Add-Result $linkName 're-pointed' "was: $linkTarget"
            }
        } else {
            Add-Result $linkName 'DRIFT' "points at '$linkTarget' -- re-run with -Force"
        }
    } else {
        Add-Result $linkName 'CONFLICT' "real directory exists at '$link'"
    }
}

# --- provider-specific agent roles: copied -----------------------------------------------------

$agentsSrcRoot  = Join-Path $root 'codex-home\agents'
$agentsDestRoot = Join-Path $agentHome 'agents'
$agentFilter = '*.toml'
if ($Target -eq 'claude') {
    $agentsSrcRoot = Join-Path $root 'claude-home\agents'
    $agentFilter = '*.md'
}

if (Test-Path -LiteralPath $agentsSrcRoot -PathType Container) {
    if (-not (Test-Path -LiteralPath $agentsDestRoot -PathType Container)) {
        if ($DryRun) {
            Add-Result 'agents/' 'would create' $agentsDestRoot
        } else {
            New-Item -ItemType Directory -Path $agentsDestRoot -Force | Out-Null
        }
    }

    foreach ($agent in (Get-ChildItem -LiteralPath $agentsSrcRoot -Filter $agentFilter -File)) {
        $dest = Join-Path $agentsDestRoot $agent.Name
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            if ($DryRun) {
                Add-Result $agent.Name 'would copy' 'agent role'
            } else {
                Copy-Item -LiteralPath $agent.FullName -Destination $dest
                Add-Result $agent.Name 'copied' 'agent role'
            }
            continue
        }

        $srcHash  = Get-FileHashOrNull $agent.FullName
        $destHash = Get-FileHashOrNull $dest
        if ($srcHash -eq $destHash) {
            Add-Result $agent.Name 'ok' 'agent role current'
        } elseif (-not $Force) {
            Add-Result $agent.Name 'DRIFT' 'installed role differs -- re-run with -Force to overwrite'
        } elseif ($DryRun) {
            Add-Result $agent.Name 'would overwrite' 'agent role differs'
        } else {
            Copy-Item -LiteralPath $dest -Destination "$dest.bak" -Force
            Copy-Item -LiteralPath $agent.FullName -Destination $dest -Force
            Add-Result $agent.Name 'updated' 'previous role saved as .bak'
        }
    }
}

# Claude commands use a prefix to avoid replacing built-in commands such as /debug.
if ($Target -eq 'claude') {
    $commandsDest = Join-Path $agentHome 'commands'
    foreach ($command in (Get-ChildItem -LiteralPath (Join-Path $root 'commands') -Filter '*.md' -File)) {
        if ($command.Name -eq 'README.md') { continue }
        $dest = Join-Path $commandsDest ('os-' + $command.Name)
        $itemName = 'commands/os-' + $command.Name
        $destHash = Get-FileHashOrNull $dest
        if ($destHash -eq (Get-FileHashOrNull $command.FullName)) {
            Add-Result $itemName 'ok' 'command current'
        } elseif ($destHash -and -not $Force) {
            Add-Result $itemName 'DRIFT' 'installed command differs -- use -Force to back up and overwrite'
        } elseif ($DryRun) {
            Add-Result $itemName 'would copy' 'command (changed files are backed up with -Force)'
        } else {
            New-Item -ItemType Directory -Path $commandsDest -Force | Out-Null
            if ($destHash) { Copy-Item -LiteralPath $dest -Destination ($dest + '.' + [guid]::NewGuid().ToString('N') + '.bak') }
            Copy-Item -LiteralPath $command.FullName -Destination $dest -Force
            Add-Result $itemName 'copied' 'command'
        }
    }
}

# Links into vendor/ that enabled.txt no longer lists. Removing a junction never touches the files
# it points at, but it is still a removal, so it needs -Force.
foreach ($dest in (Get-ChildItem -Path $skillsDest -Directory -Force -ErrorAction SilentlyContinue)) {
    if ($dest.Name -eq '.system' -or $vendorWanted.ContainsKey($dest.Name)) { continue }
    if (-not (Test-IsLink $dest.FullName)) { continue }
    $linkTarget = Get-LinkTarget $dest.FullName
    if (-not $linkTarget) { continue }
    if (-not $linkTarget.ToLower().StartsWith($vendorRoot.ToLower())) { continue }

    if ($Force) {
        if ($DryRun) {
            Add-Result $dest.Name 'would unlink' 'disabled in enabled.txt'
        } else {
            Remove-Link $dest.FullName
            Add-Result $dest.Name 'unlinked' 'disabled in enabled.txt (source folder untouched)'
        }
    } else {
        Add-Result $dest.Name 'STALE' 'no longer in enabled.txt -- re-run with -Force to unlink'
    }
}

# --- global guidance: copied, because a single file cannot be junctioned ------------------------

$agentsSrc  = Join-Path (Join-Path $root 'global') $guidanceName
$agentsDest = Join-Path $agentHome $guidanceName

if (Test-Path $agentsSrc) {
    $srcHash  = Get-FileHashOrNull $agentsSrc
    $destHash = Get-FileHashOrNull $agentsDest

    if ($null -eq $destHash) {
        if ($DryRun) {
            Add-Result $guidanceName 'would copy' $agentsDest
        } else {
            Copy-Item -LiteralPath $agentsSrc -Destination $agentsDest -Force
            Add-Result $guidanceName 'copied' $agentsDest
        }
    } elseif ($srcHash -eq $destHash) {
        Add-Result $guidanceName 'ok' 'in sync'
    } else {
        # Destination differs. It may hold edits made directly in ~/.codex that are not in the repo.
        $backup = "$agentsDest.bak"
        if (-not $Force) {
            Add-Result $guidanceName 'DRIFT' 'differs from repo -- re-run with -Force to back up and overwrite'
        } elseif ($DryRun) {
            Add-Result $guidanceName 'would overwrite' "differs from repo (backup -> $backup)"
        } else {
            Copy-Item -LiteralPath $agentsDest -Destination $backup -Force
            Copy-Item -LiteralPath $agentsSrc -Destination $agentsDest -Force
            Add-Result $guidanceName 'updated' "previous version saved to $backup"
        }
    }
}

# --- report ------------------------------------------------------------------------------------

$results | Format-Table -AutoSize

$problems = @($results | Where-Object { $_.Action -in @('DRIFT', 'CONFLICT', 'MISSING SRC', 'COLLISION', 'STALE') })
if ($problems.Count -gt 0) {
    Write-Warning "$($problems.Count) item(s) need attention -- see the flagged rows above."
    exit 1
}
if ($DryRun) { Write-Host "`nDry run -- nothing was changed." -ForegroundColor Yellow }
else { Write-Host "`nSync complete for $Target. Open a new session to pick up changes." -ForegroundColor Green }
exit 0
