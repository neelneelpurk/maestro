#!/usr/bin/env bash
# Tests for the first-run hardening: init must NOT be able to half-seed (every
# critical template must ship), and doctor must run its expanded checks.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$HERE/../lib/assert.sh"

# init.sh now dies on a missing template (fail-loud). Guard that all the
# templates it seeds actually exist, so a correct install never trips that.
templates="$ROOT/plugins/maestro/templates"
for f in maestro.rules.md learnings.md GLOSSARY.md CLAUDE.md AGENTS.md; do
  assert_status 0 test -f "$templates/$f"
done

# doctor.sh: run it where there is no git repo — it must fail (exit 1) and its
# new checks must execute (GitHub API + state-dir writeability appear in output).
doctor="$ROOT/plugins/maestro/scripts/doctor.sh"
tmp="$(mktemp -d)"
out="$( ( cd "$tmp"; bash "$doctor" ) 2>&1 )"; st=$?
assert_eq 1 "$st" "doctor fails when run outside a git repo"
assert_contains "$out" "not inside a git repository" "doctor reports the missing git repo"
assert_contains "$out" "GitHub API" "doctor runs the API-reachability check"
assert_contains "$out" "state dir" "doctor runs the state-dir writeability check"
rm -rf "$tmp"

t_end
