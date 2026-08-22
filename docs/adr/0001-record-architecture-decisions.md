# 0001 — Record architecture decisions

- Status: Amended by 0012 (ADR process), see below
- Date: 2026-08-07

## Context

Spielleiter's core promise is auditability: campaign state is versioned
files, campaign history is git history. The *development* of the template
deserves the same standard — future maintainers (human or agent) need to
know why the tooling looks the way it does, not just what it does.

Honesty note: this ADR and 0002–0005 document decisions made earlier in the
same bootstrap session (milestones M0–M2, commits `9251c6a`, `45b5a23`,
`b0d902a`) and are written immediately after, in the same pull request.
From 0006 onward, ADRs are written at decision time, before or with their
implementation.

## Decision

Every architectural decision is recorded in `docs/adr/NNNN-title.md` with
the sections Context, Decision, Consequences, Alternatives considered — at
the moment the decision is made. ADRs are immutable; changed decisions get
a superseding ADR.

## Consequences

- Design rationale survives context loss between sessions and maintainers.
- Small overhead per decision; the discipline gate ("would this need an
  ADR?") also discourages casual architectural drift.

## Alternatives considered

- **Rationale in commit messages only** — searchable but scattered; no
  single index; alternatives rarely recorded.
- **A single DESIGN.md** — drifts toward describing current state, losing
  the decision-by-decision history and supersession trail.
