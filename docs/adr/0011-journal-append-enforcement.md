# 0011 — Journal append-only is enforced by diff, not by file permissions

- Status: Amended by 0016
- Date: 2026-08-08 (documenting a decision made during M2)

## Context

G4 says `journal/` files are never rewritten, only appended; corrections
are new entries referencing the erroneous one. The agent edits these files
with ordinary tools, so "append-only" needs a check that can actually
observe a violation. The candidate mechanisms differ in where they sit:
the filesystem, the editing tool, or git.

## Decision

Enforce append-only **against git history**, in `evals/test_journal_append.sh`:
a change under `journal/` is append-only iff `git diff --numstat` reports
**zero deleted lines** for every affected file, and `--name-status` reports
no deletions or renames. The script checks, in order of preference: an
explicit commit range, else worktree-vs-HEAD if `journal/` is dirty, else
the last commit.

Rationale: git is already the source of truth for campaign history, the
check works after the fact (so it can be run on any commit, including in
review), and "deleted lines" is exactly the definition of a rewrite. New
files are additions and pass trivially.

`journal/rolls.log` is covered by the same check, and is additionally
machine-written only — the tools append to it and nothing else does
(ADR 0007 hardens what can be written into a line).

## Consequences

- The check is *detective*, not *preventive*: a rewrite is caught at review
  or commit time, not blocked at write time. Acceptable, because the repo
  is versioned — a caught rewrite is trivially revertible.
- Reformatting a journal file (even whitespace) registers as deleted lines
  and fails. Intended: journal files are a record, not a document to tidy.
- The pathspec must cover both the template root and `examples/*/journal/`,
  which needs git's `:(glob)` magic prefix — plain `examples/*/journal/`
  does not match nested paths.

## Alternatives considered

- **Filesystem append-only attributes** (`chattr +a`) — Linux-specific,
  needs root, breaks git checkouts, and would fight the editing tools.
- **A pre-commit hook** — preventive and attractive, but hooks are not
  cloned with the repository, so a fresh instance would silently lose the
  guarantee; it would also block the legitimate "revert a bad edit" flow.
  A hook could be added later *in addition to* the eval.
- **Making the agent responsible** (CLAUDE.md instruction only) — that is
  the rule being verified; verifying it with itself proves nothing.
- **Comparing file sizes / line counts** instead of diffing — cheaper, but
  blind to same-length rewrites, which are exactly the sneaky case.
