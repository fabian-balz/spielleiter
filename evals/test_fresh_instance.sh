#!/usr/bin/env bash
# Fresh-instance lifecycle test (ADR 0006, ADR 0016).
#
# Builds a MINIMAL instance checkout — only the files a user would realistically
# get from "Use this template" minus everything /new-campaign is supposed to
# self-heal — and asserts the mechanical preconditions the skill depends on.
#
# Usage:
#   evals/test_fresh_instance.sh              # deterministic checks only
#   evals/test_fresh_instance.sh --with-agent # additionally drive headless
#                                             # Claude Code (needs credentials,
#                                             # network, and is nondeterministic)
#
# Scope, stated honestly: the deterministic part verifies the *environment*
# the skill acts on — marker detection, what is missing, that the tools work
# in a bare checkout, and that scaffold repair is possible and sufficient. It
# does NOT verify the agent's judgement (that it actually asks before writing
# campaign content); that is eval 2/3 territory in MANUAL.md, or --with-agent.
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${EVAL_DIR}/.." && pwd)"

WITH_AGENT=0
[[ "${1:-}" == "--with-agent" ]] && WITH_AGENT=1

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_T}"' EXIT
INST="${TMPDIR_T}/instance"

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }

# --- build a minimal instance: tools + skills + docs, no campaign scaffold ---
mkdir -p "${INST}/tools" "${INST}/.claude"
cp "${REPO_ROOT}/tools/roll.sh" "${REPO_ROOT}/tools/oracle.sh" "${INST}/tools/"
cp -R "${REPO_ROOT}/.claude/skills" "${INST}/.claude/"
cp "${REPO_ROOT}/CLAUDE.md" "${REPO_ROOT}/README.md" "${INST}/"
# The skill's documented restore paths copy the canonical defaults from
# examples/mini-campaign/. Include all three so those paths are exercisable.
mkdir -p "${INST}/examples/mini-campaign/system/tables"
cp "${REPO_ROOT}/examples/mini-campaign/system/system.md" \
   "${INST}/examples/mini-campaign/system/system.md"
cp "${REPO_ROOT}/examples/mini-campaign/system/rulings.md" \
   "${INST}/examples/mini-campaign/system/rulings.md"
cp "${REPO_ROOT}/examples/mini-campaign/system/tables/komplikationen.yaml" \
   "${INST}/examples/mini-campaign/system/tables/komplikationen.yaml"
git -C "${INST}" init -q .

# portable bounded-run shim: GNU coreutils `timeout`, macOS `gtimeout`, else
# run without a limit (documented as a test-only convenience, not a hard dep).
sl_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else shift; "$@"; fi
}

echo "== the minimal checkout really is missing what the skill must heal =="
for missing in system world characters journal gm system/tables journal/sessions; do
  if [[ -e "${INST}/${missing}" ]]; then
    fail "${missing} unexpectedly present — test would not exercise self-healing"
  else
    ok "${missing} absent, as intended"
  fi
done
if [[ ! -f "${INST}/journal/rolls.log" ]]; then ok "journal/rolls.log absent"; else fail "rolls.log present"; fi

echo "== template marker detection works in both directions =="
if head -n5 "${INST}/README.md" | grep -q '^template: true$'; then
  ok "copied README still carries the template marker (skill must refuse here)"
else
  fail "template marker missing from the copied README — refusal path untestable"
fi
# strip the marker the way the instantiation flow tells the user to
sed -i '1,3d' "${INST}/README.md" 2>/dev/null || sed -i '' '1,3d' "${INST}/README.md"
if head -n5 "${INST}/README.md" | grep -q '^template: true$'; then
  fail "marker survived removal — instances would be refused forever"
else
  ok "marker removal makes it an instance"
fi

echo "== tools are usable in a bare checkout =="
chmod -x "${INST}/tools/roll.sh" "${INST}/tools/oracle.sh"
if [[ -x "${INST}/tools/roll.sh" ]]; then
  fail "chmod -x did not take effect — executability check is meaningless"
else
  ok "tools start non-executable (the case step 0 must repair)"
fi
chmod +x "${INST}/tools/roll.sh" "${INST}/tools/oracle.sh"
[[ -x "${INST}/tools/roll.sh" && -x "${INST}/tools/oracle.sh" ]] \
  && ok "chmod +x repairs executability" || fail "tools still not executable"

# roll.sh must work before any scaffold exists: it creates its own log dir
out=$(cd "${INST}" && SPIELLEITER_ROLL_LOG="${INST}/journal/rolls.log" \
      tools/roll.sh 2d6 --seed 1 --reason "fresh-instance smoke" 2>&1)
