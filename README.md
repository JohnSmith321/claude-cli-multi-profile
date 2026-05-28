# Multi-Profile Claude CLI cho Windows

> Chạy song song nhiều profile [Claude Code](https://docs.claude.com/claude-code) trên cùng một máy Windows, mỗi profile dùng tài khoản Anthropic khác nhau. Switch nhanh bằng PowerShell. Kèm pattern unify memory giữa các profile để Claude "nhớ" cùng context dù bạn đang ở profile nào.

[![Windows](https://img.shields.io/badge/Windows-10%2F11-blue)](#)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)](#)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-CLI-orange)](https://docs.claude.com/claude-code)

---

## Mục lục

- [Tại sao cần multi-profile?](#tại-sao-cần-multi-profile)
- [Tính năng](#tính-năng)
- [Yêu cầu](#yêu-cầu)
- [Quick Start](#quick-start)
- [Setup chi tiết](#setup-chi-tiết)
- [Sử dụng hàng ngày](#sử-dụng-hàng-ngày)
- [Memory hoạt động ra sao](#memory-hoạt-động-ra-sao)
- [Hook chặn `pip install` ngoài venv (tùy chọn)](#hook-chặn-pip-install-ngoài-venv-tùy-chọn)
- [Troubleshooting](#troubleshooting)
- [Cấu trúc Repo](#cấu-trúc-repo)
- [Đóng góp](#đóng-góp)
- [License](#license)
- [Tham khảo](#tham-khảo)

---

## Tại sao cần multi-profile?

Claude Code mặc định lưu auth, session, settings tại `~/.claude/`. Nếu bạn có:
- Nhiều tài khoản Anthropic (cá nhân + công ty, Pro + Team, v.v.)
- Hoặc muốn cô lập history/context giữa các "workspace" khác nhau

Cách thông thường là logout/login đi lại — chậm và mất history. Setup này giải quyết bằng **mỗi tài khoản một thư mục profile riêng**, switch giữa các profile bằng 1 lệnh.

## Tính năng

- **Cô lập** auth, chat history, sessions, settings, hooks giữa các profile — mỗi tài khoản Anthropic có workspace riêng
- **Switch instant** bằng lệnh PowerShell (`Switch-Claude 01`) — không cần logout/login
- **Per-terminal override** với function `claude-01`, `claude-02`... cho phép một terminal dùng profile khác mà không đổi default
- **Memory unification** mặc định qua SessionStart hook — auto-share `projects/<hash>/memory/` giữa các profile khi mở project. Tất cả chat history, sessions, settings vẫn isolate. Cài 1 lệnh (`./install-hooks.ps1`).
- **Mở rộng** số profile tùy ý (01, 02, 03, ...) — số suffix khớp số account
- **Optional hook** chặn `pip install` ngoài venv — tránh Claude lỡ tay cài package vào global Python

## Yêu cầu

| Component | Min version | Kiểm tra |
|---|---|---|
| Windows | 10/11 | — |
| Node.js | 20 LTS | `node --version` |
| PowerShell | 7+ | `$PSVersionTable.PSVersion` |
| Claude Code CLI | latest | `claude --version` |
| Git for Windows | bất kỳ | chỉ cần nếu dùng hook `.sh` |
| Tài khoản Anthropic | 1 per profile | — |

Cài Claude Code: `npm install -g @anthropic-ai/claude-code`

## Quick Start

Setup nhanh 2 profile (`.claude-01` = Account #1, `.claude-02` = Account #2):

```powershell
# 1. Login Account #1 (lần đầu chạy claude)
claude
# (Login bằng account #1, xong /exit)

# 2. Rename ~/.claude → ~/.claude-01 + tạo junction
Rename-Item "$env:USERPROFILE\.claude" ".claude-01"
cmd /c mklink /J "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude-01"

# 3. Login Account #2 vào ~/.claude-02
$env:CLAUDE_CONFIG_DIR = "$env:USERPROFILE\.claude-02"
claude
# (Login bằng account #2, xong /exit)

# 4. Add shortcuts vào PowerShell profile
notepad $PROFILE
# Paste đoạn function ở phần "Setup chi tiết" bên dưới
. $PROFILE

# 5. Cài auto memory sync hook (clone repo này về trước)
.\install-hooks.ps1
# → tạo ~/.claude-00 rỗng làm memory canonical
# → register SessionStart hook trên mọi profile
# Restart VS Code sau bước này.

# 6. Dùng
claude-02           # chạy profile 02 cho terminal này
Switch-Claude 02    # đổi default sang 02 (vĩnh viễn)
```

Quy ước số: `.claude-01` chứa account #1 đầu tiên, `.claude-02` account #2, v.v. `.claude-00` là folder rỗng làm memory canonical (xem section "Memory hoạt động ra sao").

Phần dưới đây là hướng dẫn đầy đủ + memory unification.

---

## Setup chi tiết

### Bước 1 — Login profile mặc định

```powershell
claude
```

Lần chạy đầu sẽ tạo `~/.claude/` và yêu cầu login. Login bằng account #1 của bạn, xong `/exit`.

### Bước 2 — Rename profile thành .claude-01 + tạo junction

Profile vừa login (Account #1) đang ở `~/.claude/`. Đổi tên thành `.claude-01` để khớp với quy ước "số suffix = số account".

> **Lưu ý:** Đóng tất cả VS Code và terminal có Claude đang chạy trước khi làm bước này (tránh file lock).

```powershell
Rename-Item "$env:USERPROFILE\.claude" ".claude-01"
cmd /c mklink /J "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude-01"
```

Verify:
```powershell
Get-Item "$env:USERPROFILE\.claude" | Select Name, LinkType, Target
# LinkType = Junction, Target → ...\.claude-01
```

### Bước 3 — Tạo các profile bổ sung (account #2, #3...)

Với mỗi tài khoản phụ, set `CLAUDE_CONFIG_DIR` tạm thời rồi login. **Số suffix khớp với account #**:

```powershell
# Account #2 → .claude-02
$env:CLAUDE_CONFIG_DIR = "$env:USERPROFILE\.claude-02"
claude
# Login Account #2, /exit

# Account #3 → .claude-03
$env:CLAUDE_CONFIG_DIR = "$env:USERPROFILE\.claude-03"
claude
# Login Account #3, /exit
```

Lặp lại cho `04`, `05`... nếu cần.

> **Bỏ qua `.claude-00`** — số này là memory canonical (auto-tạo bởi `install-hooks.ps1`, xem section "Memory hoạt động ra sao"). Bắt đầu account thứ 2 từ `.claude-02`.

### Bước 4 — Cài PowerShell shortcuts

Tìm đường dẫn PowerShell profile của bạn:

```powershell
$PROFILE
# Ví dụ: C:\Users\<bạn>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Tạo file nếu chưa có:

```powershell
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}
notepad $PROFILE
```

Paste vào (sửa số profile cho khớp với số bạn đã tạo):

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

Save → reload:

```powershell
. $PROFILE
```

### Bước 5 — Verify

```powershell
claude-01 auth status   # phải in ra Account #1
claude-02 auth status   # phải in ra Account #2
Switch-Claude 02        # đổi default sang Account #2
claude auth status      # giờ default = Account #2
Switch-Claude 01        # về lại Account #1
```

---

## Sử dụng hàng ngày

| Lệnh | Tác dụng |
|---|---|
| `claude` | Chạy profile đang active (do `Switch-Claude` chọn) |
| `claude-01` | Chạy profile 01 cho **terminal hiện tại** (không đổi default) |
| `claude-02` | Tương tự với profile 02 |
| `Switch-Claude 01` | Đổi default profile sang 01 (vĩnh viễn — ảnh hưởng terminal mới + VS Code) |
| `claude auth status` | Xem profile/account đang dùng |

**VS Code extension:** đọc env `CLAUDE_CONFIG_DIR` lúc khởi động. Sau khi `Switch-Claude`, phải **restart VS Code** (đóng hết cửa sổ) thì extension mới nhận profile mới.

---

## Memory hoạt động ra sao

Claude Code có **2 cơ chế "memory" độc lập** — hiểu rõ để dùng đúng:

### 1. `CLAUDE.md` (project-level)

- File nằm trong thư mục project (`<your-project>/CLAUDE.md`)
- Mọi profile mở project đều đọc cùng file → đi theo project
- Commit được vào git, share với teammate được
- **Đây là nơi nên ghi context quan trọng** của project (architecture decisions, phase đã đóng, lessons learned)

### 2. Auto memory folder (per-profile)

- Claude tự tạo ở `~/.claude-XX/projects/<encoded-project-path>/memory/`
- Path encoding: `d:\Project\Foo` → `d--Project-Foo`
- **Mặc định:** mỗi profile có một bản memory độc lập cho cùng project → switch profile = mất memory cũ

### Vấn đề và pattern giải quyết

Khi bạn dùng nhiều profile và mở **cùng 1 project** từ các profile khác nhau, mặc định memory bị phân mảnh — Claude trong profile A không thấy memory profile B đã ghi.

**Giải pháp:** Tạo `~/.claude-00/` rỗng làm memory canonical (không có auth, chỉ chứa memory). Các profile thật (`.claude-01`, `.claude-02`, `.claude-03`...) symlink memory folder trỏ về `.claude-00`.

```
~/.claude-00/projects/<proj-hash>/memory/   ← folder THẬT (canonical, KHÔNG có auth)
~/.claude-01/projects/<proj-hash>/memory/   → junction → claude-00
~/.claude-02/projects/<proj-hash>/memory/   → junction → claude-00
~/.claude-03/projects/<proj-hash>/memory/   → junction → claude-00
```

Sau khi áp pattern: Claude trong mọi profile khi mở project đó sẽ đọc/ghi memory cùng 1 nơi.

> `.claude-00` chỉ là 1 folder rỗng dành cho memory canonical. Đừng login account vào đây — `Switch-Claude` mặc định cũng không trỏ về 00 (không có auth để dùng).

### Cái gì isolate, cái gì share sau pattern

Pattern này chỉ share **đúng 1 thứ** — folder `memory/` subfolder. Mọi data khác vẫn cô lập per-profile:

| Loại data | Vị trí | Sau khi áp pattern |
|---|---|---|
| Auth credentials | `~/.claude-XX/.credentials.json` | ✓ Isolate per profile |
| Chat session logs (per project) | `~/.claude-XX/projects/<hash>/*.jsonl` | ✓ Isolate per profile |
| Global history | `~/.claude-XX/history.jsonl` | ✓ Isolate per profile |
| Sessions state | `~/.claude-XX/sessions/` | ✓ Isolate per profile |
| File history, shell snapshots, plans, cache, backups | `~/.claude-XX/{file-history,shell-snapshots,plans,cache,backups}/` | ✓ Isolate per profile |
| Per-profile settings + hook config | `~/.claude-XX/settings.json` | ✓ Isolate per profile |
| Plugins | `~/.claude-XX/plugins/` | ✓ Isolate per profile |
| **Auto memory (per project)** | `~/.claude-XX/projects/<hash>/memory/` | ⚠ **SHARED** via junction → claude-00 |

**Thực tế:** switch profile để chat dưới account khác — conversation history hoàn toàn tách biệt. Chỉ có "Claude nhớ gì về project này" (auto memory) là dùng chung. Đúng điều bạn muốn khi dùng nhiều profile.

### Có nên sync thêm gì khác không?

Câu hỏi tự nhiên: nếu memory sync được, sao không sync luôn settings, history, sessions? Câu trả lời: từng loại có trade-off riêng.

**Không sync được (technical block):**

| Data | Vì sao |
|---|---|
| `~/.claude-XX/.credentials.json` | Mỗi profile = 1 Anthropic account khác. Sync = chỉ 1 account hoạt động → mất point multi-profile |
| `~/.claude-XX/.claude.json` | Chứa `userID`, `oauthAccount`, project state — buộc vào account đang login. Sync gây state confusion |

**Có thể sync nhưng rủi ro cao — KHÔNG khuyến nghị:**

| Data | Downside |
|---|---|
| `sessions/` | **File lock conflict** nếu 2 profile chạy đồng thời (vd `claude-01` và `claude-02` mở trong 2 terminal khác nhau) → corrupt state |
| `history.jsonl` | Concurrent write risk + privacy mix (bấm ↑ trong REPL thấy prompt của account khác) |
| `projects/<hash>/*.jsonl` (chat logs) | Mix chat work/personal. Continue session cũ trên account khác = quota/billing không clean |
| `cache/`, `backups/` | Có thể tag theo `userID` → cache invalidation logic break |

**An toàn nhưng tùy chọn:**

| Data | Benefit | Caveat |
|---|---|---|
| `settings.json` | Hook config + model preference đồng nhất 1 lần | Nếu mỗi profile muốn model khác (opus vs sonnet) thì buộc phải đồng nhất |
| `plans/` | Share planning artifacts giữa các profile | Lock risk nhẹ nếu concurrent edit |
| `plugins/` | Cài plugin 1 lần, mọi profile dùng được | An toàn cao |

> ⚠ **Đừng sync `settings.local.json`** — file này grow mỗi lần bạn approve permission cho một command. Sync = mọi profile tự thừa kế quyền lẫn nhau, scope rộng hơn dự kiến.

**Khuyến nghị thực tế:**

- ✓ **Memory** (đã setup ở trên) — cần thiết, không có lý do để skip
- ✓ **`settings.json`** — sync được nếu muốn hook/model config đồng nhất. Pattern tương tự memory: chuyển file vào claude-00, các profile khác symlink trỏ về.
- ✗ **Mọi thứ khác** — giữ isolate. Multi-profile có ý nghĩa khi giữ tách biệt:
  - **Privacy:** chat personal không lẫn vào history work
  - **Concurrent safety:** chạy 2 profile cùng lúc trong 2 terminal không corrupt state
  - **Billing clarity:** mỗi account có quota riêng, biết session nào dùng quota của ai

### Auto-apply qua SessionStart hook

Đây là cách áp dụng pattern mặc định (đã có ở Quick Start bước 5). Mỗi lần Claude bắt đầu session trong 1 project, **SessionStart hook** tự động apply pattern — không cần chạy script thủ công cho từng project.

Repo này có sẵn:
- `hooks/auto-memory-sync.ps1` — hook script (idempotent, safe, silent on success)
- `install-hooks.ps1` — installer auto register hook vào mọi profile

**Cài 1 lệnh sau khi clone:**

```powershell
# Từ thư mục repo
.\install-hooks.ps1
```

Installer làm:
1. Copy `hooks/*.ps1` → `~/.claude-hooks/`
2. Tạo `~/.claude-00` làm memory canonical (nếu chưa có)
3. Detect các profile `.claude-<NN>` đang có
4. Register `SessionStart` hook trong `settings.json` của mỗi profile (trừ claude-00)

Idempotent — re-run an toàn.

Sau khi install: restart Claude CLI / VS Code. Lần sau bạn `VS Code → Open Folder` 1 project mới và mở Claude, memory tự unified, không cần thao tác gì.

**Yêu cầu:** PowerShell 7+ (installer dùng `ConvertFrom-Json -AsHashtable`).

### Script áp dụng pattern cho 1 project (manual fallback)

Nếu không dùng auto hook ở trên (hoặc cần apply một-lần cho project cụ thể), copy function dưới đây vào `$PROFILE` PowerShell:

```powershell
function Add-ClaudeMemorySync {
    <#
    .SYNOPSIS
    Apply memory unification cho 1 project (canonical = claude-00, junction từ 01/02/03).
    Idempotent + safe (refuse overwrite folder có data).
    #>
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$ProjectPath = (Get-Location).Path
    )

    # Encode project path → hash (replace non-alphanumeric với '-')
    $projHash = $ProjectPath -replace '[^a-zA-Z0-9]', '-'
    $canon = "$env:USERPROFILE\.claude-00\projects\$projHash\memory"
    Write-Host "Project: $ProjectPath" -ForegroundColor Cyan
    Write-Host "Hash:    $projHash" -ForegroundColor Cyan

    # Ensure canonical exists
    if (-not (Test-Path $canon)) {
        New-Item -ItemType Directory -Force -Path $canon | Out-Null
        Write-Host "  Created canonical at claude-00" -ForegroundColor Green
    }

    # For each profile 01/02/03: create junction (skip if already correct)
    foreach ($p in @("01","02","03")) {
        $projDir = "$env:USERPROFILE\.claude-$p\projects\$projHash"
        $junc = Join-Path $projDir "memory"
        New-Item -ItemType Directory -Force -Path $projDir | Out-Null

        if (Test-Path $junc) {
            $item = Get-Item $junc -Force
            if ($item.LinkType -eq "Junction") {
                if ($item.Target -like "*\.claude-00\*") {
                    Write-Host "  [$p] Already junctioned (skip)" -ForegroundColor DarkGray
                    continue
                }
                Write-Host "  [$p] Junction points to UNEXPECTED target: $($item.Target)" -ForegroundColor Red
                continue
            }
            # Real folder — check if empty
            $contents = Get-ChildItem $junc -Force -ErrorAction SilentlyContinue
            if ($contents) {
                Write-Host "  [$p] Memory folder has DATA (skip to avoid loss; backup + merge manually)" -ForegroundColor Yellow
                continue
            }
            Remove-Item $junc -Force
        }

        cmd /c mklink /J "$junc" "$canon" | Out-Null
        Write-Host "  [$p] Junction created -> claude-00" -ForegroundColor Green
    }
}
```

Cách dùng:

```powershell
cd d:\Project\NewProject
Add-ClaudeMemorySync                  # cho thư mục hiện tại
Add-ClaudeMemorySync "d:\Project\X"   # chỉ định path
```

> **Cảnh báo:** Function refuse overwrite memory folder đang có data. Nếu profile đích đã có memory file cho project đó, backup trước (`Copy-Item -Recurse`) rồi merge vào canonical (`claude-00`) → re-run function.

### Pre-built prompt cho teammate

Nếu bạn muốn teammate cũng setup pattern này trên máy của họ, cách đơn giản nhất là **paste hướng dẫn dưới đây vào Claude Code đang chạy trên máy teammate** — Claude sẽ tự audit + backup + plan + execute.

<details>
<summary><b>Prompt template (click để mở)</b></summary>

```text
Tôi đang setup Multi-Profile Claude CLI trên Windows theo pattern của một đồng nghiệp. Tôi có nhiều profile (`.claude-00`, `.claude-01`, có thể có thêm `.claude-02`, `.claude-03`) dưới `%USERPROFILE%`, mỗi profile login một account Anthropic khác nhau.

**Vấn đề tôi muốn giải quyết:** Mỗi profile Claude lưu auto-memory riêng cho cùng một project, nên khi switch profile thì memory không thấy nhau. Tôi muốn unify bằng pattern: **`claude-00` là canonical (folder thật)**, các profile khác (`01/02/03`...) symlink trỏ về.

Cụ thể với mỗi project có memory:

  ~/.claude-00/projects/<proj-hash>/memory/   ← folder THẬT
  ~/.claude-01/projects/<proj-hash>/memory/   → junction → claude-00
  ~/.claude-02/projects/<proj-hash>/memory/   → junction → claude-00
  ...

### Yêu cầu

Giúp tôi audit + thực hiện việc unify đó. Quy trình:

**Bước 1 — Inventory:**
- Liệt kê các profile `.claude-XX` đang tồn tại trong `%USERPROFILE%`
- Cho mỗi profile, liệt kê các project folder dưới `<profile>/projects/` có chứa folder con `memory/` không rỗng
- In ra bảng: profile × project × số file memory × danh sách file
- Cho biết các project nào có memory ở 2+ profile (= fragmented, cần merge cẩn thận)

**Bước 2 — Backup:**
- Tạo folder backup ở chỗ tôi chọn (mặc định `C:/Users/<username>/claude-memory-backup-<timestamp>/`), hỏi tôi xác nhận đường dẫn
- Copy toàn bộ memory folder của tất cả profile vào backup
- In ra tổng số file đã backup để xác nhận

**Bước 3 — Plan:**
- Cho mỗi project có memory, đề xuất:
  - Project nào có memory chỉ ở 1 profile (không phải claude-00): copy thẳng sang claude-00
  - Project nào có memory chỉ ở claude-00: giữ nguyên
  - Project nào fragmented (ở 2+ profile): liệt kê file của từng profile, gợi ý cách merge (union nếu file không trùng tên, hỏi tôi chọn bản nào nếu trùng tên với nội dung khác)
- Hiển thị plan dưới dạng bảng + dừng lại chờ tôi confirm trước khi thực hiện

**Bước 4 — Execute (sau khi tôi OK):**
- Chuẩn bị canonical: đảm bảo `~/.claude-00/projects/<proj-hash>/memory/` chứa data merged đầy đủ (copy từ các profile khác sang)
- Cho mỗi profile khác `claude-00` × mỗi project: xóa folder memory cũ (đã backup), tạo junction `mklink /J` trỏ về claude-00
- Tạo project folder trống ở profile đích trước nếu chưa có

**Bước 5 — Verify:**
- Liệt kê lại tất cả memory folder ở các profile ≠ claude-00, xác nhận đều là Junction trỏ về `.claude-00`
- Đếm: số junction tạo, số folder thật còn sót
- Đọc thử nội dung memory từ 1-2 project qua junction để confirm data đọc được OK

### Quy tắc bắt buộc

1. **Backup trước khi xóa bất kỳ memory folder nào** — nếu chưa backup thì dừng và yêu cầu tôi confirm.
2. **Không tự ý merge file trùng tên có nội dung khác nhau** — hỏi tôi chọn bản nào hoặc cho phép gộp.
3. **Junction phải dùng `cmd /c mklink /J`** (không phải symbolic link — junction không cần admin, hoạt động cross-drive).
4. **Đóng VS Code và các terminal Claude đang chạy trước khi xóa folder memory** — nếu phát hiện process đang lock file thì dừng và báo tôi.
5. **Sau khi xong: nhắc tôi restart VS Code** (extension cache memory state).

### Môi trường

- OS: Windows 10/11
- Shell: PowerShell 7
- Đường dẫn profile: `%USERPROFILE%\.claude-XX\` (có thể có `.claude-00`, `.claude-01`, `.claude-02`, `.claude-03` — tùy số profile tôi đã tạo)

Bắt đầu từ Bước 1. Cảm ơn.
```

</details>

### Khi nào nên dùng `CLAUDE.md` vs auto memory folder

| Loại context | Lưu vào |
|---|---|
| Architecture decisions, phase đã đóng, lessons learned, conventions của project | `CLAUDE.md` (đi theo project + git) |
| User preferences, behavioral feedback Claude tự note, ephemeral facts | Auto memory folder (Claude tự quản lý) |

Lý tưởng: project-relevant info luôn ở CLAUDE.md, auto memory chỉ giữ feedback/user-level. Memory unification pattern bên trên giải quyết vấn đề "auto memory phân mảnh" trong khi vẫn giữ CLAUDE.md làm source of truth cho project.

---

## Hook chặn `pip install` ngoài venv (tùy chọn)

Nếu bạn dùng Python nhiều và muốn Claude không lỡ tay cài package vào global Python, cài hook này.

### Bước 1 — Tạo hook file

```powershell
$hookDir = "$env:USERPROFILE\.claude-hooks"
New-Item -ItemType Directory -Path $hookDir -Force
notepad "$hookDir\check-venv.sh"
```

Paste:

```bash
#!/bin/bash
# Hook: block "pip install" if no venv exists in the working directory.
# Reads PreToolUse JSON from stdin. No jq dependency — uses grep/sed.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"\s*:\s*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')
[ "$TOOL_NAME" != "Bash" ] && exit 0

CWD=$(echo "$INPUT" | grep -o '"cwd"\s*:\s*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/')
COMMAND=$(echo "$INPUT" | grep -o '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')

echo "$COMMAND" | grep -qiE '(^|\s|/)pip[0-9]?\s+install' || exit 0

if [ -d "$CWD/.venv" ] || [ -d "$CWD/venv" ]; then
    if echo "$COMMAND" | grep -qE '(\.venv|venv)'; then
        exit 0
    fi
    echo "BLOCKED: venv exists at $CWD but you are calling global pip. Use .venv/Scripts/pip instead." >&2
    exit 2
fi

echo "BLOCKED: No virtual environment found in $CWD. Create one first: python -m venv .venv" >&2
exit 2
```

### Bước 2 — Đăng ký hook trong từng profile

Mở `settings.json` của từng profile (`.claude-00\settings.json`, `.claude-01\settings.json`...) và thêm vào key `hooks`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash C:/Users/<USERNAME>/.claude-hooks/check-venv.sh"
          }
        ]
      }
    ]
  }
}
```

Thay `<USERNAME>` bằng username Windows thật của bạn (`echo $env:USERNAME`). Đường dẫn dùng `/` không phải `\` vì hook chạy qua Git Bash.

---

## Troubleshooting

<details>
<summary><b><code>mklink</code> báo "Cannot create a file when that file already exists"</b></summary>

Thư mục `.claude` đã tồn tại. Đóng hết Claude/VS Code, rồi:
```powershell
cmd /c rmdir "$env:USERPROFILE\.claude"   # nếu là junction
# hoặc backup folder rồi xóa nếu là folder thật
```
</details>

<details>
<summary><b>Lệnh <code>claude-01</code> không nhận được sau khi sửa PowerShell profile</b></summary>

Reload profile: `. $PROFILE`. Hoặc mở terminal mới.
</details>

<details>
<summary><b><code>Switch-Claude</code> chạy xong nhưng VS Code vẫn dùng profile cũ</b></summary>

Restart VS Code hoàn toàn (đóng tất cả cửa sổ). Extension đọc env `CLAUDE_CONFIG_DIR` lúc khởi động.
</details>

<details>
<summary><b><code>auth status</code> hiện sai account</b></summary>

Check env var: `echo $env:CLAUDE_CONFIG_DIR`. Phải trỏ tới profile dir đúng.
</details>

<details>
<summary><b>Hook báo "bash: command not found"</b></summary>

Cài [Git for Windows](https://git-scm.com/). Hoặc sửa đường dẫn bash đầy đủ trong `settings.json`:
```json
"command": "C:/Program Files/Git/bin/bash.exe C:/Users/<USERNAME>/.claude-hooks/check-venv.sh"
```
</details>

<details>
<summary><b><code>Rename-Item</code> báo file đang được dùng</b></summary>

Có Claude/VS Code đang mở. Đóng hết rồi thử lại.
</details>

<details>
<summary><b>Memory không sync giữa các profile dù đã symlink</b></summary>

Verify junction:
```powershell
Get-Item "$env:USERPROFILE\.claude-01\projects\<proj-hash>\memory" | Select Name, LinkType, Target
```
LinkType phải là `Junction`, Target phải trỏ về `.claude-00`. Nếu không phải, xóa và mklink lại.
</details>

---

## Cấu trúc Repo

```
.
├── README.md            ← hướng dẫn đầy đủ (file này)
├── CLAUDE.md            ← quick reference cho người đang dùng setup
├── install-hooks.ps1    ← installer cho auto-memory-sync hook
├── hooks/
│   └── auto-memory-sync.ps1   ← SessionStart hook, copy vào ~/.claude-hooks/
├── LICENSE              ← MIT
└── .gitignore
```

---

## Đóng góp

Đây là setup pattern đã được dùng thực tế. Issue / PR welcome:

- Bug trong script PowerShell
- Edge case OS / shell version chưa cover
- Bổ sung cho macOS/Linux (tương đương dùng symlink + env var)
- Hook bổ sung (vd chặn `npm install` global, chặn commit secrets)

---

## License

MIT. Dùng tự do trong cá nhân và công việc, attribution không bắt buộc.

---

## Tham khảo

- [Claude Code docs](https://docs.claude.com/claude-code) — Official documentation
- [Claude Code settings reference](https://docs.claude.com/claude-code/settings) — `CLAUDE_CONFIG_DIR`, hooks config
- [Windows directory junctions](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions) — mklink /J cơ chế
