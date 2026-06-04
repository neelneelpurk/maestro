---
description: Draft a PRD from the current conversation and publish it as a GitHub issue (parent epic).
argument-hint: "[extra context]"
---

Use the **to-prd** skill (aihero) to synthesize a PRD from the current conversation and codebase understanding and publish it as a GitHub issue. Extra context: $ARGUMENTS

After the PRD issue is created, mark it as the pipeline's parent epic so the fan-out never tries to implement the PRD itself:
- `gh issue edit <prd-issue> --add-label prd --remove-label ready-for-agent --remove-label afk` (ignore "label not found" — to-prd may not have added those)

If the `to-prd` skill is not available, tell the user to install the aihero skills (see the README), or write the PRD inline using that structure: Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope.

Recommend `/sdlc:align <prd-issue>` next, then `/sdlc:issues <prd-issue>`.
