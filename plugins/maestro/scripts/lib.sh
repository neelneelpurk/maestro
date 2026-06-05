#!/usr/bin/env bash
# lib.sh — shared helpers for the maestro scripts.
#
# Source this from every other script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
#
# It is intentionally side-effect-free on source (defines vars + functions only),
# so it is safe to source from hooks, skills, and other scripts. Scripts that are
# entry points should set `set -euo pipefail` themselves.
#
# Everything here assumes the current working directory is inside the *target*
# repository (the repo whose issues/PRs we are driving) — `gh` and `git` pick the
# repo up from the cwd, so a per-issue worktree transparently targets the same repo.

# ---------------------------------------------------------------------------
# Configuration (override via environment or .maestro/config.sh in the target repo)
# ---------------------------------------------------------------------------

# Absolute path to this scripts dir, resolved independently of the current
# working directory. Critical because scripts are invoked from inside per-issue
# worktrees (a different cwd than where the scripts live).
MAESTRO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where per-repo state lives (logs, loop state, config).
: "${MAESTRO_DIR:=.maestro}"

# Load per-repo overrides if present. config.sh may set any MAESTRO_* variable or
# any of the label names below. Written by `/maestro:init`. Prefer a config.sh
# sitting next to the scripts (…/.maestro/config.sh once installed) so it resolves
# correctly even when cwd is a worktree; fall back to a cwd-relative one.
for _maestro_cfg in "${MAESTRO_LIB_DIR}/../config.sh" "${MAESTRO_DIR}/config.sh"; do
  if [[ -f "$_maestro_cfg" ]]; then
    # shellcheck disable=SC1090
    source "$_maestro_cfg"
    break
  fi
done
unset _maestro_cfg

# Triage label vocabulary. Override in config.sh if the repo already uses
# different strings.
: "${MAESTRO_LABEL_READY_AGENT:=maestro:ready-for-agent}"   # fully specified, AFK-ready
: "${MAESTRO_LABEL_READY_HUMAN:=maestro:ready-for-human}"    # needs a human
: "${MAESTRO_LABEL_NEEDS_TRIAGE:=maestro:needs-triage}"
: "${MAESTRO_LABEL_NEEDS_INFO:=maestro:needs-info}"
: "${MAESTRO_LABEL_WONTFIX:=maestro:wontfix}"
: "${MAESTRO_LABEL_BUG:=maestro:bug}"
: "${MAESTRO_LABEL_ENHANCEMENT:=maestro:enhancement}"

# Pipeline labels added by this plugin (see docs/GLOSSARY.md for the state machine).
: "${MAESTRO_LABEL_AUTO:=maestro:auto}"                # autonomous lane; skips the ready-for-agent gate
: "${MAESTRO_LABEL_HITL:=maestro:hitl}"                # needs a human; never auto-picked
: "${MAESTRO_LABEL_PRD:=maestro:prd}"                  # a PRD / epic parent issue
: "${MAESTRO_LABEL_ROADMAP:=maestro:roadmap}"          # a roadmap parent issue
: "${MAESTRO_LABEL_TECH_DEBT:=maestro:tech-debt}"      # a tech-debt item
: "${MAESTRO_LABEL_IN_PROGRESS:=maestro:in-progress}"  # a worker is implementing it
: "${MAESTRO_LABEL_IN_REVIEW:=maestro:in-review}"      # ship: PR to the default branch, awaiting human review
: "${MAESTRO_LABEL_WAITING_CLOSURE:=maestro:waiting-for-human-closure}" # drain/auto: PR merged into the integration branch
: "${MAESTRO_LABEL_BLOCKED:=maestro:blocked}"          # board marker: has open dependencies
: "${MAESTRO_LABEL_INTEGRATION:=maestro:integration}"  # the integration -> default-branch PR
# Retained for back-compat with existing issues (no longer a pick requirement).
: "${MAESTRO_LABEL_AFK:=maestro:afk}"

# Behaviour.
: "${MAESTRO_MAX_PARALLEL:=3}"                          # default fan-out concurrency
: "${MAESTRO_WORKTREE_DIR:=../maestro-worktrees}"       # where per-issue worktrees go
: "${MAESTRO_BRANCH_PREFIX:=maestro/issue-}"               # issue branch name prefix
: "${MAESTRO_INTEGRATION_PREFIX:=maestro/integration-}"    # integration branch name prefix
: "${MAESTRO_ASSIGNEE:=@me}"                            # drain works issues assigned to this user

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

maestro_warn() { printf 'maestro: %s\n' "$*" >&2; }
maestro_die()  { printf 'maestro: error: %s\n' "$*" >&2; exit 1; }

# require_cmd cmd... — fail if any command is missing.
maestro_require_cmd() {
  local missing=0 c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { maestro_warn "required command not found: $c"; missing=1; }
  done
  [[ $missing -eq 0 ]] || maestro_die "install the missing command(s) above and retry"
}

