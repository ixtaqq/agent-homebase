# Shared helpers for agent-homebase scripts. Dot-source: . "$PSScriptRoot\_common.ps1"
# Windows PowerShell 5.1 -- no &&, no ternary, no ??.

Set-StrictMode -Version 2.0

function Get-OsRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-CodexHome {
    if ($env:CODEX_HOME) { return $env:CODEX_HOME }
    return (Join-Path $env:USERPROFILE '.codex')
}

function Get-ClaudeHome {
    if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR }
    return (Join-Path $env:USERPROFILE '.claude')
}

function Get-CodexExe {
    if ($env:CODEX_EXE) { return $env:CODEX_EXE }

    $cmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $binRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path $binRoot) {
        $found = Get-ChildItem -Path $binRoot -Filter 'codex.exe' -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    throw "codex.exe not found. Add it to PATH or set CODEX_EXE."
}

# True when the path exists and is a reparse point (junction or symlink).
function Test-IsLink {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint)
}

# Resolved target of a junction/symlink, or $null.
function Get-LinkTarget {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-IsLink $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -Force
    $target = $null
    if ($item.PSObject.Properties['Target']) { $target = $item.Target }
    if ($target -is [array]) { $target = $target[0] }
    if (-not $target) {
        # PS 5.1 fallback for junctions created outside the session.
        $raw = & cmd /c dir /al (Split-Path $Path -Parent) 2>$null | Select-String ([regex]::Escape((Split-Path $Path -Leaf)))
        if ($raw -match '\[(.+)\]') { $target = $matches[1] }
    }
    if ($target) { return $target.TrimEnd('\') }
    return $null
}

# Removes a junction without touching what it points at.
# Remove-Item -Recurse on a junction can delete the TARGET contents in PS 5.1 -- never use it here.
function Remove-Link {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-IsLink $Path)) { throw "Refusing to remove '$Path': not a link." }
    [System.IO.Directory]::Delete($Path, $false)
}

function Get-FileHashOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-BackupPath {
    param([Parameter(Mandatory)][string]$Path)
    return ($Path + '.' + [guid]::NewGuid().ToString('N') + '.bak')
}

# Parses a markdown file with `---` YAML-ish frontmatter into @{ Meta = @{}; Body = '' }.
# Supports flat `key: value` pairs only, with optional quotes and # comments.
function Read-FrontMatterFile {
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $meta = @{}
    $bodyStart = 0

    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
        $i = 1
        while ($i -lt $lines.Count -and $lines[$i].Trim() -ne '---') {
            $line = $lines[$i]
            if ($line -match '^\s*#') { $i++; continue }
            if ($line -match '^\s*([A-Za-z0-9_\-]+)\s*:\s*(.*)$') {
                $key = $matches[1]
                $val = $matches[2].Trim()
                if ($val -match '\s+#\s') { $val = ($val -split '\s+#\s')[0].Trim() }
                $val = $val.Trim("'").Trim('"')
                $meta[$key] = $val
            }
            $i++
        }
        $bodyStart = $i + 1
    }

    $body = ''
    if ($bodyStart -lt $lines.Count) {
        $body = ($lines[$bodyStart..($lines.Count - 1)] -join "`n").Trim()
    }
    return @{ Meta = $meta; Body = $body }
}

function Get-MetaValue {
    param($Meta, [string]$Key, $Default = $null)
    if ($Meta.ContainsKey($Key) -and $Meta[$Key] -ne '') { return $Meta[$Key] }
    return $Default
}
