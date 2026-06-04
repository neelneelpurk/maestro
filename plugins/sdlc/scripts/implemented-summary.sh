#!/usr/bin/env bash
# implemented-summary.sh [--limit N]
#
# Summarizes what has already been implemented, to inform /sdlc:roadmap:
# recently merged PRs, recently closed issues, open PRs, and open milestones.
# Prints JSON.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
sdlc_require_cmd gh jq

limit=30; [[ "${1:-}" == "--limit" ]] && limit="${2:-30}"
repo="$(sdlc_repo)"

merged="$(gh pr list --state merged --limit "$limit" --json number,title,mergedAt 2>/dev/null || echo '[]')"
closed="$(gh issue list --state closed --limit "$limit" --json number,title,labels,closedAt 2>/dev/null || echo '[]')"
openprs="$(gh pr list --state open --limit "$limit" --json number,title,headRefName 2>/dev/null || echo '[]')"
milestones="$(gh api "repos/${repo}/milestones?state=open" --jq '[.[] | {title, open_issues, closed_issues, due_on}]' 2>/dev/null || echo '[]')"

jq -n --argjson merged "$merged" --argjson closed "$closed" --argjson openprs "$openprs" --argjson milestones "$milestones" \
  '{merged_prs:$merged, closed_issues:$closed, open_prs:$openprs, open_milestones:$milestones}'
