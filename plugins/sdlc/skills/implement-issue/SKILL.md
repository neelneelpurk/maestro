---
name: implement-issue
description: Implement exactly one ready GitHub issue end-to-end — worktree, TDD, quality gate, one PR onto the given base branch — then stop. Used by ship (base = default branch) and by drain/auto (base = the integration branch); run once per issue across parallel workers.
---

# Implement Issue

Take ONE GitHub issue to an open pull request, then stop. You never merge, and you never touch another issue. Most conventions are also enforced by `.claude/rules/sdlc.md`, which you inherit automatically — follow them.

## Inputs

- **issue** — the issue number (in your task).
- **base** — the branch your PR targets:
  - `ship` gives you the **default branch** (supervised; PR awaits human review).
  - `drain`/`auto` give you the **integration branch** (the per-issue PR is merged into it automatically).
  If no base is stated, use the default branch.

## Locate the scripts (before changing directories)
```
cd "$(git rev-parse --show-toplevel)"
source .sdlc/config.sh 2>/dev/null || true
S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"
```
If `$S` is missing, STOP and ask the user to run `/sdlc:init`.

## Procedure

1. **Read it.** `gh issue view <n> --json title,body,labels,state,comments`. Read the body and any Agent Brief comment; note the acceptance criteria and "Out of scope".
2. **Re-verify it's workable** (queues can lag): state OPEN; labelled `ready-for-agent` or `auto`; and `bash "$S/blocked-by.sh" <n>` prints nothing. If not, STOP and report — do not implement.
3. **Shared brief.** Read `CONTEXT.md` and `docs/adr/`; use that vocabulary and respect those decisions.
4. **Worktree off the base.**
   ```
   WT=$(bash "$S/make-worktree.sh" <n> --base <base>)
   cd "$WT"
   gh issue edit <n> --add-label in-progress
   ```
5. **Implement test-first** with the `tdd` skill, satisfying the acceptance criteria. Thin vertical slice only.
6. **Open the PR** (it runs the quality gate first; a red gate means no PR):
   ```
   bash "$S/open-pr.sh" <n> --base <base> --body-file <short-summary.md>
   ```
   - base = default branch → opens a PR with `Closes #<n>` and relabels the issue `in-review`.
   - base = integration branch → opens the per-issue PR, which is merged into the integration branch automatically, and relabels the issue `waiting-for-human-closure` (the issue is **not** closed).
7. **Stop.** Report the issue number, the PR URL, and a one-line summary. Do not merge; do not pick up another issue.

## Constraints
- One issue only; never merge; never push the default branch or the integration branch directly.
- All work happens inside the worktree.