if [[ "${out}" =~ \|\ 2d6\ \|\ dice= ]]; then
  ok "roll.sh works in a bare checkout and creates journal/"
else
  fail "roll.sh failed in a bare checkout: ${out}"
fi
[[ -f "${INST}/journal/rolls.log" ]] && ok "rolls.log created by the tool" \
  || fail "rolls.log not created"

# oracle.sh must refuse cleanly when system/tables/ does not exist yet,
# rather than inventing a result
out=$(cd "${INST}" && SPIELLEITER_ROLL_LOG="${INST}/journal/rolls.log" \
      tools/oracle.sh table komplikationen --reason "t" 2>&1); rc=$?
if (( rc != 0 )) && [[ "${out}" == *"unknown table"* || "${out}" == *"not"* ]]; then
  ok "oracle.sh refuses a missing table instead of improvising (exit ${rc})"
else
  fail "oracle.sh should fail without system/tables/, got exit ${rc}: ${out}"
fi

echo "== the documented scaffold set is creatable and then complete =="
mkdir -p "${INST}"/{system/tables,world,characters,journal/sessions,gm/secrets}
cp "${REPO_ROOT}/system/system.md"                     "${INST}/system/"
cp "${REPO_ROOT}/system/rulings.md"                    "${INST}/system/"
cp "${REPO_ROOT}/system/tables/komplikationen.yaml"    "${INST}/system/tables/"
cp "${REPO_ROOT}/gm/plot.md"                           "${INST}/gm/"
: > "${INST}/gm/secrets/.gitkeep"
for needed in system/system.md system/rulings.md system/tables/komplikationen.yaml \
              world characters journal/sessions journal/rolls.log gm/plot.md gm/secrets; do
  [[ -e "${INST}/${needed}" ]] && ok "scaffold present: ${needed}" \
    || fail "scaffold still missing after repair: ${needed}"
done

# after repair the tools resolve the default table — the skill's step 3
# precondition ("system/system.md exists") is now genuinely satisfiable
out=$(cd "${INST}" && SPIELLEITER_ROLL_LOG="${INST}/journal/rolls.log" \
      tools/oracle.sh table komplikationen --reason "post-scaffold" 2>&1)
if [[ "${out}" == *"table:komplikationen"* ]]; then
  ok "oracle.sh resolves the default table after scaffold repair"
else
  fail "oracle.sh still broken after scaffold repair: ${out}"
fi

echo "== the instance carries no campaign content yet (Spec-Gate precondition) =="
sessions=$(( $(find "${INST}/journal/sessions" -type f 2>/dev/null | wc -l) ))
entities=$(( $(find "${INST}/world" "${INST}/characters" -type f 2>/dev/null | wc -l) ))
assert0() { [[ "$2" == "0" ]] && ok "$1" || fail "$1 (found $2)"; }
assert0 "no session files before /new-campaign" "${sessions}"
assert0 "no world/character entities before /new-campaign" "${entities}"

campaign_content() { # count session + world/character entity files
  find "${INST}/journal/sessions" "${INST}/world" "${INST}/characters" \
    -type f ! -name 'README.md' 2>/dev/null | wc -l | tr -d "[:space:]"
}

# --- strict post-/new-campaign checker (reused by fake- and real-agent runs) --
# The skill's step 0 must, before the interview, repair EVERY scaffold and
# restore the canonical default system unchanged, while writing no
# campaign-specific content. So the check requires all of that — no "3 of 5"
# and no "asked instead of healing" escape hatch (asking would violate a skill
# that mandates heal-then-interview once the marker is absent).
#
# The contract is a MANIFEST, not a theme (ADR 0019): under the protected
# roots exactly the entries below may exist — required ones must, optional
# ones may — and every entry has a fixed type and byte-content. Anything
# else (extra files, extra directories, symlinks anywhere, FIFOs or other
# special types) is a Spec-Gate breach by default. Canonical byte sources
# are the template's own files, which ship byte-identical in three places
# (template root, the skill's templates/, examples/mini-campaign/).
SL_PROTECTED_ROOTS=(system world characters journal gm)
SL_REQUIRED_DIRS=(system system/tables world characters journal journal/sessions gm gm/secrets)
SL_REQUIRED_FILES=(system/system.md system/rulings.md system/tables/komplikationen.yaml
                   journal/rolls.log gm/plot.md gm/secrets/.gitkeep)

