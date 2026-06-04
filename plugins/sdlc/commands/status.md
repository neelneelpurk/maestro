---
description: Show the pipeline board; or `close-integrated` to close out a merged integration run.
argument-hint: "[close-integrated]"
---

```!
case "$ARGUMENTS" in
  close-integrated) "${CLAUDE_PLUGIN_ROOT}/scripts/integration.sh" close-integrated ;;
  *)                "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh" ;;
esac
```

If you showed the board, highlight what needs the user: the integration PR or `in-review` PRs awaiting review, `hitl` issues, blocked work, and issues `waiting-for-human-closure` (after merging the integration PR, run `/sdlc:status close-integrated` to close them).
