#!/usr/bin/env bash
# drain-stop-hook.sh — Stop hook implementing the ai-sdlc drain loop.
#
# While .sdlc/drain.local.md exists (created by `/sdlc:drain`), this re-feeds the
# "ship every ready issue" prompt after each turn, so the agent keeps draining
# the ready queue. It stops when:
#   - the ready queue is empty (bash ready-issues.sh --count == 0), or
#   - max_iterations is reached, or
#   - the loop belongs to a different session.
#
# Structure adapted from the official ralph-loop Stop hook; completion is
# queue-based rather than a completion-promise.
set -euo pipefail

HOOK_INPUT="$(cat)"
STATE_FILE=".sdlc/drain.local.md"
[[ -f "$STATE_FILE" ]] || exit 0   # no active loop -> allow stop

FRONTMATTER="$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")"
ITERATION="$(echo "$FRONTMATTER"  | grep '^iteration:'       | sed 's/iteration: *//')"
MAX_ITER="$(echo "$FRONTMATTER"   | grep '^max_iterations:'  | sed 's/max_iterations: *//')"
STATE_SESSION="$(echo "$FRONTMATTER" | grep '^session_id:'   | sed 's/session_id: *//' || true)"
HOOK_SESSION="$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')"

# Claim the loop for the first session whose Stop fires; ignore other sessions.
if [[ -z "$STATE_SESSION" ]]; then
  tmp="${STATE_FILE}.tmp.$$"
  sed "s/^session_id:.*/session_id: ${HOOK_SESSION}/" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
elif [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate counters; corrupt state -> stop cleanly.
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITER" =~ ^[0-9]+$ ]]; then
  echo "⚠️  ai-sdlc drain: corrupt state file; stopping." >&2
  rm -f "$STATE_FILE"; exit 0
fi

# Max iterations reached?
if [[ $MAX_ITER -gt 0 && $ITERATION -ge $MAX_ITER ]]; then
  echo "🛑 ai-sdlc drain: max iterations ($MAX_ITER) reached."
  rm -f "$STATE_FILE"; exit 0
fi

# Is anything still ready? Resolve the installed scripts and ask.
source .sdlc/config.sh 2>/dev/null || true
S="${SDLC_SCRIPTS:-$PWD/.sdlc/scripts}"
COUNT="$(bash "$S/ready-issues.sh" --count 2>/dev/null || echo 0)"
[[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0

if [[ "$COUNT" -eq 0 ]]; then
  echo "✅ ai-sdlc drain: ready queue is empty — done."
  rm -f "$STATE_FILE"; exit 0
fi

# Continue: bump iteration, re-feed the ship prompt.
NEXT=$((ITERATION + 1))
tmp="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: ${NEXT}/" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

PROMPT="$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")"
[[ -n "$PROMPT" ]] || { echo "⚠️  ai-sdlc drain: empty prompt; stopping." >&2; rm -f "$STATE_FILE"; exit 0; }

jq -n \
  --arg prompt "$PROMPT" \
  --arg msg "🔄 ai-sdlc drain iteration ${NEXT} | ${COUNT} issue(s) ready — shipping" \
  '{decision: "block", reason: $prompt, systemMessage: $msg}'
exit 0
