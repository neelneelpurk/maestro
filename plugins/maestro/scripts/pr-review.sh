#!/usr/bin/env bash
# pr-review.sh <pr> [--event COMMENT|REQUEST_CHANGES] [--body-file f] [--comments-file f]
#
# Posts ONE pull-request review using GitHub's native review features:
#   --body-file      markdown summary for the review body (disclaimer prepended)
#   --comments-file  JSON array of inline comments: [{ "path","line","body","side"? }]
#   --event          COMMENT (default) or REQUEST_CHANGES. The pipeline never APPROVEs.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh jq

pr="${1:?usage: pr-review.sh <pr> [--event E] [--body-file f] [--comments-file f]}"; shift || true
event="COMMENT"; body_file=""; comments_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) event="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --comments-file) comments_file="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ "$event" == "COMMENT" || "$event" == "REQUEST_CHANGES" ]] || maestro_die "event must be COMMENT or REQUEST_CHANGES"

repo="$(maestro_repo)"
body="$(maestro_disclaimer)"$'\n\n'
[[ -n "$body_file" && -f "$body_file" ]] && body+="$(cat "$body_file")"
comments='[]'; [[ -n "$comments_file" && -f "$comments_file" ]] && comments="$(cat "$comments_file")"

jq -n --arg e "$event" --arg b "$body" --argjson c "$comments" \
  '{event:$e, body:$b} + (if ($c|length)>0 then {comments:$c} else {} end)' \
  | gh api --method POST "repos/${repo}/pulls/${pr}/reviews" --input - >/dev/null \
  && maestro_log pr-review pr="$pr" event="$event" \
  && echo "posted ${event} review on PR #${pr}"
