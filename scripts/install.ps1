<#
.SYNOPSIS
  Sets up one developer's machine to use the team's agent standards (Windows).

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
$CodexDir  = Join-Path $HOME '.codex'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

$BeginMarker = '<!-- BEGIN agent-config: managed block, re-running install replaces it -->'
$EndMarker   = '<!-- END agent-config -->'
$CopyMarker  = '<!-- Copied by agent-config'

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
foreach ($tool in 'git', 'node', 'claude', 'codex', 'glab') {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { Write-Ok "$tool found" }
    else { Write-Warn "$tool not found"; $missing = $true }
}
if ($missing) {
    Write-Host @'
    Install what's missing, then re-run this script:
      git    https://git-scm.com/download/win
      node   https://nodejs.org (18.18 or later)
      claude https://docs.claude.com/en/docs/claude-code
      codex  npm install -g @openai/codex   (then: codex login)
      glab   winget install GLab.GLab        (then: glab auth login)
'@
}

# ---------------------------------------------------------------------------
Write-Step 'Linking shared standards'
New-Item -ItemType Directory -Force -Path $ClaudeDir, $CodexDir | Out-Null

# Claude: a managed block of imports at the top of ~/.claude/CLAUDE.md.
# Claude reads the repo files fresh every session, so `git pull` is the whole update.
$ClaudeMd = Join-Path $ClaudeDir 'CLAUDE.md'
$Block = @(
    $BeginMarker
    "@$RepoFwd/AGENTS.md"
    "@$RepoFwd/claude/orchestration.md"
    $EndMarker
) -join "`n"
$Fresh = "$Block`n`n<!-- Personal, non-team preferences can go below this line. -->`n"

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
        # Most likely the old global CLAUDE.md copied from the shared drive.
        # Its content now lives in AGENTS.md, so set it aside rather than merge it.
        Backup-Existing $ClaudeMd
        Write-Utf8 $ClaudeMd $Fresh
        Write-Ok 'Wrote ~/.claude/CLAUDE.md'
    }
} else {
    Write-Utf8 $ClaudeMd $Fresh
    Write-Ok 'Wrote ~/.claude/CLAUDE.md'
}

# Codex: ~/.codex/AGENTS.md should be a symlink to the repo's AGENTS.md.
# Windows only allows symlinks with Developer Mode or admin rights, so fall back to a copy.
$CodexAgents = Join-Path $CodexDir 'AGENTS.md'
$SourceAgents = Join-Path $RepoDir 'AGENTS.md'

$item = Get-Item -LiteralPath $CodexAgents -Force -ErrorAction SilentlyContinue
$isOurLink = $false
if ($item -and $item.LinkType -eq 'SymbolicLink') {
    $target = [string]($item.Target | Select-Object -First 1)
    if ($target -eq $SourceAgents) { $isOurLink = $true }
}

if ($isOurLink) {
    Write-Ok '~/.codex/AGENTS.md already linked'
} else {
    if ($item) {
        $isOurCopy = ($item.LinkType -ne 'SymbolicLink') -and
                     ([System.IO.File]::ReadAllText($CodexAgents).StartsWith($CopyMarker))
        if ($isOurCopy) { Remove-Item -LiteralPath $CodexAgents -Force }
        else { Backup-Existing $CodexAgents }
    }

    $linked = $false
    try {
        New-Item -ItemType SymbolicLink -Path $CodexAgents -Target $SourceAgents -ErrorAction Stop | Out-Null
        $linked = $true
    } catch {
        # Windows PowerShell 5.1 insists on admin for New-Item; mklink honors Developer Mode.
        if ($env:OS -eq 'Windows_NT') {
            cmd /c mklink "`"$CodexAgents`"" "`"$SourceAgents`"" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $linked = $true }
        }
    }

    if ($linked) {
        Write-Ok "Linked ~/.codex/AGENTS.md -> $SourceAgents"
    } else {
        $header = "$CopyMarker from $SourceAgents. Re-run scripts/install.ps1 after git pull to refresh. -->`n"
        Write-Utf8 $CodexAgents ($header + [System.IO.File]::ReadAllText($SourceAgents))
        Write-Warn 'Could not create a symlink, so copied ~/.codex/AGENTS.md instead.'
        Write-Warn 'Re-run this script after each git pull, or turn on Windows Developer Mode and re-run once.'
    }
}

# Codex config: never overwrite a personal config; seed it only if absent.
$CodexConfig = Join-Path $CodexDir 'config.toml'
if (Test-Path -LiteralPath $CodexConfig) {
    Write-Ok 'Kept your existing ~/.codex/config.toml (team defaults are in codex/config.toml if you want to compare)'
} else {
    Copy-Item -LiteralPath (Join-Path $RepoDir 'codex/config.toml') -Destination $CodexConfig
    Write-Ok 'Created ~/.codex/config.toml from team defaults'
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
        Invoke-Try 'Claude: Matt Pocock skills'      @('claude', 'plugin', 'install', 'mattpocock-skills@claude-plugins-official')
        Invoke-Try 'Claude: Codex plugin marketplace' @('claude', 'plugin', 'marketplace', 'add', 'openai/codex-plugin-cc')
        Invoke-Try 'Claude: Codex plugin'             @('claude', 'plugin', 'install', 'codex@openai-codex')
    } else {
        Write-Warn 'Skipping Claude plugins (claude not installed)'
    }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Invoke-Try 'Codex: Matt Pocock marketplace' @('codex', 'plugin', 'marketplace', 'add', 'mattpocock/skills')
        Invoke-Try 'Codex: Matt Pocock skills'      @('codex', 'plugin', 'add', 'mattpocock-skills@mattpocock')
    } else {
        Write-Warn 'Skipping Codex plugins (codex not installed)'
    }
}

# ---------------------------------------------------------------------------
Write-Step 'Next steps'
Write-Host @'
  1. In Claude Code, run /codex:setup to confirm Codex is logged in,
     and /memory to confirm both agent-config files are loaded.
  2. In each project, run scripts\init-project.ps1 <path>, then /setup-matt-pocock-skills.
  3. To get standards updates later: git pull in this repo.
'@
