<!-- Task = one tracer-bullet vertical slice. Authored by /maestro:issues. -->

## Parent
A reference to the PRD/roadmap issue (e.g. `#12`). Linked natively as a sub-issue.

## What to build
The end-to-end behaviour of this thin vertical slice (cuts through every layer).
Describe behaviour, not layer-by-layer implementation. No file paths or code.

## Acceptance criteria
- [ ] Criterion 1 (specific and testable)
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by
`#<n>` (also set natively via issue dependencies), or "None — can start immediately".

---
<!-- The worker keeps this issue as a reviewable running log. As it works it appends:
     - a decomposition checklist (the task broken into small steps),
     - critical / breaking decisions, with a link to any ADR written under docs/adr/,
     - learnings captured (also persisted to .claude/rules/learnings.md),
     - a final "Changes" summary mapping each acceptance criterion to what was done. -->
