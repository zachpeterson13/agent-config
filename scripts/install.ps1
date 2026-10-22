<#
.SYNOPSIS
  Sets up this machine to use my agent standards (Windows).

.DESCRIPTION
  Safe to re-run: it backs up anything it replaces and skips what's already done.
  Works in Windows PowerShell 5.1 and PowerShell 7+.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -NoPlugins
#>
[CmdletBinding()]
param(
    [switch]$NoPlugins
)

$ErrorActionPreference = 'Stop'

$RepoDir   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$RepoFwd   = $RepoDir -replace '\\', '/'     # Claude imports use forward slashes
$ClaudeDir = Join-Path $HOME '.claude'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

$BeginMarker = '<!-- BEGIN agent-config: managed block, re-running install replaces it -->'
$EndMarker   = '<!-- END agent-config -->'

function Write-Step([string]$Text) { Write-Host ''; Write-Host $Text -ForegroundColor White }
function Write-Ok([string]$Text)   { Write-Host "  OK  $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "  !!  $Text" -ForegroundColor Yellow }

function Write-Utf8([string]$Path, [string]$Text) {
    # UTF-8 without a byte-order mark, which Windows PowerShell 5.1 adds by default.
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Backup-Existing([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $dest = "$Path.bak-$Stamp"
        Move-Item -LiteralPath $Path -Destination $dest -Force
        Write-Warn "Backed up existing $Path to $dest"
    }
}

# ---------------------------------------------------------------------------
Write-Step 'Checking tools'
$missing = $false
foreach ($tool in 'git', 'node', 'claude', 'gh') {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { Write-Ok "$tool found" }
    else { Write-Warn "$tool not found"; $missing = $true }
}
if ($missing) {
    Write-Host @'
    Install what's missing, then re-run this script:
      git    https://git-scm.com/download/win
      node   https://nodejs.org (18.18 or later)
      claude https://docs.claude.com/en/docs/claude-code
      gh     winget install GitHub.cli        (then: gh auth login)
'@
}

# ---------------------------------------------------------------------------
Write-Step 'Linking shared standards'
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

# Claude: a managed block at the top of ~/.claude/CLAUDE.md that imports my AGENTS.md.
# Claude reads it fresh every session, so `git pull` is the whole update.
$ClaudeMd = Join-Path $ClaudeDir 'CLAUDE.md'
$Block = @(
    $BeginMarker
    "@$RepoFwd/AGENTS.md"
    $EndMarker
) -join "`n"
$Fresh = "$Block`n`n<!-- Personal preferences can go below this line. -->`n"

if (Test-Path -LiteralPath $ClaudeMd) {
    $current = [System.IO.File]::ReadAllText($ClaudeMd)
    if ($current.Contains($BeginMarker) -and $current.Contains($EndMarker)) {
        $pattern = [regex]::Escape($BeginMarker) + '(?s).*?' + [regex]::Escape($EndMarker)
        $updated = [regex]::Replace($current, $pattern, { param($m) $Block })
        if ($updated -eq $current) {
            Write-Ok '~/.claude/CLAUDE.md already up to date'
        } else {
            Write-Utf8 $ClaudeMd $updated
            Write-Ok 'Updated the managed block in ~/.claude/CLAUDE.md (kept your personal lines)'
        }
    } else {
        # Most likely an older global CLAUDE.md.
        # Its content now lives in AGENTS.md, so set it aside rather than merge it.
        Backup-Existing $ClaudeMd
        Write-Utf8 $ClaudeMd $Fresh
        Write-Ok 'Wrote ~/.claude/CLAUDE.md'
    }
} else {
    Write-Utf8 $ClaudeMd $Fresh
    Write-Ok 'Wrote ~/.claude/CLAUDE.md'
}

# ---------------------------------------------------------------------------
function Invoke-Try([string]$Label, [string[]]$Command) {
    $exe = $Command[0]
    $cmdArgs = @()
    if ($Command.Length -gt 1) { $cmdArgs = $Command[1..($Command.Length - 1)] }
    $code = 1
    try {
        & $exe @cmdArgs *> $null
        $code = $LASTEXITCODE
    } catch { $code = 1 }
    if ($code -eq 0) { Write-Ok $Label }
    else { Write-Warn "$Label failed or was already done; run it manually: $($Command -join ' ')" }
}

if (-not $NoPlugins) {
    Write-Step 'Installing plugins'
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Invoke-Try 'Claude: Matt Pocock skills' @('claude', 'plugin', 'install', 'mattpocock-skills@claude-plugins-official')
    } else {
        Write-Warn 'Skipping Claude plugins (claude not installed)'
    }
}

# ---------------------------------------------------------------------------
Write-Step 'Next steps'
Write-Host @'
  1. In Claude Code, run /memory to confirm AGENTS.md is loaded (new sessions only).
  2. In each project repo: cd into it, run scripts\init-project.ps1, then /setup-matt-pocock-skills.
  3. To get standards updates later: git pull in this repo.
'@
