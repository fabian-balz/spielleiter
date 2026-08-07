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
"${ORACLE}" yesno --likelihood maybe >/dev/null 2>&1 && fail "bad likelihood accepted" || ok "rejects bad likelihood"
"${ORACLE}" table >/dev/null 2>&1        && fail "table w/o id accepted"   || ok "rejects table without id"
"${ORACLE}" table missing >/dev/null 2>&1 && fail "unknown table accepted" || ok "rejects unknown table"
"${ORACLE}" table nodie >/dev/null 2>&1  && fail "table w/o die accepted"  || ok "rejects table without die:"

echo "== yesno: reproducibility, format, mapping =="
a=$("${ORACLE}" yesno --seed 42 | cut -d'|' -f3-)
b=$("${ORACLE}" yesno --seed 42 | cut -d'|' -f3-)
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
    line=$("${ORACLE}" yesno --likelihood "${lk}" --seed "${seed}")
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
  line=$("${ORACLE}" table testtable --seed "${seed}")
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
  if ! "${ORACLE}" table gap --seed "${seed}" >/dev/null 2>&1; then gap_fail=1; break; fi
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
if "${ORACLE}" table komplikationen >/dev/null 2>&1; then ok "komplikationen resolves"; else fail "komplikationen failed"; fi

echo
echo "test_oracle.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
