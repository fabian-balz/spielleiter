# 0013 — Every free-text field is untrusted; tables must be real files

- Status: Superseded by 0017
- Date: 2026-08-09
- Supersedes: 0007

## Context

ADR 0007 hardened `--reason` and table-id handling after the first review.
The second review found both fixes incomplete, and both gaps were
reproduced:

1. **0007 asserted that `--reason` is "the only free text in a log line".
   That was wrong.** A table's *entry text* is also free text, and it lands
   in the `result=` field. An entry of
   `harmless | total=999 | reason=forged-field` produced the log line
   `… | result=harmless | total=999 | reason=forged-field | reason=t` —
   extra, plausible-looking fields inside one physical line. The newline
   defence did not apply because no newline was involved.
2. **The path confinement canonicalized the wrong thing.** `pwd -P` on
   `$(dirname "${file}")` canonicalizes the *containing directory*; the
   final path element is never resolved. A symlink at
   `system/tables/secret.yaml` pointing outside the tree therefore passed
   the check and its content was read, printed and logged (exit 0).

The shared root cause: 0007 reasoned about *the input it had thought of*
rather than about *every value that reaches the log line*.

## Decision

Generalize the rule from "validate `--reason`" to **"every value
interpolated into a log line is untrusted free text and must be rejected if
it contains a field separator (`|`), CR, or LF"**. Concretely, this now
covers both `--reason` and table entry text; `sl_log_line` continues to
refuse multi-line payloads as a last line of defence.

For paths: **a table file must be a real file, not a symlink.** `oracle.sh`
rejects a leaf symlink outright (`[[ -L "${file}" ]]`), in addition to the
existing bare-name id validation and the containing-directory check (which
still guards against a symlinked tables *directory*).

Tests encode both as negative controls: an internally consistent symlinked
table (so that only the symlink check can reject it), and a `|`-bearing
entry. A structural assertion was added on top: every line in the log must
carry exactly the documented number of `|` separators for its line type —
this catches future field-injection routes without naming them in advance.

## Consequences

- Table entries cannot contain `|`. For German prose this is a non-issue;
  authors get a clear error naming the table and the roll.
- Symlinked tables are unsupported. A campaign wanting shared tables across
  instances must copy them or use a submodule.
- The field-count assertion is the first *structural* invariant on the log
  rather than a blocklist of known-bad inputs, and would have caught
  finding 3 without anyone thinking of it first.

## Alternatives considered

- **Encode/escape `|` in entries** instead of rejecting — preserves author
  freedom but makes log lines less readable by eye and breaks the eval
  regexes; the log's by-eye auditability is the point (G1). Rejected, as in
  0007.
- **Canonicalize the full file path** (`readlink -f`) instead of rejecting
  symlinks — GNU-only (`readlink -f` is absent on stock macOS), and it
  would *allow* symlinks that happen to resolve inside the tables dir,
  which adds a confusing case for no benefit.
- **Validate only in `sl_log_line`** — would catch the injection but with a
  useless error message ("bad payload") instead of naming the offending
  table and roll. Both layers kept.
- **Quote/delimit the result field** in the log format — would fix
  injection generically, but changes the documented format and every eval
  regex and existing log; deferred, and would need its own ADR.
