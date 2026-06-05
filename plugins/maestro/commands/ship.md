---
description: Implement ONE GitHub issue (supervised) — dispatch a background issue-implementer that opens a PR to the default branch, then await human review.
argument-hint: "<issue#>"
---

Run the maestro **ship** orchestration for issue #`$ARGUMENTS`: invoke the `maestro:ship` skill with the Skill tool and follow it through to completion. You are the coordinator — never implement, never merge.
