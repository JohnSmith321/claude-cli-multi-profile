# Installer for Multi-Profile Claude CLI hooks.
#
# Usage:
#   cd <repo-folder>
#   .\install-hooks.ps1
#
# Steps:
#   1. Copy hooks/*.ps1 -> ~/.claude-hooks/
#   2. Ensure ~/.claude-00 exists as memory canonical (empty folder).
#   3. Discover .claude-<NN> profile dirs in %USERPROFILE%.
#   4. Register SessionStart hook in settings.json for each profile (claude-01/02/03...).
#      Skip claude-00 profile (memory canonical, no auth session).
#
# Idempotent: safe to re-run. Does not modify other permissions/settings.
# Requires PowerShell 7+ (uses ConvertFrom-Json -AsHashtable).

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: This installer requires PowerShell 7+. Install via: winget install Microsoft.PowerShell" -ForegroundColor Red
    exit 1
}

$hookSourceDir = Join-Path $RepoRoot "hooks"
$hookTargetDir = "$env:USERPROFILE\.claude-hooks"

if (-not (Test-Path $hookSourceDir)) {
    Write-Host "ERROR: hooks/ folder not found at $hookSourceDir" -ForegroundColor Red
    exit 1
}

Write-Host "=== Step 1: Copy hooks -> $hookTargetDir ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $hookTargetDir | Out-Null

Get-ChildItem -Path $hookSourceDir -File | ForEach-Object {
    $dest = Join-Path $hookTargetDir $_.Name
    Copy-Item $_.FullName -Destination $dest -Force
    Write-Host "  copied $($_.Name)" -ForegroundColor Green
}

$hookFile = Join-Path $hookTargetDir "auto-memory-sync.ps1"
$hookCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$($hookFile -replace '\\','/')`""

Write-Host ""
Write-Host "=== Step 2: Ensure .claude-00 memory canonical ===" -ForegroundColor Cyan
$canonRoot = "$env:USERPROFILE\.claude-00"
$canonProjects = Join-Path $canonRoot "projects"
if (-not (Test-Path $canonRoot)) {
    New-Item -ItemType Directory -Force -Path $canonProjects | Out-Null
    Write-Host "  created $canonRoot (empty memory canonical)" -ForegroundColor Green
} else {
    New-Item -ItemType Directory -Force -Path $canonProjects | Out-Null
    Write-Host "  exists $canonRoot" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Step 3: Discover profiles ===" -ForegroundColor Cyan
# Only match .claude-<digits> (00, 01, 02, ...). Exclude .claude-hooks, .claude-backup, etc.
$profileDirs = Get-ChildItem "$env:USERPROFILE" -Directory -Filter ".claude-*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\.claude-\d+$' }
if (-not $profileDirs) {
    Write-Host "  No .claude-<NN> profile dirs found in $env:USERPROFILE" -ForegroundColor Red
    Write-Host "  Login to your first profile via 'claude' command, then re-run installer." -ForegroundColor Yellow
    exit 1
}
$profileDirs | ForEach-Object { Write-Host "  found $($_.Name)" -ForegroundColor Green }

Write-Host ""
Write-Host "=== Step 4: Register SessionStart hook in settings.json ===" -ForegroundColor Cyan

function Add-SessionStartHook {
    param([string]$SettingsPath, [string]$Command)

    # Load existing settings (or create new)
    if (Test-Path $SettingsPath) {
        $raw = Get-Content $SettingsPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $settings = [ordered]@{}
        } else {
            $settings = $raw | ConvertFrom-Json -AsHashtable
        }
    } else {
        $settings = [ordered]@{}
    }

    # Ensure nested structure
    if (-not $settings.Contains("hooks")) {
        $settings["hooks"] = [ordered]@{}
    }
    if (-not $settings["hooks"].Contains("SessionStart")) {
        $settings["hooks"]["SessionStart"] = @()
    }

    # Check if hook already registered (avoid duplicates)
    $existing = $settings["hooks"]["SessionStart"] | Where-Object {
        $_.hooks | Where-Object { $_.command -like "*auto-memory-sync.ps1*" }
    }
    if ($existing) {
        return $false   # already registered
    }

    # Append new hook entry
    $newEntry = [ordered]@{
        hooks = @(
            [ordered]@{
                type    = "command"
                command = $Command
            }
        )
    }
    $settings["hooks"]["SessionStart"] += $newEntry

    # Save
    $settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsPath -Encoding UTF8
    return $true
}

foreach ($profile in $profileDirs) {
    $profileName = $profile.Name   # e.g. ".claude-01"
    # Skip claude-00 (memory canonical only)
    if ($profileName -eq ".claude-00") {
        Write-Host "  skip $profileName (memory canonical, no session)" -ForegroundColor DarkGray
        continue
    }

    $settingsPath = Join-Path $profile.FullName "settings.json"
    $added = Add-SessionStartHook -SettingsPath $settingsPath -Command $hookCommand

    if ($added) {
        Write-Host "  registered hook in $profileName/settings.json" -ForegroundColor Green
    } else {
        Write-Host "  $profileName/settings.json already has hook (skip)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Auto memory sync will activate when you open Claude in any project." -ForegroundColor Green
Write-Host "Restart Claude CLI / VS Code to pick up the hook." -ForegroundColor Yellow
