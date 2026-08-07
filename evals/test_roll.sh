#!/usr/bin/env bash
# Eval 6 — roll.sh unit tests (plain bash asserts, no bats dependency).
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${EVAL_DIR}/.." && pwd)"
ROLL="${REPO_ROOT}/tools/roll.sh"

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_T}"' EXIT
export SPIELLEITER_ROLL_LOG="${TMPDIR_T}/rolls.log"

PASS=0 FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }

assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then ok "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

echo "== invalid expressions exit non-zero, log stays untouched =="
for expr in "" "d6" "2d" "2x6" "abc" "0d6" "2d1" "4d6kh5" "4d6kh0" "1d20++2" "101d6"; do
  if "${ROLL}" "${expr}" >/dev/null 2>&1; then
    fail "invalid expr accepted: '${expr}'"
  else
    ok "rejects '${expr}'"
  fi
done
lines=0
[[ -f "${SPIELLEITER_ROLL_LOG}" ]] && lines=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
assert_eq "no log lines written for invalid exprs" "0" "${lines}"

echo "== --seed reproducibility =="
a=$("${ROLL}" 4d6kh3 --seed 42 | cut -d'|' -f3-)
b=$("${ROLL}" 4d6kh3 --seed 42 | cut -d'|' -f3-)
assert_eq "same seed -> same dice/total" "${a}" "${b}"
c=$("${ROLL}" 4d6kh3 --seed 43 | cut -d'|' -f3-)
if [[ "${a}" != "${c}" ]]; then ok "different seed -> different result"; else fail "seeds 42/43 collided"; fi

echo "== log format stability =="
line=$("${ROLL}" 2d6+3 --seed 1 --reason "Probe: Klettern")
re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| 2d6\+3 \| dice=\[[1-6],[1-6]\] \| total=[0-9]+ \| reason=Probe: Klettern$'
if [[ "${line}" =~ ${re} ]]; then ok "plain roll line format"; else fail "format mismatch: ${line}"; fi

line=$("${ROLL}" 4d6kh3 --seed 1)
re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| 4d6kh3 \| dice=\[[1-6],[1-6],[1-6],[1-6]\] \| kept=\[[1-6],[1-6],[1-6]\] \| total=[0-9]+ \| reason=$'
if [[ "${line}" =~ ${re} ]]; then ok "kh roll line format"; else fail "kh format mismatch: ${line}"; fi

echo "== arithmetic: total = sum(kept) + modifier =="
line=$("${ROLL}" 4d6kh3+2 --seed 42)
kept=$(sed -E 's/.*kept=\[([0-9,]+)\].*/\1/' <<< "${line}")
total=$(sed -E 's/.*total=([0-9-]+).*/\1/' <<< "${line}")
sum=0; IFS=, read -ra ks <<< "${kept}"; for k in "${ks[@]}"; do sum=$((sum+k)); done
assert_eq "kh3+2 total" "$((sum+2))" "${total}"

line=$("${ROLL}" 2d6-1 --seed 5)
dice=$(sed -E 's/.*dice=\[([0-9,]+)\].*/\1/' <<< "${line}")
total=$(sed -E 's/.*total=(-?[0-9]+).*/\1/' <<< "${line}")
sum=0; IFS=, read -ra ds <<< "${dice}"; for d in "${ds[@]}"; do sum=$((sum+d)); done
assert_eq "2d6-1 total" "$((sum-1))" "${total}"

echo "== dice within bounds =="
line=$("${ROLL}" 10d8 --seed 9)
dice=$(sed -E 's/.*dice=\[([0-9,]+)\].*/\1/' <<< "${line}")
bounds_ok=1
IFS=, read -ra ds <<< "${dice}"
for d in "${ds[@]}"; do (( d >= 1 && d <= 8 )) || bounds_ok=0; done
assert_eq "10d8 count" "10" "${#ds[@]}"
assert_eq "10d8 all in 1..8" "1" "${bounds_ok}"

echo "== exactly one log line appended per invocation, stdout == log line =="
before=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
out=$("${ROLL}" 1d20 --reason "append-check")
after=$(wc -l < "${SPIELLEITER_ROLL_LOG}")
assert_eq "log grows by 1" "$((before+1))" "${after}"
assert_eq "stdout matches last log line" "$(tail -n1 "${SPIELLEITER_ROLL_LOG}")" "${out}"

echo
echo "test_roll.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
