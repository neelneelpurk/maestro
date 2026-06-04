#!/usr/bin/env bash
# blocked-by.sh <issue> [--all|--json]
#
# Parses the "## Blocked by" section of an issue body (the aihero `to-issues`
# convention) and reports blockers.
#
#   (default)  print issue numbers of blockers that are still OPEN, one per line.
#              Empty output  => the issue is unblocked and may be worked.
#   --all      print every referenced blocker number, regardless of state.
#   --json     print the OPEN (unmet) blockers as a JSON array.
#
# Blocker references are any `#<n>` or `.../issues/<n>` inside the Blocked-by
# section. "None - can start immediately" therefore yields no blockers.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

sdlc_require_cmd gh jq

issue="${1:-}"; [[ -n "$issue" ]] || sdlc_die "usage: blocked-by.sh <issue> [--all|--json]"
mode="${2:-open}"
case "$mode" in --all) mode=all ;; --json) mode=json ;; *) mode=open ;; esac

body="$(gh issue view "$issue" --json body --jq .body 2>/dev/null || true)"

# Isolate the "## Blocked by" section (up to the next ## heading).
section="$(printf '%s\n' "$body" | awk '
  /^##.*[Bb]locked[[:space:]]+[Bb]y/ { f=1; next }
  f && /^##/ { f=0 }
  f { print }
')"

# Collect referenced blocker numbers (from #n and issues/n forms), unique, sorted.
refs="$(
  {
    printf '%s\n' "$section" | grep -oE '#[0-9]+'        | tr -d '#'
    printf '%s\n' "$section" | grep -oE 'issues/[0-9]+'  | grep -oE '[0-9]+'
  } 2>/dev/null | grep -E '^[0-9]+$' | grep -vx "$issue" | sort -un || true
)"

if [[ "$mode" == "all" ]]; then
  [[ -n "$refs" ]] && printf '%s\n' "$refs"
  exit 0
fi

# Keep only blockers that are still OPEN.
open_blockers=()
if [[ -n "$refs" ]]; then
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    state="$(gh issue view "$n" --json state --jq .state 2>/dev/null || echo "UNKNOWN")"
    [[ "$state" == "OPEN" ]] && open_blockers+=("$n")
  done <<<"$refs"
fi

if [[ "$mode" == "json" ]]; then
  printf '%s\n' "${open_blockers[@]:-}" | grep -E '^[0-9]+$' | jq -R . | jq -s 'map(tonumber)'
else
  [[ ${#open_blockers[@]} -gt 0 ]] && printf '%s\n' "${open_blockers[@]}"
fi
exit 0
