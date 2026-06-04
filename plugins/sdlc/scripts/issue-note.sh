#!/usr/bin/env bash
# issue-note.sh <issue> --body-file <f>
# issue-note.sh <issue> "text..."
#
# Post a disclaimer-led comment to a GitHub issue. Used by workers to record the
# implementation plan and the changes made, so progress is trackable on the issue.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
sdlc_require_cmd gh

issue="${1:?usage: issue-note.sh <issue> (--body-file <f> | text...)}"; shift || true
if [[ "${1:-}" == "--body-file" ]]; then
  [[ -f "${2:-}" ]] || sdlc_die "body file not found: ${2:-}"
  body="$(cat "$2")"
else
  body="$*"
fi
[[ -n "$body" ]] || sdlc_die "empty comment body"

gh issue comment "$issue" --body "$(sdlc_disclaimer)
${body}" >/dev/null && sdlc_log issue-note issue="$issue" && echo "commented on #${issue}"