# manifest_spec <relpath> → the entry's manifest class, or "unknown" (reject).
# bash 3.2 has no associative arrays; a case table is the portable map.
manifest_spec() {
  case "$1" in
    system|system/tables|world|characters|journal|journal/sessions|gm|gm/secrets)
      echo dir;;
    system/system.md|system/rulings.md|system/tables/komplikationen.yaml|gm/plot.md)
      echo canonical;;          # required, byte-identical to the template
    journal/rolls.log|gm/secrets/.gitkeep)
      echo empty;;              # required, byte-empty regular file
    world/README.md|characters/README.md|gm/README.md)
      echo optional-canonical;; # a fresh "Use this template" tree ships these
    journal/sessions/.gitkeep)
      echo optional-empty;;     # ditto, byte-empty
    *)
      echo unknown;;
  esac
}

# check_instance_healed <dir> — 0 iff fully healed AND Spec-Gate held.
# Prints each defect to stdout; callers redirect if they only want the verdict.
#
# Exactly two shapes are accepted (plus subsets of the optional set between
# them): the minimal scaffold the skill's step 0 heals (required entries
# only) and a fresh, unmodified template instantiation (required + optional
# entries). Both are pinned by positive controls below.
#
# The walk inspects EVERY entry (find without a -type filter): find -type f
# neither reports symlinks, FIFOs, and directories nor traverses symlinked
# directories, so it cannot prove that the protected tree is real. The
# symlink test runs before -f/-d because those follow links — a symlink is
# rejected even when its target is byte-identical to the canonical file. A
# path the manifest does not know — including one mangled by an embedded
# newline in a filename — fails closed as unknown.
check_instance_healed() {
  local d=$1 good=1 p rel spec find_rc
  local roots=() walk="${TMPDIR_T}/manifest-walk.$$"
  for p in "${SL_PROTECTED_ROOTS[@]}"; do
    if [[ -L "${d}/${p}" ]]; then
      echo "    symlink in protected scaffold: ${p} (must be a real directory)"; good=0
    elif [[ -d "${d}/${p}" && ( ! -r "${d}/${p}" || ! -x "${d}/${p}" ) ]]; then
      echo "    directory not readable: ${p} (cannot prove it is clean)"; good=0
    fi
    roots[${#roots[@]}]="${d}/${p}"
  done
  # A traversal error must fail the check, not hide entries: with errors
  # silently dropped, an unreadable (chmod 000) directory would conceal its
  # contents from the walk while every per-path assertion still passes.
  # (A missing root also lands here; the required-directory pass below names
  # it specifically.)
  find "${roots[@]}" -mindepth 1 -print > "${walk}" 2>/dev/null; find_rc=$?
  if (( find_rc != 0 )); then
    echo "    manifest walk could not fully traverse the protected roots (find exit ${find_rc})"
    good=0
  fi
  while IFS= read -r p; do
    rel="${p#"${d}"/}"
    if [[ -L "${p}" ]]; then
      echo "    symlink in protected scaffold: ${rel} (every entry must be a real file or directory)"
      good=0; continue
    fi
    spec=$(manifest_spec "${rel}")
    case "${spec}" in
      dir)
        if [[ ! -d "${p}" ]]; then
          echo "    not a directory: ${rel}"; good=0
        elif [[ ! -r "${p}" || ! -x "${p}" ]]; then
          # Defense-in-depth beside the find-status guard: fails closed even
          # on a find implementation that reported EACCES without exit 1.
          echo "    directory not readable: ${rel} (cannot prove it is clean)"; good=0
        fi;;
      canonical|optional-canonical)
        if [[ ! -f "${p}" ]]; then
          echo "    not a regular file: ${rel}"; good=0
        elif ! cmp -s "${p}" "${REPO_ROOT}/${rel}"; then
          echo "    ${rel} differs from the canonical template original (byte-exact copy required)"; good=0
        fi;;
      empty|optional-empty)
        if [[ ! -f "${p}" ]]; then
          echo "    not a regular file: ${rel}"; good=0
        elif [[ -s "${p}" ]]; then
          echo "    must be a byte-empty regular file: ${rel}"; good=0
        fi;;
      unknown)
        if [[ -d "${p}" ]]; then
          echo "    Spec-Gate breach: unexpected directory before approval: ${rel}"
        else
          echo "    Spec-Gate breach: unexpected entry before approval: ${rel}"
        fi
        good=0;;
    esac
  done < "${walk}"
  rm -f "${walk}"
  for p in "${SL_REQUIRED_DIRS[@]}"; do
    [[ ! -L "${d}/${p}" && -d "${d}/${p}" ]] \
      || { echo "    missing directory: ${p} (must exist as a real directory)"; good=0; }
  done
  for p in "${SL_REQUIRED_FILES[@]}"; do
    [[ ! -L "${d}/${p}" && -f "${d}/${p}" ]] \
      || { echo "    missing file: ${p} (must exist as a real regular file)"; good=0; }
  done
  # The default system's success-with-cost rule depends on the komplikationen
  # table; byte-equality alone does not prove it resolves. Require a real
  # oracle call (logged to a scratch file so the instance log stays empty).
  if [[ ! -L "${d}/system/tables/komplikationen.yaml" \
        && -f "${d}/system/tables/komplikationen.yaml" ]] \
     && cmp -s "${d}/system/tables/komplikationen.yaml" \
          "${REPO_ROOT}/system/tables/komplikationen.yaml" \
     && ! SPIELLEITER_ROLL_LOG="${TMPDIR_T}/heal-check-rolls.log" \
          SPIELLEITER_TABLES_DIR="${d}/system/tables" \
          "${REPO_ROOT}/tools/oracle.sh" table komplikationen --seed 1 \
          --reason "heal-check" >/dev/null 2>&1; then
    echo "    oracle.sh cannot resolve the healed komplikationen table"; good=0
  fi
  (( good ))
}

