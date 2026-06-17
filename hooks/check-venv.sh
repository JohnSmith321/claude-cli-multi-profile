#!/bin/bash
# Hook: block "pip install" if no venv exists in the working directory.
# Reads PreToolUse JSON from stdin.

input=$(cat)

tool_name=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print(d.get('tool_name', ''))
except Exception:
    pass
" "$input" 2>/dev/null)

[[ "$tool_name" != "Bash" ]] && exit 0

cwd=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print(d.get('cwd', ''))
except Exception:
    pass
" "$input" 2>/dev/null)

command=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    inp = d.get('tool_input', {})
    print(inp.get('command', ''))
except Exception:
    pass
" "$input" 2>/dev/null)

echo "$command" | grep -qiE '(^|\s|/)pip[0-9]?\s+install' || exit 0

# If the pip invocation explicitly uses the venv binary, allow it
if echo "$command" | grep -qiE '(\.venv|venv)/bin/pip[0-9]?(\s+|$)'; then
    exit 0
fi

# If a venv is activated in the calling shell, allow pip (handles venv in parent dir)
[[ -n "${VIRTUAL_ENV:-}" ]] && exit 0

if [[ -n "$cwd" ]] && { [[ -d "$cwd/.venv" ]] || [[ -d "$cwd/venv" ]]; }; then
    echo "BLOCKED: venv exists at $cwd but you are calling global pip. Use .venv/bin/pip instead." >&2
    exit 2
fi

echo "BLOCKED: No virtual environment found in $cwd. Create one first: python3 -m venv .venv" >&2
exit 2
