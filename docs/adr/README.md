# Architecture Decision Records

Every architectural decision in this repository is recorded as a numbered
ADR: `NNNN-title.md` with the sections **Context**, **Decision**,
**Consequences**, **Alternatives considered**.

Rules:

- Write the ADR **at the moment the decision is made**, in the same commit
  as (or before) its implementation — not retroactively.
- ADRs are immutable once accepted. A changed decision gets a *new* ADR
  that supersedes the old one (note the supersession in both files' Status).
- Numbering is sequential, zero-padded to four digits.

Status values: `Accepted`, `Superseded by NNNN`.

## Index

- [0001 — Record architecture decisions](0001-record-architecture-decisions.md)
- [0002 — roll.sh design and randomness source](0002-roll-sh-design-and-randomness.md)
- [0003 — Random table format](0003-table-format.md)
- [0004 — Skills over legacy commands](0004-skills-over-commands.md)
- [0005 — git-crypt wired but not initialized](0005-git-crypt-wired-not-initialized.md)
- [0006 — Template/instance separation](0006-template-instance-separation.md)
