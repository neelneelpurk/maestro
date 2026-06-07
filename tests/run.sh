#!/usr/bin/env bash
# run.sh — run every tests/unit/*_test.sh, aggregate results, exit non-zero on any
# failure. This is the committed test entry point: CI, `make test`, and a repo's
# MAESTRO_TEST_CMD can all call `bash tests/run.sh` and get the same result.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

total=0
failed=0
for f in "$HERE"/unit/*_test.sh; do
  [ -e "$f" ] || continue
  total=$((total + 1))
  echo "── $(basename "$f")"
  if bash "$f"; then :; else failed=$((failed + 1)); fi
  echo
done

if [ "$total" -eq 0 ]; then
  echo "no test files found under $HERE/unit/" >&2
  exit 1
fi
if [ "$failed" -eq 0 ]; then
  echo "✔ all ${total} test file(s) passed"
  exit 0
fi
echo "✗ ${failed}/${total} test file(s) failed"
exit 1
