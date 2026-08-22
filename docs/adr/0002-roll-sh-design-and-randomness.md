# 0002 — roll.sh design and randomness source

- Status: Accepted
- Date: 2026-08-07

## Context

Guardrail G1 forbids the LLM from producing die results; all randomness
must come from an auditable tool that logs every invocation. Constraints:
bash + coreutils only, reproducible results for tests, a log format stable
enough for evals to assert against.

## Decision

`tools/roll.sh` is a single bash script that:

1. **Randomness** — unseeded: 4 bytes from `/dev/urandom`; seeded
   (`--seed N`, tests only): a glibc-constant LCG
   (`state = state*1103515245 + 12345 mod 2^31`) whose **low 16 bits are
   discarded** (`(state/65536) % 32768`). Both paths yield a value in
   0..32767.
2. **Die mapping** — rejection sampling (`limit = 32768/sides*sides`,
   re-draw at/above limit) so every face is exactly equiprobable; no
   modulo bias.
3. **State via variables, not command substitution** — `sl_rand`/`sl_die`
   set `SL_RAND`/`SL_DIE` instead of echoing, because `$(...)` forks a
   subshell and the seeded LCG state would never advance in the parent.
4. **Sourceable library pattern** — the `BASH_SOURCE == $0` guard lets
   `oracle.sh` source roll.sh and reuse the one RNG/logging
   implementation. There is deliberately no third `lib.sh` file (spec
   names exactly two tools).
5. **Log format** — exactly one pipe-delimited line per invocation,
   appended to `journal/rolls.log` and echoed verbatim:
   `<ISO-8601 UTC> | <expr> | dice=[…] | (kept=[…] |) total=<n> | reason=<text>`.
   Invalid expressions exit non-zero and write nothing.

Both design bugs that motivated points 1 and 3 were caught by tests during
bootstrap: the raw LCG's correlated low bits produced identical dice within
a roll (`4d6kh3 --seed 42` → `[4,4,4,4]`), and command substitution froze
the seed state.

## Consequences

- Fully auditable: narrated numbers can be mechanically checked against
  the log (eval 1); tests are deterministic via `--seed`.
- The seeded LCG is not cryptographic and doesn't need to be — it exists
  for test reproducibility only; play uses `/dev/urandom`.
- The log format is a public contract; changing it requires updating
  `evals/` and CLAUDE.md in lockstep (and a superseding ADR).

## Alternatives considered

- **`$RANDOM`** — not seedable per-invocation in a fresh process without
  the same LCG-quality issues, and its 15-bit range would have needed the
  identical rejection scaffolding anyway.
- **`shuf`/`od` per die** — one process per die; no clean seeding story
  for reproducible multi-die sequences.
- **Python/awk PRNG** — awk's `srand`/`rand` differs across mawk/gawk;
  Python violates the no-new-dependencies constraint.
- **Shared `tools/lib.sh`** — rejected to keep the tool surface exactly as
  specified; the sourceable-guard pattern achieves the same reuse.
