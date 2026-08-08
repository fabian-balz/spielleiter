#!/usr/bin/env bash
# oracle.sh — solo-play oracle and random-table lookup for Spielleiter.
#
# Usage:
#   oracle.sh yesno [--likelihood likely|even|unlikely] --reason "text" [--seed N]
#   oracle.sh table <table-id> --reason "text" [--seed N]
#
# --reason is REQUIRED (single line, no '|'); <table-id> is a bare name, never
# a path — see sl_table. Pure bash + coreutils; no awk at runtime.
#
# yesno rolls 1d20 and maps it to Yes / Yes-but / No-but / No.
# The exact odds are documented in system/system.md (section "Orakel").
#   even:     Yes 1-8   Yes-but 9-10   No-but 11-12  No 13-20
#   likely:   Yes 1-11  Yes-but 12-13  No-but 14-15  No 16-20
#   unlikely: Yes 1-5   Yes-but 6-7    No-but 8-9    No 10-20
#
# table resolves system/tables/<table-id>.yaml. Table format:
#   id: <table-id>
#   die: <NdM expr>
#   entries:
#     1-2: "entry text"
#     3: "entry text"
#
# Every invocation appends exactly one line to journal/rolls.log:
#   <ISO-8601 UTC> | oracle:yesno(<likelihood>) | dice=[n] | total=<n> | result=<r> | reason=<text>
#   <ISO-8601 UTC> | table:<id> | dice=[...] | total=<n> | result=<entry> | reason=<text>
#
# Env overrides (for tests only):
#   SPIELLEITER_ROLL_LOG   — alternative log file path
#   SPIELLEITER_TABLES_DIR — alternative tables directory

set -euo pipefail

_SL_ORACLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/roll.sh
source "${_SL_ORACLE_DIR}/roll.sh"

SL_TABLES_DIR="${SPIELLEITER_TABLES_DIR:-${_SL_REPO_ROOT}/system/tables}"

sl_yesno() {
  local likelihood=$1 reason=$2
  if ! sl_roll_expr "1d20"; then
    echo "oracle.sh: internal roll failed" >&2; return 1
  fi
  local n=${SL_TOTAL} result
  case "${likelihood}" in
    even)     if   (( n <= 8 ));  then result="Yes"
              elif (( n <= 10 )); then result="Yes-but"
              elif (( n <= 12 )); then result="No-but"
              else                     result="No"; fi;;
    likely)   if   (( n <= 11 )); then result="Yes"
              elif (( n <= 13 )); then result="Yes-but"
              elif (( n <= 15 )); then result="No-but"
              else                     result="No"; fi;;
    unlikely) if   (( n <= 5 ));  then result="Yes"
              elif (( n <= 7 ));  then result="Yes-but"
              elif (( n <= 9 ));  then result="No-but"
              else                     result="No"; fi;;
    *) echo "oracle.sh: invalid likelihood: ${likelihood} (use likely|even|unlikely)" >&2; return 2;;
  esac
  sl_log_line "$(sl_timestamp) | oracle:yesno(${likelihood}) | dice=[${n}] | total=${n} | result=${result} | reason=${reason}"
}

# sl_table_lookup <file> <roll> — print entry text whose range covers <roll>
sl_table_lookup() {
  local file=$1 roll=$2 in_entries=0 line lo hi
  local re='^  ([0-9]+)(-([0-9]+))?: *"(.*)" *$'
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "entries:" ]]; then in_entries=1; continue; fi
    if (( in_entries )) && [[ "${line}" =~ ^[^[:space:]] ]]; then in_entries=0; fi
    if (( in_entries )) && [[ "${line}" =~ ${re} ]]; then
      lo=${BASH_REMATCH[1]}; hi=${BASH_REMATCH[3]:-${lo}}
      if (( roll >= lo && roll <= hi )); then
        printf '%s\n' "${BASH_REMATCH[4]}"
        return 0
      fi
    fi
  done < "${file}"
  return 1
}

# sl_read_die <file> — print the value of the top-level `die:` field (pure bash)
sl_read_die() {
  local file=$1 line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^die:[[:space:]]*(.+)[[:space:]]*$ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "${file}"
  return 1
}

# sl_read_id <file> — print the value of the top-level `id:` field (pure bash)
sl_read_id() {
  local file=$1 line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^id:[[:space:]]*(.+)[[:space:]]*$ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "${file}"
  return 1
}

