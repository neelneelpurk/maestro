# ai-sdlc conventions

These rules govern every agent working in this repo — including the parallel
`issue-implementer` workers, which inherit this file automatically inside their
git worktrees. Keep to them.

## Implementation
- Implement exactly **one issue per worktree/branch**. Never edit files for, or comment on, another issue.
- Work **test-first** (use the `tdd` skill). Keep each change a thin vertical slice — exactly what the issue asks; honor its "Out of scope".
- Use the canonical domain vocabulary in `CONTEXT.md`. Respect decisions recorded under `docs/adr/`; do not re-open a settled decision.

## Pull requests
- Run the quality gate before opening any PR (`.sdlc/scripts/quality-gate.sh`). A **red gate means no PR**.
- `/sdlc:ship` (a single issue): open a PR to the **default branch** with `Closes #<n>`.
- `drain` / `auto`: open the per-issue PR against the **integration branch** (never the default branch). It is merged automatically once green.
- Every PR and every issue/PR comment the pipeline posts **starts with the AI disclaimer**.

## Merging & closure
- **Never merge the integration PR or the default branch yourself.** That is the human's single review gate.
- **Never auto-close an issue.** When its work is merged into the integration branch, relabel it `waiting-for-human-closure`; the human closes it when they merge the integration PR.
- The full label state machine is in [docs/GLOSSARY.md](../../docs/GLOSSARY.md).
