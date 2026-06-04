---
name: code-feedback
description: Review a pull request (post inline GitHub review comments) or the whole codebase (a findings report + optional ready-for-agent tech-debt issues). Asks the user for scope and focus first. Use for /sdlc:code-feedback.
---

# Code feedback

Give code review feedback at PR level or across the whole codebase. You coordinate review subagents and synthesize; you never approve or merge.

## 1. Ask the user
Use `AskUserQuestion` to settle:
- **Scope** — a specific PR (by number) / all open pipeline PRs / the whole codebase.
- **Focus** — correctness, security, performance, simplification, or all.

## 2a. PR scope
- Get the diff: `gh pr diff <pr>` (and `gh pr view <pr>`). For depth, fan out one review subagent per focus dimension; the `code-review` skill is a good base.
- Post **one** review with the native review API:
  `bash "$S/pr-review.sh" <pr> --event COMMENT --body-file <summary.md> [--comments-file <inline.json>]`
  where `inline.json` is `[{ "path","line","body" }, ...]`. Use `COMMENT` (or `REQUEST_CHANGES`); **never approve or merge** — this is feedback only.

## 2b. Whole-codebase scope
- Fan out parallel `Explore`/review subagents across subsystems; synthesize a findings report grouped by severity (the `improve-codebase-architecture` skill helps structure it).
- If the user opts in, open issues for actionable findings: `gh issue create ... --label ready-for-agent --assignee @me` (add `tech-debt` for debt) so `/sdlc:ship` or `/sdlc:auto` can fix them. Set dependencies where findings build on each other.

## 3. Report
Summarize what you reviewed, the review(s) posted, and any issues opened. Locate scripts first: `S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"` (after `source .sdlc/config.sh`).
