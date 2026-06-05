# maestro architecture (v3)

`maestro` is a Claude Code **plugin** (`maestro`) distributed from a single-repo **marketplace** (`maestro`). It is **self-contained** (no external skill dependencies) — an autonomous, GitHub-native maestro with a coordinator + background-worker model.

## Pipeline

```
/maestro:init            set up the repo + write CLAUDE.md / AGENTS.md / rules / glossary
/maestro:plan-with-agent grill the domain model → publish a PRD (parent issue)
/maestro:issues          PRD → native sub-issues + dependencies, ready-for-agent
/maestro:ship <issue>    one issue → PR to the default branch → in-review (supervised)
/maestro:drain           all ready issues → integration branch (dependency-ordered, per-issue PRs auto-merged)
/maestro:auto            loop: roadmap (auto-labelled) → drain, until caught up
/maestro:roadmap         analyze what's shipped → next features + tech-debt → issues
/maestro:code-feedback   review a PR or the whole codebase (GitHub PR reviews)
/maestro:code-architecture-map  module/seam/dependency map
/maestro:review          review any PR (multi-dimension) → post a GitHub review
/maestro:learn           persist a correction as a durable, inherited learning
/maestro:status          board / close out a merged integration run
```

## Execution model — coordinator + background workers

`ship`/`drain`/`maestro:auto` are **coordinators**: they never implement. They dispatch `issue-implementer` subagents with the **`Agent` tool, `run_in_background: true`**, so the main agent stays interactive and **the user can participate**; it's notified as each worker finishes. Workers run concurrently up to `MAESTRO_MAX_PARALLEL`. The custom agent type requires a **session restart** to be spawnable (the agent registry is fixed at session start; skills hot-load).

## Integration-branch model (drain & auto)

Full autonomy below the default branch, one human gate at it:

1. `integration.sh start` creates an **integration branch** (seeded with an empty commit so the PR has a diff) off the default branch and opens one **integration PR** (integration → default), labelled `maestro:integration`. Never auto-merged.
2. Each issue branches off the integration branch via `gh issue develop` (native branch↔issue link). Its **per-issue PR targets the integration branch** and is **merged automatically once the quality gate is green** (`gh pr merge --auto`, falling back to an immediate squash when there are no required checks).
3. The issue is relabeled **`maestro:waiting-for-human-closure`** (never auto-closed). A progress comment + checklist entry is added to the integration PR, linking the issue.
4. The dependency queue (`ready-issues.sh`) treats a blocker as cleared when it is **closed or `maestro:waiting-for-human-closure`** — so dependents, which branch off the now-updated integration branch, become workable and the queue self-progresses.
5. The human reviews and merges the integration PR; `/maestro:status close-integrated` then closes that run's `maestro:waiting-for-human-closure` issues.

`/maestro:ship` skips all this: one issue → PR to the default branch with `Closes #n` → `maestro:in-review`.

## GitHub-native data model

- **Sub-issues**: `gh api POST issues/{parent}/sub_issues -F sub_issue_id=<child .id>` (numeric DB id, not `#number`).
- **Dependencies**: `gh api POST issues/{n}/dependencies/blocked_by -F issue_id=<blocker .id>`.
- **Branch↔issue link**: `gh issue develop`.
- **Milestones** for roadmaps. **Closes #n** only on `ship` PRs (default branch). Projects v2 needs `gh auth refresh -s read:project,project` (opt-in); issue types need an org (labels used instead).

## Labels & state machine

See [GLOSSARY.md](GLOSSARY.md). In short: type (`maestro:prd`/`maestro:roadmap`/`maestro:bug`/`maestro:enhancement`/`maestro:tech-debt`), gate/mode (`maestro:ready-for-agent` / `maestro:auto` skips the gate / `maestro:hitl`), and execution state (`maestro:in-progress` → `maestro:in-review` for ship, or `maestro:waiting-for-human-closure` for drain/auto; `maestro:blocked` is a board marker). The integration PR carries `maestro:integration`.

## Rules & enforcement (inherited by every worker)

Subagents — including background workers in worktrees — inherit the repo's `CLAUDE.md`, `.claude/rules/*.md`, `settings.json`, and hooks. `/maestro:init` generates `.claude/rules/maestro.md` (+ `CLAUDE.md`/`AGENTS.md` importing it) so the conventions (one issue per worktree; per-issue PR targets the integration branch; quality gate before any PR; never merge the integration PR or default branch; never auto-close; use `CONTEXT.md` vocabulary; respect ADRs) bind every worker. Hard enforcement is the quality-gate hook; "never merge" is a soft rule (a repo-wide `deny` on merge would block the human too).

## Key decisions

- **Plugin in a subdir, `/maestro` namespace** — marketplace `maestro` lists plugin `maestro` at `./plugins/maestro`. Commands and skills share the `/maestro:` namespace, so each name is defined **once** (orchestrations are skills, for composability via the Skill tool; `init`/`status`/`issues` are commands).
- **`.maestro/` is machine-local runtime** (gitignored), referenced by **absolute path**; `lib.sh` resolves config + shared state from the **main worktree root** (via `git --git-common-dir`) so scripts work correctly inside worktrees.
- **bash 3.2 compatible** (no `mapfile`/assoc-arrays) — macOS `/bin/bash`.
- **Await review at the default branch**; full autonomy on the integration branch.

## Extension points

`.maestro/config.sh`: `MAESTRO_MAX_PARALLEL`, the quality-gate `MAESTRO_*_CMD` overrides, `MAESTRO_ASSIGNEE`, the `MAESTRO_LABEL_*` strings, `MAESTRO_INTEGRATION_PREFIX`. `lib.sh` centralizes repo/label/dependency access as the seam for other trackers.
