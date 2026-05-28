# Claude CLI Profile Setup — Quick Reference

> Đây là quick-ref cho người đang dùng setup này. Hướng dẫn cài đặt đầy đủ ở [README.md](README.md).

## Profile Layout

Số suffix khớp với số account (`.claude-01` = Account #1, `.claude-02` = Account #2, ...). `.claude-00` là memory canonical (folder rỗng, auto-tạo bởi `install-hooks.ps1`).

| Command | Profile Dir | Mục đích |
|---|---|---|
| `claude` | `~/.claude` (junction → profile đang active) | Mặc định, đổi bằng `Switch-Claude` |
| `claude-01` | `~/.claude-01` | Account #1 |
| `claude-02` | `~/.claude-02` | Account #2 |
| `claude-03` | `~/.claude-03` | Account #3 |
| *(memory canonical)* | `~/.claude-00` | Folder rỗng để các profile khác symlink memory về |

## PowerShell Profile

Functions cài đặt trong `$PROFILE` (xem `$PROFILE` để biết đường dẫn cụ thể trên máy bạn):

```powershell
function claude-01 { $env:CLAUDE_CONFIG_DIR="$env:USERPROFILE\.claude-01"; claude @args }
function claude-02 { $env:CLAUDE_CONFIG_DIR="$env:USERPROFILE\.claude-02"; claude @args }
function claude-03 { $env:CLAUDE_CONFIG_DIR="$env:USERPROFILE\.claude-03"; claude @args }

function Switch-Claude {
    param([string]$Profile = "01")
    $target = "$env:USERPROFILE\.claude"
    $source = "$env:USERPROFILE\.claude-$Profile"
    if (-not (Test-Path $source)) {
        Write-Host "Profile .claude-$Profile does not exist" -ForegroundColor Red
        return
    }
    if (Test-Path $target) { cmd /c rmdir "$target" }
    cmd /c mklink /J "$target" "$source"
    [System.Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $source, 'User')
    $env:CLAUDE_CONFIG_DIR = $source
    Write-Host "Default claude now uses claude-$Profile (restart VS Code to apply)" -ForegroundColor Green
}
```

`Add-ClaudeMemorySync` function (optional helper, source trong README) — apply memory unification pattern cho 1 project bất kỳ. Không bắt buộc vì SessionStart hook đã auto-apply.

## Cách hoạt động

- `~/.claude` là **directory junction** trỏ vào profile đang active.
- `Switch-Claude <N>` làm 2 việc:
  1. Redirect junction sang profile target.
  2. Set `CLAUDE_CONFIG_DIR` (User env var, persistent) → auth, session, history đều đến từ profile đúng.
- Function `claude-01`, `claude-02`, `claude-03` chỉ override `CLAUDE_CONFIG_DIR` cho terminal session đó (không đổi default).

## Switching

```powershell
Switch-Claude 01    # đổi default sang claude-01 (Account #1)
Switch-Claude 02    # đổi default sang claude-02 (Account #2)
Switch-Claude 03    # đổi default sang claude-03 (Account #3)
# (Không có Switch-Claude 00 — .claude-00 là memory canonical, không có auth)
```

Sau khi switch:
- Terminal hiện tại: áp dụng ngay.
- Terminal mới: tự pick up qua User env var.
- VS Code extension: cần **restart VS Code** để apply.

## Verify

```powershell
claude auth status   # account của profile đang active
echo $env:CLAUDE_CONFIG_DIR   # profile dir đang dùng
```

## One-Time Setup

```powershell
# Sau khi login profile đầu tiên qua `claude`:
Rename-Item "$env:USERPROFILE\.claude" ".claude-01"
cmd /c mklink /J "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude-01"

# Login thêm profile (lặp lại với CLAUDE_CONFIG_DIR khác):
$env:CLAUDE_CONFIG_DIR = "$env:USERPROFILE\.claude-02"; claude
```

## Memory Layout — Canonical at `claude-00`

`~/.claude-00/projects/<proj-hash>/memory/` là folder THẬT (canonical); các profile khác chứa junction trỏ về. Switch profile nào, Claude vẫn đọc/ghi memory vào cùng 1 nơi.

### Auto-apply qua SessionStart hook

Sau khi cài hook (`./install-hooks.ps1` từ thư mục repo), mỗi lần Claude bắt đầu session trong 1 project, hook tự apply pattern. Không cần thao tác thủ công.

- **Hook script:** `~/.claude-hooks/auto-memory-sync.ps1`
- **Registered in:** `SessionStart` của settings.json mỗi profile (trừ claude-00)
- **Behavior:**
  - Idempotent (re-run trên project đã apply: skip)
  - Safe (skip nếu memory folder đang có data)
  - Silent on success (không hiện trong Claude UI)
  - Skip nếu CLAUDE_CONFIG_DIR trỏ claude-00

→ Workflow đơn giản: mở project mới trong VS Code → mở Claude → memory auto-unified, không cần lệnh nào.

### Verify

```powershell
Get-Item "$env:USERPROFILE\.claude-01\projects\<proj-hash>\memory" | Select Name, LinkType, Target
# LinkType = Junction, Target → ...\.claude-00\... → đã áp dụng
```

Script generic + Add-ClaudeMemorySync source: xem [README.md § Memory hoạt động ra sao](README.md#memory-hoạt-động-ra-sao).

## Isolation hiện tại

Chỉ **`projects/<hash>/memory/`** là shared (qua junction về claude-00). Mọi data khác **isolate per profile**: auth, chat history, sessions, settings, hooks, plans, plugins, cache.

→ Switch profile vẫn an toàn cho privacy (chat work/personal không lẫn) và concurrent run (chạy 2 profile cùng lúc 2 terminal không corrupt state).

Trade-off chi tiết về việc sync thêm data khác (sessions, history, settings...): xem [README.md § Có nên sync thêm gì khác không?](README.md#có-nên-sync-thêm-gì-khác-không).
