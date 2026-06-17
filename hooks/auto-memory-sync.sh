#!/bin/bash
# Claude Code SessionStart hook: auto-apply memory unification pattern.
#
# Pattern: ~/.claude-00/projects/<proj-hash>/memory/ is the real folder (canonical).
# Other profiles (claude-01/02/03...) hold a symlink pointing to canonical.
# → Memory is shared across profiles; chat history stays isolated.
#
# Behavior:
#   - Idempotent (re-run safe)
#   - Safe (skips if memory folder has data — user must backup + merge manually)
#   - Silent on success (nothing shown in Claude UI)
#   - Skips if running under claude-00 (memory canonical, no real session)
#
# Input: JSON from stdin with field "cwd" (sent by Claude Code)

input=$(cat)

cwd=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print(d.get('cwd', ''))
except Exception:
    pass
" "$input" 2>/dev/null)

[[ -z "$cwd" ]] && exit 0

# Encode cwd → project hash (replace non-alphanumeric with '-')
proj_hash=$(echo "$cwd" | sed 's/[^a-zA-Z0-9]/-/g')

config_dir="${CLAUDE_CONFIG_DIR:-}"
[[ -z "$config_dir" ]] && exit 0

# Strip trailing slash
config_dir="${config_dir%/}"

# Skip if running as claude-00 (memory-only profile, no real session)
[[ "$config_dir" == *"/.claude-00" ]] && exit 0

canon="$HOME/.claude-00/projects/$proj_hash/memory"
junc="$config_dir/projects/$proj_hash/memory"
proj_dir="${junc%/memory}"

mkdir -p "$proj_dir"

if [[ -L "$junc" ]]; then
    # Already a symlink — verify it points to claude-00
    link_target=$(readlink "$junc")
    if [[ "$link_target" == *"/.claude-00/"* ]]; then
        exit 0  # Already correct
    fi
    # Points elsewhere — don't touch
    exit 0
elif [[ -d "$junc" ]]; then
    # Real directory — skip if it has data
    if [[ -n "$(ls -A "$junc" 2>/dev/null)" ]]; then
        exit 0  # Has data; user must backup + merge manually
    fi
    # Empty — safe to remove and replace with symlink
    rmdir "$junc"
fi

# Ensure canonical exists
mkdir -p "$canon"

# Create symlink
ln -s "$canon" "$junc"
exit 0
