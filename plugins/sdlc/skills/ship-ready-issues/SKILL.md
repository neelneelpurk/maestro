---
name: ship-ready-issues
description: Implement EVERY ready-for-agent issue in parallel — fan out one issue-implementer subagent per issue, each opening a PR. Use to drive the whole ready queue to pull requests at once (the core of /sdlc:ship and the drain loop).
---

# Ship Ready Issues

Drive every currently-workable issue to an open pull request by **fanning out parallel subagents — one per issue**. This is the multi-agent core of the pipeline. You orchestrate; you do not implement.

## Locate the scripts
```
cd "$(git rev-parse --show-toplevel)"
source .sdlc/config.sh 2>/dev/null || true
S="${SDLC_SCRIPTS:-$(pwd)/.sdlc/scripts}"
```
If `$S` does not exist, STOP and tell the user to run `/sdlc:init` first.

## 1. Find the runnable wave
```
bash "$S/ready-issues.sh"
```
Returns a JSON array of issues that are open, `ready-for-agent`+`afk`, and have **no open blockers** — i.e. everything safe to start right now. Blocked and `hitl` issues are deliberately excluded.

- If the array is empty, report "nothing ready to ship" and stop. For context, you may surface what's waiting on a human:
  ```
  gh issue list --label ready-for-agent --label hitl --state open
  ```
- If the user passed explicit issue numbers as arguments, ship only those — but still confirm each is workable (open, `ready-for-agent`+`afk`, `bash "$S/blocked-by.sh" <n>` empty); skip and note any that aren't.

## 2. Fan out — one subagent per issue, in parallel
Read the concurrency cap `SDLC_MAX_PARALLEL` (default 3; a `--max N` argument overrides it for this run).

For each issue in the wave, spawn an **`issue-implementer`** subagent (the Agent tool with `subagent_type: "issue-implementer"`). Keep each prompt minimal — the agent already knows the procedure:

> Implement GitHub issue #<n>: "<title>". Follow your instructions exactly — one issue, open a PR, do not merge.

Rules:
- Launch them **concurrently** — a single message with multiple Agent tool calls — up to `SDLC_MAX_PARALLEL` at once.
- If the wave is larger than the cap, run successive waves until the wave list from step 1 is exhausted.
- Each subagent gets its own git worktree, so parallel runs never collide.
- **Do not implement any issue yourself.** If a subagent reports failure, note it; do not silently take over.

## 3. Report
Collect each subagent's final report (issue number, PR URL, one-line summary) into a table:

| Issue | Branch | PR | Result |
|------:|--------|----|--------|

Then summarise: how many PRs were opened, any failures/skips, and any `hitl`/blocked issues still waiting. **Never merge** — every PR awaits human review. If this was invoked by the drain loop, simply ending your turn lets the loop decide whether to continue.
