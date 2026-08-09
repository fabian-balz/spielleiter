#!/usr/bin/env bash
# oracle.sh unit tests (plain bash asserts, no bats dependency).
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${EVAL_DIR}/.." && pwd)"
ORACLE="${REPO_ROOT}/tools/oracle.sh"

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_T}"' EXIT
export SPIELLEITER_ROLL_LOG="${TMPDIR_T}/rolls.log"
export SPIELLEITER_TABLES_DIR="${TMPDIR_T}/tables"
mkdir -p "${SPIELLEITER_TABLES_DIR}"
# Create the log up front: every assertion that counts or greps lines must
# read a file that exists. Reading a missing file silently yields empty
# output, which turns "no forged line in the log" into a vacuous pass.
: > "${SPIELLEITER_ROLL_LOG}"

cat > "${SPIELLEITER_TABLES_DIR}/testtable.yaml" <<'EOF'
id: testtable
die: 1d6
entries:
  1-2: "low entry"
  3: "mid entry"
  4-6: "high entry"
EOF

cat > "${SPIELLEITER_TABLES_DIR}/nodie.yaml" <<'EOF'
id: nodie
entries:
  1-6: "whatever"
EOF

cat > "${SPIELLEITER_TABLES_DIR}/gap.yaml" <<'EOF'
id: gap
die: 1d6
entries:
  1-2: "only low"
EOF

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
assert_eq() { if [[ "$2" == "$3" ]]; then ok "$1"; else fail "$1 (expected '$2', got '$3')"; fi; }

echo "== argument validation =="
"${ORACLE}" >/dev/null 2>&1              && fail "no mode accepted"        || ok "rejects missing mode"
"${ORACLE}" frobnicate >/dev/null 2>&1   && fail "bad mode accepted"       || ok "rejects unknown mode"
"${ORACLE}" yesno --likelihood maybe --reason "t" >/dev/null 2>&1 && fail "bad likelihood accepted" || ok "rejects bad likelihood"
"${ORACLE}" table >/dev/null 2>&1        && fail "table w/o id accepted"   || ok "rejects table without id"
"${ORACLE}" table missing --reason "t" >/dev/null 2>&1 && fail "unknown table accepted" || ok "rejects unknown table"
"${ORACLE}" table nodie --reason "t" >/dev/null 2>&1  && fail "table w/o die accepted"  || ok "rejects table without die:"

echo "== table id is a bare name: no path traversal (G6) =="
# A readable, well-formed table placed one level above the tables dir must
# stay unreachable — otherwise `table ../../gm/plot` could leak secrets.
cat > "${TMPDIR_T}/outside.yaml" <<'EOF'
id: outside
die: 1d2
entries:
  1-2: "SECRET-SHOULD-NEVER-APPEAR"
EOF
for evil in "../outside" "../../etc/passwd" "/etc/passwd" "foo/bar" "." ".." "a;b" 'x$(id)'; do
  if "${ORACLE}" table "${evil}" --reason "t" >/dev/null 2>&1; then
    fail "traversal accepted: ${evil}"
  else
    ok "rejects table id '${evil}'"
  fi
done
if grep -q "SECRET-SHOULD-NEVER-APPEAR" "${SPIELLEITER_ROLL_LOG}" 2>/dev/null; then
  fail "outside-table content reached the log"
else
  ok "no outside-table content in log"
fi

echo "== a symlinked table is refused (leaf symlink escapes a dir-only check) =="
ln -sf "${TMPDIR_T}/outside.yaml" "${SPIELLEITER_TABLES_DIR}/symlinked.yaml"
# make the symlink internally consistent so ONLY the symlink check can reject it
sed -i 's/^id: outside/id: symlinked/' "${TMPDIR_T}/outside.yaml" 2>/dev/null || \
  sed -i '' 's/^id: outside/id: symlinked/' "${TMPDIR_T}/outside.yaml"
if "${ORACLE}" table symlinked --reason "t" >/dev/null 2>&1; then
  fail "symlinked table accepted — content outside the tables dir is reachable"
else
  ok "rejects symlinked table"
fi
if grep -q "SECRET-SHOULD-NEVER-APPEAR" "${SPIELLEITER_ROLL_LOG}" 2>/dev/null; then
  fail "symlinked-table content reached the log"
else
  ok "no symlinked-table content in log"
fi
rm -f "${SPIELLEITER_TABLES_DIR}/symlinked.yaml"

echo "== a symlinked tables DIRECTORY is refused =="
# Canonicalizing both sides against the same symlink is tautological, so the
# directory has to be checked directly. Without this the whole tables tree
# can be redirected outside the repo.
mkdir -p "${TMPDIR_T}/realtables"
cat > "${TMPDIR_T}/realtables/dirlinked.yaml" <<'EOF'
id: dirlinked
die: 1d2
entries:
  1-2: "DIRECTORY-SYMLINK-SHOULD-NEVER-APPEAR"
