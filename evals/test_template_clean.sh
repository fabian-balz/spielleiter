#!/usr/bin/env bash
# Template cleanliness: the template repo root must contain no campaign
# content (ADR 0006). Runs only where the template marker is present —
# in a campaign instance (marker removed) it passes trivially.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}" || { echo "test_template_clean.sh: cannot cd to ${REPO_ROOT}" >&2; exit 2; }

if ! head -n5 README.md 2>/dev/null | grep -q '^template: true$'; then
  echo "test_template_clean.sh: no template marker — campaign instance, nothing to check"
  exit 0
fi

FAILS=0
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS+1)); }
ok()   { echo "  ok: $1"; }

# 1. No session files in the root journal
sessions=$(( $(find journal/sessions -type f ! -name '.gitkeep' 2>/dev/null | wc -l) ))
if (( sessions > 0 )); then
  fail "journal/sessions/ contains ${sessions} session file(s)"
else
  ok "journal/sessions/ empty"
fi

# 2. rolls.log empty
if [[ -s journal/rolls.log ]]; then
  fail "journal/rolls.log is not empty"
else
  ok "journal/rolls.log empty"
fi

# 3. No entity files beyond the convention READMEs
for dir in world characters; do
  extra=$(( $(find "${dir}" -type f ! -name 'README.md' 2>/dev/null | wc -l) ))
  if (( extra > 0 )); then
    fail "${dir}/ contains ${extra} file(s) beyond README.md:"$'\n'"$(find "${dir}" -type f ! -name 'README.md')"
  else
    ok "${dir}/ holds only README.md"
  fi
done

# 4. gm/ is placeholder-only: no files beyond the known scaffold set
while IFS= read -r f; do
  case "${f}" in
    gm/README.md|gm/plot.md|gm/secrets/.gitkeep) ;;
    *) fail "unexpected file in gm/: ${f}";;
  esac
done < <(find gm -type f 2>/dev/null)
ok "gm/ scaffold files checked"

# 5. gm/plot.md still the placeholder (all content lines are headers,
#    blockquote, em-dash placeholders, or blank)
if [[ -f gm/plot.md ]] && grep -vE '^(#|>|—|$)' gm/plot.md | grep -q .; then
  fail "gm/plot.md contains non-placeholder content"
else
  ok "gm/plot.md is placeholder-only"
fi

# 6. system/rulings.md has no rulings (nothing after the format separator)
if [[ -f system/rulings.md ]] && sed -n '/^---$/,$p' system/rulings.md | tail -n +2 | grep -q .; then
  fail "system/rulings.md contains rulings — campaign content"
else
  ok "system/rulings.md empty of rulings"
fi

# 7. Demo identifiers from examples/ must not appear in template-owned files.
#    (evals/ and docs/adr/ legitimately discuss the demo, so they are exempt.)
DEMO_IDS='Kaya|Eschenau|Alma|Bren|MOORLICHT-SIGIL-77|Kräuterfrau|Steinfeld'
demo_hits=$(grep -rniE "${DEMO_IDS}" \
  --include='*.md' --include='*.yaml' \
  CLAUDE.md README.md system world characters gm .claude 2>/dev/null || true)
if [[ -n "${demo_hits}" ]]; then
  fail "demo identifiers outside examples/:"$'\n'"${demo_hits}"
else
  ok "no demo identifiers in template-owned files"
fi

# 8. Template-owned defaults still carry their template markers
if ! grep -q '^template: true$' <(head -n5 README.md); then
  fail "README.md lost its 'template: true' marker"
else
  ok "README.md template marker present"
fi

# 9. Default system and default table must be BYTE-IDENTICAL to the canonical
#    snapshots. A marker/label grep is not enough: appending a campaign house
#    rule to system/system.md keeps the label intact and would slip through.
SNAP=evals/snapshots/template-defaults.sha256
# Portable hashing: GNU coreutils ships sha256sum, stock macOS only shasum.
sl_sha256() { # <file> -> bare hex digest
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    echo "NO-HASH-TOOL"
  fi
}
if [[ ! -f "${SNAP}" ]]; then
  fail "missing snapshot file ${SNAP}"
elif [[ "$(sl_sha256 /dev/null)" == "NO-HASH-TOOL" ]]; then
  fail "neither sha256sum nor shasum available — cannot verify template defaults"
else
  # Report only the concrete mismatching files (no duplicate summary line).
  while read -r want rel; do
    [[ -z "${rel:-}" ]] && continue
    got="$(sl_sha256 "system/${rel}")"
    if [[ "${got}" == "${want}" ]]; then
      ok "system/${rel} matches its snapshot"
    else
      fail "template default modified: system/${rel} (snapshot ${want:0:12}…, actual ${got:0:12}…)"
    fi
  done < "${SNAP}"
fi

# 10. Only the shipped default table is present
while IFS= read -r t; do
  case "${t}" in
    system/tables/komplikationen.yaml) ;;
    *) fail "unexpected table in template: ${t}";;
  esac
done < <(find system/tables -type f 2>/dev/null)
ok "system/tables/ holds only the default table"

echo
if (( FAILS > 0 )); then
  echo "test_template_clean.sh: FAILED (${FAILS} violation(s)) — campaign content in the template repo"
  exit 1
fi
echo "test_template_clean.sh: OK — template root is clean"
