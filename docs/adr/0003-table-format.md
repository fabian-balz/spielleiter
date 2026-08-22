# 0003 — Random table format

- Status: Superseded by 0014 (parser), see below
- Date: 2026-08-07

## Context

Random tables (`system/tables/<id>.yaml`) must be human-editable, resolved
exclusively by `tools/oracle.sh table <id>` (G1), and parseable with bash +
coreutils only — no yq/jq/python. The environment's default awk is mawk,
which lacks gawk extensions (this bit during bootstrap: `match()` with a
capture array is gawk-only).

## Decision

A deliberately flat YAML subset:

```yaml
id: <table-id>
die: <NdM expression>
entries:
  1-2: "entry text"
  3: "entry text"
```

- `entries` is a YAML map whose keys are single numbers or `lo-hi` ranges,
  values are double-quoted strings — one line each, two-space indent.
- Parsed in pure bash (`[[ =~ ]]` with the pattern in a variable) inside
  `sl_table_lookup`; the `die:` field is extracted with basic awk `sub`.
- A roll not covered by any range is a hard error (exit non-zero), not a
  silent nearest-match — gaps are authoring bugs and must surface.

## Consequences

- Files remain valid YAML (future tooling can parse them with a real
  parser) while today's parser stays dependency-free.
- The format is rigid: multi-line entry text, nested structures, or
  unquoted values are not supported. Authors get errors, not surprises.
- Table coverage errors are caught at roll time and tested
  (`evals/test_oracle.sh` gap-table case).

## Alternatives considered

- **Full YAML via yq/python** — new runtime dependency; violates the
  constraint without asking.
- **List-of-objects YAML** (`- range: 1-2` / `text: …`) — the original
  sketch; needs multi-line stateful parsing for no expressive gain.
- **CSV/TSV** — trivially parseable but hostile to hand-editing quoted
  German prose with commas, and inconsistent with the repo's
  "YAML frontmatter everywhere" convention.
- **gawk-based parser** — worked locally only where gawk exists; mawk is
  the Debian/Ubuntu default. Rejected for portability.
