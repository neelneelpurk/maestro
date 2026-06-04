#!/usr/bin/env bash
# open-pr.sh <issue> [--title <t>] [--body-file <path>] [--draft] [--no-link]
#
# Run this from inside the issue's worktree. It:
#   1. pushes the current branch to origin
#   2. opens a PR (or reuses an existing one for the branch) whose body has
#      the AI disclaimer, `Closes #<issue>`, the issue's acceptance criteria,
#      and a commit summary
#   3. unless --no-link: relabels the issue ready-for-agent/in-progress -> in-review
#      and comments the PR link on the issue
# Prints the PR URL on stdout.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

sdlc_require_cmd gh git jq

issue=""; title=""; body_file=""; draft=0; link=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)     title="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --draft)     draft=1; shift ;;
    --no-link)   link=0; shift ;;
    -*)          sdlc_die "unknown flag: $1" ;;
    *)           issue="$1"; shift ;;
  esac
done
[[ -n "$issue" ]] || sdlc_die "usage: open-pr.sh <issue> [--title t] [--body-file f] [--draft] [--no-link]"

branch="$(git rev-parse --abbrev-ref HEAD)"
default="$(sdlc_default_branch)"
[[ "$branch" != "$default" ]] || sdlc_die "refusing to open a PR from the default branch ($default) — work in an issue worktree"

# Issue title/body for the PR title + acceptance criteria.
issue_json="$(gh issue view "$issue" --json title,body 2>/dev/null || echo '{}')"
issue_title="$(jq -r '.title // ""' <<<"$issue_json")"
issue_body="$(jq -r '.body // ""' <<<"$issue_json")"
[[ -n "$title" ]] || title="$issue_title"
[[ -n "$title" ]] || title="Implement issue #${issue}"

ac="$(printf '%s\n' "$issue_body" | awk '
  /^##.*[Aa]cceptance/ {f=1; next}
  f && /^##/ {f=0}
  f {print}
' | grep -E '^[[:space:]]*- \[[ xX]\]' || true)"

# Push the branch.
git push -u origin "$branch" >&2

# Reuse an existing PR for this branch if present.
existing="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
if [[ -n "$existing" ]]; then
  sdlc_warn "a PR already exists for ${branch}; reusing it"
  url="$existing"
else
  # Build the body.
  tmp_body="$(mktemp)"; trap 'rm -f "$tmp_body"' EXIT
  {
    sdlc_disclaimer
    echo
    echo "Closes #${issue}"
    echo
    if [[ -n "$body_file" && -f "$body_file" ]]; then
      echo "## Summary"; echo
      cat "$body_file"; echo
    fi
    echo "## Commits"; echo
    git log --oneline "origin/${default}..HEAD" 2>/dev/null | sed 's/^/- /' || true
    echo
    if [[ -n "$ac" ]]; then
      echo "## Acceptance criteria (from #${issue})"; echo
      printf '%s\n' "$ac"
    fi
  } >"$tmp_body"

  args=(--title "$title" --body-file "$tmp_body" --head "$branch" --base "$default")
  [[ $draft -eq 1 ]] && args+=(--draft)
  url="$(gh pr create "${args[@]}" 2>&1 | grep -oE 'https://github.com/[^ ]+/pull/[0-9]+' | head -1 || true)"
  [[ -n "$url" ]] || sdlc_die "gh pr create did not return a PR URL (check output above)"
fi

if [[ $link -eq 1 ]]; then
  gh issue edit "$issue" \
    --add-label "$SDLC_LABEL_IN_REVIEW" \
    --remove-label "$SDLC_LABEL_READY_AGENT" \
    --remove-label "$SDLC_LABEL_IN_PROGRESS" >/dev/null 2>&1 || sdlc_warn "could not relabel issue #${issue}"
  gh issue comment "$issue" --body "$(sdlc_disclaimer)
Opened PR for this issue: ${url}" >/dev/null 2>&1 || sdlc_warn "could not comment on issue #${issue}"
fi

sdlc_log pr-opened issue="$issue" branch="$branch" url="$url"
printf '%s\n' "$url"
