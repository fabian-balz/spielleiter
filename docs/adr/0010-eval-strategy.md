# 0010 — Eval strategy: what is executable, what stays manual

- Status: Accepted
- Date: 2026-08-08 (formalizing M2 practice, revised after PR review)

## Context

The spec asks for evals as a fitness function: "executable checks where
possible, otherwise documented manual scenarios". The six acceptance tests
split unevenly. Some assert on artifacts a script can read (`rolls.log`,
`git diff`, the file tree); others assert on *agent behaviour in a
conversation* (does it ask instead of improvising? does it narrate for the
PC?), which no shell script can produce or observe on its own.

A PR review sharpened this: eval 5 (secret leakage) was documented as
manual with a suggested `grep -c`, which is not a test — `grep -c` exits 0
when the marker *is* present, so the suggested command inverts the pass
condition. A "mechanical check" that cannot fail is worse than an honest
manual step, because it invites false confidence.

## Decision

Classify every eval explicitly, and make each class honest about itself:

**Executable (assert on artifacts):**
- `test_roll.sh`, `test_oracle.sh` — tool unit tests, including the
  guardrail negative tests from ADR 0007.
- `test_journal_append.sh` — G4, via `git diff --numstat` over `journal/`.
- `test_template_clean.sh` — ADR 0006 cleanliness.
- `test_secret_leak.sh` — G6 *verbatim* marker leakage in a saved
  transcript. Ships a `--self-test` mode that runs the detector against a
  deliberately leaking fixture (negative control) and fails if the leak is
  not detected.

**Manual (require a conversation), documented in `evals/MANUAL.md` with
explicit PASS/FAIL criteria:** dice integrity (eval 1), rules gate
(eval 2), player agency (eval 3), and the *paraphrase* half of secret
leakage (eval 5).

Two rules follow:

1. **Every executable eval must have a proven failure mode.** A test is
   only committed once it has been observed rejecting the thing it claims
   to catch (traversal, forged log line, journal rewrite, seeded campaign
   content, leaked marker). Where the failure mode is not obvious, it is
   encoded as a self-test or negative-control fixture.
2. **Manual evals must not pretend to be automated.** They state what a
   human must read and judge. Where a partial mechanical check exists
   (marker grep), the eval says exactly what it does *not* cover.

## Consequences

- Evals 1–3 still need a person; the suite is a fitness function with a
  human in the loop, not CI-complete. This is stated in `MANUAL.md` rather
  than papered over.
- `test_secret_leak.sh` needs a marker convention (`Eval-Marker: <STRING>`
  in a `gm/` file); a campaign without one gets a setup error (exit 2),
  distinct from a leak (exit 1).
- Verbatim-only detection means a paraphrased leak passes the script. That
  is a known, documented limit, not an oversight.

## Alternatives considered

- **Automate evals 1–3 by driving Claude Code headlessly** and asserting on
  the transcript — genuinely attractive and probably right eventually, but
  it needs a harness, a pinned model, and tolerance for nondeterministic
  phrasing; out of scope for v1 and worth its own ADR.
- **Semantic leak detection** (embedding similarity against `gm/` content)
  — would catch paraphrase, but needs a model at eval time, i.e. a runtime
  dependency, and would produce false positives on legitimately disclosed
  facts.
- **Dropping eval 5's mechanical half** and leaving it fully manual — the
  reviewer's finding was that the mechanical part was broken, not that it
  was unwanted; a working detector plus a stated limit is strictly better.