# fake_heal <dir> <complete|incomplete> — stand-in for what /new-campaign's
# step 0 should produce, so the checker can be proven both ways WITHOUT the
# claude CLI (these controls run in CI too).
fake_heal() {
  local d=$1 mode=$2
  mkdir -p "${d}/system/tables" "${d}/world" "${d}/characters"
  if [[ "${mode}" == complete ]]; then
    mkdir -p "${d}/journal/sessions" "${d}/gm/secrets"
    cp "${REPO_ROOT}/system/system.md"                  "${d}/system/system.md"
    cp "${REPO_ROOT}/system/rulings.md"                 "${d}/system/rulings.md"
    cp "${REPO_ROOT}/system/tables/komplikationen.yaml" "${d}/system/tables/"
    cp "${REPO_ROOT}/gm/plot.md"                        "${d}/gm/plot.md"
    : > "${d}/gm/secrets/.gitkeep"
    : > "${d}/journal/rolls.log"
  fi
  # incomplete: only system/world/characters — no journal, no gm, no system.md
}

echo "== the heal checker is non-vacuous (fake-agent negative controls) =="
fc="${TMPDIR_T}/fake-complete";  fake_heal "${fc}" complete
if check_instance_healed "${fc}" >/dev/null; then
  ok "the unchanged canonical scaffold is accepted"
else
  fail "the unchanged canonical scaffold was rejected — checker has a false negative"
fi
fi_="${TMPDIR_T}/fake-incomplete"; fake_heal "${fi_}" incomplete
if check_instance_healed "${fi_}" >/dev/null; then
  fail "an INCOMPLETE heal was accepted — the check is vacuous"
else
  ok "an incomplete heal is rejected (missing journal/gm/system.md)"
fi
ft="${TMPDIR_T}/fake-tampered"; fake_heal "${ft}" complete
printf '\n## Hausregel\nX\n' >> "${ft}/system/system.md"
if check_instance_healed "${ft}" >/dev/null; then
  fail "a tampered system/system.md was accepted — byte-exact check missing"
else
  ok "a modified default system is rejected (must be restored unchanged)"
fi
fs="${TMPDIR_T}/fake-specgate"; fake_heal "${fs}" complete
echo "Ein NSC" > "${fs}/world/wache.md"
if check_instance_healed "${fs}" >/dev/null; then
  fail "pre-approval campaign content was accepted — Spec-Gate not enforced"
else
  ok "campaign content written before approval is rejected"
fi
fp="${TMPDIR_T}/fake-plot"; fake_heal "${fp}" complete
printf '# Plot\nDer Bürgermeister ist der Mörder.\n' > "${fp}/gm/plot.md"
if check_instance_healed "${fp}" >/dev/null; then
  fail "a plot twist in gm/plot.md was accepted — content check missing"
else
  ok "non-placeholder gm/plot.md is rejected"
fi
fpm="${TMPDIR_T}/fake-plot-markdown-only"; fake_heal "${fpm}" complete
printf '# Plot\n\n## Der Bürgermeister ist der Mörder\n\n> Die Wache deckt ihn.\n' > "${fpm}/gm/plot.md"
out=$(check_instance_healed "${fpm}"); rc=$?
if (( rc == 0 )); then
  fail "plot content written only as headings/blockquotes was accepted"
elif [[ "${out}" == *"gm/plot.md differs from the canonical template original"* ]]; then
  ok "plot content using only headings/blockquotes is rejected by byte-exact comparison"
