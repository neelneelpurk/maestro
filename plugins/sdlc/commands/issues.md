---
description: Break a PRD issue into ready-for-agent vertical-slice issues the pipeline can implement.
argument-hint: "<prd-issue#>"
---

Use the **to-issues** skill (aihero) to break the PRD (issue `$ARGUMENTS`) into tracer-bullet vertical slices and publish each as a GitHub issue, recording dependencies in a `## Blocked by` section as `#<n>` references.

Then make each new slice legible to the pipeline by applying the right pipeline labels (to-issues marks slices HITL/AFK in prose — the pipeline needs the *labels*):
- AFK slices (no human needed): `gh issue edit <n> --add-label ready-for-agent --add-label afk`
- HITL slices (need a human): `gh issue edit <n> --add-label ready-for-agent --add-label hitl`

Reference the aligned `CONTEXT.md`/ADRs (from `/sdlc:align`) so slice titles and descriptions use the canonical domain vocabulary.

If `to-issues` is not available, install the aihero skills (README) or create the slices manually using its structure (Parent, What to build, Acceptance criteria, Blocked by).

When done, recommend `/sdlc:ship` (or `/sdlc:drain`) to implement the AFK slices in parallel.
