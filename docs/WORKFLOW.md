# ai-sdlc workflow (integration-branch flow)

How a feature travels through the ai-sdlc pipeline, from a plan to merged code,
with **one human review gate** at the default branch and full autonomy below it.

For the canonical vocabulary see [CONTEXT.md](../CONTEXT.md) and
[GLOSSARY.md](GLOSSARY.md); for the design behind it see
[ARCHITECTURE.md](ARCHITECTURE.md).

## The flow at a glance

```
plan-with-agent → issues → ship / drain → per-issue PRs ──auto-merge──▶ integration branch
                                                                              │
                                                                  human merges the
                                                                  integration PR ──▶ default branch
```

1. **Plan** — `/sdlc:plan-with-agent` grills the feature against the domain
   model (updating `CONTEXT.md` + the ADRs under `docs/adr/`) and publishes a
   **PRD** as a parent issue.
2. **Issues** — `/sdlc:issues <prd#>` breaks the PRD into native **sub-issues**
   with **dependencies** (`blocked_by`), labelled `ready-for-agent` (the human
   gate) — or `auto`, which skips that gate.
3. **Ship or drain** — implement the ready queue:
   - **`/sdlc:ship <issue#>`** (supervised) takes **one** issue to a PR against
     the **default branch** with `Closes #<n>`, then relabels it `in-review`
     and awaits your review. This skips the integration-branch model below.
   - **`/sdlc:drain`** (autonomous) implements **all** workable issues in
     dependency order on a single **integration branch**. `/sdlc:auto` loops
     roadmap → drain until the queue is caught up.

## The integration-branch model (drain & auto)

`drain`/`auto` are **coordinators**: they never implement. They fan out one
background `issue-implementer` **Worker** per issue in the current **Wave** (up
to `SDLC_MAX_PARALLEL`), so you can keep participating in the same session.

1. **Start the run** — `integration.sh start` creates an **integration branch**
   (`sdlc/integration-<stamp>`) off the default branch and opens one
   **integration PR** (integration → default), labelled `integration`. This PR
   is **never** auto-merged — it is your single review gate.
2. **One Worker per issue** — each Worker owns exactly one issue, in its own
   git worktree, branched off the integration branch via `gh issue develop`
   (a native branch↔issue link). It implements a thin vertical slice
   **test-first**, then relabels the issue `in-progress`.
3. **Quality gate, then per-issue PR** — the Worker runs the **quality gate**
   (install → lint → typecheck → test); a **red gate means no PR**. On green it
   opens a **per-issue PR** targeting the **integration branch**, which is
   **merged automatically** once the gate is green (`gh pr merge --auto`).
4. **Wait for human closure** — the merged issue is relabeled
   **`waiting-for-human-closure`** (never auto-closed); a progress comment +
   checklist entry is added to the integration PR. A blocker counts as cleared
   once it is **closed or `waiting-for-human-closure`**, so dependents — which
   branch off the now-updated integration branch — become workable and the
   queue self-progresses through successive Waves until it is empty.
5. **The human merges** — you review the accumulated work on the **integration
   PR** and merge it into the **default branch**. `/sdlc:status close-integrated`
   then bulk-closes that run's `waiting-for-human-closure` issues.

## What a Worker never does

- Never touches more than **one issue**, or files outside its own worktree.
- Never **merges** the integration PR or the default branch — that is the
  human's gate.
- Never **auto-closes** an issue.

These conventions are enforced for every Worker via `.claude/rules/sdlc.md`
(inherited inside each worktree) and the quality-gate hook.
