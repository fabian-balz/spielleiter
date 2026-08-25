# Architecture Decision Records

Every architectural decision in this repository is recorded as a numbered
ADR: `NNNN-title.md` with the sections **Context**, **Decision**,
**Consequences**, **Alternatives considered**.

Rules:

- Write the ADR **at the moment the decision is made**, in the same commit
  as (or before) its implementation — not retroactively.
- ADRs are immutable once accepted, **except the `Status:` line**, which is
  the only field that may change (to record supersession). A changed or
  corrected decision gets a *new* ADR; the superseded one keeps its
  original text, mistakes included. See ADR 0012.
- Numbering is sequential, zero-padded to four digits.

Status values: `Accepted`, `Superseded by NNNN`, `Amended by NNNN`,
`Deprecated`.

## Index

- [0001 — Record architecture decisions](0001-record-architecture-decisions.md) — *amended by 0012*
- [0002 — roll.sh design and randomness source](0002-roll-sh-design-and-randomness.md)
- [0003 — Random table format](0003-table-format.md) — *parser superseded by 0014; format stands*
- [0004 — Skills over legacy commands](0004-skills-over-commands.md) — *superseded by 0015*
- [0005 — git-crypt wired but not initialized](0005-git-crypt-wired-not-initialized.md)
- [0006 — Template/instance separation](0006-template-instance-separation.md)
- [0007 — Tool input integrity: reason validation and table-id confinement](0007-tool-input-integrity.md) — *superseded by 0013*
- [0008 — Oracle bands and API](0008-oracle-bands-and-api.md)
- [0009 — A minimal default system ships with the template](0009-default-system.md)
- [0010 — Eval strategy: what is executable, what stays manual](0010-eval-strategy.md) — *amended by 0016*
- [0011 — Journal append-only is enforced by diff, not by file permissions](0011-journal-append-enforcement.md) — *amended by 0016*
- [0012 — ADR process: the Status line is the only mutable field](0012-adr-process-amendments.md)
- [0013 — Every free-text field is untrusted; tables must be real files](0013-log-field-and-path-integrity.md) — *path confinement superseded by 0017*
- [0014 — Pure-bash YAML parsing and bash 3.2 portability](0014-pure-bash-parser-and-portability.md)
- [0015 — `/recap` is made read-only by denying tools, including Bash](0015-recap-read-only-enforcement.md) — *superseded by 0018*
- [0016 — Every eval must be proven to fail; snapshots over marker greps](0016-eval-negative-controls.md) — *amended by 0017*
- [0017 — Confinement checks need an independent root; checks need real subjects](0017-independent-path-roots-and-non-vacuous-checks.md)
- [0018 — Deny the subagent tool under every name it goes by](0018-recap-tool-denial-across-harnesses.md)
- [0019 — The pre-approval scaffold is a byte-exact, default-deny manifest](0019-spec-gate-scaffold-manifest.md)
- [0020 — Multiplayer interaction model: hotseat](0020-multiplayer-hotseat.md)