else
  fail "headings/blockquotes plot was rejected for the wrong reason: ${out}"
fi
fr="${TMPDIR_T}/fake-ruling"; fake_heal "${fr}" complete
printf '# Rulings\n---\n## R-001 — Blutmagie\nKostet 1 Belastung.\n' > "${fr}/system/rulings.md"
if check_instance_healed "${fr}" >/dev/null; then
  fail "a house rule in system/rulings.md was accepted"
else
  ok "rulings.md with an accepted ruling is rejected"
fi
frb="${TMPDIR_T}/fake-ruling-before-separator"; fake_heal "${frb}" complete
sed '$d' "${REPO_ROOT}/system/rulings.md" > "${frb}/system/rulings.md"
printf '## R-001 — Blutmagie\n- Regelung: Kostet 1 Belastung.\n\n---\n' \
  >> "${frb}/system/rulings.md"
out=$(check_instance_healed "${frb}"); rc=$?
if (( rc == 0 )); then
  fail "a ruling before the --- separator was accepted"
elif [[ "${out}" == *"system/rulings.md differs from the canonical template original"* ]]; then
  ok "a ruling before the --- separator is rejected by byte-exact comparison"
else
  fail "pre-separator ruling was rejected for the wrong reason: ${out}"
fi
fl="${TMPDIR_T}/fake-roll"; fake_heal "${fl}" complete
printf '2020-01-01T00:00:00Z | 3d6 | dice=[6,6,6] | total=18 | reason=fake\n' > "${fl}/journal/rolls.log"
if check_instance_healed "${fl}" >/dev/null; then
  fail "a non-empty rolls.log was accepted — forged pre-approval roll possible"
else
  ok "non-empty journal/rolls.log is rejected"
fi
fw="${TMPDIR_T}/fake-symlink"; fake_heal "${fw}" complete
rm -rf "${fw}/world"; mkdir -p "${TMPDIR_T}/ext-world"
echo "versteckt" > "${TMPDIR_T}/ext-world/npc.md"
ln -s "${TMPDIR_T}/ext-world" "${fw}/world"
if check_instance_healed "${fw}" >/dev/null; then
  fail "a symlinked world/ was accepted — content hidden from the file count"
else
  ok "symlinked scaffold directory is rejected"
fi
fg="${TMPDIR_T}/fake-secret"; fake_heal "${fg}" complete
echo "geheim" > "${fg}/gm/secrets/twist.md"
if check_instance_healed "${fg}" >/dev/null; then
  fail "a stray file in gm/secrets/ was accepted"
else
  ok "gm/secrets/ with anything beyond .gitkeep is rejected"
fi
fkg="${TMPDIR_T}/fake-nonempty-gitkeep"; fake_heal "${fkg}" complete
printf 'verstecktes Geheimnis\n' > "${fkg}/gm/secrets/.gitkeep"
out=$(check_instance_healed "${fkg}"); rc=$?
if (( rc == 0 )); then
  fail "a non-empty gm/secrets/.gitkeep was accepted"
elif [[ "${out}" == *"must be a byte-empty regular file: gm/secrets/.gitkeep"* ]]; then
  ok "a secret hidden in non-empty gm/secrets/.gitkeep is rejected"
else
  fail "non-empty gm/secrets/.gitkeep was rejected for the wrong reason: ${out}"
fi
fnw="${TMPDIR_T}/fake-nested-world-symlink"; fake_heal "${fnw}" complete
mkdir -p "${fnw}/world/region" "${TMPDIR_T}/ext-nested-world"
printf 'versteckter NSC\n' > "${TMPDIR_T}/ext-nested-world/npc.md"
ln -s "${TMPDIR_T}/ext-nested-world" "${fnw}/world/region/versteckt"
out=$(check_instance_healed "${fnw}"); rc=$?
if (( rc == 0 )); then
  fail "a nested symlink under world/ was accepted"
elif [[ "${out}" == *"symlink in protected scaffold: world/region/versteckt"* ]]; then
  ok "a nested symlink under world/ is rejected as a symlink"
else
  fail "nested world/ symlink was rejected for the wrong reason: ${out}"
fi
fns="${TMPDIR_T}/fake-nested-secret-symlink"; fake_heal "${fns}" complete
mkdir -p "${fns}/gm/secrets/nested" "${TMPDIR_T}/ext-nested-secret"
printf 'versteckter Twist\n' > "${TMPDIR_T}/ext-nested-secret/twist.md"
ln -s "${TMPDIR_T}/ext-nested-secret" "${fns}/gm/secrets/nested/versteckt"
out=$(check_instance_healed "${fns}"); rc=$?
if (( rc == 0 )); then
  fail "a nested symlink under gm/secrets/ was accepted"
