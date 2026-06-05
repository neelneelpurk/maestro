#!/usr/bin/env bash
# dependency.sh <add|list|open|remove> ...
#
# Native GitHub issue dependencies via gh api. The REST endpoints take the
# blocker's NUMERIC database id (.id), not the #number.
#
#   add <issue> <blocker>    mark <issue> blocked_by <blocker>
#   list <issue>             list all blockers (number<TAB>state)
#   open <issue>             list only blockers that are still OPEN (numbers, one per line)
#   remove <issue> <blocker> remove the dependency
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh jq

cmd="${1:-}"; repo="$(maestro_repo)"
case "$cmd" in
  add)
    issue="${2:?usage: dependency.sh add <issue> <blocker>}"; blk="${3:?blocker required}"
    bid="$(maestro_issue_id "$blk")"; [[ -n "$bid" ]] || maestro_die "could not resolve DB id for #$blk"
    gh api --method POST "repos/${repo}/issues/${issue}/dependencies/blocked_by" -F "issue_id=${bid}" >/dev/null \
      && maestro_log dependency-add issue="$issue" blocker="$blk" \
      && echo "#$issue is now blocked by #$blk"
    ;;
  list)
    issue="${2:?usage: dependency.sh list <issue>}"
    gh api "repos/${repo}/issues/${issue}/dependencies/blocked_by" --jq '.[] | "\(.number)\t\(.state)"' 2>/dev/null || true
    ;;
  open)
    issue="${2:?usage: dependency.sh open <issue>}"
    gh api "repos/${repo}/issues/${issue}/dependencies/blocked_by" \
      --jq '.[] | select(.state=="open") | .number' 2>/dev/null || true
    ;;
  remove)
    issue="${2:?usage: dependency.sh remove <issue> <blocker>}"; blk="${3:?blocker required}"
    bid="$(maestro_issue_id "$blk")"; [[ -n "$bid" ]] || maestro_die "could not resolve DB id for #$blk"
    gh api --method DELETE "repos/${repo}/issues/${issue}/dependencies/blocked_by/${bid}" >/dev/null \
      && echo "removed dependency: #$issue no longer blocked by #$blk"
    ;;
  *) maestro_die "usage: dependency.sh <add|list|open|remove> ..." ;;
esac
