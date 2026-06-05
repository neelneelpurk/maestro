---
name: implement-issue
description: Implement exactly one ready GitHub issue end-to-end, strictly test-first — worktree, TDD, quality gate, one PR onto the given base branch — recording the plan and changes on the issue, then stop. Used by ship (base = default branch) and drain/auto (base = the integration branch); run once per issue across parallel workers.
---

# Implement Issue

Take ONE GitHub issue to an open pull request, **strictly test-first**, then stop. You never merge and never touch another issue. You also inherit `CLAUDE.md` and `.claude/rules/sdlc.md` (including `.claude/rules/learnings.md`) — obey them.

## Inputs
- **issue** — the issue number (in your task).
- **base** — the branch your PR targets: the **default branch** (ship; awaits review) or the **integration branch** (drain/auto; the per-issue PR is merged into it automatically). Default: the default branch.

## Locate the scripts (before changing directories)
```
cd "$(git rev-parse --show-toplevel)"
source .sdlc/config.sh 2>/dev/null || true
S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"
```
If `$S` is missing, STOP and ask the user to run `/sdlc:init`.

## Procedure

1. **Read it.** `gh issue view <n> --json title,body,labels,state,comments`. Note the acceptance criteria, any prior plan comments, and "Out of scope".
2. **Re-verify it's workable** (queues can lag): state OPEN; labelled `ready-for-agent` or `auto`; and `bash "$S/blocked-by.sh" <n>` prints nothing. If not, STOP and report — do not implement.
3. **Shared brief.** Read `CONTEXT.md`, `docs/adr/`, and the project's `CLAUDE.md`/rules. Use that vocabulary; respect those decisions and recorded learnings.
4. **Worktree off the base.**
   ```
   WT=$(bash "$S/make-worktree.sh" <n> --base <base>)
   cd "$WT"
   gh issue edit <n> --add-label in-progress
   ```
5. **Post your plan + decomposition to the issue** (so the work is reviewable as it happens):
   ```
   bash "$S/issue-note.sh" <n> --body-file plan.md
   ```
   `plan.md` = "## Implementation plan": the approach, the modules you'll touch, the **test plan** (which behaviours you'll drive out test-first), and a **decomposition checklist** that breaks the task into small, ordered steps:
   ```
   - [ ] step 1
   - [ ] step 2
   ```
6. **Implement strictly test-first** ([TDD.md](TDD.md)): red → green → refactor, one step at a time, until the acceptance criteria are met. Match the codebase's existing style, naming, and structure; keep it a thin vertical slice; follow `.claude/rules/sdlc.md`.
   **Keep the issue as a review log as you go** — post a short `issue-note.sh` comment when you:
   - finish a decomposition step (tick it: `- [x] step 1`);
   - make a **critical or hard-to-reverse decision** — write an ADR under `docs/adr/` and link it on the issue;
   - **learn something** from a correction or surprise — persist it (`bash "$S/learn-note.sh" "<rule>"`) and note it;
   - discover the task **breaks into more parts** — add the new steps to the checklist.
7. **Record the changes on the issue:**
   ```
   bash "$S/issue-note.sh" <n> --body-file changes.md
   ```
   `changes.md` = "## Changes": what you changed, any ADRs/learnings, and how each acceptance criterion is satisfied (this also becomes the PR summary; mirror the PR template).
8. **Open the PR** (it runs the quality gate first — a red gate means no PR):
   ```
   bash "$S/open-pr.sh" <n> --base <base> --body-file changes.md
   ```
   - base = default branch → PR with `Closes #<n>`, issue relabelled `in-review`.
   - base = integration branch → per-issue PR merged into the integration branch automatically; issue relabelled `waiting-for-human-closure` (not closed).
9. **Stop.** Report the issue number, the PR URL, and a one-line summary. Do not merge; do not pick up another issue.

## Constraints
- One issue only; never merge; never push the default or integration branch directly.
- No production code without a failing test first (TDD.md).
- All work happens inside the worktree.
