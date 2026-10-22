<#
.SYNOPSIS
  Adds my agent files to the repo in the current directory (Windows).

.DESCRIPTION
  Run it from the root of the repo. No arguments. Safe to re-run, before or
  after /setup-matt-pocock-skills.

  It adds what's missing and never overwrites your content:
    AGENTS.md              repo context (from the template)
    CLAUDE.md              a one-line import of AGENTS.md, so both tools read one file
    .claude/settings.json  enables Matt Pocock's skills 
    docs/standards/*.md    my stack standards, read only when relevant

  It does NOT create anything /setup-matt-pocock-skills owns (docs/agents/,
  the glossary, ADRs, labels). One fix-up: if that skill wrote its
  "## Agent skills" block into CLAUDE.md, the block is moved to AGENTS.md.

.EXAMPLE
  cd C:\code\my-project
  powershell -ExecutionPolicy Bypass -File $HOME\agent-config\scripts\init-project.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoDir   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Target    = (Get-Location).Path
$Template  = Join-Path $RepoDir 'project-template'
$Standards = Join-Path $RepoDir 'standards'
$Import    = '@AGENTS.md'
$BlockHead = '## Agent skills'

if (-not (Test-Path -LiteralPath (Join-Path $Target '.git'))) {
    Write-Error "Run this from the root of a git repo (no .git folder in $Target)."
}
if ($Target -eq $RepoDir) {
    Write-Error 'This is the agent-config repo itself. cd into the project repo first.'
}

function Read-Text([string]$File)  { [System.IO.File]::ReadAllText($File) }
function Write-Utf8([string]$File, [string]$Text) {
    [System.IO.File]::WriteAllText($File, $Text, (New-Object System.Text.UTF8Encoding $false))
}

# Splits text around the first "## Agent skills" section (up to the next "## " heading).
function Split-Block([string]$Text) {
    $lines = $Text -split "`r?`n"
    $before = @(); $block = @(); $after = @(); $state = 0
    foreach ($line in $lines) {
        if ($state -eq 0 -and $line -match '^## Agent skills\s*$') { $state = 1; $block += $line; continue }
        if ($state -eq 1 -and $line -match '^## ') { $state = 2 }
        switch ($state) { 0 { $before += $line } 1 { $block += $line } 2 { $after += $line } }
    }
    @{ Before = ($before -join "`n"); Block = ($block -join "`n").TrimEnd(); After = ($after -join "`n") }
}

# What's left of a CLAUDE.md once comments, the import line and the skills block are removed.
function Get-LegacyContent([string]$Text) {
    $noBlock = (Split-Block $Text)
    $rest = $noBlock.Before + "`n" + $noBlock.After
    $rest = [regex]::Replace($rest, '(?s)<!--.*?-->', '')
    (($rest -split "`r?`n") | Where-Object { $_.Trim() -ne $Import }) -join "`n" | ForEach-Object { $_.Trim() }
}

$added = @(); $skipped = @(); $notes = @()
$agentsPath = Join-Path $Target 'AGENTS.md'
$claudePath = Join-Path $Target 'CLAUDE.md'
$templateClaude = Read-Text (Join-Path $Template 'CLAUDE.md')

# --- AGENTS.md and CLAUDE.md ----------------------------------------------
if (Test-Path -LiteralPath $claudePath) {
    $claudeText = Read-Text $claudePath
    $split  = Split-Block $claudeText
    $legacy = Get-LegacyContent $claudeText

    if (-not (Test-Path -LiteralPath $agentsPath)) {
        if ($legacy) {
            # Old-style repo: CLAUDE.md held the project context. Move it all.
            $moved = [regex]::Replace($claudeText, "(?m)^\s*$([regex]::Escape($Import))\s*$\r?\n?", '')
            Write-Utf8 $agentsPath ($moved.Trim() + "`n")
            $notes += 'Moved the project context from CLAUDE.md into AGENTS.md.'
            $notes += '  Compare it with project-template/AGENTS.md and add any missing sections.'
        } else {
            $agents = Read-Text (Join-Path $Template 'AGENTS.md')
            if ($split.Block) {
                $agents = $agents.TrimEnd() + "`n`n" + $split.Block + "`n"
                $notes += "Moved the '$BlockHead' block from CLAUDE.md into AGENTS.md."
            }
            Write-Utf8 $agentsPath $agents
            $added += 'AGENTS.md'
        }
        Write-Utf8 $claudePath $templateClaude
    } else {
        if ($split.Block) {
            $agentsText = Read-Text $agentsPath
            $agentsSplit = Split-Block $agentsText
            if ($agentsSplit.Block) {
                $newAgents = $agentsSplit.Before.TrimEnd() + "`n`n" + $split.Block + "`n`n" + $agentsSplit.After.TrimStart()
                $notes += "Replaced the '$BlockHead' block in AGENTS.md with the newer one from CLAUDE.md."
            } else {
                $newAgents = $agentsText.TrimEnd() + "`n`n" + $split.Block + "`n"
                $notes += "Moved the '$BlockHead' block from CLAUDE.md into AGENTS.md."
            }
            Write-Utf8 $agentsPath ($newAgents.TrimEnd() + "`n")
            $claudeText = ($split.Before.TrimEnd() + "`n" + $split.After).Trim() + "`n"
            Write-Utf8 $claudePath $claudeText
        }
        if ($legacy) {
            $notes += 'CLAUDE.md has its own content and AGENTS.md also exists. AGENTS.md is the source of truth:'
            $notes += "  merge CLAUDE.md into AGENTS.md by hand, then make CLAUDE.md just: $Import"
        } elseif ((Read-Text $claudePath) -notmatch [regex]::Escape($Import)) {
            Write-Utf8 $claudePath $templateClaude
            $notes += "CLAUDE.md didn't import AGENTS.md; reset it to the one-line import."
        } else {
            $skipped += 'CLAUDE.md'
        }
        $skipped += 'AGENTS.md'
    }
} elseif (-not (Test-Path -LiteralPath $agentsPath)) {
    Copy-Item -LiteralPath (Join-Path $Template 'AGENTS.md') -Destination $agentsPath
    Write-Utf8 $claudePath $templateClaude
    $added += 'AGENTS.md', 'CLAUDE.md'
} else {
    Write-Utf8 $claudePath $templateClaude
    $added += 'CLAUDE.md'; $skipped += 'AGENTS.md'
}

# --- Other template files (anything not handled above) ---------------------
$files = Get-ChildItem -LiteralPath $Template -Recurse -File -Force | Sort-Object FullName
foreach ($file in $files) {
    $rel = $file.FullName.Substring($Template.Length).TrimStart('\', '/')
    if ($rel -in 'AGENTS.md', 'CLAUDE.md') { continue }
    $dest = Join-Path $Target $rel
    if (Test-Path -LiteralPath $dest) { $skipped += $rel }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $dest
        $added += $rel
    }
}

# --- Standards ------------------------------------------------------------
$stdDest = Join-Path $Target 'docs/standards'
foreach ($file in Get-ChildItem -LiteralPath $Standards -Filter '*.md' -File | Sort-Object Name) {
    $rel  = "docs/standards/$($file.Name)"
    $dest = Join-Path $stdDest $file.Name
    if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Force -Path $stdDest | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $dest
        $added += $rel
    } elseif ((Read-Text $dest) -ne (Read-Text $file.FullName)) {
        $skipped += "$rel (differs from the template version; kept yours)"
    } else {
        $skipped += $rel
    }
}
if ((Read-Text $agentsPath) -notmatch 'docs/standards/') {
    $notes += "AGENTS.md doesn't point to docs/standards/. Add a section like:"
    $notes += '  ## Standards'
    $notes += '  Read the matching file before writing or reviewing code. Don''t load these otherwise.'
    $notes += '  - C#/.NET code: `docs/standards/dotnet.md`'
}

# --- Report ----------------------------------------------------------------
Write-Host "Repo: $Target"
if ($notes.Count) { Write-Host ''; $notes | ForEach-Object { Write-Host "  !! $_" -ForegroundColor Yellow } }
if ($added.Count) { Write-Host ''; Write-Host 'Added:'; $added | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green } }
if ($skipped.Count) { Write-Host ''; Write-Host 'Already present (left alone):'; $skipped | ForEach-Object { Write-Host "  = $_" } }

Write-Host ''
Write-Host 'Next:'
Write-Host '  1. Fill in the TODOs in AGENTS.md (or ask your agent to, from the project files).'
if (-not (Test-Path -LiteralPath (Join-Path $Target 'docs/agents'))) {
    Write-Host '  2. Run /setup-matt-pocock-skills (issue tracker: GitHub). If it writes to CLAUDE.md,'
    Write-Host '     re-run this script to move its block into AGENTS.md.'
}
Write-Host '  3. Commit on a chore/ branch and open a PR into main.'
