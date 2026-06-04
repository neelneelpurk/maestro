#!/usr/bin/env bash
# integration.sh <start|branch|pr|integrate|status|close-integrated> ...
#
# Implements the drain/auto integration-branch model: one integration branch off
# the default branch + one integration PR (integration -> default) that is the
# single human review gate (never auto-merged). Per-issue PRs target the
# integration branch and are merged into it automatically; their issues are NOT
# closed — they move to `waiting-for-human-closure`.
#
# Run state lives in .sdlc/integration.local.md (gitignored).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
sdlc_require_cmd gh jq git

STATE="$(sdlc_state_dir)/integration.local.md"
repo="$(sdlc_repo)"; default="$(sdlc_default_branch)"

_field() { [[ -f "$STATE" ]] && sed -n "s/^$1: //p" "$STATE" | head -1 || true; }
_int_open() { local n; n="$(_field pr_number)"; [[ -n "$n" ]] && [[ "$(gh pr view "$n" --json state --jq .state 2>/dev/null)" == "OPEN" ]]; }

cmd="${1:-status}"; shift || true
case "$cmd" in
  start)
    if [[ -f "$STATE" ]] && _int_open; then
      _field branch; exit 0   # reuse the active run
    fi
    stamp="$(date +%Y%m%d-%H%M%S)"
    branch="${SDLC_INTEGRATION_PREFIX}${stamp}"
    git fetch origin "$default" --quiet 2>/dev/null || true
    # Seed the integration branch with an empty commit (via a throwaway worktree)
    # so the integration PR has a diff and can be opened immediately. All git
    # chatter goes to stderr; only the branch name is printed on stdout.
    tmpwt="$(mktemp -d)"
    if git worktree add -B "$branch" "$tmpwt" "origin/${default}" >&2 2>/dev/null \
       || git worktree add -B "$branch" "$tmpwt" "$default" >&2 2>/dev/null; then
      git -C "$tmpwt" -c commit.gpgsign=false commit --allow-empty -q -m "ai-sdlc: start integration run ${stamp}" >&2 2>/dev/null || true
      git -C "$tmpwt" push -u origin "$branch" >&2 2>/dev/null
      git worktree remove "$tmpwt" --force >/dev/null 2>&1 || true
    else
      rm -rf "$tmpwt"; sdlc_die "could not create the integration branch ${branch}"
    fi
    body="$(sdlc_disclaimer)
Integration PR for an ai-sdlc drain/auto run. Per-issue PRs merge into \`${branch}\`; **this** PR is your single review gate to \`${default}\` — it is never auto-merged.

## Integrated issues
"
    url="$(gh pr create --title "ai-sdlc integration ${stamp}" --body "$body" --head "$branch" --base "$default" 2>&1 | grep -oE 'https://github.com/[^ ]+/pull/[0-9]+' | head -1)"
    [[ -n "$url" ]] || sdlc_die "could not open the integration PR"
    num="${url##*/}"
    gh pr edit "$num" --add-label "$SDLC_LABEL_INTEGRATION" >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$STATE")"
    cat > "$STATE" <<EOF
---
branch: ${branch}
pr_number: ${num}
pr_url: ${url}
default_base: ${default}
EOF
    echo "---" >> "$STATE"
    sdlc_log integration-start branch="$branch" pr="$num"
    sdlc_warn "integration run started: ${url}"
    printf '%s\n' "$branch"
    ;;

  branch) _field branch ;;
  pr)     _field pr_number ;;

  integrate)
    # integrate <issue> <per-issue-pr-number>  — merge the per-issue PR into the
    # integration branch, relabel the issue, and log progress on the integration PR.
    issue="${1:?usage: integration.sh integrate <issue> <pr>}"; pr="${2:?pr required}"
    intpr="$(_field pr_number)"
    title="$(gh issue view "$issue" --json title --jq .title 2>/dev/null || echo "#$issue")"
    if gh pr merge "$pr" --squash --auto >/dev/null 2>&1 || gh pr merge "$pr" --squash >/dev/null 2>&1; then
      gh issue edit "$issue" \
        --add-label "$SDLC_LABEL_WAITING_CLOSURE" \
        --remove-label "$SDLC_LABEL_IN_PROGRESS" \
        --remove-label "$SDLC_LABEL_READY_AGENT" >/dev/null 2>&1 || true
      gh issue comment "$issue" --body "$(sdlc_disclaimer)
Implemented and merged into the integration branch via PR #${pr}. Awaiting human closure when the integration PR (#${intpr}) merges to \`${default}\`." >/dev/null 2>&1 || true
      if [[ -n "$intpr" ]]; then
        gh pr comment "$intpr" --body "$(sdlc_disclaimer)
✅ Integrated #${issue} (${title}) via PR #${pr}." >/dev/null 2>&1 || true
        # Tick the checklist in the integration PR body.
        cur="$(gh pr view "$intpr" --json body --jq .body 2>/dev/null || true)"
        printf '%s\n- [x] #%s %s (PR #%s)\n' "$cur" "$issue" "$title" "$pr" > /tmp/intbody.$$ \
          && gh pr edit "$intpr" --body-file /tmp/intbody.$$ >/dev/null 2>&1; rm -f /tmp/intbody.$$
      fi
      sdlc_log integration-merge issue="$issue" pr="$pr"
      echo "integrated #${issue} (PR #${pr})"
    else
      gh issue edit "$issue" --add-label "$SDLC_LABEL_HITL" --remove-label "$SDLC_LABEL_IN_PROGRESS" >/dev/null 2>&1 || true
      gh pr comment "$pr" --body "$(sdlc_disclaimer)
Could not auto-merge into the integration branch (likely a conflict). Flagged \`${SDLC_LABEL_HITL}\` for a human." >/dev/null 2>&1 || true
      sdlc_die "merge of PR #${pr} for issue #${issue} failed — flagged for a human"
    fi
    ;;

  status)
    if [[ -f "$STATE" ]] && _int_open; then
      echo "integration run ACTIVE: branch=$(_field branch) PR=$(_field pr_url)"
    else
      echo "no active integration run."
    fi
    ;;

  close-integrated)
    # After the human merges the integration PR, close this run's issues.
    intpr="$(_field pr_number)"
    [[ -n "$intpr" ]] || sdlc_die "no integration run state found"
    st="$(gh pr view "$intpr" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
    if [[ "$st" != "MERGED" && "${1:-}" != "--force" ]]; then
      sdlc_die "integration PR #${intpr} is ${st}, not MERGED — merge it first (or pass --force)"
    fi
    gh issue list --label "$SDLC_LABEL_WAITING_CLOSURE" --state open --json number --jq '.[].number' 2>/dev/null \
    | while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        gh issue close "$n" --reason completed >/dev/null 2>&1 \
          && gh issue edit "$n" --remove-label "$SDLC_LABEL_WAITING_CLOSURE" >/dev/null 2>&1 \
          && echo "closed #$n"
      done
    rm -f "$STATE"
    sdlc_log integration-closed pr="$intpr"
    echo "integration run closed."
    ;;

  *) sdlc_die "usage: integration.sh <start|branch|pr|integrate|status|close-integrated> ..." ;;
esac
