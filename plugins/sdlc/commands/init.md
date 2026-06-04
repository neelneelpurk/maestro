---
description: One-time setup of this repo for the ai-sdlc pipeline (labels, .sdlc/ runtime, PR template, prereqs check).
argument-hint: ""
---

Set up this repository for the ai-sdlc pipeline:
```!
"${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"
```

Then:
- Summarize the output for the user.
- Remind them to **restart Claude Code (or run `/reload-plugins`)** so the `issue-implementer` agent type and `/sdlc:*` commands load — the agent registry is fixed at session start, so `/sdlc:ship` can only fan out subagents in a session started *after* install.
- If any aihero front-end skills were reported missing (`to-prd`, `to-issues`, `grill-with-docs`, `triage`, `tdd`), point the user to the README prerequisites / https://www.aihero.dev/skills.
