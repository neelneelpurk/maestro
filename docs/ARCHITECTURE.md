# ai-sdlc architecture (v3)

`ai-sdlc` is a Claude Code **plugin** (`sdlc`) distributed from a single-repo **marketplace** (`ai-sdlc`). It builds on the [aihero.dev](https://www.aihero.dev/skills) engineering skills and adds an autonomous, GitHub-native orchestration layer with a coordinator + background-worker model.

## Pipeline

```
/sdlc:init            set up the repo + write CLAUDE.md / AGENTS.md / rules / glossary
/sdlc:plan-with-agent grill the domain model → publish a PRD (parent issue)        [composes grill-with-docs + to-prd]
/sdlc:issues          PRD → native sub-issues + dependencies, ready-for-agent       [composes to-issues]
/sdlc:ship <issue>    one issue → PR to the default branch → in-review (supervised)
/sdlc:drain           all ready issues → integration branch (dependency-ordered, per-issue PRs auto-merged)
/sdlc:auto            loop: roadmap (auto-labelled) → drain, until caught up
/sdlc:roadmap         analyze what's shipped → next features + tech-debt → issues
/sdlc:code-feedback   review a PR or the whole codebase (GitHub PR reviews)         [composes code-review]
/sdlc:code-architecture-map  module/seam/dependency map                            [composes improve-codebase-architecture]
/sdlc:status          board / close out a merged integration run
```

## Execution model — coordinator + background workers

`ship`/`drain`/`auto` are **coordinators**: they never implement. They dispatch `issue-implementer` subagents with the **`Agent` tool, `run_in_background: true`**, so the main agent stays interactive and **the user can participate**; it's notified as each worker finishes. Workers run concurrently up to `SDLC_MAX_PARALLEL`. The custom agent type requires a **session restart** to be spawnable (the agent registry is fixed at session start; skills hot-load).

## Integration-branch model (drain & auto)

Full autonomy below the default branch, one human gate at it:

1. `integration.sh start` creates an **integration branch** (seeded with an empty commit so the PR has a diff) off the default branch and opens one **integration PR** (integration → default), labelled `integration`. Never auto-merged.
2. Each issue branches off the integration branch via `gh issue develop` (native branch↔issue link). Its **per-issue PR targets the integration branch** and is **merged automatically once the quality gate is green** (`gh pr merge --auto`, falling back to an immediate squash when there are no required checks).
3. The issue is relabeled **`waiting-for-human-closure`** (never auto-closed). A progress comment + checklist entry is added to the integration PR, linking the issue.
4. The dependency queue (`ready-issues.sh`) treats a blocker as cleared when it is **closed or `waiting-for-human-closure`** — so dependents, which branch off the now-updated integration branch, become workable and the queue self-progresses.
5. The human reviews and merges the integration PR; `/sdlc:status close-integrated` then closes that run's `waiting-for-human-closure` issues.

`/sdlc:ship` skips all this: one issue → PR to the default branch with `Closes #n` → `in-review`.

## GitHub-native data model

- **Sub-issues**: `gh api POST issues/{parent}/sub_issues -F sub_issue_id=<child .id>` (numeric DB id, not `#number`).
- **Dependencies**: `gh api POST issues/{n}/dependencies/blocked_by -F issue_id=<blocker .id>`.
- **Branch↔issue link**: `gh issue develop`.
- **Milestones** for roadmaps. **Closes #n** only on `ship` PRs (default branch). Projects v2 needs `gh auth refresh -s read:project,project` (opt-in); issue types need an org (labels used instead).

## Labels & state machine

See [GLOSSARY.md](GLOSSARY.md). In short: type (`prd`/`roadmap`/`bug`/`enhancement`/`tech-debt`), gate/mode (`ready-for-agent` / `auto` skips the gate / `hitl`), and execution state (`in-progress` → `in-review` for ship, or `waiting-for-human-closure` for drain/auto; `blocked` is a board marker). The integration PR carries `integration`.

## Rules & enforcement (inherited by every worker)

Subagents — including background workers in worktrees — inherit the repo's `CLAUDE.md`, `.claude/rules/*.md`, `settings.json`, and hooks. `/sdlc:init` generates `.claude/rules/sdlc.md` (+ `CLAUDE.md`/`AGENTS.md` importing it) so the conventions (one issue per worktree; per-issue PR targets the integration branch; quality gate before any PR; never merge the integration PR or default branch; never auto-close; use `CONTEXT.md` vocabulary; respect ADRs) bind every worker. Hard enforcement is the quality-gate hook; "never merge" is a soft rule (a repo-wide `deny` on merge would block the human too).

## Key decisions

- **Plugin in a subdir, `/sdlc` namespace** — marketplace `ai-sdlc` lists plugin `sdlc` at `./plugins/sdlc`. Commands and skills share the `/sdlc:` namespace, so each name is defined **once** (orchestrations are skills, for composability via the Skill tool; `init`/`status`/`issues` are commands).
- **`.sdlc/` is machine-local runtime** (gitignored), referenced by **absolute path**; `lib.sh` resolves config + shared state from the **main worktree root** (via `git --git-common-dir`) so scripts work correctly inside worktrees.
- **bash 3.2 compatible** (no `mapfile`/assoc-arrays) — macOS `/bin/bash`.
- **Await review at the default branch**; full autonomy on the integration branch.

## Extension points

`.sdlc/config.sh`: `SDLC_MAX_PARALLEL`, the quality-gate `SDLC_*_CMD` overrides, `SDLC_ASSIGNEE`, the `SDLC_LABEL_*` strings, `SDLC_INTEGRATION_PREFIX`. `lib.sh` centralizes repo/label/dependency access as the seam for other trackers.
