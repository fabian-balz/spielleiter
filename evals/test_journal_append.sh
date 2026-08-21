#!/usr/bin/env bash
# Eval 4 — journal immutability: changes under journal/ must be append-only.
#
# Usage:
#   evals/test_journal_append.sh            # check every pending state:
#                                           #   index vs HEAD, worktree vs index
#                                           # and, if both are clean, HEAD~1..HEAD
#   evals/test_journal_append.sh <a> <b>    # check range <a>..<b>
#
# Append-only means, per modified file: the OLD content is a byte-exact
# PREFIX of the new content. "Zero deleted lines" alone is not enough — git
# reports an insertion in the middle of a file as pure additions (e.g.
# "2  0"), which would pass a numstat-only check while violating G4.
#
# Index and worktree are checked SEPARATELY and both must pass. Checking only
# worktree-vs-HEAD is not enough: a rewrite staged in the index while the
# worktree is restored to the original content leaves worktree-vs-HEAD empty,
# so the violation would be invisible (the "MM" state).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}" || { echo "test_journal_append.sh: cannot cd to ${REPO_ROOT}" >&2; exit 2; }

PATHS=(journal/ ':(glob)examples/*/journal/**')
FAILS=0
SL_TMP="$(mktemp -d)"
trap 'rm -rf "${SL_TMP}"' EXIT

# sl_prefix_ok <mode> <path> [<a> <b>] — 0 iff the old version of <path> is a
# byte-exact prefix of the new one (or the file is new on the old side).
# modes: index (HEAD -> index), worktree (index -> worktree), range (a -> b)
sl_prefix_ok() {
  local mode=$1 path=$2 a=${3:-} b=${4:-}
  local oldf="${SL_TMP}/old" newf="${SL_TMP}/new" oldsize
  case "${mode}" in
    index)    git cat-file blob "HEAD:${path}" > "${oldf}" 2>/dev/null || return 0
              git cat-file blob ":0:${path}"   > "${newf}" 2>/dev/null || return 1;;
    worktree) git cat-file blob ":0:${path}"   > "${oldf}" 2>/dev/null || return 0
              cat -- "${path}" > "${newf}" 2>/dev/null || return 1;;
    range)    git cat-file blob "${a}:${path}" > "${oldf}" 2>/dev/null || return 0
              git cat-file blob "${b}:${path}" > "${newf}" 2>/dev/null || return 1;;
    *) return 1;;
  esac
  oldsize=$(( $(wc -c < "${oldf}") ))
  head -c "${oldsize}" "${newf}" | cmp -s - "${oldf}"
}

# sl_check_diff <mode> [<a> <b>] — fail on deleted lines, renames, binaries,
# and non-prefix modifications. Sets SL_CHECKED (files seen). Must NOT be
# called in a command substitution: the subshell would discard FAILS.
sl_check_diff() {
  local mode=$1 a=${2:-} b=${3:-}
  local label=${mode} diffargs=()
  case "${mode}" in
    index)    diffargs=(--cached HEAD);;
    worktree) diffargs=();;
    range)    diffargs=("${a}" "${b}"); label="${a}..${b}";;
  esac
  local checked=0 added deleted path status_path status
  while IFS=$'\t' read -r added deleted path; do
    [[ -z "${path:-}" ]] && continue
    checked=$((checked+1))
    if [[ "${deleted}" == "-" || "${added}" == "-" ]]; then
      # git reports "-  -" for binary files: line-based append-only cannot be
      # verified, so a modified binary under journal/ is a violation by
      # definition.
      echo "FAIL [${label}]: ${path} is binary — journal files must be text so appends are verifiable (G4)" >&2
      FAILS=$((FAILS+1))
    elif [[ "${deleted}" != "0" ]]; then
      echo "FAIL [${label}]: ${path} has ${deleted} deleted line(s) — journal files are append-only (G4)" >&2
      FAILS=$((FAILS+1))
    elif ! sl_prefix_ok "${mode}" "${path}" "${a}" "${b}"; then
      echo "FAIL [${label}]: ${path} — old content is not a byte prefix of the new (insertion or in-place edit, G4)" >&2
      FAILS=$((FAILS+1))
    else
      echo "  ok [${label}]: ${path} (+${added}, old is a prefix)"
    fi
  done < <(git diff --numstat "${diffargs[@]}" -- "${PATHS[@]}")

  while IFS= read -r status_path; do
    [[ -z "${status_path}" ]] && continue
    status="${status_path%%$'\t'*}"
    case "${status}" in
      D*|R*) echo "FAIL [${label}]: ${status_path} — journal files must not be deleted or renamed (G4)" >&2
             FAILS=$((FAILS+1));;
    esac
  done < <(git diff --name-status "${diffargs[@]}" -- "${PATHS[@]}")

  SL_CHECKED=${checked}
}

if (( $# == 2 )); then
  echo "checking journal/ append-only: $1..$2"
  sl_check_diff range "$1" "$2"
else
  echo "checking journal/ append-only: index vs HEAD, worktree vs index"
  # 1. staged changes (index vs HEAD) — catches the masked "MM" rewrite
  sl_check_diff index; staged=${SL_CHECKED}
  # 2. unstaged changes (worktree vs index)
  sl_check_diff worktree; unstaged=${SL_CHECKED}

  if (( staged == 0 && unstaged == 0 && FAILS == 0 )); then
    if git rev-parse -q --verify HEAD~1 >/dev/null; then
      echo "nothing pending — checking HEAD~1..HEAD instead"
      sl_check_diff range HEAD~1 HEAD > /dev/null
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
