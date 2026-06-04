---
description: Set up this repo for the pipeline (labels, .sdlc runtime, PR template, rules, glossary) and create project context (CLAUDE.md / AGENTS.md).
argument-hint: ""
---

Set up this repository for the ai-sdlc pipeline:
```!
"${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"
```

Then:
- **Summarize** the script output.
- **Create project context.** Have a short planning discussion with the user (one question at a time): what this project is, how it's built and tested (so the quality gate runs the right command), and the conventions that matter. Write the answers into the freshly-seeded `CLAUDE.md` and `AGENTS.md`.
- **Remind** the user to **restart Claude Code (or run `/reload-plugins`)** so the `issue-implementer` agent type and `/sdlc:*` commands load (the agent registry is fixed at session start).
