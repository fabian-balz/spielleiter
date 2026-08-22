# 0014 — Pure-bash YAML parsing and bash 3.2 portability

- Status: Accepted
- Date: 2026-08-09
- Supersedes: 0003 (parser implementation only; the file *format* stands)

## Context

ADR 0003 chose the flat YAML table format and described a parser built on
`awk` for the `die:` field plus bash pattern matching for entries. The first
review found two portability problems the ADR had not considered:

- `awk` is a runtime dependency the README did not declare, and the
  environment's default (`mawk`) lacks the gawk `match()` extension the
  original code used — 0003 documented this for entries but still left
  `awk` in the `die:` path.
- `roll.sh` used `mapfile`, a bash 4 builtin. macOS ships bash 3.2 as
  `/bin/bash`, so the tools would fail there while the README asked only for
  "bash".

0003's Decision section is therefore no longer implementation-true, which is
what this ADR supersedes. The *format* decision in 0003 (flat YAML, quoted
values, ranges as keys, hard error on uncovered rolls) is unchanged and
still governs.

## Decision

- **All YAML parsing is pure bash.** `die:`, `id:` and `entries:` are read
  with `while IFS= read -r` loops and `[[ =~ ]]` with the pattern held in a
  variable (the form bash 3.2 requires). No `awk`, `yq`, `jq` or python at
  runtime.
- **Target bash 3.2.** `mapfile`/`readarray`, associative arrays and
  `${var^^}` are not used; `mapfile` was replaced with a read loop.
- **Declare dependencies honestly.** The README lists bash 3.2+, the
  coreutils actually invoked, and `sed`/`grep`/`find` for the evals — and
  states plainly that 3.2 is a code-level guarantee only, since CI here runs
  bash 5.2.

## Consequences

- One implementation of "read a scalar field" is duplicated for `die:` and
  `id:`; a generic reader would be marginally DRYer but less readable in
  bash. Accepted.
- Pure-bash parsing is slower than `awk` — irrelevant at table sizes of tens
  of entries, invoked once per roll.
- The bash 3.2 claim is untested. If someone reports a 3.2 failure it is a
  bug to fix, not a documented limitation.

## Alternatives considered

- **Keep `awk` and just document it** — simplest, and `awk` is POSIX; but
  the gawk/mawk `match()` split had already caused one bug, and removing
  the dependency entirely made the honest dependency list shorter.
- **Require bash 4 and document it** — legitimate (the reviewer offered it
  as an option), but macOS users are a plausible audience and `mapfile` was
  used in exactly one place; the read loop cost three lines.
- **Ship a vendored micro-YAML parser** — more general, far more code to
  audit, and the format is deliberately tiny.
