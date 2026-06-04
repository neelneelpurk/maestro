#!/usr/bin/env bash
# drain-control.sh <start|stop|status> [--max N]
#
# Manages the ralph-style drain loop state file, .sdlc/drain.local.md, which the
# Stop hook (drain-stop-hook.sh) reads to decide whether to keep shipping.
#
#   start [--max N]  begin a drain loop (default max 10 iterations). The loop is
#                    claimed by the first session whose Stop hook fires.
#   stop             end the loop (remove the state file).
#   status           show whether a loop is active and its iteration.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

cmd="${1:-status}"; shift || true
max=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max) max="$2"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "$SDLC_DIR"
state="${SDLC_DIR}/drain.local.md"

case "$cmd" in
  start)
    [[ "$max" =~ ^[0-9]+$ ]] || sdlc_die "--max must be a non-negative integer"
    cat > "$state" <<EOF
---
iteration: 0
max_iterations: ${max}
session_id:
---
Run the ship-ready-issues skill now: implement EVERY ready-for-agent issue by fanning out one issue-implementer subagent per issue (each in its own worktree, each opening a PR). Do not merge anything. Then stop.
EOF
    sdlc_log drain-start max="$max"
    echo "drain loop armed (max ${max} iterations). It will run after each turn until the ready queue is empty."
    echo "Stop early with: /sdlc:drain stop"
    ;;
  stop)
    if [[ -f "$state" ]]; then rm -f "$state"; sdlc_log drain-stop; echo "drain loop stopped."; else echo "no drain loop active."; fi
    ;;
  status)
    if [[ -f "$state" ]]; then
      it="$(grep '^iteration:' "$state" | sed 's/iteration: *//')"
      mx="$(grep '^max_iterations:' "$state" | sed 's/max_iterations: *//')"
      echo "drain loop ACTIVE — iteration ${it:-?}/${mx:-?}"
    else
      echo "no drain loop active."
    fi
    ;;
  *) sdlc_die "usage: drain-control.sh <start|stop|status> [--max N]" ;;
esac
