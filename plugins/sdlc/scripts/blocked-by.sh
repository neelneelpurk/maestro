#!/usr/bin/env bash
# blocked-by.sh <issue> [--json]
#
# Prints the issue numbers of blockers that are still OPEN AND not yet integrated
# — empty output means the issue is unblocked and may be worked.
#
# A blocker is considered CLEARED when it is closed OR labelled
# `waiting-for-human-closure` (its work is already merged into the integration
# branch). This is what lets the drain queue self-progress without auto-closing
# issues. Sources: GitHub NATIVE dependencies first, then a "## Blocked by"
# markdown section (legacy / external). Union, de-duplicated.
#   --json   print the open blockers as a JSON array of numbers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
sdlc_require_cmd gh jq

issue="${1:-}"; [[ -n "$issue" ]] || sdlc_die "usage: blocked-by.sh <issue> [--json]"
json=0; [[ "${2:-}" == "--json" ]] && json=1

# Candidate blockers: native dependencies (any state) + markdown #refs.
native="$(bash "${SCRIPT_DIR}/dependency.sh" list "$issue" 2>/dev/null | cut -f1 || true)"
body="$(gh issue view "$issue" --json body --jq .body 2>/dev/null || true)"
section="$(printf '%s\n' "$body" | awk '
  /^##.*[Bb]locked[[:space:]]+[Bb]y/ { f=1; next }
  f && /^##/ { f=0 }
  f { print }')"
md="$( { printf '%s\n' "$section" | grep -oE '#[0-9]+' | tr -d '#'
         printf '%s\n' "$section" | grep -oE 'issues/[0-9]+' | grep -oE '[0-9]+'; } 2>/dev/null || true)"

candidates="$(printf '%s\n%s\n' "$native" "$md" | grep -E '^[0-9]+$' | grep -vx "$issue" | sort -un || true)"

# A candidate blocks iff it is OPEN and not yet integrated (waiting-for-human-closure).
open_blockers=""
if [[ -n "$candidates" ]]; then
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    read -r state labels < <(gh issue view "$n" --json state,labels --jq '[.state, (.labels|map(.name)|join(","))] | @tsv' 2>/dev/null || echo $'UNKNOWN\t')
    [[ "$state" == "OPEN" ]] || continue
    [[ ",$labels," == *",${SDLC_LABEL_WAITING_CLOSURE},"* ]] && continue   # work already integrated
    open_blockers+="$n"$'\n'
  done <<<"$candidates"
fi
open_blockers="$(printf '%s' "$open_blockers" | grep -E '^[0-9]+$' | sort -un || true)"

if [[ $json -eq 1 ]]; then
  printf '%s\n' "$open_blockers" | grep -E '^[0-9]+$' | jq -R . | jq -s 'map(tonumber)'
else
  [[ -n "$open_blockers" ]] && printf '%s\n' "$open_blockers" || true
fi
exit 0
