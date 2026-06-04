---
name: review
description: Review any pull request in the project — multi-dimensional (correctness, security, performance, tests/TDD, coding standards) — and post a native GitHub PR review. Never approves or merges. Use for /sdlc:review [pr#].
---

# Review a PR

Give a thorough, posted review of any pull request in this project. You coordinate review subagents and synthesize; you never approve or merge.

## Steps
1. **Pick the PR.** Use the number given. If none, `gh pr list --state open` and ask which (or offer to review each open PR in turn). This works for any PR — pipeline integration/ship PRs or human ones.
2. **Gather context.** `gh pr view <pr>` and `gh pr diff <pr>`; read the linked issue, its acceptance criteria, and the implementation-plan / changes comments the worker posted; read `CONTEXT.md`, `docs/adr/`, and `.claude/rules/` (including `learnings.md`).
3. **Review across dimensions** — fan out one subagent per dimension for depth, each returning concrete findings (file, line, severity, why, suggested fix):
   - **Correctness** — does it do what the issue asks? edge cases, error handling, race conditions.
   - **Security** — injection, authz, secrets, unsafe input handling.
   - **Performance** — N+1s, hot paths, needless work.
   - **Tests** — do they assert external behaviour and cover the acceptance criteria? Does it look genuinely test-driven, not bolted on?
   - **Standards & consistency** — matches the codebase's style; respects ADRs and persisted learnings.
4. **Verify** each finding against the diff; drop the speculative ones.
5. **Post one native review:** `bash "$S/pr-review.sh" <pr> --event COMMENT --body-file <summary.md> [--comments-file <inline.json>]` — use `REQUEST_CHANGES` if there are blocking issues, `COMMENT` otherwise. **Never approve or merge.**
6. **Report** a verdict (ship / needs changes) and the key findings. (Locate scripts first: `source .sdlc/config.sh; S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"`.)