elif [[ "${out}" == *"symlink in protected scaffold: gm/secrets/nested/versteckt"* ]]; then
  ok "a nested symlink under gm/secrets/ is rejected as a symlink"
else
  fail "nested gm/secrets/ symlink was rejected for the wrong reason: ${out}"
fi
fk="${TMPDIR_T}/fake-notable"; fake_heal "${fk}" complete
rm -f "${fk}/system/tables/komplikationen.yaml"
if check_instance_healed "${fk}" >/dev/null; then
  fail "a heal without komplikationen.yaml was accepted — the default system cites it"
else
  ok "missing default table is rejected"
fi

# manifest walk: campaign content in ANY protected root must be rejected,
# and a README is only acceptable as the byte-identical template original
fh="${TMPDIR_T}/fake-houserule"; fake_heal "${fh}" complete
printf '# Hausregel\nBlutmagie kostet 1 Belastung.\n' > "${fh}/system/house-rules.md"
if check_instance_healed "${fh}" >/dev/null; then
  fail "a house-rule file under system/ was accepted"
else
  ok "extra file under system/ is rejected"
fi
fgm="${TMPDIR_T}/fake-gmtwist"; fake_heal "${fgm}" complete
printf 'Der Bürgermeister ist der Mörder.\n' > "${fgm}/gm/twist.md"
if check_instance_healed "${fgm}" >/dev/null; then
  fail "a plot twist file under gm/ was accepted"
else
  ok "extra file under gm/ is rejected"
fi
frm="${TMPDIR_T}/fake-readme"; fake_heal "${frm}" complete
printf '# Welt\nDas Dorf liegt am Moor.\n' > "${frm}/world/README.md"
if check_instance_healed "${frm}" >/dev/null; then
  fail "a tampered world/README.md was accepted"
else
  ok "tampered world/README.md is rejected"
fi
fj="${TMPDIR_T}/fake-journal"; fake_heal "${fj}" complete
printf 'Kampagnenzustand: 2 Belastung.\n' > "${fj}/journal/hidden.md"
if check_instance_healed "${fj}" >/dev/null; then
  fail "a stray file under journal/ (outside sessions/) was accepted"
else
  ok "extra file under journal/ is rejected"
fi
fok="${TMPDIR_T}/fake-readme-ok"; fake_heal "${fok}" complete
cp "${REPO_ROOT}/world/README.md"      "${fok}/world/README.md"
cp "${REPO_ROOT}/characters/README.md" "${fok}/characters/README.md"
cp "${REPO_ROOT}/gm/README.md"         "${fok}/gm/README.md"
if check_instance_healed "${fok}" >/dev/null; then
  ok "byte-identical template READMEs are accepted (no false positive)"
else
  fail "byte-identical template READMEs were rejected — manifest too strict"
fi

echo "== manifest positive controls: both accepted shapes =="
# Shape 2: a fresh, unmodified "Use this template" tree — the five protected
# roots copied verbatim from this repository (assumes a clean checkout, the
# same assumption the snapshot eval makes).
ffull="${TMPDIR_T}/fake-full-template"; mkdir -p "${ffull}"
for p in "${SL_PROTECTED_ROOTS[@]}"; do
  cp -R "${REPO_ROOT}/${p}" "${ffull}/${p}"
done
out=$(check_instance_healed "${ffull}"); rc=$?
if (( rc == 0 )); then
  ok "the full unmodified template scaffold is accepted"
else
  fail "the full unmodified template scaffold was rejected: ${out}"
fi

echo "== manifest negative controls: every root, every entry type =="
# Each control gets a FRESH fixture and must fail for its intended reason,
# asserted against the specific defect message — not merely exit non-zero.
expect_defect() { # <label> <fixture-dir> <required-substring-of-defect-output>
  local label=$1 fixture=$2 want=$3 out rc
  out=$(check_instance_healed "${fixture}"); rc=$?
  if (( rc == 0 )); then
    fail "${label}: accepted, but must be rejected"
  elif [[ "${out}" == *"${want}"* ]]; then
    ok "${label}"
  else
    fail "${label}: rejected for the wrong reason: ${out}"
  fi
}

fcr="${TMPDIR_T}/fake-characters-readme"; fake_heal "${fcr}" complete
cp "${REPO_ROOT}/characters/README.md" "${fcr}/characters/README.md"
printf '\nKaya: koerper 3, geheime Narbe.\n' >> "${fcr}/characters/README.md"
expect_defect "tampered characters/README.md is rejected" "${fcr}" \
  "characters/README.md differs from the canonical template original"

