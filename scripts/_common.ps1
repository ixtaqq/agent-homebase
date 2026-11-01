# Shared helpers for agent-homebase scripts. Dot-source: . "$PSScriptRoot\_common.ps1"
# Windows PowerShell 5.1 -- no &&, no ternary, no ??.

Set-StrictMode -Version 2.0

function Get-OsRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-ClaudeHome {
    if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR }
    return (Join-Path $env:USERPROFILE '.claude')
}

function Get-ClaudeExe {
    if ($env:CLAUDE_EXE) { return $env:CLAUDE_EXE }

    # An npm install also puts claude.ps1 on PATH; only an application can be started as a process.
    $cmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    # Default location of the native installer.
    $native = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $native) { return $native }
    throw "claude CLI not found. Install Claude Code CLI, add it to PATH, or set CLAUDE_EXE."
}

# One argument quoted for a raw Windows command line, by the MSVCRT rules. Windows PowerShell 5.1
# quotes arguments that contain double quotes inconsistently, so JSON is passed through
# Invoke-NativeCapture with a command line built from these instead of through `&`.
function ConvertTo-NativeArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    if ($Value -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = ($Value -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1'
    return ('"' + $escaped + '"')
}

# Runs a native command with a verbatim command line, UTF-8 stdin, and stdout/stderr captured to
# files. Returns the exit code.
function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$ArgumentLine,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string]$InputText = '',
        [Parameter(Mandatory)][string]$OutFile,
        [Parameter(Mandatory)][string]$ErrFile
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $ArgumentLine
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.StandardErrorEncoding = $utf8

    $process = [System.Diagnostics.Process]::Start($psi)
    $stderr = $process.StandardError.ReadToEndAsync()
    $bytes = $utf8.GetBytes($InputText)
    $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()

    [System.IO.File]::WriteAllText($OutFile, $stdout, $utf8)
    [System.IO.File]::WriteAllText($ErrFile, $stderr.Result, $utf8)
    return $process.ExitCode
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
