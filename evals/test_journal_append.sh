#!/usr/bin/env bash
# Eval 4 — journal immutability: changes under journal/ must be append-only.
#
# Usage:
#   evals/test_journal_append.sh            # check every pending state:
#                                           #   index vs HEAD, worktree vs index
#                                           # and, if both are clean, HEAD~1..HEAD
#   evals/test_journal_append.sh <a> <b>    # check range <a>..<b>
#
# A journal change is append-only iff git reports zero deleted lines for
# every file under journal/ (new files are fine; rewrites/deletions are not).
#
# Index and worktree are checked SEPARATELY and both must pass. Checking only
# worktree-vs-HEAD is not enough: a rewrite staged in the index while the
# worktree is restored to the original content leaves worktree-vs-HEAD empty,
# so the violation would be invisible (the "MM" state).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

PATHS=(journal/ ':(glob)examples/*/journal/**')
FAILS=0

# sl_check_diff <label> <git-diff-args...> — fail on deleted lines/renames.
# Sets SL_CHECKED (files seen). Must NOT be called in a command substitution:
# the subshell would discard FAILS.
sl_check_diff() {
  local label=$1; shift
  local checked=0 added deleted path status_path status
  while IFS=$'\t' read -r added deleted path; do
    [[ -z "${path:-}" ]] && continue
    checked=$((checked+1))
    if [[ "${deleted}" == "-" || "${added}" == "-" ]]; then
      # git reports "-  -" for binary files: line-based append-only cannot be
      # verified, so a modified binary under journal/ is a violation by
      # definition. Treating "-" as "zero deletions" let a full binary
      # rewrite pass.
      echo "FAIL [${label}]: ${path} is binary — journal files must be text so appends are verifiable (G4)" >&2
      FAILS=$((FAILS+1))
    elif [[ "${deleted}" != "0" ]]; then
      echo "FAIL [${label}]: ${path} has ${deleted} deleted line(s) — journal files are append-only (G4)" >&2
      FAILS=$((FAILS+1))
    else
      echo "  ok [${label}]: ${path} (+${added})"
    fi
  done < <(git diff --numstat "$@" -- "${PATHS[@]}")

  while IFS= read -r status_path; do
    [[ -z "${status_path}" ]] && continue
    status="${status_path%%$'\t'*}"
    case "${status}" in
      D*|R*) echo "FAIL [${label}]: ${status_path} — journal files must not be deleted or renamed (G4)" >&2
             FAILS=$((FAILS+1));;
    esac
  done < <(git diff --name-status "$@" -- "${PATHS[@]}")

  SL_CHECKED=${checked}
}

if (( $# == 2 )); then
  echo "checking journal/ append-only: $1..$2"
  sl_check_diff "$1..$2" "$1" "$2"
else
  echo "checking journal/ append-only: index vs HEAD, worktree vs index"
  # 1. staged changes (index vs HEAD) — catches the masked "MM" rewrite
  sl_check_diff "index" --cached HEAD; staged=${SL_CHECKED}
  # 2. unstaged changes (worktree vs index)
  sl_check_diff "worktree"; unstaged=${SL_CHECKED}

  if (( staged == 0 && unstaged == 0 && FAILS == 0 )); then
    if git rev-parse -q --verify HEAD~1 >/dev/null; then
      echo "nothing pending — checking HEAD~1..HEAD instead"
      sl_check_diff "HEAD~1..HEAD" HEAD~1 HEAD > /dev/null
    else
      echo "test_journal_append.sh: nothing to check (no changes, no parent commit)"
    fi
  fi
fi

echo
if (( FAILS > 0 )); then
  echo "test_journal_append.sh: FAILED (${FAILS} violation(s))"
  exit 1
fi
echo "test_journal_append.sh: OK"
