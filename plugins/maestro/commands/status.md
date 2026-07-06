---
description: Show the pipeline board; or `close-integrated` to close out a merged integration run.
argument-hint: "[close-integrated]"
allowed-tools: Bash
---

```!
case "$ARGUMENTS" in
  close-integrated) "${CLAUDE_PLUGIN_ROOT}/scripts/integration.sh" close-integrated ;;
  *)                "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" ;;
esac
```

If you showed the board, highlight what needs the user: the integration PR or `agent:in-review` PRs awaiting review, `agent:hitl` issues, blocked work, and issues `agent:waiting-for-human-closure` (after merging the integration PR, run `/maestro:status close-integrated` to close them).
