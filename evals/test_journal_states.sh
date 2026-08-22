#!/usr/bin/env bash
# Negative controls for test_journal_append.sh (ADR 0016).
#
# Builds a throwaway git repo and drives it through every reachable journal
# state, asserting the expected verdict for each. A check that has never been
# observed failing is not a check — this is what proves the append-only eval
# actually rejects what it claims to reject.
#
# Usage: evals/test_journal_states.sh
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${EVAL_DIR}/test_journal_append.sh"

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_T}"' EXIT

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }

REPO="${TMPDIR_T}/repo"
mkdir -p "${REPO}/evals" "${REPO}/journal/sessions"
git -C "${REPO}" init -q .
cp "${CHECKER}" "${REPO}/evals/"
printf 'Zeile 1\nZeile 2\nZeile 3\n' > "${REPO}/journal/sessions/session-001.md"
git -C "${REPO}" add -A
git -C "${REPO}" -c user.name=t -c user.email=t@t commit -qm "session 001"
printf 'Zeile 4\n' >> "${REPO}/journal/sessions/session-001.md"
git -C "${REPO}" add -A
git -C "${REPO}" -c user.name=t -c user.email=t@t commit -qm "append"

reset_repo() {
  git -C "${REPO}" reset -q HEAD -- . 2>/dev/null
  git -C "${REPO}" checkout -q -- . 2>/dev/null
  rm -f "${REPO}/journal/blob.bin"
}

# expect <want-exit> <description> ; state must already be set up
expect() {
  local want=$1 desc=$2 got
  (cd "${REPO}" && bash evals/test_journal_append.sh >/dev/null 2>&1); got=$?
  if [[ "${got}" == "${want}" ]]; then ok "${desc} → exit ${got}"
  else fail "${desc}: expected exit ${want}, got ${got}"; fi
  reset_repo
}

SESSION="${REPO}/journal/sessions/session-001.md"

echo "== states that must PASS =="
expect 0 "clean tree"
printf 'Nachtrag\n' >> "${SESSION}";                                   expect 0 "unstaged append"
printf 'Nachtrag\n' >> "${SESSION}"; git -C "${REPO}" add -A;          expect 0 "staged append"
printf 'Neu\n' > "${REPO}/journal/sessions/session-002.md";            expect 0 "brand-new session file"

echo "== states that must FAIL =="
printf 'nur eine zeile\n' > "${SESSION}";                              expect 1 "unstaged rewrite"
printf 'nur eine zeile\n' > "${SESSION}"; git -C "${REPO}" add -A;     expect 1 "staged rewrite"

# the masked case: rewrite staged, worktree restored to the original content
printf 'Zeile 1\nGEAENDERT\nZeile 3\nZeile 4\n' > "${SESSION}"
git -C "${REPO}" add "journal/sessions/session-001.md"
printf 'Zeile 1\nZeile 2\nZeile 3\nZeile 4\n' > "${SESSION}"
expect 1 "rewrite staged, worktree restored (masked MM)"

# insertion in the MIDDLE: numstat reports it as pure additions ("N 0"),
# so only the byte-prefix check can catch it
printf 'Zeile 1\nEINGESCHOBEN\nZeile 2\nZeile 3\nZeile 4\n' > "${SESSION}"
expect 1 "mid-file insertion (unstaged; numstat says additions only)"
printf 'Zeile 1\nEINGESCHOBEN\nZeile 2\nZeile 3\nZeile 4\n' > "${SESSION}"
git -C "${REPO}" add "journal/sessions/session-001.md"
expect 1 "mid-file insertion (staged)"
# prepending at the very top is the same class
printf 'GANZ OBEN\nZeile 1\nZeile 2\nZeile 3\nZeile 4\n' > "${SESSION}"
expect 1 "prepend at top of file"

rm -f "${SESSION}";                                                    expect 1 "session file deleted"

# a NEWLY ADDED binary file: journal/ is text-only, so even an addition is
# refused — git reports '-  -' for it, and "unverifiable append" means "no"
printf 'A\x00B\x00C\x00' > "${REPO}/journal/added.bin"
git -C "${REPO}" add -A
expect 1 "newly added binary file"
git -C "${REPO}" rm -q --cached journal/added.bin 2>/dev/null; rm -f "${REPO}/journal/added.bin"

# a binary file REWRITE: line-based append-only is unverifiable, so refused
printf 'A\x00B\x00C\x00' > "${REPO}/journal/blob.bin"
git -C "${REPO}" add -A
git -C "${REPO}" -c user.name=t -c user.email=t@t commit -qm "binary"
printf 'V\x00O\x00E\x00L\x00L\x00I\x00G\x00-\x00A\x00N\x00D\x00E\x00R\x00S\x00' > "${REPO}/journal/blob.bin"
(cd "${REPO}" && bash evals/test_journal_append.sh >/dev/null 2>&1); got=$?
if [[ "${got}" == "1" ]]; then ok "binary rewrite → exit 1"
else fail "binary rewrite: expected exit 1, got ${got} (git reports '-  -' for binary diffs)"; fi

echo
echo "test_journal_states.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
