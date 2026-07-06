#!/usr/bin/env bash
# ensure-labels.sh — create (or update) the triage + pipeline labels this plugin
# relies on. Idempotent: safe to run repeatedly (`gh label create --force`).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

maestro_require_cmd gh
repo="$(maestro_repo)"

# name | hex color | description   (see docs/GLOSSARY.md for the state machine)
labels=(
  # Triage state
  "${MAESTRO_LABEL_NEEDS_TRIAGE}|fbca04|Maintainer needs to evaluate this issue"
  "${MAESTRO_LABEL_NEEDS_INFO}|d93f0b|Waiting on the reporter for more information"
  "${MAESTRO_LABEL_READY_AGENT}|0e8a16|Human-approved for autonomous implementation"
  "${MAESTRO_LABEL_READY_HUMAN}|1d76db|Specified, but needs a human to implement"
  "${MAESTRO_LABEL_WONTFIX}|cccccc|Will not be actioned"
  # Type
  "${MAESTRO_LABEL_BUG}|d73a4a|Something is broken"
  "${MAESTRO_LABEL_ENHANCEMENT}|a2eeef|New feature or improvement"
  "${MAESTRO_LABEL_PRD}|0052cc|A PRD / epic parent issue"
  "${MAESTRO_LABEL_ROADMAP}|5319e7|A roadmap parent issue"
  "${MAESTRO_LABEL_TECH_DEBT}|d4c5f9|Technical debt to pay down"
  # Gate / mode
  "${MAESTRO_LABEL_AUTO}|8a2be2|Autonomous lane — picked without the ready-for-agent human gate"
  "${MAESTRO_LABEL_HITL}|e99695|Needs human interaction; never auto-picked"
  # Execution state
  "${MAESTRO_LABEL_IN_PROGRESS}|fef2c0|A worker is implementing this"
  "${MAESTRO_LABEL_IN_REVIEW}|006b75|ship: PR to the default branch, awaiting human review"
  "${MAESTRO_LABEL_WAITING_CLOSURE}|c2e0c6|drain/auto: PR merged into the integration branch; awaiting human closure"
  "${MAESTRO_LABEL_BLOCKED}|b60205|Has open dependencies (board marker)"
  # PR
  "${MAESTRO_LABEL_INTEGRATION}|0e8a16|The integration -> default-branch PR (your review gate)"
)

echo "Ensuring agent: labels on ${repo} ..."
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if gh label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1; then
    echo "  ✔ ${name}"
  else
    maestro_warn "could not create/update label: ${name}"
  fi
done
maestro_log labels-ensured repo="$repo"
echo "Done."
