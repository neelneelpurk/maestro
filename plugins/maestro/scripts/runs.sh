#!/usr/bin/env bash
# runs.sh — observe maestro runs from the structured log (.maestro/log.jsonl).
#
# A "run" is one drain/ship/auto pass. Coordinators call `runs.sh start` to begin
# one: it writes .maestro/run.local so EVERY script — including background workers
# in their own worktrees, which resolve the same main-worktree state dir — stamps
# its log events with the same run_id (see maestro_log in lib.sh). `runs.sh end`
# clears it. The read views then summarize what a whole run did.
#
#   runs.sh new                       print a fresh run id (does NOT persist it)
#   runs.sh start                     begin a run: persist + print a fresh run id
#   runs.sh end                       end the current run (clear .maestro/run.local)
#   runs.sh list  [--log F] [-n N]    recent runs, newest first (default N=10)
#   runs.sh show  [--log F] [RUN_ID]  detail for a run (latest if RUN_ID omitted)
#
# Read-only except start/end. bash 3.2 compatible.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd jq

log=""; n=10; rid=""
cmd="${1:-show}"; shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) log="$2"; shift 2 ;;
    -n)    n="$2"; shift 2 ;;
    -*)    maestro_die "unknown flag: $1" ;;
    *)     rid="$1"; shift ;;
  esac
done
[[ -n "$log" ]] || log="$(maestro_state_dir)/log.jsonl"

case "$cmd" in
  new) maestro_new_run_id ;;

  start)
    id="$(maestro_new_run_id)"
    dir="$(maestro_state_dir)"; mkdir -p "$dir"
    printf '%s\n' "$id" > "$dir/run.local"
    maestro_log run-start 2>/dev/null || true   # stamped with run_id via run.local
    printf '%s\n' "$id"
    ;;

  end)
    dir="$(maestro_state_dir)"
    maestro_log run-end 2>/dev/null || true     # still stamped (run.local present)
    rm -f "$dir/run.local"
    ;;

  list)
    [[ -f "$log" ]] || { echo "no runs yet (${log} not found)"; exit 0; }
    jq -s -r --argjson n "$n" '
      map(select(.run_id != null))
      | group_by(.run_id)
      | map({
          run_id:     .[0].run_id,
          start:      (map(.ts) | min),
          events:     length,
          prs:        (map(select(.event == "pr-opened"))         | length),
          integrated: (map(select(.event == "integration-merge")) | length),
          closed:     ((map(select(.event == "integration-closed")) | length) > 0)
        })
      | sort_by(.start) | reverse | .[0:$n]
      | .[]
      | "\(.run_id)  \(.start)  events=\(.events) prs=\(.prs) integrated=\(.integrated)  \(if .closed then "[closed]" else "[active]" end)"
    ' "$log"
    ;;

  show)
    [[ -f "$log" ]] || { echo "no runs yet (${log} not found)"; exit 0; }
    if [[ -z "$rid" ]]; then
      rid="$(jq -s -r '
        map(select(.run_id != null)) | group_by(.run_id)
        | map({run_id: .[0].run_id, start: (map(.ts) | min)})
        | sort_by(.start) | last | .run_id // empty' "$log")"
    fi
    [[ -n "$rid" ]] || { echo "no runs found in ${log}"; exit 0; }
    jq -s -r --arg rid "$rid" '
      (map(select(.run_id == $rid))) as $ev
      | if ($ev | length) == 0 then "no events for run \($rid)"
        else
          (($ev | map(select(.event == "integration-start")) | .[0])) as $is
          | ( [ "run \($rid)",
                "  started:    \($ev | map(.ts) | min)",
                "  last event: \($ev | map(.ts) | max)",
                "  status:     \(if ($ev | map(select(.event == "integration-closed")) | length) > 0 then "closed" elif ($ev | map(select(.event == "run-end")) | length) > 0 then "ended" else "active" end)",
                "  integration: \(if $is then "branch=\($is.branch) pr=\($is.pr)" else "(none — ship run)" end)",
                "  pr-opened: \($ev | map(select(.event == "pr-opened")) | length)   integrated: \($ev | map(select(.event == "integration-merge")) | length)   gate-fail: \($ev | map(select(.event == "quality-gate" and ((.result == "fail") or (.result == "empty-fail")))) | length)"
              ]
              + ( $ev | map(select(.issue != null)) | group_by(.issue)
                  | map("    #\(.[0].issue): " + ([ .[].event ] | unique | join(", "))) )
            )
          | .[]
        end
    ' "$log"
    ;;

  *) maestro_die "usage: runs.sh <new|start|end|list|show> [--log F] [-n N] [RUN_ID]" ;;
esac
