#!/usr/bin/env bash
# ready-issues.sh [--json|--numbers|--count] [--anyone]
#
# The single source of truth for "what the drain queue can work right now":
# issues that are open, assigned to me (SDLC_ASSIGNEE, default @me), labelled
# ready-for-agent OR auto, NOT already in-progress / in-review /
# waiting-for-human-closure / hitl, NOT a prd or roadmap parent, and with no
# still-open blockers (native dependencies, per blocked-by.sh).
#
#   --json     (default) JSON array of {number, title, slug, labels}
#   --numbers  issue numbers, one per line
#   --count    integer count
#   --anyone   ignore the assignee filter (any assignee)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
sdlc_require_cmd gh jq

out="--json"; assignee_args=(--assignee "$SDLC_ASSIGNEE")
for a in "$@"; do
  case "$a" in
    --anyone) assignee_args=() ;;
    --count|--numbers|--json) out="$a" ;;
  esac
done

q() { gh issue list "${assignee_args[@]}" --label "$1" --state open --limit 300 --json number,title,labels 2>/dev/null || echo '[]'; }

# ready-for-agent OR auto, merged + de-duplicated by number.
merged="$(jq -s 'add | unique_by(.number)' <(q "$SDLC_LABEL_READY_AGENT") <(q "$SDLC_LABEL_AUTO"))"

# Drop in-flight / closure / hitl / parent states.
filtered="$(jq -c \
  --arg ip "$SDLC_LABEL_IN_PROGRESS" --arg ir "$SDLC_LABEL_IN_REVIEW" \
  --arg wc "$SDLC_LABEL_WAITING_CLOSURE" --arg hitl "$SDLC_LABEL_HITL" \
  --arg prd "$SDLC_LABEL_PRD" --arg roadmap "$SDLC_LABEL_ROADMAP" '
  map(select((.labels|map(.name)) as $l
    | ($l|index($ip)|not) and ($l|index($ir)|not) and ($l|index($wc)|not)
      and ($l|index($hitl)|not) and ($l|index($prd)|not) and ($l|index($roadmap)|not)))' <<<"$merged")"

# Keep only unblocked issues; attach a branch slug.
ready="$(
  jq -c '.[]' <<<"$filtered" | while IFS= read -r obj; do
    n="$(jq -r .number <<<"$obj")"
    if [[ -z "$(bash "${SCRIPT_DIR}/blocked-by.sh" "$n" 2>/dev/null)" ]]; then
      title="$(jq -r .title <<<"$obj")"
      jq -c --arg slug "$(sdlc_slug "$title")" '{number, title, labels: (.labels|map(.name)), slug: $slug}' <<<"$obj"
    fi
  done | jq -s 'sort_by(.number)'
)"
ready="${ready:-[]}"

case "$out" in
  --count)   jq 'length' <<<"$ready" ;;
  --numbers) jq -r '.[].number' <<<"$ready" ;;
  *)         printf '%s\n' "$ready" ;;
esac
