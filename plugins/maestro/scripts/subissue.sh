#!/usr/bin/env bash
# subissue.sh <add|list|remove> ...
#
# Native GitHub sub-issues via gh api. The REST endpoints take the child's
# NUMERIC database id (.id), not the #number — maestro_issue_id resolves it.
#
#   add <parent> <child>     link <child> as a sub-issue of <parent>
#   list <parent>            list a parent's sub-issues (number<TAB>state<TAB>title)
#   remove <parent> <child>  unlink <child> from <parent>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh jq

cmd="${1:-}"; repo="$(maestro_repo)"
case "$cmd" in
  add)
    parent="${2:?usage: subissue.sh add <parent> <child>}"; child="${3:?child required}"
    cid="$(maestro_issue_id "$child")"; [[ -n "$cid" ]] || maestro_die "could not resolve DB id for #$child"
    gh api --method POST "repos/${repo}/issues/${parent}/sub_issues" -F "sub_issue_id=${cid}" >/dev/null \
      && maestro_log subissue-add parent="$parent" child="$child" \
      && echo "linked #$child under #$parent"
    ;;
  list)
    parent="${2:?usage: subissue.sh list <parent>}"
    gh api "repos/${repo}/issues/${parent}/sub_issues" --jq '.[] | "\(.number)\t\(.state)\t\(.title)"'
    ;;
  remove)
    parent="${2:?usage: subissue.sh remove <parent> <child>}"; child="${3:?child required}"
    cid="$(maestro_issue_id "$child")"; [[ -n "$cid" ]] || maestro_die "could not resolve DB id for #$child"
    # Note: removal endpoint is singular "sub_issue".
    gh api --method DELETE "repos/${repo}/issues/${parent}/sub_issue" -F "sub_issue_id=${cid}" >/dev/null \
      && echo "unlinked #$child from #$parent"
    ;;
  *) maestro_die "usage: subissue.sh <add|list|remove> ..." ;;
esac
