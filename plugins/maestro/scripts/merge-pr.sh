#!/usr/bin/env bash
# merge-pr.sh [<pr-number>] [--merge|--squash|--rebase] [--admin] [--force]
#
# Human action — exercise your single review gate: merge a maestro PR AND close
# the issues it covers, in one step.
#
#   • No PR number → target the ACTIVE integration run's PR. Merging it then closes
#     every issue in that run (the `maestro:waiting-for-human-closure` set) and
#     clears the run state — i.e. `gh pr merge` + `integration.sh close-integrated`.
#   • With a PR number → merge that PR. A per-issue / ship PR closes its linked
#     issue via `Closes #n` on merge.
#
# This is MANUAL. The autonomous lane (/maestro:auto, /maestro:drain) never calls
# it — the integration PR is yours to merge. Default method: --merge (a merge
# commit, preserving the per-issue squashed commits).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh jq
S="$MAESTRO_LIB_DIR"

method="--merge"; admin=0; force=0; pr=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --merge|--squash|--rebase) method="$1"; shift ;;
    --admin) admin=1; shift ;;
    --force) force=1; shift ;;
    -*) maestro_die "unknown flag: $1" ;;
    *)  pr="$1"; shift ;;
  esac
done

intpr="$(bash "$S/integration.sh" pr 2>/dev/null || true)"
[[ -n "$pr" ]] || pr="$intpr"
[[ -n "$pr" ]] || maestro_die "no PR given and no active integration run — usage: merge-pr.sh [<pr>] [--merge|--squash|--rebase] [--admin]"

is_integration=0
[[ -n "$intpr" && "$pr" == "$intpr" ]] && is_integration=1

state="$(gh pr view "$pr" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
case "$state" in
  MERGED) echo "PR #${pr} is already merged." ;;
  OPEN)
    echo "Merging PR #${pr} (${method#--})…"
    args=("$method"); [[ $admin -eq 1 ]] && args+=(--admin)
    gh pr merge "$pr" "${args[@]}" >&2 \
      || maestro_die "could not merge PR #${pr} — resolve conflicts / required checks (or pass --admin), then retry"
    maestro_log pr-merged pr="$pr" integration="$is_integration"
    echo "merged PR #${pr}."
    ;;
  *) maestro_die "PR #${pr} is ${state}; refusing to merge." ;;
esac

if [[ $is_integration -eq 1 ]]; then
  echo "Closing this run's issues…"
  if [[ $force -eq 1 ]]; then
    bash "$S/integration.sh" close-integrated --force
  else
    bash "$S/integration.sh" close-integrated
  fi
else
  echo "If this PR used 'Closes #<n>', GitHub closed its issue on merge."
fi
