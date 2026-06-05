# Test-Driven Development (strict)

All implementation in this pipeline follows TDD. No production code is written
without a failing test that demands it.

## The loop — red → green → refactor

1. **Red.** Write the smallest test that expresses the next bit of required
   behaviour from the acceptance criteria. Run it; watch it **fail for the right
   reason** (asserting the behaviour, not a typo/import error).
2. **Green.** Write the minimum production code to make that test pass. Nothing
   more. Run the test; watch it pass.
3. **Refactor.** With tests green, clean up names, duplication, and structure —
   production *and* test code. Re-run; stay green.
4. Repeat for the next slice of behaviour until the acceptance criteria are met.

## What makes a good test

- **Test external behaviour, not implementation details.** Assert what a caller
  observes (return values, effects, errors), never private internals — so tests
  survive refactors.
- Test at the **highest stable seam** that still gives fast feedback; prefer an
  existing seam to a new one.
- One reason to fail per test. Clear arrange / act / assert. Deterministic — no
  reliance on time, network, or order unless that is the behaviour under test.
- Cover the error and edge cases named in the issue, not just the happy path.
- Match the project's existing test style and framework; look at neighbouring
  tests first.

## Discipline

- If you catch yourself writing production code with no failing test, stop and
  write the test first.
- Keep each commit green. The quality gate (`quality-gate.sh`) runs the suite
  before any PR — a red gate means no PR.
- Don't delete or weaken a test to go green; fix the code (or, if the test was
  wrong, fix the test for the right reason and say so).
