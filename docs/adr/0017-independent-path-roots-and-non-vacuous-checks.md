# 0017 — Confinement checks need an independent root; checks need real subjects

- Status: Accepted
- Date: 2026-08-09
- Supersedes: 0013 (path confinement); amends 0016

## Context

A third review round found that two of the previous round's fixes were
*shaped* correctly but *anchored* wrongly. Both were reproduced:

1. **The directory check was tautological.** 0013 kept a check comparing
   `pwd -P` of the table file's directory against `pwd -P` of the tables
   directory. When the tables directory *itself* is a symlink, both sides
   canonicalize the same link and are equal by construction — the check can
   never fail. Pointing `SPIELLEITER_TABLES_DIR` at a symlinked directory
   leaked external table content with exit 0. The leaf-symlink fix from 0013
   was real but covered only the last path element.

2. **The structural log check ran over zero lines.** 0016 introduced "every
   log line must carry the documented number of `|` separators" as a
   structural invariant. In the actual test order, `rolls.log` did not exist
   yet at that point: the loop iterated over nothing, `badfields` stayed 0,
   and the suite reported `38/38 PASS` while printing
   `No such file or directory` to stderr. The same pattern — reading a
   missing file and concluding "clean" — affected several `before`/`after`
   line-count assertions.

Additionally, the binary-file case defeated the journal eval: `git diff
--numstat` reports `-  -` for binary blobs, and the code treated
`deleted == "-"` as "no deletions", so replacing a binary file under
`journal/` wholesale passed.

The three share one root cause: **a check is only as good as the thing it is
anchored to.** A comparison against a value derived from the same untrusted
input, an assertion over an absent file, and a numeric test on a
non-numeric sentinel all produce confident green output while verifying
nothing.

## Decision

1. **Confinement compares against an independently determined root.** The
   tables directory must not itself be a symlink (checked directly, not by
   comparison), and when no `SPIELLEITER_TABLES_DIR` override is set, the
   canonical tables directory must equal the canonical
   `<repo-root>/system/tables`. The override remains for tests, and its
   presence is what distinguishes "configured elsewhere on purpose" from
   "redirected behind our back".
2. **Assertions must have a real subject.** Test suites create
   `rolls.log` up front so no assertion can read a missing file; the
   structural check first *produces* valid lines of every shape, asserts the
   log is non-empty, and is paired with a hand-forged tampered log that it
   must flag. A check that cannot fail is a bug, not a pass.
3. **Non-numeric diff output is a violation, not a zero.** Binary files
   under `journal/` are refused outright: line-based append-only is
   unverifiable for them, so "unverifiable" must read as "rejected".
4. **Negative controls live in their own suite.**
   `evals/test_journal_states.sh` drives a throwaway repo through nine
   journal states (four that must pass, five that must fail, including the
   masked `MM` rewrite and the binary rewrite) and asserts the expected exit
   code for each.

## Consequences

- Binary files cannot live under `journal/`. Acceptable: the journal is a
  text record by design. Campaigns wanting to attach images should put them
  in `world/` and reference them.
- With no override set, the tools only read tables from the repository's own
  `system/tables`. Symlinking that directory elsewhere is no longer
  supported (it was never intended).
- The eval suite has grown a second tier — tests of the tests. That is the
  correct shape for a repo whose evals *are* the fitness function, and it is
  cheap: one throwaway git repo per run.

## Alternatives considered

- **`realpath -e` / `readlink -f` on the full path** — would solve the
  directory case in one call, but is GNU-only (`readlink -f` is absent on
  stock macOS), which conflicts with the portability commitment in 0014.
- **Allowing symlinked tables directories if they resolve somewhere
  "sensible"** — there is no non-arbitrary definition of sensible, and the
  legitimate use case (tables shared between campaigns) is better served by
  copying or a git submodule.
- **Byte-prefix check for binary journal files** (old blob must be a prefix
  of the new one) — genuinely append-only-correct and was proposed in the
  review. Rejected for v1 as more machinery than the case deserves: nothing
  in the design writes binary journal files, so refusing them is both
  simpler and a clearer statement of intent. If a real use case appears,
  the prefix check is the right fix and gets its own ADR.
- **Leaving the structural check as-is** since it passes on a correct log —
  this is exactly the vacuous-pass trap; a check whose failure mode has
  never been observed provides false assurance, which is worse than no
  check because it is counted as coverage.
