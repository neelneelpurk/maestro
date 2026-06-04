#!/usr/bin/env bash
# ensure-labels.sh — create (or update) the triage + pipeline labels this plugin
# relies on. Idempotent: safe to run repeatedly (`gh label create --force`).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

sdlc_require_cmd gh
repo="$(sdlc_repo)"

# name | hex color | description
labels=(
  "${SDLC_LABEL_NEEDS_TRIAGE}|fbca04|Maintainer needs to evaluate this issue"
  "${SDLC_LABEL_NEEDS_INFO}|d93f0b|Waiting on the reporter for more information"
  "${SDLC_LABEL_READY_AGENT}|0e8a16|Fully specified — an AFK agent can pick this up"
  "${SDLC_LABEL_READY_HUMAN}|1d76db|Specified, but needs a human to implement"
  "${SDLC_LABEL_WONTFIX}|cccccc|Will not be actioned"
  "${SDLC_LABEL_BUG}|d73a4a|Something is broken"
  "${SDLC_LABEL_ENHANCEMENT}|a2eeef|New feature or improvement"
  "${SDLC_LABEL_AFK}|5319e7|Can be implemented end-to-end with no human in the loop"
  "${SDLC_LABEL_HITL}|e99695|Requires human interaction (decision, design, manual test)"
  "${SDLC_LABEL_PRD}|0052cc|A PRD / epic parent issue"
  "${SDLC_LABEL_IN_PROGRESS}|fef2c0|An ai-sdlc agent is actively working this"
  "${SDLC_LABEL_IN_REVIEW}|006b75|A PR is open and awaiting human review"
)

echo "Ensuring ai-sdlc labels on ${repo} ..."
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if gh label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1; then
    echo "  ✔ ${name}"
  else
    sdlc_warn "could not create/update label: ${name}"
  fi
done
sdlc_log labels-ensured repo="$repo"
echo "Done."
