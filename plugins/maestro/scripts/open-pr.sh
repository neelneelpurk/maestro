#!/usr/bin/env bash
# open-pr.sh <issue> [--base <branch>] [--body-file f] [--draft] [--no-gate]
#
# Run from inside the issue's worktree. Runs the quality gate (the authoritative
# guard — red gate => no PR), pushes the branch, and opens ONE PR for the issue:
#
#   --base = default branch (ship, supervised):  PR with `Closes #<n>` -> default
#       branch; relabel the issue `in-review`; await human review.
#   --base = an integration branch (drain/auto):  PR (no `Closes`) -> integration
#       branch, then hand off to integration.sh, which merges it and relabels the
#       issue `waiting-for-human-closure` (the issue is NOT auto-closed).
#
# Prints the per-issue PR URL on stdout.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh git jq

issue=""; base=""; body_file=""; draft=0; no_gate=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)      base="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --draft)     draft=1; shift ;;
    --no-gate)   no_gate=1; shift ;;
    -*)          maestro_die "unknown flag: $1" ;;
    *)           issue="$1"; shift ;;
  esac
done
[[ -n "$issue" ]] || maestro_die "usage: open-pr.sh <issue> [--base <branch>] [--body-file f] [--draft] [--no-gate]"

branch="$(git rev-parse --abbrev-ref HEAD)"
default="$(maestro_default_branch)"
[[ -n "$base" ]] || base="$default"
[[ "$branch" != "$default" && "$branch" != "$base" ]] || maestro_die "refusing to open a PR from '$branch' — work on an issue branch in a worktree"

# Quality gate — the authoritative no-red-PR guard. Runs in the worktree.
if [[ $no_gate -eq 0 && "${MAESTRO_SKIP_GATE:-0}" != "1" ]]; then
  bash "${MAESTRO_LIB_DIR}/quality-gate.sh" || maestro_die "quality gate failed — not opening a PR for #${issue} (fix and retry, or --no-gate to override)."
fi

git push -u origin "$branch" >&2

# Reuse an existing open PR for this branch.
url="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
if [[ -z "$url" ]]; then
  issue_json="$(gh issue view "$issue" --json title,body 2>/dev/null || echo '{}')"
  title="$(jq -r '.title // ""' <<<"$issue_json")"; [[ -n "$title" ]] || title="Implement issue #${issue}"
  ac="$(jq -r '.body // ""' <<<"$issue_json" | awk '
    /^##.*[Aa]cceptance/ {f=1; next} f && /^##/ {f=0} f {print}' | grep -E '^[[:space:]]*- \[[ xX]\]' || true)"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  {
    maestro_disclaimer; echo
    if [[ "$base" == "$default" ]]; then echo "Closes #${issue}"; else echo "Part of #${issue} (merges into the integration branch \`${base}\`; the issue stays open until the integration PR merges)."; fi
    echo
    [[ -n "$body_file" && -f "$body_file" ]] && { echo "## Summary"; echo; cat "$body_file"; echo; }
    echo "## Commits"; echo
    git log --oneline "origin/${base}..HEAD" 2>/dev/null | sed 's/^/- /' || true
    echo
    [[ -n "$ac" ]] && { echo "## Acceptance criteria (from #${issue})"; echo; printf '%s\n' "$ac"; }
  } >"$tmp"
  args=(--title "$title" --body-file "$tmp" --head "$branch" --base "$base")
  [[ $draft -eq 1 ]] && args+=(--draft)
  url="$(gh pr create "${args[@]}" 2>&1 | grep -oE 'https://github.com/[^ ]+/pull/[0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || maestro_die "gh pr create did not return a PR URL"
fi
num="${url##*/}"

if [[ "$base" == "$default" ]]; then
  # Ship (supervised): await human review. Assign + request review from whoever
  # owns the issue so it surfaces in their GitHub inbox, not just the tracker.
  gh issue edit "$issue" --add-label "$MAESTRO_LABEL_IN_REVIEW" \
    --remove-label "$MAESTRO_LABEL_READY_AGENT" --remove-label "$MAESTRO_LABEL_IN_PROGRESS" \
    --remove-label "$MAESTRO_LABEL_AUTO" >/dev/null 2>&1 || true
  gh pr edit "$num" --add-assignee "$MAESTRO_ASSIGNEE" >/dev/null 2>&1 || true
  gh pr edit "$num" --add-reviewer "$MAESTRO_ASSIGNEE" >/dev/null 2>&1 || true
  gh issue comment "$issue" --body "$(maestro_disclaimer)
Opened PR for review: ${url}" >/dev/null 2>&1 || true
else
  # Integration (drain/auto): merge into the integration branch + relabel.
  bash "${MAESTRO_LIB_DIR}/integration.sh" integrate "$issue" "$num" >&2
fi

maestro_log pr-opened issue="$issue" branch="$branch" base="$base" url="$url"
printf '%s\n' "$url"
