---
description: Implement every ready-for-agent issue in parallel — one issue-implementer subagent and one PR per issue.
argument-hint: "[issue numbers...] [--max N]"
---

Use the **ship-ready-issues** skill to implement all currently-ready issues, fanning out one `issue-implementer` subagent per issue. Each subagent works in its own git worktree and opens a pull request; **none are merged** — every PR awaits human review.

Arguments: `$ARGUMENTS`
- If issue numbers are given, ship only those (still verify each is workable first).
- `--max N` overrides the parallel cap (`SDLC_MAX_PARALLEL`) for this run.

Steps:
1. Locate the scripts (`cd "$(git rev-parse --show-toplevel)"; source .sdlc/config.sh; S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"`). If missing, tell the user to run `/sdlc:init`.
2. Run `bash "$S/ready-issues.sh"` to get the runnable wave.
3. Fan out `issue-implementer` subagents in parallel (up to the cap), as the skill describes.
4. Print the summary table of issues → PRs.
