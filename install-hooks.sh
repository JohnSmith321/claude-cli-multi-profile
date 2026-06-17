#!/bin/bash
# Claude CLI Multi-Profile — WSL/Linux hook installer
# Requires: bash 4+, python3
#
# What this does:
#   1. Copies hooks/*.sh → ~/.claude-hooks/
#   2. Creates ~/.claude-00 as the canonical memory store
#   3. Discovers existing .claude-NN profiles
#   4. Registers the SessionStart hook in each profile's settings.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DEST="$HOME/.claude-hooks"
CANON="$HOME/.claude-00"

err() { echo "ERROR: $1" >&2; exit 1; }

# --- requirements ---

[[ -d "$HOOKS_SRC" ]] || err "hooks/ directory not found next to this script."
python3 --version &>/dev/null || err "python3 is required (sudo apt install python3)."

# --- copy hook scripts ---

echo "→ Copying hooks to $HOOKS_DEST"
mkdir -p "$HOOKS_DEST"
cp "$HOOKS_SRC"/*.sh "$HOOKS_DEST/"
chmod +x "$HOOKS_DEST"/*.sh
echo "  Done."

# --- create canonical memory store ---

echo "→ Creating canonical memory store at $CANON"
mkdir -p "$CANON/projects"
echo "  Done."

# --- discover profiles ---

profiles=()
for dir in "$HOME"/.claude-[0-9][0-9]; do
    [[ -d "$dir" ]] || continue
    suffix="${dir##*\.claude-}"
    [[ "$suffix" == "00" ]] && continue
    profiles+=("$suffix")
done

if [[ ${#profiles[@]} -eq 0 ]]; then
    echo ""
    echo "No profiles found (expected ~/.claude-01, ~/.claude-02, ...)."
    echo "Create them first — see README.md Quick Start."
    exit 0
fi

echo "→ Found profiles: ${profiles[*]}"
echo ""

# --- register hook in each profile ---

hook_cmd="bash \"$HOOKS_DEST/auto-memory-sync.sh\""

register_hook() {
    local settings="$1"
    local cmd="$2"

    python3 - "$settings" "$cmd" <<'PYEOF'
import sys, json, os

settings_path = sys.argv[1]
hook_cmd = sys.argv[2]

if os.path.exists(settings_path):
    with open(settings_path) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            data = {}
else:
    data = {}

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

# Idempotent: skip if already registered
for entry in session_start:
    for h in entry.get("hooks", []):
        if h.get("command", "") == hook_cmd:
            print("    Already registered, skipping.")
            sys.exit(0)

session_start.append({
    "hooks": [{"type": "command", "command": hook_cmd}]
})

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("    Registered.")
PYEOF
}

for p in "${profiles[@]}"; do
    settings="$HOME/.claude-$p/settings.json"
    echo "  Profile $p → $settings"
    register_hook "$settings" "$hook_cmd"
done

echo ""
echo "Installation complete. Next steps:"
echo ""
echo "  1. Add profile functions to your shell:"
echo "       echo 'source $SCRIPT_DIR/profile-functions.sh' >> ~/.bashrc"
echo "       source ~/.bashrc"
echo ""
echo "  2. Restart Claude CLI / VS Code."
