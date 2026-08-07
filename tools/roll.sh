#!/usr/bin/env bash
# roll.sh — deterministic, auditable dice roller for Spielleiter.
#
# Usage: roll.sh <expr> [--reason "text"] [--seed N]
#   expr: NdM, NdM+K, NdM-K, NdMkhX, NdMkhX+K   (e.g. 2d6+3, 1d20, 4d6kh3)
#
# Every invocation appends exactly one line to journal/rolls.log and prints
# the same line to stdout. The log is machine-written; never edit it by hand.
#
# Log line format (stable, do not change without updating evals/):
#   <ISO-8601 UTC> | <expr> | dice=[a,b,...] | total=<n> | reason=<text>
#   kh variant inserts: kept=[a,b,...] before total=
#
# Env overrides (for tests only):
#   SPIELLEITER_ROLL_LOG — alternative log file path
#
# This file is sourceable: `source roll.sh` defines functions without running.

set -euo pipefail

_SL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SL_REPO_ROOT="$(cd "${_SL_SCRIPT_DIR}/.." && pwd)"
SL_LOG_FILE="${SPIELLEITER_ROLL_LOG:-${_SL_REPO_ROOT}/journal/rolls.log}"

# --- RNG -------------------------------------------------------------------
# Unseeded: 4 bytes from /dev/urandom. Seeded: LCG (glibc constants) for
# reproducible tests; the low-order 16 bits are discarded because they cycle
# with a short period. sl_rand always prints an integer in 0..32767.
_SL_SEED_STATE=""

sl_srand() { _SL_SEED_STATE=$(( $1 % 2147483648 )); }

# sl_rand sets SL_RAND (not echo: command substitution would fork a subshell
# and lose the seeded state between calls).
sl_rand() {
  if [[ -n "${_SL_SEED_STATE}" ]]; then
    _SL_SEED_STATE=$(( (_SL_SEED_STATE * 1103515245 + 12345) % 2147483648 ))
    SL_RAND=$(( (_SL_SEED_STATE / 65536) % 32768 ))
  else
    local n
    n=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
    SL_RAND=$(( n % 32768 ))
  fi
}

# sl_die <sides> — sets SL_DIE to a result in 1..sides, rejection sampling
# (no modulo bias)
sl_die() {
  local sides=$1 limit
  limit=$(( 32768 / sides * sides ))
  while :; do
    sl_rand
    (( SL_RAND < limit )) && break
  done
  SL_DIE=$(( SL_RAND % sides + 1 ))
}

# --- logging ---------------------------------------------------------------
# sl_log_line <line> — append to rolls.log and echo to stdout
sl_log_line() {
  mkdir -p "$(dirname "${SL_LOG_FILE}")"
  printf '%s\n' "$1" >> "${SL_LOG_FILE}"
  printf '%s\n' "$1"
}

sl_timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- roll core -------------------------------------------------------------
# sl_roll_expr <expr>
# Sets: SL_DICE (space-separated), SL_KEPT (space-separated), SL_TOTAL
# Returns non-zero on invalid expr.
sl_roll_expr() {
  local expr=$1
  if ! [[ "${expr}" =~ ^([0-9]+)d([0-9]+)(kh([0-9]+))?([+-][0-9]+)?$ ]]; then
    return 1
  fi
  local count=${BASH_REMATCH[1]} sides=${BASH_REMATCH[2]}
  local keep=${BASH_REMATCH[4]:-} mod=${BASH_REMATCH[5]:-+0}
  (( count >= 1 && count <= 100 )) || return 1
  (( sides >= 2 && sides <= 1000 )) || return 1
  if [[ -n "${keep}" ]]; then
    (( keep >= 1 && keep <= count )) || return 1
  fi

  local dice=() i
  for (( i = 0; i < count; i++ )); do
    sl_die "${sides}"
    dice+=( "${SL_DIE}" )
  done
  SL_DICE="${dice[*]}"

  local kept=()
  if [[ -n "${keep}" ]]; then
    mapfile -t kept < <(printf '%s\n' "${dice[@]}" | sort -rn | head -n "${keep}")
    SL_KEPT="${kept[*]}"
  else
    kept=( "${dice[@]}" )
    SL_KEPT=""
  fi

  local sum=0 d
  for d in "${kept[@]}"; do sum=$(( sum + d )); done
  SL_TOTAL=$(( sum + mod ))
}

# sl_join_csv a b c -> a,b,c
sl_join_csv() { local IFS=,; echo "$*"; }

# --- main ------------------------------------------------------------------
sl_roll_main() {
  local expr="" reason="" seed=""
  while (( $# > 0 )); do
    case "$1" in
      --reason) shift; reason="${1:-}";;
      --seed)   shift; seed="${1:-}";;
      -h|--help)
        echo "Usage: roll.sh <expr> [--reason \"text\"] [--seed N]  (expr: 2d6+3, 1d20, 4d6kh3)"
        return 0;;
      -*)
        echo "roll.sh: unknown option: $1" >&2; return 2;;
      *)
        if [[ -n "${expr}" ]]; then echo "roll.sh: too many arguments" >&2; return 2; fi
        expr="$1";;
    esac
    shift
  done

  if [[ -z "${expr}" ]]; then
    echo "roll.sh: missing dice expression (e.g. 2d6+3)" >&2
    return 2
  fi
  if [[ -n "${seed}" ]]; then
    [[ "${seed}" =~ ^[0-9]+$ ]] || { echo "roll.sh: --seed must be a non-negative integer" >&2; return 2; }
    sl_srand "${seed}"
  fi

  if ! sl_roll_expr "${expr}"; then
    echo "roll.sh: invalid dice expression: ${expr}" >&2
    return 1
  fi

  local line kept_part=""
  if [[ -n "${SL_KEPT}" ]]; then
    # shellcheck disable=SC2086
    kept_part="kept=[$(sl_join_csv ${SL_KEPT})] | "
  fi
  # shellcheck disable=SC2086
  line="$(sl_timestamp) | ${expr} | dice=[$(sl_join_csv ${SL_DICE})] | ${kept_part}total=${SL_TOTAL} | reason=${reason}"
  sl_log_line "${line}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  sl_roll_main "$@"
fi