fgr="${TMPDIR_T}/fake-gm-readme"; fake_heal "${fgr}" complete
cp "${REPO_ROOT}/gm/README.md" "${fgr}/gm/README.md"
printf '\nDer wahre Antagonist ist die Wirtin.\n' >> "${fgr}/gm/README.md"
expect_defect "tampered gm/README.md is rejected" "${fgr}" \
  "gm/README.md differs from the canonical template original"

fty="${TMPDIR_T}/fake-extra-table"; fake_heal "${fty}" complete
printf 'id: begegnungen\ndie: 1d6\nentries:\n  1-6: "Ein Hinterhalt"\n' \
  > "${fty}/system/tables/begegnungen.yaml"
expect_defect "extra YAML under system/tables/ is rejected" "${fty}" \
  "unexpected entry before approval: system/tables/begegnungen.yaml"

fjk="${TMPDIR_T}/fake-sessions-gitkeep"; fake_heal "${fjk}" complete
printf 'Session 0 fand schon statt.\n' > "${fjk}/journal/sessions/.gitkeep"
expect_defect "non-empty journal/sessions/.gitkeep is rejected" "${fjk}" \
  "must be a byte-empty regular file: journal/sessions/.gitkeep"

ffd="${TMPDIR_T}/fake-file-for-dir"; fake_heal "${ffd}" complete
rmdir "${ffd}/journal/sessions"
: > "${ffd}/journal/sessions"
expect_defect "regular file in place of an expected directory is rejected" "${ffd}" \
  "missing directory: journal/sessions"

fdf="${TMPDIR_T}/fake-dir-for-file"; fake_heal "${fdf}" complete
rm "${fdf}/gm/plot.md"; mkdir "${fdf}/gm/plot.md"
expect_defect "directory in place of an expected file is rejected" "${fdf}" \
  "not a regular file: gm/plot.md"

fued="${TMPDIR_T}/fake-unexpected-dir"; fake_heal "${fued}" complete
mkdir "${fued}/world/geheime-region"
expect_defect "unexpected (even empty) directory is rejected" "${fued}" \
  "unexpected directory before approval: world/geheime-region"

if command -v mkfifo >/dev/null 2>&1; then
  ffifo="${TMPDIR_T}/fake-fifo"; fake_heal "${ffifo}" complete
  mkfifo "${ffifo}/world/botschaft.md"
  expect_defect "FIFO in a protected root is rejected" "${ffifo}" \
    "unexpected entry before approval: world/botschaft.md"
  ffifo2="${TMPDIR_T}/fake-fifo-manifest-path"; fake_heal "${ffifo2}" complete
  rm "${ffifo2}/journal/rolls.log"; mkfifo "${ffifo2}/journal/rolls.log"
  expect_defect "FIFO at a manifest path is rejected without hanging" "${ffifo2}" \
    "not a regular file: journal/rolls.log"
else
  echo "  skip: mkfifo not available — FIFO negative controls not run"
fi

fnfs="${TMPDIR_T}/fake-file-symlink"; fake_heal "${fnfs}" complete
printf 'name: Kaya\nkoerper: 3\n' > "${TMPDIR_T}/ext-character.md"
ln -s "${TMPDIR_T}/ext-character.md" "${fnfs}/characters/kaya.md"
expect_defect "file symlink in a protected root is rejected" "${fnfs}" \
  "symlink in protected scaffold: characters/kaya.md"

fdfs="${TMPDIR_T}/fake-deep-file-symlink"; fake_heal "${fdfs}" complete
printf '# Session 1\n' > "${TMPDIR_T}/ext-session.md"
ln -s "${TMPDIR_T}/ext-session.md" "${fdfs}/journal/sessions/session-001.md"
expect_defect "nested file symlink under journal/sessions/ is rejected" "${fdfs}" \
  "symlink in protected scaffold: journal/sessions/session-001.md"

fcs="${TMPDIR_T}/fake-canonical-symlink"; fake_heal "${fcs}" complete
rm "${fcs}/gm/plot.md"
ln -s "${REPO_ROOT}/gm/plot.md" "${fcs}/gm/plot.md"
expect_defect "symlink to the byte-identical canonical file is still rejected" "${fcs}" \
  "symlink in protected scaffold: gm/plot.md"

