#!/usr/bin/env bash
# status.sh — print the maestro board: where every issue/PR sits in the pipeline.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
maestro_require_cmd gh jq

repo="$(maestro_repo)"
version="$(maestro_version)"
echo "═══ maestro status (v${version}) — ${repo} ═══"

list_label() {  # list_label "<label...>" "<heading>"
  local labels="$1" heading="$2" args=() l
  for l in $labels; do args+=(--label "$l"); done
  local json; json="$(gh issue list "${args[@]}" --state open --limit 200 --json number,title 2>/dev/null || echo '[]')"
  local n; n="$(jq 'length' <<<"$json")"
  echo
  echo "■ ${heading} (${n})"
  jq -r '.[] | "   #\(.number)  \(.title)"' <<<"$json"
}

# Ready to ship right now (unblocked, afk).
ready="$(bash "${SCRIPT_DIR}/ready-issues.sh" 2>/dev/null || echo '[]')"
echo
echo "■ Ready to ship ($(jq 'length' <<<"$ready"))   ← /maestro:ship picks these up"
jq -r '.[] | "   #\(.number)  \(.title)"' <<<"$ready"

# Blocked: afk + ready-for-agent, but waiting on open blockers.
ready_nums="$(jq -r '.[].number' <<<"$ready" | sort -u)"
afk_all="$(gh issue list --label "$MAESTRO_LABEL_READY_AGENT" --label "$MAESTRO_LABEL_AFK" --state open --limit 200 --json number,title 2>/dev/null || echo '[]')"
echo
echo "■ Blocked (waiting on a blocker to merge)"
jq -r '.[] | "\(.number)\t\(.title)"' <<<"$afk_all" | while IFS=$'\t' read -r num title; do
  [[ -n "$num" ]] || continue
  grep -qxF "$num" <<<"$ready_nums" && continue   # it's ready, not blocked
  blockers="$(bash "${SCRIPT_DIR}/blocked-by.sh" "$num" 2>/dev/null | tr '\n' ' ')"
  [[ -n "${blockers// /}" ]] && echo "   #${num}  ${title}  ⟵ blocked by: ${blockers}"
done

list_label "$MAESTRO_LABEL_IN_PROGRESS" "In progress (a worker is implementing)"
list_label "$MAESTRO_LABEL_IN_REVIEW" "In review (ship: PR to default branch, awaiting you)"
list_label "$MAESTRO_LABEL_WAITING_CLOSURE" "Integrated, waiting for human closure (drain/auto)"
list_label "$MAESTRO_LABEL_HITL" "Needs a human (hitl)"

# Open PRs.
echo
prs="$(gh pr list --state open --limit 200 --json number,title,headRefName 2>/dev/null || echo '[]')"
echo "■ Open PRs ($(jq 'length' <<<"$prs"))"
jq -r '.[] | "   #\(.number)  \(.title)  [\(.headRefName)]"' <<<"$prs"

# Integration run.
echo
printf '■ '
bash "${SCRIPT_DIR}/integration.sh" status 2>/dev/null || echo "no active integration run."

# Recent runs (from the structured log) — see `runs.sh show` for a full breakdown.
echo
echo "■ Recent runs"
bash "${SCRIPT_DIR}/runs.sh" list -n 5 2>/dev/null | sed 's/^/   /' || true