EOF
ln -sfn "${TMPDIR_T}/realtables" "${TMPDIR_T}/linkedtables"
if SPIELLEITER_TABLES_DIR="${TMPDIR_T}/linkedtables" "${ORACLE}" table dirlinked --reason "t" >/dev/null 2>&1; then
  fail "symlinked tables directory accepted — the whole table tree can be redirected"
else
  ok "rejects symlinked tables directory"
fi
if grep -q "DIRECTORY-SYMLINK-SHOULD-NEVER-APPEAR" "${SPIELLEITER_ROLL_LOG}" 2>/dev/null; then
  fail "directory-symlink content reached the log"
else
  ok "no directory-symlink content in log"
fi

echo "== table entries cannot inject log fields (G1) =="
cat > "${SPIELLEITER_TABLES_DIR}/inject.yaml" <<'EOF'
id: inject
die: 1d2
entries:
  1-2: "harmless | total=999 | reason=forged-field"
EOF
before=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
if "${ORACLE}" table inject --reason "t" >/dev/null 2>&1; then
  fail "entry containing '|' accepted — extra log fields forged"
else
  ok "rejects entry containing '|'"
fi
after=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
assert_eq "rejected entry wrote nothing to the log" "${before}" "${after}"
if grep -q "forged-field" "${SPIELLEITER_ROLL_LOG}"; then
  fail "forged field reached the log"
else
  ok "no forged field in log"
fi
# Structural invariant: every log line carries exactly the documented number
# of '|' separators. Checked against REAL lines produced right here — an
# earlier version ran this over a log that did not exist yet and reported
# "ok" over zero lines (a vacuous pass).
sl_count_badfields() { # <file> -> prints number of malformed lines
  local f=$1 bad=0 l n
  while IFS= read -r l; do
    [[ -z "${l}" ]] && continue
    n=$(tr -cd '|' <<< "${l}" | wc -c)
    case "${l}" in
      *"| result="*) (( n == 5 )) || bad=$((bad+1));;   # ts|expr|dice|total|result|reason
      *"| kept="*)   (( n == 5 )) || bad=$((bad+1));;   # ts|expr|dice|kept|total|reason
      *)             (( n == 4 )) || bad=$((bad+1));;   # ts|expr|dice|total|reason
    esac
  done < "${f}"
  echo "${bad}"
}

# produce valid lines of every shape, then assert the log is non-empty
"${ORACLE}" yesno --seed 5 --reason "struktur-yesno" >/dev/null
"${ORACLE}" table testtable --seed 5 --reason "struktur-table" >/dev/null
"${REPO_ROOT}/tools/roll.sh" 2d6+1 --seed 5 --reason "struktur-roll" >/dev/null
"${REPO_ROOT}/tools/roll.sh" 4d6kh3 --seed 5 --reason "struktur-kept" >/dev/null
loglines=$(grep -c . "${SPIELLEITER_ROLL_LOG}")
if (( loglines >= 4 )); then
  ok "structure check has ${loglines} real log lines to inspect (not vacuous)"
else
  fail "structure check would run over ${loglines} lines — vacuous"
fi
assert_eq "every real log line has the documented field count" "0" "$(sl_count_badfields "${SPIELLEITER_ROLL_LOG}")"

# negative control: a hand-forged log with an injected field MUST be flagged
cat > "${TMPDIR_T}/tampered.log" <<'EOF'
2026-01-01T00:00:00Z | 1d6 | dice=[3] | total=3 | reason=ok
2026-01-01T00:00:01Z | table:x | dice=[1] | total=1 | result=harmless | total=999 | reason=forged | reason=t
EOF
tampered_bad=$(sl_count_badfields "${TMPDIR_T}/tampered.log")
if (( tampered_bad >= 1 )); then
  ok "structure check flags a tampered log (negative control)"
else
  fail "structure check did NOT flag a tampered log — the check is worthless"
fi

echo "== declared id must match requested id =="
cat > "${SPIELLEITER_TABLES_DIR}/mismatch.yaml" <<'EOF'
id: something-else
die: 1d2
entries:
  1-2: "x"
EOF
"${ORACLE}" table mismatch --reason "t" >/dev/null 2>&1 && fail "id mismatch accepted" || ok "rejects id mismatch"
cat > "${SPIELLEITER_TABLES_DIR}/noid.yaml" <<'EOF'
die: 1d2
entries:
  1-2: "x"
EOF
"${ORACLE}" table noid --reason "t" >/dev/null 2>&1 && fail "missing id accepted" || ok "rejects table without id:"

