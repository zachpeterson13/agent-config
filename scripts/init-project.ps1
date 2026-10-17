<#
.SYNOPSIS
  Adds the team's agent files to a project, new or existing (Windows).

.DESCRIPTION
  Never overwrites. Files that already exist are skipped and listed.
  One exception: a project set up under the old standards (a CLAUDE.md with
  real content and no AGENTS.md) has that content moved into AGENTS.md, and
  CLAUDE.md becomes a one-line import, so Codex can read it too.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\init-project.ps1 C:\code\my-project
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Error "Not a directory: $Path"
}
$Target   = (Resolve-Path -LiteralPath $Path).Path
$Template = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') 'project-template')).Path
$Import   = '@AGENTS.md'

function Write-Utf8([string]$File, [string]$Text) {
    [System.IO.File]::WriteAllText($File, $Text, (New-Object System.Text.UTF8Encoding $false))
}

$added = @(); $skipped = @(); $notes = @()

# --- Migrate an old-style project CLAUDE.md --------------------------------
$projClaude = Join-Path $Target 'CLAUDE.md'
$projAgents = Join-Path $Target 'AGENTS.md'
if (Test-Path -LiteralPath $projClaude) {
    $claudeText = [System.IO.File]::ReadAllText($projClaude)
    $isImportOnly = ($claudeText.Trim() -eq $Import)
    if (-not $isImportOnly) {
        if (Test-Path -LiteralPath $projAgents) {
            $notes += 'CLAUDE.md has its own content and AGENTS.md also exists. Codex only reads AGENTS.md:'
            $notes += "  merge CLAUDE.md into AGENTS.md by hand, then make CLAUDE.md just: $Import"
        } else {
            Write-Utf8 $projAgents $claudeText
            Write-Utf8 $projClaude "$Import`n"
            $notes += 'Moved the existing CLAUDE.md content into AGENTS.md; CLAUDE.md now just imports it.'
            $notes += '  Compare AGENTS.md with the template sections and fill in anything missing.'
        }
    }
}

# --- Copy template files that don't exist yet ------------------------------
$files = Get-ChildItem -LiteralPath $Template -Recurse -File -Force | Sort-Object FullName
foreach ($file in $files) {
    $rel  = $file.FullName.Substring($Template.Length).TrimStart('\', '/')
    $dest = Join-Path $Target $rel
    if (Test-Path -LiteralPath $dest) {
        $skipped += $rel
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $dest
        $added += $rel
    }
}

# --- Report ----------------------------------------------------------------
Write-Host "Project: $Target"
if ($notes.Count) {
    Write-Host ''
    $notes | ForEach-Object { Write-Host "  !! $_" -ForegroundColor Yellow }
}
if ($added.Count) {
    Write-Host ''; Write-Host 'Added:'
    $added | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
}
if ($skipped.Count) {
    Write-Host ''; Write-Host 'Already present (left alone, check they match the template):'
    $skipped | ForEach-Object { Write-Host "  = $_" }
}

Write-Host @'

Next:
  1. Fill in the TODOs in AGENTS.md, or open Claude Code and ask it to fill them
     in by inspecting the solution.
  2. Run /setup-matt-pocock-skills (choose GitLab, your triage labels, and docs/ for docs).
  3. Commit the new files on a chore/ branch and open an MR into dev.
'@
