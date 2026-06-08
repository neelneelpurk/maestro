#!/usr/bin/env bash
# Tests that every slash command which pre-executes shell via the ```! fence
# declares `allowed-tools` in its frontmatter. Without it, Claude Code prompts
# for (or denies) permission on every run — which is exactly what broke
# /maestro:init. This guards the whole class so it can't silently return.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$HERE/../lib/assert.sh"

commands="$ROOT/plugins/maestro/commands"
assert_status 0 test -d "$commands"

# bash 3.2: no mapfile/associative arrays — iterate the glob directly.
for cmd in "$commands"/*.md; do
  [ -e "$cmd" ] || continue
  # A command pre-executes shell if it opens a fenced block with `!` (```!).
  if grep -Eq '^```!' "$cmd"; then
    name="$(basename "$cmd")"
    if grep -Eq '^allowed-tools:' "$cmd"; then
      _t_ok "$name declares allowed-tools for its ! shell block"
    else
      _t_no "$name uses a ! shell block but is missing allowed-tools" \
        "add 'allowed-tools: Bash' to the frontmatter or it will prompt on every run"
    fi
  fi
done

t_end
