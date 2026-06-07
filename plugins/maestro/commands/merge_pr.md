---
description: Merge a maestro PR and close the issues it covers. With no number, merges the active integration PR and closes its whole run's issues. Your manual review gate — never used by the autonomous lane.
argument-hint: "[pr#] [--squash|--merge|--rebase] [--admin]"
---

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/merge-pr.sh" $ARGUMENTS
```

This is a **human action** — you are exercising your single review gate. After it runs, report what merged and which issues were closed. If the merge was refused (merge conflict or required checks not green), say so and point the user to `/maestro:status` to resolve it. Do **not** invoke this from `/maestro:auto` or `/maestro:drain` — those never merge the integration PR.
