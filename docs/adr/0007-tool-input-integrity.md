# 0007 — Tool input integrity: reason validation and table-id confinement

- Status: Accepted
- Date: 2026-08-08

## Context

A PR review of the M0–M2 branch found two ways to defeat the guardrails
through tool *input*, both reproduced before fixing:

1. **Forged log entries (G1).** `--reason` was written into
   `journal/rolls.log` unvalidated. A reason containing a newline appended a
   second physical line that was syntactically indistinguishable from a real
   roll:
   `2020-01-01T00:00:00Z | 3d6 | dice=[6,6,6] | total=18 | reason=FORGED`.
   The log is the single source of truth for G1 ("narrated numbers must
   match the log"), so a forgeable log defeats the whole guardrail. An empty
   or absent reason was also accepted, contradicting CLAUDE.md.
2. **Path traversal (G6).** `oracle.sh table <id>` concatenated the id into
   `${SL_TABLES_DIR}/${id}.yaml` without validation. `table ../geheim` read
   and logged `system/geheim.yaml` — outside the tables directory. Any
   YAML-shaped file under `gm/` was therefore disclosable via stdout and
   `rolls.log`.

A third, smaller issue: the `id:` field declared inside a table file was
never checked, so a table could be logged under a name that misrepresented
its content.

## Decision

Treat all tool input as untrusted, and validate at the boundary:

- **`--reason` is mandatory** and must be a single line containing no `|`
  (the field separator). Empty, missing, CR/LF-containing, and
  `|`-containing reasons are rejected with exit 2 and **nothing is
  written**. `sl_log_line` additionally refuses any multi-line payload —
  one invocation, one physical line, enforced at the write itself.
- **A table id is a bare name**, matching `^[A-Za-z0-9][A-Za-z0-9_-]*$`.
  Paths, `..`, absolute paths, and shell metacharacters are rejected. As a
  second layer, the resolved file's directory must equal the canonical
  tables directory (catches symlinks out of the tree).
- **The declared `id:` must equal the requested id**, otherwise the lookup
  fails.

Each rule has negative tests, including a traversal test that places a
readable, well-formed table one level above the tables directory and
asserts both that the call fails and that its content never reaches the log.

## Consequences

- `--reason` is now required everywhere, including in tests and the
  example campaign; the CLAUDE.md instruction ("every roll gets a
  `--reason`") is enforced by the tool instead of by discipline.
- Table ids can no longer contain `/` or dots — a flat namespace. Nested
  table directories would need a superseding decision.
- Reasons cannot contain `|`. German narration reasons rarely need it; the
  alternative (escaping) was rejected as more complex for no real gain.
- The log format is unchanged, so existing logs and evals stay valid.

## Alternatives considered

- **Escaping/encoding the reason** (e.g. percent- or backslash-escaping
  newlines) — preserves arbitrary text but makes log lines harder to read
  by eye and to assert on; the log's readability is a feature. Rejected.
- **Quoting the reason field in the log** — same drawback, plus it would
  break the documented format and every existing eval regex.
- **Only validating in `sl_log_line`** — would catch forgery but not the
  empty-reason case, and would report the error late; validating at the
  argument boundary gives better messages. Both layers are cheap, so both
  are in place.
- **`realpath --relative-to` for the traversal check** — not portable
  (GNU coreutils only, absent on macOS by default); `cd … && pwd -P` is
  POSIX-ish and sufficient.
- **Allowing subdirectories in table ids** (validating the canonical path
  stays *below* the tables dir rather than equal to it) — more flexible,
  but no current need and a larger attack surface. Deferred.
