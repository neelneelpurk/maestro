---
description: Break a PRD into ready-for-agent sub-issues (tracer-bullet vertical slices) with native dependencies, assigned to you.
argument-hint: "<prd-issue#>"
---

Break PRD #`$ARGUMENTS` into independently-grabbable issues, using the aligned `CONTEXT.md`/ADR vocabulary. (Scripts live in `.sdlc/scripts/`.)

## 1. Draft vertical slices
Read the PRD (`gh issue view <prd>`). Break it into **tracer-bullet** issues: each a thin **vertical slice** that cuts through every layer end-to-end (schema, logic, UI, tests), not a horizontal slice of one layer.
- Each slice is independently demoable/verifiable and small. Prefer many thin slices over a few thick ones.
- Mark each slice AFK (an agent can finish it unattended) or HITL (needs a human decision/design/manual test). Prefer AFK.
- Identify dependencies between slices (what must merge before what).

Present the breakdown as a numbered list (title, AFK/HITL, blocked-by, which user stories it covers) and iterate with the user until they approve.

## 2. Publish the slices (in dependency order)
For each approved slice, create a GitHub issue following the task template (also seeded at `.github/ISSUE_TEMPLATE/task.md`): a "What to build" (end-to-end behaviour, no file paths/code), an "Acceptance criteria" checklist, and a "Blocked by" note. Then make it native to the pipeline:
- create it **assigned to `@me`**, labelled **`ready-for-agent`** (use `hitl` instead for HITL slices; add `enhancement`/`bug` as apt);
- link it as a sub-issue of the PRD: `.sdlc/scripts/subissue.sh add <prd> <child>`;
- set dependencies: `.sdlc/scripts/dependency.sh add <issue> <blocker>` (publish blockers first so you can reference them).

Do not modify or close the PRD. When done, recommend `/sdlc:drain` (or `/sdlc:ship <issue>` for one).
