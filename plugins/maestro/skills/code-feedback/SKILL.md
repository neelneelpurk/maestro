---
name: code-feedback
description: Review a pull request (post inline GitHub review comments) or the whole codebase (a findings report + optional ready-for-agent tech-debt issues). Asks the user for scope and focus first. Use for /maestro:code-feedback.
---

# Code feedback

Give code-review feedback at PR level or across the whole codebase. You coordinate review subagents and synthesize; you never approve or merge.

## 1. Ask the user
Use `AskUserQuestion` to settle:
- **Scope** — a specific PR (by number) / all open pipeline PRs / the whole codebase.
- **Focus** — correctness, security, performance, simplification, tests/TDD adherence, or all.

## 2a. PR scope
- Read the diff (`gh pr diff <pr>`) and the PR/issue context. Fan out one review subagent per focus dimension for depth; each returns concrete findings (file, line, severity, why, suggested fix).
- Verify findings before posting (drop the speculative ones). Post **one** review via the native API:
  `bash "$S/pr-review.sh" <pr> --event COMMENT --body-file <summary.md> [--comments-file <inline.json>]`
  where `inline.json` is `[{ "path","line","body" }, ...]`. Use `COMMENT` (or `REQUEST_CHANGES`); **never approve or merge** — feedback only.

## 2b. Whole-codebase scope
- Fan out parallel `Explore`/review subagents across subsystems (correctness, security, performance, dead code, test coverage). Synthesize a findings report grouped by severity, using `CONTEXT.md` vocabulary and respecting `docs/adr/`.
- If the user opts in, open issues for actionable findings: `gh issue create ... --label agent:ready-for-agent --assignee @me` (add `agent:tech-debt` for debt) so `/maestro:ship` or `/maestro:auto` can fix them; set dependencies where findings build on each other.

## 3. Report
Summarize what you reviewed, the review(s) posted, and any issues opened. Locate scripts first: `source .maestro/config.sh; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"`.
