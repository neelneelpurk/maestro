# Glossary

The canonical vocabulary of the ai-sdlc pipeline. Produced/maintained by the
alignment gate (`/sdlc:align`). Glossary only — no implementation details.

## Pipeline
The end-to-end flow PRD → align → issues → ship, driving GitHub issues to pull requests.

## Worker
A single `issue-implementer` subagent. A Worker owns exactly one issue, in its own
worktree, and opens exactly one PR. It never merges and never touches another issue.

## Wave
The set of issues that are workable *right now* — open, `ready-for-agent`+`afk`, and
with no open blockers. `/sdlc:ship` fans out one Worker per issue in the current Wave.

## Drain
Repeatedly shipping successive Waves until the ready queue is empty. Within a session
this is the `/sdlc:drain` loop; over time it is the scheduled routine.

## Ready queue
The open issues labelled `ready-for-agent` + `afk` whose blockers are all closed.
The single source of truth is `ready-issues.sh`.

## Shared brief
`CONTEXT.md` (this glossary) plus the ADRs under `docs/adr/`. Every Worker reads it
before coding so parallel work stays consistent in language and decisions.

## Quality gate
The install → lint → typecheck → test check (`quality-gate.sh`) that must pass before
a PR is opened. A red gate means no PR.
