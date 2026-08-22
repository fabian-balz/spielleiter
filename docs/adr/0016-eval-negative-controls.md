# 0016 — Every eval must be proven to fail; snapshots over marker greps

- Status: Amended by 0017
- Date: 2026-08-09
- Amends: 0010, 0011

## Context

ADR 0010 already required that "every executable eval must have a proven
failure mode". The second review showed three evals that passed while the
thing they claimed to catch was present — the rule existed but had not been
applied thoroughly enough:

1. **`test_journal_append.sh` missed a staged rewrite.** With a rewrite in
   the index and the original content restored in the worktree (the `MM`
   state), `git diff HEAD` was empty, so the script fell through to
   `HEAD~1..HEAD` and passed. The masked case is precisely the one an
   author covering their tracks would produce.
2. **`test_template_clean.sh` accepted campaign content in the default
   system.** It grepped for the "Default-System" label; appending a house
   rule to `system/system.md` keeps the label and passed.
3. **`test_secret_leak.sh` masked a missing instance marker.** It collected
   markers from `gm/` *and* `examples/`, so an instance with no marker of
   its own still "passed" on the demo's marker — a vacuous pass in exactly
   the campaign that needed the check.

Common shape: each eval verified *a* condition rather than *the* condition,
and each was only ever tested against the failure it was written for.

## Decision

1. **Check every reachable state, not the convenient one.** The journal eval
   now checks index-vs-HEAD and worktree-vs-index **separately**, and both
   must pass; the commit-range check runs only when nothing is pending. The
   six-state matrix (clean, worktree append, worktree rewrite, staged
   append, staged rewrite, masked `MM`) is verified by hand on every change
   to that script.
2. **Compare byte-exact snapshots, not markers,** for files the template
   owns. `evals/snapshots/template-defaults.sha256` pins `system/system.md`
   and `system/tables/komplikationen.yaml`; any edit fails the eval and
   must be accompanied by a deliberate snapshot update.
3. **Never let a fixture stand in for the real subject.** Instance markers
   come from `gm/` only; the demo markers under `examples/` are used
   exclusively by `--self-test`. A missing instance marker is a setup error
   (exit 2), distinct from clean (0) and leak (1) — vacuous passes are
   forbidden as a class.
4. **Prefer structural invariants to blocklists.** The oracle suite now
   asserts that every log line carries exactly the documented number of `|`
   separators, which catches field-injection routes nobody enumerated.

## Consequences

- Editing a template default is now a two-step operation (edit, then
  regenerate the snapshot). Intended friction: it makes "campaign content
  crept into the template" impossible to do accidentally.
- The snapshot file must be regenerated whenever the default system legitimately
  changes — e.g. the success/tie/failure fix that came out of this same
  review round.
- Exit code 2 (setup error) is now meaningful across the suite; callers must
  distinguish it from 1 (violation).

## Alternatives considered

- **`git stash` before checking the journal** — would normalize the states
  but mutates the user's working tree from a test; unacceptable.
- **Checking only `git status --porcelain` codes** (e.g. flagging any `MM`)
  — simpler, but flags legitimate staged-append-plus-worktree-append too,
  and says nothing about deleted lines.
- **Signing template defaults with git attributes / hooks** — heavier and
  not cloned with the repo; a checked-in checksum file travels with the
  template and is trivially auditable.
- **Auto-updating the snapshot when the eval runs** — self-defeating: the
  check would ratify whatever it found.
