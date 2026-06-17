# Claude CLI Multi-Profile — WSL Quick Reference

## Profile Layout

`.claude-01` = Account #1, `.claude-02` = Account #2, etc.  
`.claude-00` = memory canonical (empty auth, created by `install-hooks.sh`).  
`~/.claude` = symlink pointing to the active profile.

## Daily Commands

| Command | Effect |
|---|---|
| `claude` | Run the active profile (last set by `switch-claude`) |
| `claude-01` | Run profile 01 in **this terminal only** (no default change) |
| `claude-02` | Run profile 02 in **this terminal only** |
| `claude-03` | Run profile 03 in **this terminal only** |
| `claude-04` | Run profile 04 in **this terminal only** |
| `switch-claude 01` | Change default to profile 01 (persists across new shells) |
| `claude auth status` | Show which account is active |

## One-Time Setup

```bash
# 1. First login (creates ~/.claude automatically)
claude
# Log in with account #1, then /exit

# 2. Move it to ~/.claude-01 and replace with a symlink
mv ~/.claude ~/.claude-01
ln -s ~/.claude-01 ~/.claude

# 3. Log in with accounts #2, #3, #4 — each gets its own directory
CLAUDE_CONFIG_DIR="$HOME/.claude-02" claude   # log in account #2, /exit
CLAUDE_CONFIG_DIR="$HOME/.claude-03" claude   # log in account #3, /exit
CLAUDE_CONFIG_DIR="$HOME/.claude-04" claude   # log in account #4, /exit

# 4. Install hooks + profile functions (from this repo's directory)
bash install-hooks.sh
echo "source $(pwd)/profile-functions.sh" >> ~/.bashrc
source ~/.bashrc

# 5. Verify all four accounts
claude-01 auth status   # → Account #1
claude-02 auth status   # → Account #2
claude-03 auth status   # → Account #3
claude-04 auth status   # → Account #4
```

## How Memory Sharing Works

Each profile stores auto-memory at `~/.claude-XX/projects/<path-hash>/memory/`.  
Without unification, switching profiles loses that memory.

**Pattern:** `~/.claude-00` is the real (canonical) memory folder. All other profiles symlink to it.

```
~/.claude-00/projects/<hash>/memory/   ← real folder
~/.claude-01/projects/<hash>/memory/   → symlink → claude-00
~/.claude-02/projects/<hash>/memory/   → symlink → claude-00
```

The `SessionStart` hook (`hooks/auto-memory-sync.sh`) applies this automatically on every new session. No manual steps needed after `install-hooks.sh`.

## What Is Shared vs. Isolated

| Data | Location | State |
|---|---|---|
| Auth credentials | `~/.claude-XX/.credentials.json` | Isolated |
| Chat history | `~/.claude-XX/projects/<hash>/*.jsonl` | Isolated |
| Settings + hooks | `~/.claude-XX/settings.json` | Isolated |
| Sessions, plans, cache | `~/.claude-XX/sessions/` etc. | Isolated |
| **Auto memory** | `~/.claude-XX/projects/<hash>/memory/` | **Shared** via symlink |

## Verify Memory Symlinks

```bash
ls -la ~/.claude-01/projects/
# memory/ should appear as a symlink → ~/.claude-00/projects/.../memory/
```

## VS Code Note

The Claude VS Code extension reads `CLAUDE_CONFIG_DIR` at startup.  
After `switch-claude`, **restart VS Code** for the extension to pick up the new profile.

## Optional: Block `pip install` Outside venv

Register `hooks/check-venv.sh` as a `PreToolUse` hook in `~/.claude-XX/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "bash ~/.claude-hooks/check-venv.sh"}]
      }
    ]
  }
}
```
