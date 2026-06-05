#!/usr/bin/env bash
# doctor.sh — preflight health check for an maestro setup.
#
# Verifies the environment a Worker needs before driving issues to PRs:
#   • gh installed and authenticated
#   • jq installed
#   • current directory is a git repo with a GitHub remote
#   • the pipeline scripts are installed under .maestro/scripts (run /maestro:init)
#
# Prints a ✔/✘ line per check and a final summary. Exit 0 = all checks passed,
# exit 1 = at least one check failed. Run it from the target repo (or a worktree).
set -uo pipefail   # deliberately no -e: we run every check and tally failures ourselves
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PASS=0
FAIL=0

# pass <message> — record and print a successful check.
pass() { printf '  \xe2\x9c\x94 %s\n' "$1"; PASS=$((PASS + 1)); }
# fail <message> [hint] — record and print a failed check (+ optional remediation hint).
fail() {
  printf '  \xe2\x9c\x98 %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '      \xe2\x86\xb3 %s\n' "$2"
  FAIL=$((FAIL + 1))
}

echo "maestro doctor — checking $(pwd)"
echo

# 1. gh installed -----------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  pass "gh installed ($(gh --version 2>/dev/null | head -1))"
  # 2. gh authenticated (only meaningful if gh exists) ----------------------
  if gh auth status >/dev/null 2>&1; then
    pass "gh authenticated"
  else
    fail "gh not authenticated" "run: gh auth login"
  fi
else
  fail "gh not installed" "install the GitHub CLI: https://cli.github.com/"
  fail "gh not authenticated" "install gh first, then run: gh auth login"
fi

# 3. jq installed -----------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  pass "jq installed ($(jq --version 2>/dev/null))"
else
  fail "jq not installed" "install jq: https://jqlang.github.io/jq/"
fi

# 4. git repo with a GitHub remote ------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  fail "git not installed" "install git, then run inside a GitHub-backed repo"
elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "not inside a git repository" "cd into your project's git repo and re-run"
else
  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "$remote_url" == *github.com* ]]; then
    pass "git repo with a GitHub remote ($remote_url)"
  else
    fail "git repo has no GitHub remote" "add one: git remote add origin git@github.com:OWNER/REPO.git"
  fi
fi

# 5. .maestro/scripts installed ------------------------------------------------
if [[ -d "${MAESTRO_DIR}/scripts" ]]; then
  pass "pipeline scripts installed (${MAESTRO_DIR}/scripts)"
else
  fail "pipeline scripts not installed (${MAESTRO_DIR}/scripts missing)" "run /maestro:init in this repo"
fi

# Summary -------------------------------------------------------------------
echo
total=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf 'Summary: %d/%d checks passed \xe2\x80\x94 ready to ship.\n' "$PASS" "$total"
  maestro_log doctor result=pass passed="$PASS" total="$total" 2>/dev/null || true
  exit 0
else
  printf 'Summary: %d/%d checks passed, %d failed \xe2\x80\x94 fix the \xe2\x9c\x98 items above.\n' "$PASS" "$total" "$FAIL"
  maestro_log doctor result=fail passed="$PASS" failed="$FAIL" total="$total" 2>/dev/null || true
  exit 1
fi
