---
description: Show the ai-sdlc board — issues by pipeline stage, open PRs, and drain status.
argument-hint: ""
---

Show the pipeline board:
```!
"${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

Then briefly highlight what needs the user's attention — PRs awaiting review (`in-review`), issues that need a human (`hitl`), and anything blocked. Keep it to a few lines.
