# Claude Code SessionStart hook: auto-apply memory unification pattern
# khi Claude bắt đầu session trong 1 project.
#
# Pattern: ~/.claude-00/projects/<proj-hash>/memory/ là folder THẬT (canonical).
# Các profile khác (claude-01/02/03...) chứa junction trỏ về canonical.
# → Memory share giữa các profile, chat history vẫn isolate.
#
# Behavior:
#   - Idempotent (re-run safe)
#   - Safe (skip nếu memory folder có data, để user backup + merge thủ công)
#   - Silent trên success (Claude UI không hiện gì)
#   - Skip nếu đang ở profile claude-00 (memory canonical, không có session)
#
# Input: JSON từ stdin với field "cwd" (Claude Code tự gửi)

$ErrorActionPreference = "Continue"

# Read JSON input từ stdin
$inputJson = [Console]::In.ReadToEnd()
try {
    $hookInput = $inputJson | ConvertFrom-Json
} catch {
    exit 0
}

$cwd = $hookInput.cwd
if (-not $cwd) { exit 0 }

# Encode cwd → project hash (replace non-alphanumeric với '-')
$projHash = $cwd -replace '[^a-zA-Z0-9]', '-'

# Profile hiện tại từ CLAUDE_CONFIG_DIR
$configDir = $env:CLAUDE_CONFIG_DIR
if (-not $configDir) { exit 0 }

# Normalize path: convert forward slashes to backslashes (mklink yêu cầu consistent)
$configDir = $configDir -replace '/', '\'

# Skip nếu đang chạy as claude-00 (memory-only profile, không có session thực)
if ($configDir -like "*\.claude-00*") { exit 0 }

$canon = "$env:USERPROFILE\.claude-00\projects\$projHash\memory"
$junc = "$configDir\projects\$projHash\memory"
$projDir = Split-Path $junc -Parent

# Ensure project folder exists ở profile đích
New-Item -ItemType Directory -Force -Path $projDir | Out-Null

# Check state hiện tại
if (Test-Path $junc) {
    $item = Get-Item $junc -Force
    if ($item.LinkType -eq "Junction") {
        # Đã là junction — verify target trỏ về claude-00
        if ($item.Target -like "*\.claude-00\*") {
            exit 0  # OK
        }
        # Junction trỏ chỗ khác — don't touch
        exit 0
    }
    # Real folder — check empty
    $contents = Get-ChildItem $junc -Force -ErrorAction SilentlyContinue
    if ($contents) {
        # Có data → don't touch (user phải backup + merge thủ công)
        exit 0
    }
    # Empty folder → safe to remove
    Remove-Item $junc -Force
}

# Ensure canonical exists
New-Item -ItemType Directory -Force -Path $canon | Out-Null

# Create junction
cmd /c mklink /J "$junc" "$canon" 2>&1 | Out-Null
exit 0
