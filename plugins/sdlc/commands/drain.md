---
description: Drain the ready queue — loop /sdlc:ship until no ready issues remain. Also supports stop / status.
argument-hint: "[--max N] | stop | status"
---

Run the drain controller:
```!
case "$ARGUMENTS" in
  stop|status) "${CLAUDE_PLUGIN_ROOT}/scripts/drain-control.sh" $ARGUMENTS ;;
  *)           "${CLAUDE_PLUGIN_ROOT}/scripts/drain-control.sh" start $ARGUMENTS ;;
esac
```

Then, based on that output:

- If the **drain loop was armed**, immediately invoke the **ship-ready-issues** skill now: implement every ready-for-agent issue by fanning out one `issue-implementer` subagent per issue (each works in its own worktree and opens a PR; **never merge**). Then end your turn — the `Stop` hook re-runs the ship step automatically after each turn until the ready queue is empty (or `max_iterations` is reached). To stop early: `/sdlc:drain stop`.
- If you ran **stop** or **status**, just report the controller output and do nothing else.

Note: the drain loop only continues within the session that started it. Because the pipeline awaits human review (no auto-merge), one drain pass ships everything currently ready; issues that are blocked until a PR merges get picked up on a later drain (or by the scheduled routine).
