#!/usr/bin/env bash
# pr-quality-gate.sh — PreToolUse (Bash) backstop.
#
# When the agent is about to run a DIRECT `gh pr create`, run the quality gate
# in that command's working directory and block the PR (exit 2) if it fails.
# The pipeline's own open-pr.sh already gates itself, so this only catches
# out-of-band/manual PRs. Best-effort: if the gate can't be located or the dir
# is unknown, it allows the call rather than blocking spuriously.
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT="$(cat)"
cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"
cwd="$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")"

# Only act on a direct `gh pr create`; the pipeline path (open-pr.sh) self-gates.
printf '%s' "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create' || exit 0
printf '%s' "$cmd" | grep -q 'open-pr.sh' && exit 0

gate="${HOOK_DIR}/../scripts/quality-gate.sh"
[[ -f "$gate" ]] || exit 0

workdir="${cwd:-$PWD}"
if ! ( cd "$workdir" 2>/dev/null && bash "$gate" --no-install >&2 ); then
  echo "ai-sdlc: quality gate failed in ${workdir} — blocking 'gh pr create'. Fix the failures before opening a PR (or open it through the pipeline, which reports gate output)." >&2
  exit 2   # exit code 2 blocks the tool call; stderr is shown to Claude
fi
exit 0
