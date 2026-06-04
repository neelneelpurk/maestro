#!/usr/bin/env bash
# lib.sh — shared helpers for the ai-sdlc scripts.
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
# Configuration (override via environment or .sdlc/config.sh in the target repo)
# ---------------------------------------------------------------------------

# Absolute path to this scripts dir, resolved independently of the current
# working directory. Critical because scripts are invoked from inside per-issue
# worktrees (a different cwd than where the scripts live).
SDLC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where per-repo state lives (logs, loop state, config).
: "${SDLC_DIR:=.sdlc}"

# Load per-repo overrides if present. config.sh may set any SDLC_* variable or
# any of the label names below. Written by `/sdlc:init`. Prefer a config.sh
# sitting next to the scripts (…/.sdlc/config.sh once installed) so it resolves
# correctly even when cwd is a worktree; fall back to a cwd-relative one.
for _sdlc_cfg in "${SDLC_LIB_DIR}/../config.sh" "${SDLC_DIR}/config.sh"; do
  if [[ -f "$_sdlc_cfg" ]]; then
    # shellcheck disable=SC1090
    source "$_sdlc_cfg"
    break
  fi
done
unset _sdlc_cfg

# Triage label vocabulary (canonical aihero roles). Override in config.sh if the
# repo already uses different strings.
: "${SDLC_LABEL_READY_AGENT:=ready-for-agent}"   # fully specified, AFK-ready
: "${SDLC_LABEL_READY_HUMAN:=ready-for-human}"    # needs a human
: "${SDLC_LABEL_NEEDS_TRIAGE:=needs-triage}"
: "${SDLC_LABEL_NEEDS_INFO:=needs-info}"
: "${SDLC_LABEL_WONTFIX:=wontfix}"
: "${SDLC_LABEL_BUG:=bug}"
: "${SDLC_LABEL_ENHANCEMENT:=enhancement}"

# Pipeline labels added by this plugin (see docs/GLOSSARY.md for the state machine).
: "${SDLC_LABEL_AUTO:=auto}"                # autonomous lane; skips the ready-for-agent gate
: "${SDLC_LABEL_HITL:=hitl}"                # needs a human; never auto-picked
: "${SDLC_LABEL_PRD:=prd}"                  # a PRD / epic parent issue
: "${SDLC_LABEL_ROADMAP:=roadmap}"          # a roadmap parent issue
: "${SDLC_LABEL_TECH_DEBT:=tech-debt}"      # a tech-debt item
: "${SDLC_LABEL_IN_PROGRESS:=in-progress}"  # a worker is implementing it
: "${SDLC_LABEL_IN_REVIEW:=in-review}"      # ship: PR to the default branch, awaiting human review
: "${SDLC_LABEL_WAITING_CLOSURE:=waiting-for-human-closure}" # drain/auto: PR merged into the integration branch
: "${SDLC_LABEL_BLOCKED:=blocked}"          # board marker: has open dependencies
: "${SDLC_LABEL_INTEGRATION:=integration}"  # the integration -> default-branch PR
# Retained for back-compat with existing issues (no longer a pick requirement).
: "${SDLC_LABEL_AFK:=afk}"

# Behaviour.
: "${SDLC_MAX_PARALLEL:=3}"                          # default fan-out concurrency
: "${SDLC_WORKTREE_DIR:=../ai-sdlc-worktrees}"       # where per-issue worktrees go
: "${SDLC_BRANCH_PREFIX:=sdlc/issue-}"               # issue branch name prefix
: "${SDLC_INTEGRATION_PREFIX:=sdlc/integration-}"    # integration branch name prefix
: "${SDLC_ASSIGNEE:=@me}"                            # drain works issues assigned to this user

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

sdlc_warn() { printf 'sdlc: %s\n' "$*" >&2; }
sdlc_die()  { printf 'sdlc: error: %s\n' "$*" >&2; exit 1; }

# require_cmd cmd... — fail if any command is missing.
sdlc_require_cmd() {
  local missing=0 c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { sdlc_warn "required command not found: $c"; missing=1; }
  done
  [[ $missing -eq 0 ]] || sdlc_die "install the missing command(s) above and retry"
}

# ---------------------------------------------------------------------------
# Repo / git helpers
# ---------------------------------------------------------------------------

# sdlc_repo — print the GitHub repo as owner/name. Cached per process.
sdlc_repo() {
  if [[ -z "${_SDLC_REPO:-}" ]]; then
    _SDLC_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
    [[ -n "$_SDLC_REPO" ]] || sdlc_die "could not determine the GitHub repo (run inside a repo with a GitHub remote, gh authenticated)"
  fi
  printf '%s\n' "$_SDLC_REPO"
}

