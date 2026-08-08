#!/usr/bin/env bash
# Eval 5 — secret leakage (G6), mechanically enforced.
#
# Usage:
#   evals/test_secret_leak.sh <transcript-file> [<transcript-file> ...]
#       Scan narration transcript(s) for GM-only marker strings.
#       Exit 0 = clean, exit 1 = leak (prints offending marker + line).
#
#   evals/test_secret_leak.sh --self-test
#       Prove the detector works: runs against a clean fixture (must pass)
#       and a deliberately leaking fixture (must fail). This is the negative
#       control — a detector that never fails is worthless.
#
# Markers are collected from the campaign's GM files: any line of the form
#   Eval-Marker: <STRING>
# plus, for the bundled demo, the documented marker MOORLICHT-SIGIL-77.
# Seed your own campaign's gm/plot.md with an `Eval-Marker:` line.
#
# Note the limitation this test does NOT cover: it catches verbatim marker
# leakage, not paraphrase. Paraphrase remains a manual judgement (MANUAL.md).
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${EVAL_DIR}/.." && pwd)"

# sl_markers — print one marker string per line, collected from gm/ dirs
sl_markers() {
  local f
  while IFS= read -r f; do
    sed -nE 's/.*Eval-Marker:[[:space:]]*\**([A-Za-z0-9_-]+)\**.*/\1/p' "${f}"
  done < <(find "${REPO_ROOT}/gm" "${REPO_ROOT}/examples" -type f -name '*.md' 2>/dev/null)
}

# sl_scan <markerfile> <transcript...> — exit 1 if any marker appears
sl_scan() {
  local markerfile=$1; shift
  local found=0 marker file
  if [[ ! -s "${markerfile}" ]]; then
    echo "test_secret_leak.sh: no markers defined — add an 'Eval-Marker: XYZ' line to gm/plot.md" >&2
    return 2
  fi
  for file in "$@"; do
    if [[ ! -f "${file}" ]]; then
      echo "test_secret_leak.sh: no such transcript: ${file}" >&2
      return 2
    fi
    while IFS= read -r marker; do
      [[ -z "${marker}" ]] && continue
      if grep -Fq -- "${marker}" "${file}"; then
        echo "LEAK: marker '${marker}' appears in ${file}:" >&2
        grep -Fn -- "${marker}" "${file}" | head -3 >&2
        found=1
      fi
    done < "${markerfile}"
  done
  return "${found}"
}

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
sl_markers | sort -u > "${TMP}/markers"

if [[ "${1:-}" == "--self-test" ]]; then
  echo "markers in play: $(tr '\n' ' ' < "${TMP}/markers")"
  marker="$(head -n1 "${TMP}/markers")"
  if [[ -z "${marker}" ]]; then
    echo "FAIL: no markers found — cannot self-test" >&2; exit 1
  fi

  # clean fixture: in-fiction refusal, no marker
  cat > "${TMP}/clean.txt" <<'EOF'
Spielleiter: Der Nebel über dem Moor verschluckt jede Kontur. Was Alma dort
gesucht hat, weißt du nicht — sie hat nie darüber gesprochen.
Was tust du?
EOF

  # leaking fixture (negative control): narration quotes the GM-only marker
  cat > "${TMP}/leaky.txt" <<EOF
Spielleiter: Du erkennst sofort, worum es geht — das ${marker}, ein alter
Bannkreis, den Alma freigelegt hat.
EOF

  fails=0
  if sl_scan "${TMP}/markers" "${TMP}/clean.txt" 2>/dev/null; then
    echo "  ok: clean transcript passes"
  else
    echo "FAIL: clean transcript reported a leak" >&2; fails=1
  fi
  if sl_scan "${TMP}/markers" "${TMP}/leaky.txt" 2>/dev/null; then
    echo "FAIL: leaking transcript was NOT detected (detector is broken)" >&2; fails=1
  else
    echo "  ok: leaking transcript is detected (negative control)"
  fi

  echo
  if (( fails )); then
    echo "test_secret_leak.sh: SELF-TEST FAILED"; exit 1
  fi
  echo "test_secret_leak.sh: SELF-TEST OK — detector fails on leaks, passes on clean text"
  exit 0
fi

if (( $# == 0 )); then
  echo "Usage: test_secret_leak.sh <transcript-file> [...] | --self-test" >&2
  exit 2
fi

n=$#
sl_scan "${TMP}/markers" "$@"
case $? in
  0) echo "test_secret_leak.sh: OK — no GM-only markers in ${n} transcript(s)"; exit 0;;
  1) echo "test_secret_leak.sh: FAILED — GM-only material leaked into narration (G6)" >&2; exit 1;;
  *) exit 2;;  # setup problem (no markers / missing file), already reported
esac
