#!/usr/bin/env bash
# ready-issues.sh [--count|--numbers|--json]
#
# Prints the issues that can be worked autonomously RIGHT NOW: open, labelled
# ready-for-agent AND afk, NOT already in-progress/in-review, NOT a prd parent,
# and with no still-open blockers (per blocked-by.sh).
#
#   --json     (default) JSON array of {number, title, slug, labels}
#   --numbers  issue numbers, one per line
#   --count    just the integer count
#
# This is the single source of truth for "what the fan-out should pick up".
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

sdlc_require_cmd gh jq
out="${1:---json}"

# AND-ed labels: ready-for-agent AND afk, open only.
candidates="$(gh issue list \
  --label "$SDLC_LABEL_READY_AGENT" \
  --label "$SDLC_LABEL_AFK" \
  --state open --limit 300 \
  --json number,title,labels 2>/dev/null || echo '[]')"

# Drop anything already being worked / done / a parent epic.
filtered="$(jq -c \
  --arg ip "$SDLC_LABEL_IN_PROGRESS" \
  --arg ir "$SDLC_LABEL_IN_REVIEW" \
  --arg prd "$SDLC_LABEL_PRD" '
  map(select(
    (.labels | map(.name)) as $l
    | ($l | index($ip) | not)
      and ($l | index($ir) | not)
      and ($l | index($prd) | not)
  ))' <<<"$candidates")"

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