# sdlc_main_root — absolute path to the MAIN working tree, even when called from
# inside a linked worktree (so shared state under .sdlc/ resolves consistently).
sdlc_main_root() {
  if [[ -z "${_SDLC_MAIN_ROOT:-}" ]]; then
    local cdir
    cdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$cdir" ]]; then
      _SDLC_MAIN_ROOT="$(cd "$(dirname "$cdir")" && pwd)"
    else
      _SDLC_MAIN_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
  fi
  printf '%s\n' "$_SDLC_MAIN_ROOT"
}

# sdlc_state_dir — the .sdlc dir in the main working tree (shared across worktrees).
sdlc_state_dir() { printf '%s/%s\n' "$(sdlc_main_root)" "$SDLC_DIR"; }

# sdlc_default_branch — print the repo's default branch (e.g. main).
sdlc_default_branch() {
  if [[ -z "${_SDLC_DEFAULT_BRANCH:-}" ]]; then
    _SDLC_DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || true)"
    [[ -n "$_SDLC_DEFAULT_BRANCH" ]] || _SDLC_DEFAULT_BRANCH="main"
  fi
  printf '%s\n' "$_SDLC_DEFAULT_BRANCH"
}

# sdlc_issue_id <issue-number> — print the issue's NUMERIC database id (.id),
# which the sub-issue and dependency REST endpoints require (NOT the #number).
sdlc_issue_id() { gh api "repos/$(sdlc_repo)/issues/$1" --jq '.id' 2>/dev/null; }

# sdlc_slug "Some Title" — kebab-case, ascii, max ~50 chars, for branch names.
sdlc_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-50 \
    | sed -E 's/-+$//'
}

# sdlc_branch_for <issue> <slug> — deterministic branch name for an issue.
sdlc_branch_for() { printf '%s%s-%s\n' "$SDLC_BRANCH_PREFIX" "$1" "$2"; }

# ---------------------------------------------------------------------------
# Conventions
# ---------------------------------------------------------------------------

# The disclaimer that must lead every issue/PR comment the pipeline posts
# (mirrors the aihero `triage` convention).
sdlc_disclaimer() { printf '> *This was generated by an AI agent in the ai-sdlc pipeline.*\n'; }

# sdlc_version — print the running plugin's version (e.g. 0.1.0), read from
# plugins/sdlc/.claude-plugin/plugin.json via jq. Degrades to "unknown" if the
# manifest or jq cannot be found. Cached per process.
#
# The scripts run from two possible homes — the canonical source tree
# (plugins/sdlc/scripts/, where the manifest is a sibling at
# ../.claude-plugin/) and the per-repo install (.sdlc/scripts/, where it is
# not) — so we probe a few candidate locations and fall back gracefully.
sdlc_version() {
  if [[ -z "${_SDLC_VERSION:-}" ]]; then
    _SDLC_VERSION="unknown"
    if command -v jq >/dev/null 2>&1; then
      local manifest toplevel candidates=()
      # 1) Manifest next to the source scripts (plugins/sdlc/scripts/../.claude-plugin/).
      candidates+=("${SDLC_LIB_DIR}/../.claude-plugin/plugin.json")
      # 2) Manifest at its canonical path under the current repo's toplevel
      #    (covers the installed .sdlc/scripts/ copy, run from inside the repo).
      toplevel="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      [[ -n "$toplevel" ]] && candidates+=("${toplevel}/plugins/sdlc/.claude-plugin/plugin.json")
      for manifest in "${candidates[@]}"; do
        if [[ -f "$manifest" ]]; then
          local v
          v="$(jq -r '.version // empty' "$manifest" 2>/dev/null || true)"
          if [[ -n "$v" ]]; then _SDLC_VERSION="$v"; break; fi
        fi
      done
    fi
  fi
  printf '%s\n' "$_SDLC_VERSION"
}

# sdlc_log <event> [key=value ...] — append a JSON line to .sdlc/log.jsonl.
# Timestamps via `date` are fine here (these scripts are not workflow-replayed).
sdlc_log() {
  local event="$1"; shift || true
  local dir; dir="$(sdlc_state_dir 2>/dev/null || echo "$SDLC_DIR")"
  mkdir -p "$dir"
  local kv_json="{}" k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    kv_json="$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<<"$kv_json")"
  done
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg event "$event" --argjson data "$kv_json" \
    '{ts: $ts, event: $event} + $data' >>"${dir}/log.jsonl"
}
