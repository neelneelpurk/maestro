---
title: "One Human Gate: Building a GitHub-Native SDLC That Drains Your Backlog"
date: 2026-06-05
author: Soumyadeep Purkait
tags: [ai, sdlc, claude-code, github, agents]
---

I wanted to stop babysitting my AI coding agent one ticket at a time and instead point it at a backlog and walk away — without surrendering the merge button. So I built a self-contained Claude Code plugin that turns GitHub issues into parallel background workers landing on a single integration branch, then dogfooded it on its own repo until it could build itself.

## The problem: one-ticket babysitting doesn't scale

You've felt this. You hand an AI agent a ticket, and then you sit there. It opens a file, asks to proceed. It runs a command, asks to proceed. Your session is hostage to a single task, and you're the cursor clicking "yes." Finish one issue, repeat for the next. That's not leverage — it's a faster way to do one thing at a time while staring at a terminal.

The real job is the backlog, not the ticket. You have a PRD broken into a dozen sub-issues with real dependencies between them. What you actually want is to say "work the ready queue" and walk away — let the independent issues go in parallel, let the blocked ones start the moment their blocker lands, and come back to something you can review *as a whole*. But "walk away" is exactly where naive automation gets scary. Two failure modes dominate: it blocks your session so you can't do anything else while it grinds, and it makes irreversible decisions — merging code you never saw, or worse, merging code that's *red*.

So the goal narrows to something precise: **drain an entire backlog autonomously, while preserving exactly one human decision — the merge — and never landing red code or a surprise.**

Those constraints do a lot of work downstream. "Never block the session" forces a coordinator that only *dispatches* and never implements, so the human stays live while workers run. "Exactly one human gate" rules out merging to your default branch at all, which is what produces the integration-branch model. And "never land red" gets enforced upstream of the gate: strictly test-first development, plus a quality gate — install, lint, typecheck, test — that must pass before any PR opens. A red gate means no PR. The rest of this post is mostly the consequences of taking those three constraints seriously.

## The shape of the pipeline: PRD → issues → ship, all GitHub-native

The plugin's command surface follows the natural arc of feature work, and it's worth seeing the core path before the orchestration details. You start with `/sdlc:plan-with-agent`, which grills a feature against the domain model — updating `CONTEXT.md` and the ADRs as decisions crystallise — then publishes a real PRD as a parent GitHub issue, not a doc rotting in someone's Drive. Then `/sdlc:issues` decomposes that PRD into native GitHub sub-issues, each a thin vertical slice, wired together with `blocked_by` dependencies so the build order is encoded in the tracker itself. From there you choose your throttle: `/sdlc:ship <issue>` implements exactly one issue under supervision; `/sdlc:drain` implements every ready issue in parallel. (There's a wider surface around this core — `/sdlc:init`, `/sdlc:status`, `/sdlc:review`, `/sdlc:roadmap`, `/sdlc:code-feedback`, `/sdlc:code-architecture-map`, `/sdlc:learn` — but the four above are the spine.)

The deliberate choice underneath all of it is to invent *no* parallel state store. There is no sidecar database, no YAML manifest tracking what's done. State lives in GitHub primitives that already exist and that a human can read and edit directly: sub-issues for decomposition, `blocked_by` for dependencies, and `gh issue develop` to create each issue's branch so GitHub itself records the branch↔issue link. Labels carry execution state — `ready-for-agent`, `in-progress`, `waiting-for-human-closure`. The pipeline is a coordinator *over* GitHub, not a system that shadows it.

That decision pays off directly in how dependencies advance, which the next section gets to. The cost is that leaning on GitHub means living with GitHub — its label search, for one, is only eventually consistent, a wrinkle I'll come back to in the lessons.

## The key insight: the integration branch as a single review gate

The problem with autonomous coding agents isn't writing code — it's the review explosion. Fan out ten agents and you get ten PRs against your default branch, ten gates to mind, ten chances to merge something half-baked. The mental load defeats the point.

