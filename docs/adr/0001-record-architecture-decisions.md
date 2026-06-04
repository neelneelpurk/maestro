# 1. Record architecture decisions

Date: 2026-06-04

## Status

Accepted

## Context

As this project grows, we make architecturally significant decisions: choosing
tools, defining boundaries between components, settling conventions, and ruling
options in or out. These decisions shape the system, yet the reasoning behind
them is easily lost. New contributors — and AI agents working autonomously on
the codebase — repeatedly re-litigate settled questions because the original
context, the alternatives considered, and the trade-offs accepted were never
written down.

We need a lightweight, durable, low-ceremony way to capture these decisions
where they live with the code, so that anyone (human or agent) reading the repo
can understand not just *what* was decided but *why*, and can trust that a
documented decision is settled rather than open.

## Decision

We will record architecturally significant decisions as **Architecture Decision
Records (ADRs)**, using the format described by Michael Nygard.

- Each ADR is a Markdown file stored under `docs/adr/`.
- Files are numbered sequentially and named
  `NNNN-title-in-kebab-case.md` (e.g. `0001-record-architecture-decisions.md`).
- Each ADR uses the standard sections: **Status**, **Context**, **Decision**,
  and **Consequences**.
- An ADR's **Status** is one of `Proposed`, `Accepted`, `Deprecated`, or
  `Superseded`. When a decision is reversed or replaced, we do not delete the
  old ADR; we mark it `Superseded` (referencing the ADR that replaces it) and
  add a new ADR, preserving the historical record.
- ADRs are immutable once accepted, except to update their status.

This document, ADR 0001, is itself the first record and establishes the process.

## Consequences

- The reasoning behind significant decisions is captured next to the code, in
  version control, and is reviewable through the normal pull-request process.
- Contributors and autonomous agents can read `docs/adr/` to understand prior
  decisions and avoid re-opening questions that are already settled.
- Each significant decision carries a small, recurring cost: writing and
  reviewing an ADR. This is a deliberate trade-off in favour of long-term
  clarity over short-term speed.
- The sequence of ADRs forms a chronological log of the project's architectural
  evolution, including decisions that were later superseded.
