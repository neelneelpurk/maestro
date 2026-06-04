---
description: Break a PRD into ready-for-agent sub-issues with native dependencies, assigned to you.
argument-hint: "<prd-issue#>"
---

Use the **to-issues** skill (aihero) to break PRD #`$ARGUMENTS` into tracer-bullet vertical slices, using the aligned `CONTEXT.md`/ADR vocabulary. Then make each slice native to the pipeline (scripts live in `.sdlc/scripts/`):

- create it **assigned to `@me`**, labelled **`ready-for-agent`** (add `hitl` instead if it needs a human; add `enhancement`/`bug` as apt);
- link it as a sub-issue of the PRD: `.sdlc/scripts/subissue.sh add <prd> <child>`;
- set dependencies between slices: `.sdlc/scripts/dependency.sh add <issue> <blocker>`.

If `to-issues` isn't available, create the slices directly using its structure (Parent, What to build, Acceptance criteria). Then recommend `/sdlc:drain` (or `/sdlc:ship <issue>` for one).
