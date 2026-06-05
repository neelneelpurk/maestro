---
name: drain
description: Drain the ready queue — implement every issue assigned to me in a ready state, in dependency order, on an integration branch, with each per-issue PR auto-merged into it. The main agent only coordinates; you can participate. Ends when nothing is pending. Use for /maestro:drain (and inside /maestro:auto).
---

# Drain

You are the **coordinator**. You do NOT implement and you NEVER merge the integration PR. You start an integration run, dispatch background workers in dependency order, and report. This is equivalent to looping `/maestro:ship` over the assigned ready queue (the user may also run `/loop /maestro:drain`).

## Steps

1. Locate scripts: `cd "$(git rev-parse --show-toplevel)"; source .maestro/config.sh 2>/dev/null || true; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"`.
2. **Start (or reuse) the integration run:** `INTB=$(bash "$S/integration.sh" start)`. This opens the integration PR — your single review gate. Tell the user its URL (`bash "$S/integration.sh" status`).
3. **Queue loop:**
   a. `bash "$S/ready-issues.sh"` → issues assigned to me, `maestro:ready-for-agent` or `maestro:auto`, **unblocked** (no open blockers; a blocker counts as cleared once it's `maestro:waiting-for-human-closure`).
   b. If it's empty **and** no workers are still running → the queue is drained. Go to step 4.
   c. Otherwise dispatch up to `MAESTRO_MAX_PARALLEL` workers (default 3) — Agent tool, `subagent_type: "issue-implementer"`, `run_in_background: true`, one per ready issue, each:
      > Implement issue #<n>: "<title>". Base branch: <INTB>. Open the per-issue PR against the integration branch.
      (Fallback to `general-purpose` following the `implement-issue` skill if the agent type isn't loaded yet.)
   d. End your turn so the user can participate. Each worker, on finishing, merges its per-issue PR into the integration branch and relabels its issue `maestro:waiting-for-human-closure` — which **unblocks dependents**.
   e. When a worker completes you'll be notified: **re-run step (a)** and dispatch any newly-unblocked issues (the next dependency layer). As a safety heartbeat you may also `ScheduleWakeup` to re-check.
4. **Done:** report the table of integrated issues → per-issue PRs, and the **integration PR** for the human to review and merge. Remind them: merging the integration PR then `bash "$S/integration.sh" close-integrated` closes the `maestro:waiting-for-human-closure` issues.

Never merge the integration PR or the default branch.