# ---------------------------------------------------------------------------
# Repo / git helpers
# ---------------------------------------------------------------------------

# maestro_repo — print the GitHub repo as owner/name. Cached per process.
maestro_repo() {
  if [[ -z "${_MAESTRO_REPO:-}" ]]; then
    _MAESTRO_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
    [[ -n "$_MAESTRO_REPO" ]] || maestro_die "could not determine the GitHub repo (run inside a repo with a GitHub remote, gh authenticated)"
  fi
  printf '%s\n' "$_MAESTRO_REPO"
}

# maestro_main_root — absolute path to the MAIN working tree, even when called from
# inside a linked worktree (so shared state under .maestro/ resolves consistently).
maestro_main_root() {
  if [[ -z "${_MAESTRO_MAIN_ROOT:-}" ]]; then
    local cdir
    cdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$cdir" ]]; then
      _MAESTRO_MAIN_ROOT="$(cd "$(dirname "$cdir")" && pwd)"
    else
      _MAESTRO_MAIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
  fi
  printf '%s\n' "$_MAESTRO_MAIN_ROOT"
}

# maestro_state_dir — the .maestro dir in the main working tree (shared across worktrees).
maestro_state_dir() { printf '%s/%s\n' "$(maestro_main_root)" "$MAESTRO_DIR"; }

# maestro_default_branch — print the repo's default branch (e.g. main).
maestro_default_branch() {
  if [[ -z "${_MAESTRO_DEFAULT_BRANCH:-}" ]]; then
    _MAESTRO_DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || true)"
    [[ -n "$_MAESTRO_DEFAULT_BRANCH" ]] || _MAESTRO_DEFAULT_BRANCH="main"
  fi
  printf '%s\n' "$_MAESTRO_DEFAULT_BRANCH"
}

# maestro_issue_id <issue-number> — print the issue's NUMERIC database id (.id),
# which the sub-issue and dependency REST endpoints require (NOT the #number).
maestro_issue_id() { gh api "repos/$(maestro_repo)/issues/$1" --jq '.id' 2>/dev/null; }

# maestro_slug "Some Title" — kebab-case, ascii, max ~50 chars, for branch names.
maestro_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-50 \
    | sed -E 's/-+$//'
}

# maestro_branch_for <issue> <slug> — deterministic branch name for an issue.
maestro_branch_for() { printf '%s%s-%s\n' "$MAESTRO_BRANCH_PREFIX" "$1" "$2"; }

# ---------------------------------------------------------------------------
# Conventions
# ---------------------------------------------------------------------------

# The disclaimer that must lead every issue/PR comment the pipeline posts.
maestro_disclaimer() { printf '> *This was generated by an AI agent in the maestro pipeline.*\n'; }

# maestro_version — print the running plugin's version (e.g. 0.1.0), read from
# plugins/maestro/.claude-plugin/plugin.json via jq. Degrades to "unknown" if the
# manifest or jq cannot be found. Cached per process.
#
# The scripts run from two possible homes — the canonical source tree
# (plugins/maestro/scripts/, where the manifest is a sibling at
# ../.claude-plugin/) and the per-repo install (.maestro/scripts/, where it is
# not) — so we probe a few candidate locations and fall back gracefully.
maestro_version() {
  if [[ -z "${_MAESTRO_VERSION:-}" ]]; then
    _MAESTRO_VERSION="unknown"
    if command -v jq >/dev/null 2>&1; then
      local manifest toplevel candidates=()
      # 1) Manifest next to the source scripts (plugins/maestro/scripts/../.claude-plugin/).
      candidates+=("${MAESTRO_LIB_DIR}/../.claude-plugin/plugin.json")
      # 2) Manifest at its canonical path under the current repo's toplevel
      #    (covers the installed .maestro/scripts/ copy, run from inside the repo).
      toplevel="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      [[ -n "$toplevel" ]] && candidates+=("${toplevel}/plugins/maestro/.claude-plugin/plugin.json")
      for manifest in "${candidates[@]}"; do
        if [[ -f "$manifest" ]]; then
          local v
          v="$(jq -r '.version // empty' "$manifest" 2>/dev/null || true)"
          if [[ -n "$v" ]]; then _MAESTRO_VERSION="$v"; break; fi
        fi
      done
    fi
  fi
  printf '%s\n' "$_MAESTRO_VERSION"
}

# maestro_log <event> [key=value ...] — append a JSON line to .maestro/log.jsonl.
# Timestamps via `date` are fine here (these scripts are not workflow-replayed).
maestro_log() {
  local event="$1"; shift || true
  local dir; dir="$(maestro_state_dir 2>/dev/null || echo "$MAESTRO_DIR")"
  mkdir -p "$dir"
  local kv_json="{}" k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    kv_json="$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<<"$kv_json")"
  done
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg event "$event" --argjson data "$kv_json" \
    '{ts: $ts, event: $event} + $data' >>"${dir}/log.jsonl"
}
