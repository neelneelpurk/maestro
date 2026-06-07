#!/usr/bin/env bash
# assert.sh — a tiny, dependency-free test harness for maestro's bash scripts.
#
# Why not bats? maestro is deliberately self-contained ("bash + gh + jq", bash 3.2
# compatible for macOS). A ~60-line pure-bash harness keeps that promise: zero new
# dependencies, runs anywhere bash does. Source it at the top of a
# tests/unit/*_test.sh file, make assertions, and end with `t_end`.
#
#   source "$(dirname "$0")/../lib/assert.sh"
#   assert_eq "a" "a" "a equals a"
#   t_end                       # prints a summary; the file's exit status follows it
#
# Each assertion prints a TAP-ish `ok`/`not ok` line. `t_end` returns non-zero if
# any assertion failed, so a test file's exit code reflects its result and the
# runner (tests/run.sh) can aggregate. bash 3.2 compatible: no mapfile, no
# associative arrays.

_T_COUNT=0
_T_FAIL=0
_T_NAME="$(basename "${0:-tests}")"

_t_ok() { _T_COUNT=$((_T_COUNT + 1)); printf 'ok %d - %s\n' "$_T_COUNT" "$1"; }
_t_no() {
  _T_COUNT=$((_T_COUNT + 1)); _T_FAIL=$((_T_FAIL + 1))
  printf 'not ok %d - %s\n' "$_T_COUNT" "$1"
  [ -n "${2:-}" ] && printf '  # %s\n' "$2"
  return 0
}

# assert_eq <expected> <actual> [desc]
assert_eq() {
  local exp="$1" act="$2" desc="${3:-assert_eq}"
  if [ "$exp" = "$act" ]; then _t_ok "$desc"; else _t_no "$desc" "expected [$exp] got [$act]"; fi
}

# assert_ne <unexpected> <actual> [desc]
assert_ne() {
  local nexp="$1" act="$2" desc="${3:-assert_ne}"
  if [ "$nexp" != "$act" ]; then _t_ok "$desc"; else _t_no "$desc" "did not expect [$act]"; fi
}

# assert_contains <haystack> <needle> [desc]
assert_contains() {
  local hay="$1" needle="$2" desc="${3:-assert_contains}"
  case "$hay" in
    *"$needle"*) _t_ok "$desc" ;;
    *) _t_no "$desc" "[$hay] does not contain [$needle]" ;;
  esac
}

# assert_not_contains <haystack> <needle> [desc]
assert_not_contains() {
  local hay="$1" needle="$2" desc="${3:-assert_not_contains}"
  case "$hay" in
    *"$needle"*) _t_no "$desc" "[$hay] unexpectedly contains [$needle]" ;;
    *) _t_ok "$desc" ;;
  esac
}

# assert_matches <string> <basic-regex> [desc]  — uses grep -E
assert_matches() {
  local str="$1" re="$2" desc="${3:-assert_matches}"
  if printf '%s' "$str" | grep -Eq "$re"; then _t_ok "$desc"; else _t_no "$desc" "[$str] does not match /$re/"; fi
}

# assert_status <expected-exit> <cmd...>  — run cmd (output muted), compare exit code
assert_status() {
  local exp="$1"; shift
  local desc="exit $exp: $*"
  local got=0
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$exp" ]; then _t_ok "$desc"; else _t_no "$desc" "got exit $got"; fi
}

# t_end — print a per-file summary line and return non-zero if anything failed.
t_end() {
  printf '# %s: %d assertion(s), %d failed\n' "$_T_NAME" "$_T_COUNT" "$_T_FAIL"
  [ "$_T_FAIL" -eq 0 ]
}
