#!/usr/bin/env bash
# Tests for runs.sh — summarizing a run from a fixture log.jsonl.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$HERE/../lib/assert.sh"

runs="$ROOT/plugins/maestro/scripts/runs.sh"
fixture="$(mktemp)"
cat > "$fixture" <<'EOF'
{"ts":"2026-06-08T09:00:00Z","event":"integration-start","branch":"old","pr":"90","run_id":"R0"}
{"ts":"2026-06-08T09:05:00Z","event":"pr-opened","issue":"5","run_id":"R0"}
{"ts":"2026-06-08T10:00:00Z","event":"integration-start","branch":"maestro/integration-x","pr":"100","run_id":"R1"}
{"ts":"2026-06-08T10:01:00Z","event":"worktree-created","issue":"12","run_id":"R1"}
{"ts":"2026-06-08T10:02:00Z","event":"pr-opened","issue":"12","pr":"101","run_id":"R1"}
{"ts":"2026-06-08T10:03:00Z","event":"integration-merge","issue":"12","pr":"101","run_id":"R1"}
{"ts":"2026-06-08T10:04:00Z","event":"pr-opened","issue":"13","pr":"102","run_id":"R1"}
{"ts":"2026-06-08T10:05:00Z","event":"quality-gate","result":"fail","run_id":"R1"}
{"ts":"2026-06-08T11:00:00Z","event":"init","repo":"x"}
EOF

# new — prints a run id of the expected shape.
assert_matches "$(bash "$runs" new)" '^[0-9]{8}-[0-9]{6}-[0-9]+$' "runs new prints a run id"

# list — both runs present, newest (R1) first, integrated counted.
out="$(bash "$runs" list --log "$fixture")"
assert_contains "$out" "R1" "list shows R1"
assert_contains "$out" "R0" "list shows R0"
assert_contains "$(printf '%s\n' "$out" | head -1)" "R1" "list is newest-first"
assert_contains "$out" "integrated=1" "list counts integrated"

# show — defaults to the latest run (R1) and breaks it down.
sh="$(bash "$runs" show --log "$fixture")"
assert_contains "$sh" "run R1" "show defaults to the latest run"
assert_contains "$sh" "branch=maestro/integration-x" "show reports the integration branch"
assert_contains "$sh" "pr-opened: 2" "show counts PRs opened"
assert_contains "$sh" "integrated: 1" "show counts integrated"
assert_contains "$sh" "gate-fail: 1" "show counts gate failures"
assert_contains "$sh" "#12" "show lists issue 12"
assert_contains "$sh" "#13" "show lists issue 13"

# show — honors an explicit run id.
sh0="$(bash "$runs" show --log "$fixture" R0)"
assert_contains "$sh0" "run R0" "show honors an explicit run id"
assert_contains "$sh0" "branch=old" "show R0 reports its branch"

# graceful when the log is missing.
assert_contains "$(bash "$runs" list --log /nonexistent/nope.jsonl)" "no runs yet" "list handles a missing log"

rm -f "$fixture"
t_end