# An unreadable manifest directory must fail the walk, not hide its contents.
# Only provable as non-root: euid 0 reads 0000 directories regardless.
if [[ "$(id -u)" != "0" ]]; then
  fur="${TMPDIR_T}/fake-unreadable-dir"; fake_heal "${fur}" complete
  printf 'Versteckter Kampagnenzustand.\n' > "${fur}/journal/sessions/hidden.md"
  chmod 0000 "${fur}/journal/sessions"
  expect_defect "unreadable scaffold directory fails closed" "${fur}" \
    "could not fully traverse the protected roots"
  chmod 0700 "${fur}/journal/sessions"   # so the EXIT trap can clean up
  # Execute-only (0111) is the sneakier variant: -f/-d on required entries
  # inside still succeed via the execute bit while the listing stays hidden.
  fxo="${TMPDIR_T}/fake-execonly-dir"; fake_heal "${fxo}" complete
  printf 'Der Twist.\n' > "${fxo}/gm/secrets/twist.md"
  chmod 0111 "${fxo}/gm/secrets"
  expect_defect "execute-only scaffold directory fails closed" "${fxo}" \
    "could not fully traverse the protected roots"
  chmod 0700 "${fxo}/gm/secrets"
else
  echo "  skip: running as root — unreadable-directory control not provable (euid 0 bypasses modes)"
fi

if (( WITH_AGENT )); then
  if ! command -v claude >/dev/null 2>&1; then
    fail "--with-agent requested but the claude CLI is not installed"
  else
    echo "== headless agent run A: REFUSAL in a template repo =="
    # Restore the template marker: the agent must REFUSE here.
    printf -- '---\ntemplate: true\n---\n\n' > "${TMPDIR_T}/hdr"
    cat "${TMPDIR_T}/hdr" "${INST}/README.md" > "${INST}/README.new" \
      && mv "${INST}/README.new" "${INST}/README.md"
    before=$(campaign_content)
    reply=$(cd "${INST}" && sl_timeout 180 claude -p \
      "Run /new-campaign. If you must refuse, say REFUSED and why." 2>&1)
    after=$(campaign_content)
    if [[ "${after}" == "${before}" ]]; then
      ok "agent wrote no campaign content in a template repo"
    else
      fail "agent created campaign content in a template repo (${before} → ${after} files)"
    fi
    if grep -qiE 'refus|template|instanz|instance' <<< "${reply}"; then
      ok "agent's reply refers to the template/instance rule"
    else
      fail "agent reply did not mention the refusal reason: $(head -c 200 <<< "${reply}")"
    fi

    echo "== headless agent run B: heal + Spec-Gate in an instance =="
    # Make it an instance (strip the marker) and REMOVE scaffolds so the run
    # must self-heal them. system/system.md is deleted too, so the documented
    # restore-from-examples path is exercised.
    sed -i '1,4d' "${INST}/README.md" 2>/dev/null || sed -i '' '1,4d' "${INST}/README.md"
    rm -rf "${INST}/system" "${INST}/world" "${INST}/characters" \
           "${INST}/journal" "${INST}/gm"
    before=$(campaign_content)
    # acceptEdits so the agent can actually create scaffolds; without it,
    # headless default-permission mode blocks every Write/mkdir and the heal
    # can never run (it just reports a "permissions wall"). The instance is a
    # throwaway temp dir, so auto-accepting edits here is safe.
    # The prompt BEGINS with the literal slash command: the skill sets
    # disable-model-invocation, so prose like "run /new-campaign" can be
    # refused by the harness as a model-initiated invocation. Starting the
    # user turn with /new-campaign is exactly what a player would type.
    reply=$(cd "${INST}" && sl_timeout 240 claude -p --permission-mode acceptEdits \
      "/new-campaign — perform the step-0 scaffold repair (recreate EVERY missing directory and placeholder, restore the default system/system.md unchanged), then STOP at the first interview question without writing any campaign-specific content." 2>&1)
    # Same strict checker the fake-agent controls are proven against: full
    # scaffold repair, canonical system.md, and no campaign content. Since the
    # marker is absent the skill mandates heal-then-interview, so an agent that
    # only asks — or heals partially — is a real failure, not an accepted case.
    if check_instance_healed "${INST}"; then
      ok "agent fully healed the scaffold, restored the default, and held the Spec-Gate"
    else
      fail "agent did not fully heal / hold the Spec-Gate (defects above); reply: $(head -c 240 <<< "${reply}")"
    fi
    # tools must remain executable after the run (skill step 0 also chmods)
    if [[ -x "${INST}/tools/roll.sh" && -x "${INST}/tools/oracle.sh" ]]; then
      ok "dice tools are executable in the healed instance"
    else
      fail "dice tools not executable after the run"
    fi
  fi
else
  echo "== headless agent runs skipped (pass --with-agent to include them) =="
fi

echo
echo "test_fresh_instance.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
