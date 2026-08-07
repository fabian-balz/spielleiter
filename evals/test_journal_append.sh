#!/usr/bin/env bash
# Eval 4 — journal immutability: changes under journal/ must be append-only.
#
# Usage:
#   evals/test_journal_append.sh            # check worktree+index vs HEAD;
#                                           # if clean, check HEAD~1..HEAD
#   evals/test_journal_append.sh <a> <b>    # check range <a>..<b>
#
# A journal change is append-only iff git reports zero deleted lines for
# every file under journal/ (new files are fine; rewrites/deletions are not).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if (( $# == 2 )); then
  range=("$1" "$2")
  label="$1..$2"
elif ! git diff --quiet HEAD -- journal/ ':(glob)examples/*/journal/**' 2>/dev/null; then
  range=("HEAD")
  label="worktree vs HEAD"
elif git rev-parse -q --verify HEAD~1 >/dev/null; then
  range=("HEAD~1" "HEAD")
  label="HEAD~1..HEAD"
else
  echo "test_journal_append.sh: nothing to check (no changes, no parent commit)"
  exit 0
fi

echo "checking journal/ append-only: ${label}"

fails=0 checked=0
while IFS=$'\t' read -r added deleted path; do
  [[ -z "${path:-}" ]] && continue
  checked=$((checked+1))
  if [[ "${deleted}" != "0" && "${deleted}" != "-" ]]; then
    echo "FAIL: ${path} has ${deleted} deleted line(s) — journal files are append-only (G4)" >&2
    fails=$((fails+1))
  else
    echo "  ok: ${path} (+${added})"
  fi
done < <(git diff --numstat "${range[@]}" -- journal/ ':(glob)examples/*/journal/**')

# deleted or renamed journal files are also violations
while IFS= read -r status_path; do
  status="${status_path%%$'\t'*}"
  case "${status}" in
    D*|R*) echo "FAIL: ${status_path} — journal files must not be deleted or renamed (G4)" >&2
           fails=$((fails+1));;
  esac
done < <(git diff --name-status "${range[@]}" -- journal/ ':(glob)examples/*/journal/**')

if (( checked == 0 && fails == 0 )); then
  echo "no journal changes in ${label} — trivially append-only"
fi

if (( fails > 0 )); then
  echo "test_journal_append.sh: FAILED (${fails} violation(s))"
  exit 1
fi
echo "test_journal_append.sh: OK"
