---
name: implement-issue
description: Implement exactly one ready-for-agent GitHub issue end-to-end — worktree, TDD, quality gate, PR — then stop for human review. Use when implementing a single SDLC issue by number; the ship-ready-issues orchestrator runs this once per issue across parallel subagents.
---

# Implement Issue

Take ONE GitHub issue from `ready-for-agent` to an open pull request that closes it, then stop. You never merge, and you never touch any other issue.

## Input

The issue number is given to you (as an argument, or in your task description). If you have no issue number, stop and say so.

## Locate the scripts (do this first, before changing directories)

The deterministic pipeline scripts are installed at an **absolute** path recorded by `/sdlc:init`. From the repo root:
```
cd "$(git rev-parse --show-toplevel)"
source .sdlc/config.sh 2>/dev/null || true
S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"
```
`$S` is absolute on purpose, so it keeps working after you `cd` into a worktree. If `$S` does not exist, STOP and tell the user to run `/sdlc:init` first — do not improvise.

## Procedure

### 1. Read the issue and its brief
```
gh issue view <n> --json title,body,labels,state,comments
```
Read the body and especially any **Agent Brief** comment — that is the authoritative spec. Note the acceptance criteria and the "Out of scope" section.

### 2. Re-assert the issue is workable (guard against stale queues)
GitHub's label search is eventually consistent, so verify live state yourself — do not trust that the orchestrator's snapshot is still true:
- `state` is `OPEN`
- labels include `ready-for-agent` **and** `afk`
- `bash "$S/blocked-by.sh" <n>` prints nothing (no open blockers)

If any check fails, STOP and report why. Do not implement.

### 3. Load the shared brief (domain alignment)
Read `CONTEXT.md` (the glossary) and `docs/adr/` (past decisions) if they exist. Use that exact vocabulary and **respect those decisions** — do not re-litigate anything already settled in an ADR. This is what keeps parallel agents from drifting.

### 4. Create an isolated worktree
```
WT=$(bash "$S/make-worktree.sh" <n>)   # slug auto-derived from the title
cd "$WT"
gh issue edit <n> --add-label in-progress
```
Do **all** work inside `$WT`. The worktree also contains `.sdlc/scripts/`, so keep using `$S` there.

### 5. Implement test-first
Use the **`tdd`** skill (red → green → refactor) to satisfy the acceptance criteria. Test external behavior, not implementation details. Keep it a thin vertical slice — exactly what the issue asks, nothing more. Honor the issue's "Out of scope".

### 6. Quality gate
The gate is enforced for you: `open-pr.sh` (step 7) runs `quality-gate.sh` and refuses to open a PR if it fails. For fast feedback you can run it yourself first and fix any failures before attempting the PR:
```
bash "$S/quality-gate.sh"
```

### 7. Commit and open the PR
Commit with a message that references the issue, then:
```
bash "$S/open-pr.sh" <n> --body-file <short-summary.md>
```
`open-pr.sh` runs the quality gate (red gate ⇒ no PR), opens the PR (`Closes #<n>`, AI disclaimer, acceptance criteria), relabels the issue to `in-review`, and comments the PR link. The optional `--body-file` should briefly map what you did to each acceptance criterion. If it reports the gate failed, fix the failures and run it again.

### 8. Stop
Report the issue number, the PR URL, and a one-line summary. **Do not merge. Do not pick up another issue.** You are done.

## Constraints
- One issue only — never edit files for, comment on, or open PRs for other issues.
- Never merge or close the PR; a human is the merge gate.
- Never commit to or push the default branch.
- All work happens inside the issue's worktree.