sl_table() {
  local table_id=$1 reason=$2
  # A table id is a bare name, never a path. Without this, `table ../../gm/plot`
  # would read and log a file outside system/tables/ — a G6 secret-leak vector.
  if ! [[ "${table_id}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "oracle.sh: invalid table id: ${table_id} (letters, digits, '_' and '-' only; no paths)" >&2
    return 1
  fi
  local file="${SL_TABLES_DIR}/${table_id}.yaml"
  if [[ ! -f "${file}" ]]; then
    echo "oracle.sh: unknown table: ${table_id} (no ${file})" >&2; return 1
  fi
  # Belt and braces: the resolved file must still sit directly in the tables
  # directory (catches symlinks pointing out of the tree).
  local resolved_dir tables_dir
  resolved_dir="$(cd "$(dirname "${file}")" 2>/dev/null && pwd -P)" || resolved_dir=""
  tables_dir="$(cd "${SL_TABLES_DIR}" 2>/dev/null && pwd -P)" || tables_dir=""
  if [[ -z "${resolved_dir}" || "${resolved_dir}" != "${tables_dir}" ]]; then
    echo "oracle.sh: table ${table_id} resolves outside ${SL_TABLES_DIR}" >&2; return 1
  fi
  # The declared id must match the requested one, so a table cannot be logged
  # under a name that misrepresents its content (ADR 0003).
  local declared
  declared="$(sl_read_id "${file}")" || declared=""
  if [[ -z "${declared}" ]]; then
    echo "oracle.sh: table ${table_id} has no 'id:' field" >&2; return 1
  fi
  if [[ "${declared}" != "${table_id}" ]]; then
    echo "oracle.sh: table id mismatch: file declares '${declared}', requested '${table_id}'" >&2
    return 1
  fi
  local die
  die="$(sl_read_die "${file}")" || die=""
  if [[ -z "${die}" ]]; then
    echo "oracle.sh: table ${table_id} has no 'die:' field" >&2; return 1
  fi
  if ! sl_roll_expr "${die}"; then
    echo "oracle.sh: table ${table_id} has invalid die expression: ${die}" >&2; return 1
  fi
  local entry
  if ! entry="$(sl_table_lookup "${file}" "${SL_TOTAL}")"; then
    echo "oracle.sh: table ${table_id} has no entry for roll ${SL_TOTAL}" >&2; return 1
  fi
  # shellcheck disable=SC2086
  sl_log_line "$(sl_timestamp) | table:${table_id} | dice=[$(sl_join_csv ${SL_DICE})] | total=${SL_TOTAL} | result=${entry} | reason=${reason}"
}

sl_oracle_main() {
  local mode="" table_id="" likelihood="even" reason="" seed=""
  while (( $# > 0 )); do
    case "$1" in
      --likelihood) shift; likelihood="${1:-}";;
      --reason)     shift; reason="${1:-}";;
      --seed)       shift; seed="${1:-}";;
      -h|--help)
        echo "Usage: oracle.sh yesno [--likelihood likely|even|unlikely] | oracle.sh table <table-id>"
        return 0;;
      -*)
        echo "oracle.sh: unknown option: $1" >&2; return 2;;
      *)
        if [[ -z "${mode}" ]]; then mode="$1"
        elif [[ "${mode}" == "table" && -z "${table_id}" ]]; then table_id="$1"
        else echo "oracle.sh: too many arguments" >&2; return 2; fi;;
    esac
    shift
  done

  if [[ -n "${seed}" ]]; then
    [[ "${seed}" =~ ^[0-9]+$ ]] || { echo "oracle.sh: --seed must be a non-negative integer" >&2; return 2; }
    sl_srand "${seed}"
  fi

  if [[ "${mode}" == "yesno" || "${mode}" == "table" ]]; then
    sl_check_reason "${reason}" || return 2
  fi

  case "${mode}" in
    yesno) sl_yesno "${likelihood}" "${reason}";;
    table)
      if [[ -z "${table_id}" ]]; then
        echo "oracle.sh: table mode needs a table id" >&2; return 2
      fi
      sl_table "${table_id}" "${reason}";;
    "") echo "oracle.sh: missing mode (yesno | table <id>)" >&2; return 2;;
    *)  echo "oracle.sh: unknown mode: ${mode}" >&2; return 2;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  sl_oracle_main "$@"
fi
