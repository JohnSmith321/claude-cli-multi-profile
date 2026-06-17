# Claude CLI Multi-Profile — shell functions for WSL/Linux
# Source this file from ~/.bashrc or ~/.zshrc:
#   source /path/to/profile-functions.sh

claude-01() { CLAUDE_CONFIG_DIR="$HOME/.claude-01" claude "$@"; }
claude-02() { CLAUDE_CONFIG_DIR="$HOME/.claude-02" claude "$@"; }
claude-03() { CLAUDE_CONFIG_DIR="$HOME/.claude-03" claude "$@"; }
claude-04() { CLAUDE_CONFIG_DIR="$HOME/.claude-04" claude "$@"; }

switch-claude() {
    local profile="${1:-01}"
    local target="$HOME/.claude"
    local source="$HOME/.claude-$profile"

    if [[ ! -d "$source" ]]; then
        echo "Profile .claude-$profile does not exist." >&2
        return 1
    fi

    if [[ -L "$target" ]]; then
        rm "$target"
    elif [[ -d "$target" ]]; then
        echo "~/.claude is a real directory, not a symlink. Move it to ~/.claude-01 first:" >&2
        echo "  mv ~/.claude ~/.claude-01 && ln -s ~/.claude-01 ~/.claude" >&2
        return 1
    elif [[ -e "$target" ]]; then
        echo "~/.claude exists but is not a symlink or directory. Remove it first:" >&2
        echo "  rm ~/.claude" >&2
        return 1
    fi

    ln -s "$source" "$target" || { echo "Failed to create symlink ~/.claude → $source" >&2; return 1; }
    export CLAUDE_CONFIG_DIR="$source"

    # Persist CLAUDE_CONFIG_DIR for new shells
    echo "export CLAUDE_CONFIG_DIR=\"$source\"" > "$HOME/.claude-env"

    echo "Default claude now uses claude-$profile (restart VS Code to apply)."
}

# Load persisted profile on shell start
[[ -f "$HOME/.claude-env" ]] && source "$HOME/.claude-env"
