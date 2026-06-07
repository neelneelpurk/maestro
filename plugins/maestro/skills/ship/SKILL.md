---
name: ship
description: Implement ONE specific GitHub issue (supervised) — dispatch a background issue-implementer that opens a PR to the default branch, then await human review. Use for /maestro:ship <issue>.
---

# Ship one issue

You are the **coordinator** — you do NOT implement. You dispatch one worker for one issue and report. You never merge.

## Input
An issue number (required). If none is given, ask which issue.

## Steps
1. Locate scripts: `cd "$(git rev-parse --show-toplevel)"; source .maestro/config.sh 2>/dev/null || true; S="${MAESTRO_SCRIPTS:-$(pwd)/.maestro/scripts}"`. If missing, ask the user to run `/maestro:init`. Then begin an observable run: `RUN=$(bash "$S/runs.sh" start)` (the worker's log events get stamped with it; watch with `bash "$S/runs.sh" show`).
2. Verify the issue is workable: open; labelled `maestro:ready-for-agent` or `maestro:auto`; `bash "$S/blocked-by.sh" <n>` prints nothing. If not, report why and stop.
3. Determine the default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
4. **Dispatch one background worker.** Use the Agent tool with `subagent_type: "issue-implementer"` and `run_in_background: true`:
   > Implement issue #<n>: "<title>". Base branch: <default-branch>. Open a PR to the default branch (`Closes #<n>`); do not merge.
   If the `issue-implementer` agent type isn't available (the plugin was installed mid-session — a restart loads it), fall back to `subagent_type: "general-purpose"` and tell it to read and follow `.maestro/scripts/../../skills/implement-issue/SKILL.md` (or the plugin's `implement-issue` skill) for issue #<n> with that base.
5. Tell the user the worker is running in the background — they can keep working — and end your turn. When it completes, end the run (`bash "$S/runs.sh" end`) and report the issue → **PR URL**, which now awaits their review (`maestro:in-review`).

Never merge. State flow: `maestro:ready-for-agent`/`maestro:auto` → `maestro:in-progress` → `maestro:in-review`.
