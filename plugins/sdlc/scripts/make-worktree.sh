#!/usr/bin/env bash
# make-worktree.sh <issue> [slug]
#
# Creates (or reuses) an isolated git worktree + branch for one issue, based on
# the latest default branch. Idempotent. Prints the ABSOLUTE worktree path on
# stdout (and nothing else on stdout) so callers can `cd "$(make-worktree.sh ...)"`.
# Progress goes to stderr. If <slug> is omitted it is derived from the issue title.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

sdlc_require_cmd git

issue="${1:-}"; slug="${2:-}"
[[ -n "$issue" ]] || sdlc_die "usage: make-worktree.sh <issue> [slug]"
if [[ -z "$slug" ]]; then
  sdlc_require_cmd gh
  title="$(gh issue view "$issue" --json title --jq .title 2>/dev/null || true)"
  [[ -n "$title" ]] || sdlc_die "could not fetch issue #$issue to derive a slug; pass <slug> explicitly"
  slug="$(sdlc_slug "$title")"
  [[ -n "$slug" ]] || slug="issue"
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || sdlc_die "not inside a git repository"
default="$(sdlc_default_branch)"
branch="$(sdlc_branch_for "$issue" "$slug")"

# Resolve the worktree base dir to an absolute, normalised path.
case "$SDLC_WORKTREE_DIR" in
  /*) wt_base="$SDLC_WORKTREE_DIR" ;;
  *)  wt_base="$repo_root/$SDLC_WORKTREE_DIR" ;;
esac
mkdir -p "$wt_base"
wt_base="$(cd "$wt_base" && pwd)"
wt_path="${wt_base}/issue-${issue}-${slug}"

# Already registered? Reuse it.
if git -C "$repo_root" worktree list --porcelain | grep -qxF "worktree ${wt_path}"; then
  sdlc_warn "reusing existing worktree: ${wt_path}"
  printf '%s\n' "$wt_path"
  exit 0
fi

# A stale directory with no worktree registration — clear it.
if [[ -e "$wt_path" ]]; then
  sdlc_warn "removing stale path before re-creating worktree: ${wt_path}"
  git -C "$repo_root" worktree prune || true
  rm -rf "$wt_path"
fi

# Pick the freshest start point for the new branch.
git -C "$repo_root" fetch origin "$default" --quiet 2>/dev/null || true
if git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${default}"; then
  start="origin/${default}"
elif git -C "$repo_root" show-ref --verify --quiet "refs/heads/${default}"; then
  start="$default"
else
  start="HEAD"
fi

sdlc_warn "creating worktree ${wt_path} on branch ${branch} (from ${start})"
if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
  # Branch already exists — check it out into the worktree.
  git -C "$repo_root" worktree add "$wt_path" "$branch" >&2
else
  git -C "$repo_root" worktree add "$wt_path" -b "$branch" "$start" >&2
fi

sdlc_log worktree-created issue="$issue" branch="$branch" path="$wt_path"
printf '%s\n' "$wt_path"
