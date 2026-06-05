#!/usr/bin/env bash
# make-worktree.sh <issue> [--base <branch>] [--slug <slug>]
#
# Creates (or reuses) an isolated git worktree + branch for one issue, based on
# <branch> (default: the repo's default branch; drain/auto pass the integration
# branch). The branch is created with `gh issue develop` so GitHub records a
# native branch<->issue "Development" link. Idempotent. Prints the ABSOLUTE
# worktree path on stdout (only that); progress to stderr.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd git gh

issue="${1:-}"; shift || true
[[ -n "$issue" ]] || maestro_die "usage: make-worktree.sh <issue> [--base <branch>] [--slug <slug>]"
base=""; slug=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --slug) slug="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$base" ]] || base="$(maestro_default_branch)"
if [[ -z "$slug" ]]; then
  title="$(gh issue view "$issue" --json title --jq .title 2>/dev/null || true)"
  slug="$(maestro_slug "${title:-issue}")"; [[ -n "$slug" ]] || slug="issue"
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || maestro_die "not inside a git repository"
branch="$(maestro_branch_for "$issue" "$slug")"

case "$MAESTRO_WORKTREE_DIR" in
  /*) wt_base="$MAESTRO_WORKTREE_DIR" ;;
  *)  wt_base="$repo_root/$MAESTRO_WORKTREE_DIR" ;;
esac
mkdir -p "$wt_base"; wt_base="$(cd "$wt_base" && pwd)"
wt_path="${wt_base}/issue-${issue}-${slug}"

# Reuse an existing registered worktree.
if git -C "$repo_root" worktree list --porcelain | grep -qxF "worktree ${wt_path}"; then
  maestro_warn "reusing existing worktree: ${wt_path}"
  printf '%s\n' "$wt_path"; exit 0
fi
if [[ -e "$wt_path" ]]; then
  maestro_warn "clearing stale path: ${wt_path}"
  git -C "$repo_root" worktree prune || true; rm -rf "$wt_path"
fi

git -C "$repo_root" fetch origin "$base" --quiet 2>/dev/null || true

# Create the branch + native issue link if it doesn't exist yet on the remote.
if ! git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  maestro_warn "creating linked branch ${branch} off ${base} (gh issue develop #${issue})"
  if ! gh issue develop "$issue" --base "$base" --name "$branch" >&2 2>/dev/null; then
    # Fallback: create the branch directly off the base if gh issue develop fails.
    maestro_warn "gh issue develop unavailable; creating ${branch} directly off origin/${base}"
    git -C "$repo_root" branch "$branch" "origin/${base}" 2>/dev/null \
      || git -C "$repo_root" branch "$branch" "$base" 2>/dev/null || true
    git -C "$repo_root" push -u origin "$branch" >&2 2>/dev/null || true
  fi
fi
git -C "$repo_root" fetch origin "$branch" --quiet 2>/dev/null || true

# Build the worktree, forcing the local branch to track the (freshly created) remote branch.
if git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  git -C "$repo_root" worktree add -B "$branch" "$wt_path" "origin/${branch}" >&2
else
  git -C "$repo_root" worktree add "$wt_path" -b "$branch" "origin/${base}" >&2
fi

maestro_log worktree-created issue="$issue" branch="$branch" base="$base" path="$wt_path"
printf '%s\n' "$wt_path"