So a drain run inverts it. When you call `/sdlc:drain`, a setup step (`integration.sh start`) opens exactly **one** integration branch (`sdlc/integration-<stamp>`) off your default branch, and exactly **one** integration PR from that branch back to the default. That integration PR is the single human review gate — and it is *never* auto-merged. Everything the run produces lands behind that one PR, so you review one diff, once. (A small bootstrap detail: a PR needs a diff to exist, so the integration branch is seeded with an empty commit the moment it's created.)

Underneath, each issue still gets its own worker, its own `sdlc/issue-<n>-<slug>` branch via `gh issue develop`, and its own PR. But the per-issue PR targets the **integration branch**, not the default. When that worker's quality gate goes green, its PR auto-merges into integration. No green gate, no merge.

That target choice is what makes the dependency queue self-progress. Because dependents branch off the integration branch, a worker picking up issue #42 starts from a tree that *already contains* the merged work of the issues it was blocked by. The next wave builds on integrated reality, not on stale `main`. One subtle consequence forced a rule: a finished-but-unmerged blocker still has to unblock its dependents, so "work merged into integration" counts as cleared — even though the issue itself is still open. Which it stays: issues are **never** auto-closed. When a worker's PR merges, the issue is relabelled `waiting-for-human-closure` rather than shut. It closes for real only after you merge the integration PR and then run `/sdlc:status close-integrated`, which bulk-closes that run's issues. Even closure is human-triggered.

One branch in, one PR out, one decision to make: ship it, or don't.

## Coordinate, don't implement: the background-worker pattern

The integration model is what the human sees; the worker pattern is how the work actually gets done. `/sdlc:ship`, `/sdlc:drain`, and `/sdlc:auto` never write a line of production code themselves — they *coordinate*. Each fans out `issue-implementer` subagents using the `Agent` tool with `run_in_background: true`, then steps back. The workers churn through their issues in parallel while you stay live in the same session: you can ask questions, queue more work, or watch the status board, all without blocking on any single implementation. The coordinator is notified as each worker finishes, and concurrency is capped by `SDLC_MAX_PARALLEL`.

The contract for a worker is deliberately narrow. One worker owns exactly one issue, in its own git worktree, and opens exactly one PR. It never merges, and it never touches another issue's files. That isolation is what makes parallelism safe — two workers editing the same tree would be a disaster, but separate worktrees are just independent checkouts.

Inside that worktree, the worker is held to the bar a careful human would be. Every change is strictly test-first: red, green, refactor — no production code without a failing test that demands it. Before a worker is allowed to open its PR, it runs the quality gate (install → lint → typecheck → test). A red gate means no PR, full stop, and a PreToolUse hook backstops the rule even against a manual `gh pr create`.

The piece that keeps parallel work from drifting is inheritance. `/sdlc:init` writes `.claude/rules/sdlc.md` plus `CLAUDE.md`/`AGENTS.md` into the repo, and Claude Code loads those rules automatically — even inside a linked worktree. So every worker reads the same conventions, the same canonical vocabulary in `CONTEXT.md`, and the same hard-won corrections in `learnings.md` without anyone wiring it up per-agent. One of those learnings is small but real: keep every bash script compatible with macOS's bash 3.2 — no `mapfile`, no associative arrays. A worker spawned tomorrow obeys it as faithfully as the one that learned it, because the rule lives in the repo, not in a conversation. When the user corrects the agent, `/sdlc:learn` persists the lesson there so it isn't repeated.

## The lessons the docs don't warn you about

Every interesting bug in this project lived in the gap between what an API claims and what it actually does. These are the ones that cost real time.

**GitHub's label search is eventually consistent.** Relabel an issue `in-progress` and immediately query for it, and you'll get stale results — the index lags the write. A worker that trusts the search will happily grab an issue another worker already owns. So every `issue-implementer` re-verifies an issue's *live* state right before acting, never trusting the queue snapshot it was handed. This one race is the reason the whole queue is built on re-verification rather than a cached list.

**A plugin's custom agent type isn't spawnable until a session restart.** The agent registry is frozen at session start; skills hot-load, agents don't. Run `/sdlc:init`, and the `issue-implementer` agent it defines simply won't exist for `ship`/`drain` to fan out — until you restart. That ordering surprise is now called out explicitly in the install steps instead of failing mysteriously.

**macOS `/bin/bash` is 3.2.** No `mapfile`, no `readarray`, no associative arrays — all bash 4+. Scripts like `ready-issues.sh` are written to the 3.2 floor (it's literally the first entry in `learnings.md`), or they break on a stock Mac.

**The sub-issue and dependency REST APIs need the numeric database id, not the `#number`.** `#42` is the display number; the `blocked_by` and sub-issue endpoints want the issue's internal `.id`. Pass the wrong one and you get silent mismatches.

**Shared state must resolve from the main worktree.** Workers run inside linked git worktrees, so a plain relative path points at the wrong tree. Everything shared — config, runtime state — resolves through `git --git-common-dir` to anchor on the main checkout (`lib.sh` does this centrally).

**A finished-but-unmerged blocker must still unblock its dependents.** Since issues never auto-close under drain — they sit at `waiting-for-human-closure` with their work already in the integration branch — the queue treats "merged into integration" as cleared. Otherwise the dependency graph would deadlock, every wave waiting on a human to close issues that are, for all practical purposes, done.

## Dogfooding and where it goes next

The pipeline was built on its own issues. Once `/sdlc:init` had written the rules and the first few commands existed, the work of building the *rest* of it went through it: `/sdlc:plan-with-agent` to grill a feature into a PRD, `/sdlc:issues` to break it into native sub-issues, `/sdlc:ship` and `/sdlc:drain` to implement them. Nearly every lesson in the previous section was paid for that way — watching the thing run on itself, in parallel, against real GitHub.

The soft spots are honest ones. "Never merge the integration PR yourself" is a *convention* the agents inherit, not a hard deny — a repo-wide deny on merge would also block the human, who is the entire point of the single review gate. So that boundary lives in the rules, not in tooling that can enforce it. The quality gate, by contrast, *is* hard-enforced by a hook. Worth naming the difference: one is a guardrail, the other a trust assumption.

The open frontier is the loop. `/sdlc:auto` already chains roadmap thinking into a drain — `/sdlc:roadmap` finds missing features, files them as `auto`-labelled issues that skip the human gate, and the drain implements them — but a genuinely *unattended* loop that wakes on a schedule, clears whatever is ready, and knows when to stop is still young; today it self-paces off worker completion and `/loop` / `ScheduleWakeup`. A cron-triggered drain that leaves an integration PR waiting for you in the morning is the natural next step. And the bigger seam is already cut: `lib.sh` centralises every repo, label, and dependency call, which is exactly where you'd *start* if you wanted to swap `gh` for Linear or Jira and keep the state machine. None of that is done. But the shape is there — and it's there because the thing was built by running it on itself, one human gate the whole way.