echo "== reason is mandatory and single-line =="
"${ORACLE}" yesno >/dev/null 2>&1                    && fail "yesno w/o reason"   || ok "yesno rejects missing --reason"
"${ORACLE}" table testtable >/dev/null 2>&1          && fail "table w/o reason"   || ok "table rejects missing --reason"
"${ORACLE}" yesno --reason $'a\nb | fake' >/dev/null 2>&1 && fail "newline reason" || ok "rejects newline in --reason"
"${ORACLE}" yesno --reason "a|b" >/dev/null 2>&1     && fail "pipe reason"        || ok "rejects '|' in --reason"

echo "== yesno: reproducibility, format, mapping =="
a=$("${ORACLE}" yesno --seed 42 --reason "t" | cut -d'|' -f3-)
b=$("${ORACLE}" yesno --seed 42 --reason "t" | cut -d'|' -f3-)
assert_eq "same seed -> same yesno" "${a}" "${b}"

for lk in likely even unlikely; do
  line=$("${ORACLE}" yesno --likelihood "${lk}" --seed 7 --reason "t")
  re="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| oracle:yesno\(${lk}\) \| dice=\[[0-9]+\] \| total=[0-9]+ \| result=(Yes|Yes-but|No-but|No) \| reason=t$"
  if [[ "${line}" =~ ${re} ]]; then ok "yesno(${lk}) line format"; else fail "yesno(${lk}) format: ${line}"; fi
done

# exact mapping check: sweep seeds, recompute expected result from the rolled
# number per the odds documented in system/system.md § Orakel
map_even()     { local n=$1; if ((n<=8)); then echo Yes; elif ((n<=10)); then echo Yes-but; elif ((n<=12)); then echo No-but; else echo No; fi; }
map_likely()   { local n=$1; if ((n<=11)); then echo Yes; elif ((n<=13)); then echo Yes-but; elif ((n<=15)); then echo No-but; else echo No; fi; }
map_unlikely() { local n=$1; if ((n<=5)); then echo Yes; elif ((n<=7)); then echo Yes-but; elif ((n<=9)); then echo No-but; else echo No; fi; }

map_ok=1
for lk in even likely unlikely; do
  for seed in $(seq 1 40); do
    line=$("${ORACLE}" yesno --likelihood "${lk}" --seed "${seed}" --reason "t")
    n=$(sed -E 's/.*total=([0-9]+).*/\1/' <<< "${line}")
    got=$(sed -E 's/.*result=([A-Za-z-]+).*/\1/' <<< "${line}")
    want=$("map_${lk}" "${n}")
    [[ "${got}" == "${want}" ]] || { map_ok=0; fail "yesno(${lk}) seed ${seed}: roll ${n} -> ${got}, want ${want}"; }
  done
done
(( map_ok )) && ok "yesno mapping matches documented odds (120 seeds)"

echo "== table: resolution, format, ranges =="
line=$("${ORACLE}" table testtable --seed 3 --reason "why")
re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| table:testtable \| dice=\[[1-6]\] \| total=[1-6] \| result=(low|mid|high) entry \| reason=why$'
if [[ "${line}" =~ ${re} ]]; then ok "table line format (id + entry logged)"; else fail "table format: ${line}"; fi

range_ok=1
for seed in $(seq 1 30); do
  line=$("${ORACLE}" table testtable --seed "${seed}" --reason "t")
  n=$(sed -E 's/.*total=([0-9]+).*/\1/' <<< "${line}")
  got=$(sed -E 's/.*result=(.*) \| reason=.*/\1/' <<< "${line}")
  case "${n}" in
    1|2) want="low entry";;
    3)   want="mid entry";;
    *)   want="high entry";;
  esac
  [[ "${got}" == "${want}" ]] || { range_ok=0; fail "table seed ${seed}: roll ${n} -> '${got}', want '${want}'"; }
done
(( range_ok )) && ok "range resolution correct (30 seeds)"

echo "== table with uncovered roll fails =="
gap_fail=0
for seed in $(seq 1 20); do
  if ! "${ORACLE}" table gap --seed "${seed}" --reason "t" >/dev/null 2>&1; then gap_fail=1; break; fi
done
(( gap_fail )) && ok "uncovered roll -> non-zero exit" || fail "gap table never failed in 20 seeds"

echo "== exactly one log line per invocation =="
before=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
out=$("${ORACLE}" yesno --reason "append-check")
after=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
assert_eq "log grows by 1" "$((before+1))" "${after}"
assert_eq "stdout matches last log line" "$(tail -n1 "${SPIELLEITER_ROLL_LOG}")" "${out}"

echo "== real repo table komplikationen resolves =="
unset SPIELLEITER_TABLES_DIR
if "${ORACLE}" table komplikationen --reason "t" >/dev/null 2>&1; then ok "komplikationen resolves"; else fail "komplikationen failed"; fi

echo
echo "test_oracle.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
