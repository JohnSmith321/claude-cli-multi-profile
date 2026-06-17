# Multi-Profile Claude CLI cho WSL/Linux

> Chạy song song nhiều profile [Claude Code](https://docs.claude.com/claude-code) trên cùng một máy WSL/Linux, mỗi profile dùng tài khoản Anthropic khác nhau. Switch nhanh bằng bash. Kèm pattern unify memory giữa các profile để Claude "nhớ" cùng context dù bạn đang ở profile nào.

[![WSL/Linux](https://img.shields.io/badge/WSL%2FLinux-supported-blue)](#)
[![Bash](https://img.shields.io/badge/Bash-4%2B-blue)](#)
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
- **Switch instant** bằng lệnh bash (`switch-claude 01`) — không cần logout/login
- **Per-terminal override** với function `claude-01`, `claude-02`... cho phép một terminal dùng profile khác mà không đổi default
- **Memory unification** mặc định qua SessionStart hook — auto-share `projects/<hash>/memory/` giữa các profile khi mở project. Tất cả chat history, sessions, settings vẫn isolate. Cài 1 lệnh (`bash install-hooks.sh`).
- **Mở rộng** số profile tùy ý (01, 02, 03, ...) — số suffix khớp số account
- **Optional hook** chặn `pip install` ngoài venv — tránh Claude lỡ tay cài package vào global Python

## Yêu cầu

| Component | Min version | Kiểm tra |
|---|---|---|
| WSL hoặc Linux | Ubuntu 20.04+ | — |
| Node.js | 20 LTS | `node --version` |
| Bash | 4+ | `bash --version` |
| python3 | bất kỳ | `python3 --version` |
| Claude Code CLI | latest | `claude --version` |
| Tài khoản Anthropic | 1 per profile | — |

Cài Claude Code: `npm install -g @anthropic-ai/claude-code`

## Quick Start

Setup nhanh 2 profile (`.claude-01` = Account #1, `.claude-02` = Account #2):

```bash
# 1. Login Account #1 (lần đầu chạy claude)
claude
# (Login bằng account #1, xong /exit)

# 2. Rename ~/.claude → ~/.claude-01 + tạo symlink
mv ~/.claude ~/.claude-01
ln -s ~/.claude-01 ~/.claude

# 3. Login Account #2 vào ~/.claude-02
CLAUDE_CONFIG_DIR="$HOME/.claude-02" claude
# (Login bằng account #2, xong /exit)

# 4. Add profile functions vào shell (clone repo này về trước)
echo "source $(pwd)/profile-functions.sh" >> ~/.bashrc
source ~/.bashrc

# 5. Cài auto memory sync hook
bash install-hooks.sh
# → tạo ~/.claude-00 rỗng làm memory canonical
# → register SessionStart hook trên mọi profile
# Restart VS Code sau bước này.

# 6. Dùng
claude-02           # chạy profile 02 cho terminal này
switch-claude 02    # đổi default sang 02 (vĩnh viễn)
```

Quy ước số: `.claude-01` chứa account #1 đầu tiên, `.claude-02` account #2, v.v. `.claude-00` là folder rỗng làm memory canonical (xem section "Memory hoạt động ra sao").

Phần dưới đây là hướng dẫn đầy đủ + memory unification.

---

## Setup chi tiết

### Bước 1 — Login profile mặc định

```bash
claude
```

Lần chạy đầu sẽ tạo `~/.claude/` và yêu cầu login. Login bằng account #1 của bạn, xong `/exit`.

### Bước 2 — Rename profile thành .claude-01 + tạo symlink

Profile vừa login (Account #1) đang ở `~/.claude/`. Đổi tên thành `.claude-01` để khớp với quy ước "số suffix = số account".

> **Lưu ý:** Đóng tất cả VS Code và terminal có Claude đang chạy trước khi làm bước này.

```bash
mv ~/.claude ~/.claude-01
ln -s ~/.claude-01 ~/.claude
```

Verify:
```bash
ls -la ~ | grep '\.claude'
# .claude -> /home/<user>/.claude-01
```

### Bước 3 — Tạo các profile bổ sung (account #2, #3...)

Với mỗi tài khoản phụ, set `CLAUDE_CONFIG_DIR` tạm thời rồi login. **Số suffix khớp với account #**:

```bash
# Account #2 → .claude-02
CLAUDE_CONFIG_DIR="$HOME/.claude-02" claude
# Login Account #2, /exit

# Account #3 → .claude-03
CLAUDE_CONFIG_DIR="$HOME/.claude-03" claude
# Login Account #3, /exit
```

Lặp lại cho `04`, `05`... nếu cần.

> **Bỏ qua `.claude-00`** — số này là memory canonical (auto-tạo bởi `install-hooks.sh`, xem section "Memory hoạt động ra sao"). Bắt đầu account thứ 2 từ `.claude-02`.

### Bước 4 — Cài profile functions

Clone repo này về rồi source `profile-functions.sh` từ shell config:

```bash
echo "source /path/to/Multi-Profile_Claude_CLI/profile-functions.sh" >> ~/.bashrc
source ~/.bashrc
```

File `profile-functions.sh` định nghĩa các function:

```bash
claude-01() { CLAUDE_CONFIG_DIR="$HOME/.claude-01" claude "$@"; }
claude-02() { CLAUDE_CONFIG_DIR="$HOME/.claude-02" claude "$@"; }
claude-03() { CLAUDE_CONFIG_DIR="$HOME/.claude-03" claude "$@"; }
claude-04() { CLAUDE_CONFIG_DIR="$HOME/.claude-04" claude "$@"; }

switch-claude() { ... }   # đổi default profile, persist qua ~/.claude-env
```

### Bước 5 — Verify

```bash
claude-01 auth status   # phải in ra Account #1
claude-02 auth status   # phải in ra Account #2
switch-claude 02        # đổi default sang Account #2
claude auth status      # giờ default = Account #2
switch-claude 01        # về lại Account #1
```

---

## Sử dụng hàng ngày

| Lệnh | Tác dụng |
|---|---|
| `claude` | Chạy profile đang active (do `switch-claude` chọn) |
| `claude-01` | Chạy profile 01 cho **terminal hiện tại** (không đổi default) |
| `claude-02` | Tương tự với profile 02 |
| `switch-claude 01` | Đổi default profile sang 01 (vĩnh viễn — ảnh hưởng terminal mới + VS Code) |
| `claude auth status` | Xem profile/account đang dùng |

**VS Code extension:** đọc env `CLAUDE_CONFIG_DIR` lúc khởi động. Sau khi `switch-claude`, phải **restart VS Code** (đóng hết cửa sổ) thì extension mới nhận profile mới.

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
- Path encoding: `/home/user/Project/Foo` → `-home-user-Project-Foo`
- **Mặc định:** mỗi profile có một bản memory độc lập cho cùng project → switch profile = mất memory cũ

### Vấn đề và pattern giải quyết

Khi bạn dùng nhiều profile và mở **cùng 1 project** từ các profile khác nhau, mặc định memory bị phân mảnh — Claude trong profile A không thấy memory profile B đã ghi.

**Giải pháp:** Tạo `~/.claude-00/` rỗng làm memory canonical (không có auth, chỉ chứa memory). Các profile thật (`.claude-01`, `.claude-02`, `.claude-03`...) symlink memory folder trỏ về `.claude-00`.

```
~/.claude-00/projects/<proj-hash>/memory/   ← folder THẬT (canonical, KHÔNG có auth)
~/.claude-01/projects/<proj-hash>/memory/   → symlink → claude-00
~/.claude-02/projects/<proj-hash>/memory/   → symlink → claude-00
~/.claude-03/projects/<proj-hash>/memory/   → symlink → claude-00
```

Sau khi áp pattern: Claude trong mọi profile khi mở project đó sẽ đọc/ghi memory cùng 1 nơi.

> `.claude-00` chỉ là 1 folder rỗng dành cho memory canonical. Đừng login account vào đây — `switch-claude` mặc định cũng không trỏ về 00 (không có auth để dùng).

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
| **Auto memory (per project)** | `~/.claude-XX/projects/<hash>/memory/` | ⚠ **SHARED** via symlink → claude-00 |

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
- `hooks/auto-memory-sync.sh` — hook script (idempotent, safe, silent on success)
- `install-hooks.sh` — installer auto register hook vào mọi profile

**Cài 1 lệnh sau khi clone:**

```bash
# Từ thư mục repo
bash install-hooks.sh
```

Installer làm:
1. Copy `hooks/*.sh` → `~/.claude-hooks/`
2. Tạo `~/.claude-00` làm memory canonical (nếu chưa có)
3. Detect các profile `.claude-<NN>` đang có
4. Register `SessionStart` hook trong `settings.json` của mỗi profile (trừ claude-00)

Idempotent — re-run an toàn.

Sau khi install: restart Claude CLI / VS Code. Lần sau bạn `VS Code → Open Folder` 1 project mới và mở Claude, memory tự unified, không cần thao tác gì.

**Yêu cầu:** python3 (dùng để parse JSON trong hook).

### Script áp dụng pattern cho 1 project (manual fallback)

Nếu không dùng auto hook ở trên (hoặc cần apply một-lần cho project cụ thể), paste function dưới đây vào terminal:

```bash
add_claude_memory_sync() {
    local project_path="${1:-$(pwd)}"
    local proj_hash
    proj_hash=$(echo "$project_path" | sed 's/[^a-zA-Z0-9]/-/g')
    local canon="$HOME/.claude-00/projects/$proj_hash/memory"

    echo "Project: $project_path"
    echo "Hash:    $proj_hash"

    mkdir -p "$canon"
    echo "  Canonical at ~/.claude-00"

    for p in 01 02 03; do
        local proj_dir="$HOME/.claude-$p/projects/$proj_hash"
        local junc="$proj_dir/memory"
        [[ -d "$HOME/.claude-$p" ]] || continue
        mkdir -p "$proj_dir"

        if [[ -L "$junc" ]]; then
            local target
            target=$(readlink "$junc")
            if [[ "$target" == *"/.claude-00/"* ]]; then
                echo "  [$p] Already symlinked (skip)"
            else
                echo "  [$p] Symlink points to unexpected target: $target"
            fi
            continue
        fi

        if [[ -d "$junc" ]]; then
            if [[ -n "$(ls -A "$junc" 2>/dev/null)" ]]; then
                echo "  [$p] Memory folder has DATA (skip — backup + merge manually)"
                continue
            fi
            rmdir "$junc"
        fi

        ln -s "$canon" "$junc"
        echo "  [$p] Symlink created -> claude-00"
    done
}
```

Cách dùng:

```bash
cd ~/Project/NewProject
add_claude_memory_sync          # cho thư mục hiện tại
add_claude_memory_sync ~/Project/X   # chỉ định path
```

> **Cảnh báo:** Function refuse overwrite memory folder đang có data. Nếu profile đích đã có memory file cho project đó, backup trước (`cp -r`) rồi merge vào canonical (`claude-00`) → re-run function.

### Pre-built prompt cho teammate

Nếu bạn muốn teammate cũng setup pattern này trên máy của họ, cách đơn giản nhất là **paste hướng dẫn dưới đây vào Claude Code đang chạy trên máy teammate** — Claude sẽ tự audit + backup + plan + execute.

<details>
<summary><b>Prompt template (click để mở)</b></summary>

```text
Tôi đang setup Multi-Profile Claude CLI trên WSL/Linux theo pattern của một đồng nghiệp. Tôi có nhiều profile (`.claude-00`, `.claude-01`, có thể có thêm `.claude-02`, `.claude-03`) dưới `$HOME`, mỗi profile login một account Anthropic khác nhau.

**Vấn đề tôi muốn giải quyết:** Mỗi profile Claude lưu auto-memory riêng cho cùng một project, nên khi switch profile thì memory không thấy nhau. Tôi muốn unify bằng pattern: **`claude-00` là canonical (folder thật)**, các profile khác (`01/02/03`...) symlink trỏ về.

Cụ thể với mỗi project có memory:

  ~/.claude-00/projects/<proj-hash>/memory/   ← folder THẬT
  ~/.claude-01/projects/<proj-hash>/memory/   → symlink → claude-00
  ~/.claude-02/projects/<proj-hash>/memory/   → symlink → claude-00
  ...

### Yêu cầu

Giúp tôi audit + thực hiện việc unify đó. Quy trình:

**Bước 1 — Inventory:**
- Liệt kê các profile `.claude-XX` đang tồn tại trong `$HOME`
- Cho mỗi profile, liệt kê các project folder dưới `<profile>/projects/` có chứa folder con `memory/` không rỗng
- In ra bảng: profile × project × số file memory × danh sách file
- Cho biết các project nào có memory ở 2+ profile (= fragmented, cần merge cẩn thận)

**Bước 2 — Backup:**
- Tạo folder backup ở chỗ tôi chọn (mặc định `~/claude-memory-backup-<timestamp>/`), hỏi tôi xác nhận đường dẫn
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
- Cho mỗi profile khác `claude-00` × mỗi project: xóa folder memory cũ (đã backup), tạo symlink `ln -s` trỏ về claude-00
- Tạo project folder trống ở profile đích trước nếu chưa có

**Bước 5 — Verify:**
- Liệt kê lại tất cả memory folder ở các profile ≠ claude-00, xác nhận đều là symlink trỏ về `.claude-00`
- Đếm: số symlink tạo, số folder thật còn sót
- Đọc thử nội dung memory từ 1-2 project qua symlink để confirm data đọc được OK

### Quy tắc bắt buộc

1. **Backup trước khi xóa bất kỳ memory folder nào** — nếu chưa backup thì dừng và yêu cầu tôi confirm.
2. **Không tự ý merge file trùng tên có nội dung khác nhau** — hỏi tôi chọn bản nào hoặc cho phép gộp.
3. **Symlink dùng `ln -s <target> <link>`** (không phải hard link).
4. **Đóng VS Code và các terminal Claude đang chạy trước khi xóa folder memory** — nếu phát hiện process đang lock file thì dừng và báo tôi.
5. **Sau khi xong: nhắc tôi restart VS Code** (extension cache memory state).

### Môi trường

- OS: WSL/Linux (Ubuntu)
- Shell: Bash 4+
- Đường dẫn profile: `$HOME/.claude-XX/` (có thể có `.claude-00`, `.claude-01`, `.claude-02`, `.claude-03` — tùy số profile tôi đã tạo)

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

Nếu bạn dùng Python nhiều và muốn Claude không lỡ tay cài package vào global Python, cài hook này. File `hooks/check-venv.sh` đã có sẵn trong repo và được `install-hooks.sh` copy vào `~/.claude-hooks/` tự động.

Chỉ cần đăng ký thêm vào `settings.json` của profile muốn bảo vệ:

```bash
# Mở settings.json của profile đích
nano ~/.claude-01/settings.json
```

Thêm vào key `hooks`:

```json
{
  "hooks": {
    "SessionStart": [ ... ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude-hooks/check-venv.sh"
          }
        ]
      }
    ]
  }
}
```

Hook sẽ block bất kỳ lệnh `pip install` nào khi không có venv, và yêu cầu dùng `.venv/bin/pip` khi venv đang tồn tại trong project.

---

## Troubleshooting

<details>
<summary><b><code>ln -s</code> báo "File exists"</b></summary>

Thư mục `.claude` hoặc `memory/` đã tồn tại. Kiểm tra:
```bash
ls -la ~/.claude
# Nếu là symlink: rm ~/.claude
# Nếu là folder thật: mv ~/.claude ~/.claude-01 rồi ln -s lại
```
</details>

<details>
<summary><b>Lệnh <code>claude-01</code> không nhận được sau khi source profile-functions.sh</b></summary>

Mở terminal mới hoặc:
```bash
source ~/.bashrc
```
Đảm bảo dòng `source .../profile-functions.sh` có trong `~/.bashrc` (không phải `~/.bash_profile` nếu bạn dùng interactive shell).
</details>

<details>
<summary><b><code>switch-claude</code> chạy xong nhưng VS Code vẫn dùng profile cũ</b></summary>

Restart VS Code hoàn toàn (đóng tất cả cửa sổ). Extension đọc env `CLAUDE_CONFIG_DIR` lúc khởi động.
</details>

<details>
<summary><b><code>auth status</code> hiện sai account</b></summary>

Check env var:
```bash
echo $CLAUDE_CONFIG_DIR
```
Phải trỏ tới profile dir đúng. Nếu trống, chạy lại `switch-claude 01` hoặc source lại:
```bash
source ~/.claude-env
```
</details>

<details>
<summary><b>Hook không chạy / memory không sync</b></summary>

1. Verify hook đã register trong `~/.claude-XX/settings.json` (phải có entry `SessionStart`)
2. Kiểm tra `CLAUDE_CONFIG_DIR` được set khi Claude chạy — hook exit sớm nếu biến này trống
3. Chạy thử hook thủ công:
```bash
echo '{"cwd":"/home/user/myproject"}' | CLAUDE_CONFIG_DIR="$HOME/.claude-01" bash ~/.claude-hooks/auto-memory-sync.sh
ls -la ~/.claude-01/projects/-home-user-myproject/
# memory/ phải là symlink
```
</details>

<details>
<summary><b>Memory không sync giữa các profile dù đã symlink</b></summary>

Verify symlink:
```bash
ls -la ~/.claude-01/projects/<proj-hash>/memory
# phải có dấu -> trỏ về ~/.claude-00/...
readlink ~/.claude-01/projects/<proj-hash>/memory
```
Nếu không phải symlink, xóa và tạo lại:
```bash
rm -rf ~/.claude-01/projects/<proj-hash>/memory
ln -s ~/.claude-00/projects/<proj-hash>/memory ~/.claude-01/projects/<proj-hash>/memory
```
</details>

<details>
<summary><b>WSL: <code>python3</code> not found trong hook</b></summary>

```bash
sudo apt install python3
```
</details>

---

## Cấu trúc Repo

```
.
├── README.md                    ← hướng dẫn đầy đủ (file này)
├── CLAUDE.md                    ← quick reference cho người đang dùng setup
├── profile-functions.sh         ← bash functions: claude-01/02/03, switch-claude
├── install-hooks.sh             ← installer cho auto-memory-sync hook
├── hooks/
│   ├── auto-memory-sync.sh      ← SessionStart hook, copy vào ~/.claude-hooks/
│   └── check-venv.sh            ← PreToolUse hook chặn pip install ngoài venv (optional)
├── LICENSE                      ← MIT
└── .gitignore
```

---

## Đóng góp

Đây là setup pattern đã được dùng thực tế. Issue / PR welcome:

- Bug trong shell script
- Edge case OS / shell version chưa cover
- Bổ sung cho macOS (tương đương dùng symlink + env var, không cần mklink)
- Hook bổ sung (vd chặn `npm install` global, chặn commit secrets)

---

## License

MIT. Dùng tự do trong cá nhân và công việc, attribution không bắt buộc.

---

## Tham khảo

- [Claude Code docs](https://docs.claude.com/claude-code) — Official documentation
- [Claude Code settings reference](https://docs.claude.com/claude-code/settings) — `CLAUDE_CONFIG_DIR`, hooks config
- [Linux symbolic links](https://man7.org/linux/man-pages/man7/symlink.7.html) — `ln -s` cơ chế
