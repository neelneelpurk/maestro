#!/usr/bin/env bash
# integration.sh <start|branch|pr|integrate|status|close-integrated> ...
#
# Implements the drain/auto integration-branch model: one integration branch off
# the default branch + one integration PR (integration -> default) that is the
# single human review gate (never auto-merged). Per-issue PRs target the
# integration branch and are merged into it automatically; their issues are NOT
# closed — they move to `waiting-for-human-closure`.
#
#   integration.sh start [goal ...]   start (or reuse) a run; goal is freeform,
#                                      folded into the PR title/body for context.
#
# Run state lives in .maestro/integration.local.md (gitignored).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
maestro_require_cmd gh jq git

STATE="$(maestro_state_dir)/integration.local.md"
repo="$(maestro_repo)"; default="$(maestro_default_branch)"

_field() { [[ -f "$STATE" ]] && sed -n "s/^$1: //p" "$STATE" | head -1 || true; }
_int_open() { local n; n="$(_field pr_number)"; [[ -n "$n" ]] && [[ "$(gh pr view "$n" --json state --jq .state 2>/dev/null)" == "OPEN" ]]; }
_plural() { [[ "$1" -eq 1 ]] && echo "" || echo "s"; }

# The integrated-issues checklist is derived from the durable log (never from
# the PR body itself), so concurrent background workers integrating at nearly
# the same time can't clobber each other's entries — the worst case is a body
# that's briefly one entry behind, self-healed on the very next integrate call.
_int_checklist() {
  local intpr="$1" log; log="$(maestro_state_dir)/log.jsonl"
  [[ -f "$log" ]] || return 0
  jq -s -r --arg intpr "$intpr" '
    map(select(.event == "integration-merge" and ((.intpr // "") == $intpr)))
    | sort_by(.ts)
    | map("- [x] #" + .issue + " " + (.title // "") + " (PR #" + .pr + ")")
    | .[]
  ' "$log" 2>/dev/null || true
}

# _int_render <pr#> <branch> — recompute the title + body from the goal (state)
# and the checklist (log) and write them in one shot. Idempotent: safe to call
# from `start` and after every `integrate`.
_int_render() {
  local intpr="$1" branch="$2" goal login checklist count title body
  goal="$(_field goal)"
  login="$(maestro_assignee_login)"
  checklist="$(_int_checklist "$intpr")"
  count=0; [[ -n "$checklist" ]] && count="$(printf '%s\n' "$checklist" | grep -c '^- \[x\]')"

  if [[ -n "$goal" ]]; then title="Integration (@${login}): ${goal}"
  else title="Integration (@${login}): ready queue"; fi
  [[ "$count" -gt 0 ]] && title="${title} — ${count} issue$(_plural "$count") integrated"
  title="$(printf '%s' "$title" | cut -c1-120)"

  body="$(maestro_disclaimer)
Integration PR for a maestro drain/auto run$( [[ -n "$goal" ]] && printf ' toward: **%s**' "$goal" ). Per-issue PRs merge into \`${branch}\`; **this** PR is your single review gate to \`${default}\` — it is never auto-merged.

## Integrated issues
$( [[ -n "$checklist" ]] && printf '%s\n' "$checklist" || echo '_none yet_' )"

  gh pr edit "$intpr" --title "$title" --body "$body" >/dev/null 2>&1 || true
}

cmd="${1:-status}"; shift || true
case "$cmd" in
  start)
    if [[ -f "$STATE" ]] && _int_open; then
      _field branch; exit 0   # reuse the active run
    fi
    goal="$*"
    stamp="$(date +%Y%m%d-%H%M%S)"
    branch="${MAESTRO_INTEGRATION_PREFIX}${stamp}"
    git fetch origin "$default" --quiet 2>/dev/null || true
    # Seed the integration branch with an empty commit (via a throwaway worktree)
    # so the integration PR has a diff and can be opened immediately. All git
    # chatter goes to stderr; only the branch name is printed on stdout.
    tmpwt="$(mktemp -d)"
    if git worktree add -B "$branch" "$tmpwt" "origin/${default}" >&2 2>/dev/null \
       || git worktree add -B "$branch" "$tmpwt" "$default" >&2 2>/dev/null; then
      git -C "$tmpwt" -c commit.gpgsign=false commit --allow-empty -q -m "maestro: start integration run ${stamp}" >&2 2>/dev/null || true
      git -C "$tmpwt" push -u origin "$branch" >&2 2>/dev/null
      git worktree remove "$tmpwt" --force >/dev/null 2>&1 || true
    else
      rm -rf "$tmpwt"; maestro_die "could not create the integration branch ${branch}"
    fi
    login="$(maestro_assignee_login)"
    if [[ -n "$goal" ]]; then title="Integration (@${login}): ${goal}"
    else title="Integration (@${login}): ready queue"; fi
    title="$(printf '%s' "$title" | cut -c1-120)"
    body="$(maestro_disclaimer)
Integration PR for a maestro drain/auto run$( [[ -n "$goal" ]] && printf ' toward: **%s**' "$goal" ). Per-issue PRs merge into \`${branch}\`; **this** PR is your single review gate to \`${default}\` — it is never auto-merged.

## Integrated issues
_none yet_"
    url="$(gh pr create --title "$title" --body "$body" --head "$branch" --base "$default" 2>&1 | grep -oE 'https://github.com/[^ ]+/pull/[0-9]+' | head -1)"
    [[ -n "$url" ]] || maestro_die "could not open the integration PR"
    num="${url##*/}"
    gh pr edit "$num" --add-label "$MAESTRO_LABEL_INTEGRATION" >/dev/null 2>&1 || true
    gh pr edit "$num" --add-assignee "$MAESTRO_ASSIGNEE" >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$STATE")"
    {
      echo "---"
      echo "branch: ${branch}"
      echo "pr_number: ${num}"
      echo "pr_url: ${url}"
      echo "default_base: ${default}"
      echo "goal: $(printf '%s' "$goal" | tr '\n' ' ')"
      echo "---"
    } > "$STATE"
    maestro_log integration-start branch="$branch" pr="$num"
    maestro_warn "integration run started: ${url}"
    printf '%s\n' "$branch"
    ;;

  branch) _field branch ;;
  pr)     _field pr_number ;;

  integrate)
    # integrate <issue> <per-issue-pr-number>  — merge the per-issue PR into the
    # integration branch, relabel the issue, and log progress on the integration PR.
    issue="${1:?usage: integration.sh integrate <issue> <pr>}"; pr="${2:?pr required}"
    intpr="$(_field pr_number)"
    branch="$(_field branch)"
    title="$(gh issue view "$issue" --json title --jq .title 2>/dev/null || echo "#$issue")"
    if gh pr merge "$pr" --squash --auto >/dev/null 2>&1 || gh pr merge "$pr" --squash >/dev/null 2>&1; then
      gh issue edit "$issue" \
        --add-label "$MAESTRO_LABEL_WAITING_CLOSURE" \
        --remove-label "$MAESTRO_LABEL_IN_PROGRESS" \
        --remove-label "$MAESTRO_LABEL_READY_AGENT" >/dev/null 2>&1 || true
      gh issue comment "$issue" --body "$(maestro_disclaimer)
Implemented and merged into the integration branch via PR #${pr}. Awaiting human closure when the integration PR (#${intpr}) merges to \`${default}\`." >/dev/null 2>&1 || true
      if [[ -n "$intpr" ]]; then
        gh pr comment "$intpr" --body "$(maestro_disclaimer)
✅ Integrated #${issue} (${title}) via PR #${pr}." >/dev/null 2>&1 || true
        maestro_log integration-merge issue="$issue" pr="$pr" intpr="$intpr" title="$title"
        _int_render "$intpr" "$branch"
      else
        maestro_log integration-merge issue="$issue" pr="$pr" title="$title"
      fi
      echo "integrated #${issue} (PR #${pr})"
    else
      gh issue edit "$issue" --add-label "$MAESTRO_LABEL_HITL" --remove-label "$MAESTRO_LABEL_IN_PROGRESS" >/dev/null 2>&1 || true
      gh pr comment "$pr" --body "$(maestro_disclaimer)
Could not auto-merge into the integration branch (likely a conflict). Flagged \`${MAESTRO_LABEL_HITL}\` for a human." >/dev/null 2>&1 || true
      maestro_die "merge of PR #${pr} for issue #${issue} failed — flagged for a human"
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
    [[ -n "$intpr" ]] || maestro_die "no integration run state found"
    st="$(gh pr view "$intpr" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
    if [[ "$st" != "MERGED" && "${1:-}" != "--force" ]]; then
      maestro_die "integration PR #${intpr} is ${st}, not MERGED — merge it first (or pass --force)"
    fi
    gh issue list --label "$MAESTRO_LABEL_WAITING_CLOSURE" --state open --json number --jq '.[].number' 2>/dev/null \
    | while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        gh issue close "$n" --reason completed >/dev/null 2>&1 \
          && gh issue edit "$n" --remove-label "$MAESTRO_LABEL_WAITING_CLOSURE" >/dev/null 2>&1 \
          && echo "closed #$n"
      done
    rm -f "$STATE"
    maestro_log integration-closed pr="$intpr"
    echo "integration run closed."
    ;;

  *) maestro_die "usage: integration.sh <start|branch|pr|integrate|status|close-integrated> ..." ;;
esac
