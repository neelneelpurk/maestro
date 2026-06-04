#!/usr/bin/env bash
# learn-note.sh "<learning>"
#
# Append a dated learning to .claude/rules/learnings.md in the main working tree.
# That file is committed and inherited by every agent (including workers in
# worktrees), so persisted corrections are followed everywhere, across sessions.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

text="$*"
[[ -n "$text" ]] || sdlc_die 'usage: learn-note.sh "<learning>"'

file="$(sdlc_main_root)/.claude/rules/learnings.md"
mkdir -p "$(dirname "$file")"
if [[ ! -f "$file" ]]; then
  cat > "$file" <<'EOF'
# Learnings

Durable corrections the agent must follow. Appended by `/sdlc:learn` when the
user corrects the agent; inherited by every agent (including workers in
worktrees). Keep entries behavioural and high-signal.

## Learnings
EOF
fi

printf -- '- (%s) %s\n' "$(date +%Y-%m-%d)" "$text" >> "$file"
sdlc_log learning-added text="$text"
echo "persisted learning → ${file}"
