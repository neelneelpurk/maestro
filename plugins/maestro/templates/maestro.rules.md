# maestro conventions

These rules govern every agent working in this repo — including the parallel
`issue-implementer` workers, which inherit this file automatically inside their
git worktrees. Keep to them.

## Implementation
- Implement exactly **one issue per worktree/branch**. Never edit files for, or comment on, another issue.
- **Strictly test-first (TDD).** No production code without a failing test that demands it: red → green → refactor. Test external behaviour, not implementation details. Keep each change a thin vertical slice — exactly what the issue asks; honor its "Out of scope".
- **Keep the GitHub issue a review log.** Post your implementation plan + a decomposition checklist when you start; as you work, append critical/hard-to-reverse decisions (link any ADR you write under `docs/adr/`), learnings, and ticked steps; post a changes summary at PR time. The issue should read as a clear trail of the work.
- Use the canonical domain vocabulary in `CONTEXT.md`. Respect decisions recorded under `docs/adr/`; do not re-open a settled decision.

## Coding standards
- Match the codebase's existing style, naming, structure, and formatter/linter — read neighbouring code first; don't introduce a new pattern when one exists.
- Prefer clear names and small, deep modules over clever one-liners. No dead code, no commented-out code, no debug prints left behind.
- Handle errors and edge cases explicitly; never silently swallow failures. No hardcoded secrets.
- Keep the quality gate green (`.maestro/scripts/quality-gate.sh`) — lint, types, and tests pass before any PR.

## Learnings
- `.claude/rules/learnings.md` holds corrections the user has taught the agent. **Read and obey it.** When the user corrects you, run `/maestro:learn` to persist the lesson there so it isn't repeated.

## Pull requests
- Run the quality gate before opening any PR (`.maestro/scripts/quality-gate.sh`). A **red gate means no PR**.
- `/maestro:ship` (a single issue): open a PR to the **default branch** with `Closes #<n>`.
- `/maestro:drain` / `/maestro:auto`: open the per-issue PR against the **integration branch** (never the default branch). It is merged automatically once green.
- Every PR and every issue/PR comment the pipeline posts **starts with the AI disclaimer**.

## Merging & closure
- **Never merge the integration PR or the default branch yourself.** That is the human's single review gate.
- **Never auto-close an issue.** When its work is merged into the integration branch, relabel it `agent:waiting-for-human-closure`; the human closes it when they merge the integration PR.
- The full label state machine is in [docs/GLOSSARY.md](../../docs/GLOSSARY.md).
