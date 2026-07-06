# Troubleshooting

A field guide to the failure modes you'll actually hit running maestro, and how to
recover. Most answers start at **`/maestro:status`** (the board) and
**`bash .maestro/scripts/runs.sh show`** (what the last run did). Scripts live in
the target repo under `.maestro/scripts/` after `/maestro:init`.

> First, run the preflight: `bash .maestro/scripts/doctor.sh`. It checks gh +
> auth, jq, a GitHub remote, **API reachability**, **repo write access**, and a
> **writeable state dir** — most setup problems show up here with a fix hint.

---

## Setup

**`doctor` says "gh not authenticated".** Run `gh auth login` (needs `repo`
scope). Re-check with `gh auth status`.

**`doctor` says "insufficient repo permission (READ)".** Your token can read but
not write the repo, so it can't open PRs/issues. Re-authenticate a token with
write access (`gh auth refresh -s repo`) or ask a repo admin for write.

**`doctor` says "GitHub API not reachable".** Network/proxy issue, or the token
is invalid. Confirm `gh api rate_limit` works from the same shell.

**`doctor` says "cannot write the state dir".** maestro keeps logs and run state
under `.maestro/` (gitignored). Fix the directory's write permissions in the repo.

**`doctor` says "pipeline scripts not installed".** Run `/maestro:init` in the
repo.

**Commands or the `issue-implementer` agent don't exist after install.** The agent
registry is fixed at session start. **Restart Claude Code** (or `/reload-plugins`)
— skills hot-load, but the custom agent type and `/maestro:*` commands need the
restart.

**`/maestro:init` aborted with "template missing".** Your plugin install is
incomplete (a `templates/*.md` file is absent). Reinstall the plugin and re-run
`/maestro:init` — init now fails loud rather than seeding a half-configured repo.

---

## "No ready issues" when you expected some

`/maestro:drain` and `/maestro:ship` work the queue from
`bash .maestro/scripts/ready-issues.sh`. An issue is picked only when it is **open**,
**assigned to you** (`MAESTRO_ASSIGNEE`, default `@me`), labelled
`agent:ready-for-agent` **or** `agent:auto`, **not** already in-flight
(`in-progress`/`in-review`/`waiting-for-human-closure`/`hitl`), **not** a
`agent:prd`/`agent:roadmap` parent, and **unblocked**. Common misses:

- **Not assigned to you.** Assign it (`gh issue edit <n> --add-assignee @me`) or
  check with `bash .maestro/scripts/ready-issues.sh --anyone`.
- **Still blocked.** See its blockers: `bash .maestro/scripts/blocked-by.sh <n>`. A
  blocker clears only when it is **closed** or labelled
  `agent:waiting-for-human-closure`.
- **Label search lag.** GitHub's label search is eventually consistent — an issue
  you just labelled can take a few seconds to appear. Re-run the command.

---

## Quality gate

**"no toolchain detected and no checks configured — nothing ran".** The gate now
**refuses to report a false green** (a repo with no tests must not produce green
PRs). Fix it one of two ways in `.maestro/config.sh`:

- Configure a real check, e.g. `MAESTRO_TEST_CMD='pytest -q'` (or `MAESTRO_LINT_CMD`,
  `MAESTRO_TYPECHECK_CMD`, `MAESTRO_INSTALL_CMD`); or
- If the repo genuinely has nothing to run (docs-only), opt in explicitly:
  `MAESTRO_ALLOW_EMPTY_GATE=1`.

This also affects the **`gh pr create` backstop hook** — a manual PR in an
unconfigured repo is blocked until you do one of the above.

**The gate fails on a step.** Run it yourself to see the output:
`bash .maestro/scripts/quality-gate.sh` (add `--no-install` to skip install on a
repeat run). Red gate ⇒ no PR — fix the failing step and retry.

---

## Drain / integration runs

**A per-issue PR got labelled `agent:hitl`.** Its auto-merge into the
integration branch failed — almost always a conflict with work already integrated.
Resolve it by hand:

```bash
git fetch origin
git switch maestro/issue-<n>-<slug>
git rebase origin/maestro/integration-<stamp>   # resolve conflicts, then:
git push --force-with-lease
gh issue edit <n> --remove-label agent:hitl --add-label agent:ready-for-agent
```

Then re-run `/maestro:drain` to re-pick it.

**A new drain reuses an old integration run.** Only one run is active at a time;
`integration.sh start` reuses the run while its PR is open. Finish the current one
first — review and `/maestro:merge_pr` (or close the integration PR) — then start a
new drain. Check the active run: `bash .maestro/scripts/integration.sh status`.

**The integration PR is merged but issues are still open.** Issues are never
auto-closed — they sit at `agent:waiting-for-human-closure`. Close them with
`/maestro:status close-integrated` (or `/maestro:merge_pr`, which merges *and*
closes in one step).

**Force-close a stuck run** (e.g. you merged the PR manually):
`bash .maestro/scripts/integration.sh close-integrated --force`.

---

## Observing a run

- **What's happening now / last:** `bash .maestro/scripts/runs.sh show` — branch,
  PR, per-issue events, PRs opened, integrated, gate failures.
- **History:** `bash .maestro/scripts/runs.sh list` (newest first).
- **Raw events:** `.maestro/log.jsonl` (one JSON object per event, stamped with the
  `run_id`).

A run that never reaches `integrated` for an issue means the worker stopped before
its PR merged — check that issue's comments and `runs.sh show` for the last event
it logged.

---

## Worktrees

Each issue gets its own git worktree under `../maestro-worktrees/` (or
`MAESTRO_WORKTREE_DIR`). After a failed/abandoned run they can linger:

```bash
git worktree list                      # see them
git worktree remove <path> --force     # remove one
git worktree prune                     # drop stale registrations
```

`make-worktree.sh` reuses an existing worktree for the same issue, so a re-run
picks up where it left off rather than duplicating.
