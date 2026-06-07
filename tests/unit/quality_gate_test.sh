#!/usr/bin/env bash
# Tests for quality-gate.sh — the no-red-PR guard must also refuse a FALSE GREEN:
# when no toolchain is detected and nothing is configured, "nothing ran" must not
# be reported as "passed" (unless explicitly opted into).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$HERE/../lib/assert.sh"

# Make sure no override leaks in from the caller's environment.
unset MAESTRO_INSTALL_CMD MAESTRO_LINT_CMD MAESTRO_TYPECHECK_CMD MAESTRO_TEST_CMD MAESTRO_ALLOW_EMPTY_GATE 2>/dev/null || true

gate="$ROOT/plugins/maestro/scripts/quality-gate.sh"
empty="$(mktemp -d)"   # an empty dir: no package.json/go.mod/Makefile/etc.

# 1. Nothing detected, nothing configured → FAIL (no false green).
( cd "$empty"; bash "$gate" ) >/dev/null 2>&1; st=$?
assert_eq 1 "$st" "empty gate fails instead of reporting a false green"

# 2. Explicit opt-in → pass.
( cd "$empty"; MAESTRO_ALLOW_EMPTY_GATE=1 bash "$gate" ) >/dev/null 2>&1; st=$?
assert_eq 0 "$st" "empty gate passes with MAESTRO_ALLOW_EMPTY_GATE=1"

# 3. A configured step that passes → pass.
( cd "$empty"; MAESTRO_TEST_CMD=true bash "$gate" ) >/dev/null 2>&1; st=$?
assert_eq 0 "$st" "gate passes when a configured step passes"

# 4. A configured step that fails → fail.
( cd "$empty"; MAESTRO_TEST_CMD=false bash "$gate" ) >/dev/null 2>&1; st=$?
assert_eq 1 "$st" "gate fails when a configured step fails"

rm -rf "$empty"
t_end
