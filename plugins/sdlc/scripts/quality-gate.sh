#!/usr/bin/env bash
# quality-gate.sh [--no-install]
#
# Detects the project toolchain in the current directory and runs:
#   install → lint → typecheck → test
# Exit 0 = gate passed (or genuinely nothing to run). Exit 1 = a gate failed.
#
# Detection is overridable per-repo via .sdlc/config.sh (or env):
#   SDLC_INSTALL_CMD, SDLC_LINT_CMD, SDLC_TYPECHECK_CMD, SDLC_TEST_CMD
# Any override set to the empty string SKIPS that step.
#
# Philosophy: run what's detected. A missing tool => skip (note it). A present
# tool that exits non-zero => the gate fails. Used both by the worker skill and
# by the PreToolUse hook that guards `gh pr create`.
set -uo pipefail   # deliberately no -e: we manage failures ourselves
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

do_install=1
[[ "${1:-}" == "--no-install" ]] && do_install=0

have() { command -v "$1" >/dev/null 2>&1; }
pkg_has() { [[ -f package.json ]] && jq -e --arg s "$1" '.scripts[$s] // empty' package.json >/dev/null 2>&1; }

FAILED=()
RAN=0
run_step() {  # run_step <name> <shell-command-string>
  local name="$1" cmd="$2"
  [[ -z "$cmd" ]] && { echo "   ∘ ${name}: skipped" >&2; return 0; }
  RAN=1
  echo "── ${name}: ${cmd}" >&2
  if bash -c "$cmd"; then
    echo "   ✔ ${name}" >&2
  else
    echo "   ✗ ${name} FAILED (exit $?)" >&2
    FAILED+=("$name")
  fi
}

# --- Resolve each step's command: explicit override wins, else auto-detect. ---
install_cmd="" lint_cmd="" typecheck_cmd="" test_cmd=""

if [[ -f package.json ]]; then
  pm=npm
  [[ -f bun.lockb ]]       && pm=bun
  [[ -f yarn.lock ]]       && pm=yarn
  [[ -f pnpm-lock.yaml ]]  && pm=pnpm
  case "$pm" in
    npm)  install_cmd="$([[ -f package-lock.json ]] && echo 'npm ci' || echo 'npm install')" ;;
    pnpm) install_cmd="pnpm install" ;;
    yarn) install_cmd="yarn install" ;;
    bun)  install_cmd="bun install" ;;
  esac
  pkg_has lint      && lint_cmd="$pm run lint"
  if pkg_has typecheck; then typecheck_cmd="$pm run typecheck"
  elif [[ -f tsconfig.json ]] && have npx; then typecheck_cmd="npx --no-install tsc --noEmit"; fi
  pkg_has test && test_cmd="$pm run test"
elif [[ -f go.mod ]]; then
  install_cmd="go mod download"
  lint_cmd="go vet ./..."
  test_cmd="go test ./..."
elif [[ -f Cargo.toml ]]; then
  install_cmd="cargo fetch"
  have cargo-clippy && lint_cmd="cargo clippy --all-targets -- -D warnings"
  test_cmd="cargo test"
elif [[ -f pyproject.toml || -f requirements.txt || -f setup.py ]]; then
  if [[ -f uv.lock ]] && have uv; then install_cmd="uv sync"
  elif [[ -f poetry.lock ]] && have poetry; then install_cmd="poetry install"
  elif [[ -f requirements.txt ]] && have pip; then install_cmd="pip install -r requirements.txt"; fi
  have ruff  && lint_cmd="ruff check ."
  have mypy  && typecheck_cmd="mypy ."
  have pytest && test_cmd="pytest -q"
elif [[ -f Makefile ]]; then
  grep -qE '^test:' Makefile && test_cmd="make test"
  grep -qE '^lint:' Makefile && lint_cmd="make lint"
fi

# Apply overrides (set, including empty-to-skip).
[[ -n "${SDLC_INSTALL_CMD+x}" ]]   && install_cmd="$SDLC_INSTALL_CMD"
[[ -n "${SDLC_LINT_CMD+x}" ]]      && lint_cmd="$SDLC_LINT_CMD"
[[ -n "${SDLC_TYPECHECK_CMD+x}" ]] && typecheck_cmd="$SDLC_TYPECHECK_CMD"
[[ -n "${SDLC_TEST_CMD+x}" ]]      && test_cmd="$SDLC_TEST_CMD"

echo "Quality gate in $(pwd)" >&2
[[ $do_install -eq 1 ]] && run_step install "$install_cmd"
# If install failed, the rest is meaningless.
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "✗ quality gate FAILED at install" >&2
  exit 1
fi
run_step lint      "$lint_cmd"
run_step typecheck "$typecheck_cmd"
run_step test      "$test_cmd"

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "✗ quality gate FAILED: ${FAILED[*]}" >&2
  sdlc_log quality-gate result=fail steps="${FAILED[*]}" 2>/dev/null || true
  exit 1
fi
if [[ $RAN -eq 0 ]]; then
  echo "⚠ quality gate: no toolchain detected and no overrides set — nothing ran." >&2
  echo "  Set SDLC_TEST_CMD / SDLC_LINT_CMD in .sdlc/config.sh to enforce checks." >&2
fi
echo "✔ quality gate passed" >&2
sdlc_log quality-gate result=pass 2>/dev/null || true
exit 0
