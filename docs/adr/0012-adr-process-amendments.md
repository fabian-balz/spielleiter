# 0012 — ADR process: the Status line is the only mutable field

- Status: Accepted
- Date: 2026-08-09
- Amends: 0001

## Context

ADR 0001 requires ADRs to be immutable and changed decisions to be recorded
in a superseding ADR. The first review round violated that rule in the very
commit that answered it: `5b9e3a8` edited ADR 0001's Decision section (to
add a bootstrap exception) and appended a "Correction" block to ADR 0004,
both in place. A second review caught it.

The violation is not cosmetic. The value of an ADR log is that it shows what
was believed *at the time*; editing an accepted ADR erases exactly the
signal it exists to preserve. Notably, 0004's in-place "correction" made the
log claim a thing was known which had in fact been got wrong and later
fixed — the tidy version is the misleading one.

0001 also left a mechanical gap: supersession has to be discoverable from
the superseded file, but if nothing in an accepted ADR may change, the
`Status:` line can never record it.

## Decision

Amend the process from ADR 0001:

1. **The `Status:` line is the only mutable field of an accepted ADR.** It
   may be changed to `Superseded by NNNN`, `Amended by NNNN`, or
   `Deprecated`. Everything else — Context, Decision, Consequences,
   Alternatives — is frozen at acceptance, mistakes included.
2. **Corrections are made by a new ADR**, which states what it supersedes
   or amends and what specifically was wrong. The superseded ADR keeps its
   original text.
3. **Retrospective ADRs are marked as such** in their Date line
   ("documenting a decision made during MN"). The one-time bootstrap
   exception covers 0002–0005 and the M0–M2 decisions documented later in
   0008, 0009 and 0011. It does **not** extend to decisions taken from the
   first review round onward: 0006, 0007, and 0012–0015 were each written
   with or before their implementation.

The earlier wording "the exception is closed as of ADR 0006" was imprecise —
0008, 0009 and 0011 are retrospective by content while carrying later
numbers, because they document M0–M2 decisions that the first review found
undocumented. The exception is scoped **by the decision's date, not by ADR
number**.

## Consequences

- The ADR log can now contain visibly wrong-then-corrected entries. That is
  the intended cost: 0004 stays wrong on the record and 0015 says why.
- Two files must be touched per correction (Status line + new ADR).
- Readers must follow the supersession chain rather than trusting a single
  file. The index in `README.md` carries the current status.

## Alternatives considered

- **Full immutability including Status** — supersession becomes invisible
  from the superseded file; a reader landing on 0004 would have no pointer
  to 0015. Rejected as unusable.
- **Allow in-place correction with a visible changelog block** (what
  `5b9e3a8` did) — keeps everything in one file, but destroys the "what was
  believed then" signal and makes diffs the only history. This is the thing
  the review objected to; rejected.
- **Delete superseded ADRs** — worst of all: the reasoning that led to a
  bad decision is usually the most useful part.
- **Rewrite the branch so no ADR was ever edited** — same objection as the
  rebase proposal in the first review: it would hide that the process was
  broken and then fixed. The violation is part of the record.
