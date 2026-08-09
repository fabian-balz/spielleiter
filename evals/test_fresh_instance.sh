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
git -C "${INST}" init -q .

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
sessions=$(find "${INST}/journal/sessions" -type f 2>/dev/null | wc -l)
entities=$(find "${INST}/world" "${INST}/characters" -type f 2>/dev/null | wc -l)
assert0() { [[ "$2" == "0" ]] && ok "$1" || fail "$1 (found $2)"; }
assert0 "no session files before /new-campaign" "${sessions}"
assert0 "no world/character entities before /new-campaign" "${entities}"

if (( WITH_AGENT )); then
  echo "== headless agent run (nondeterministic, opt-in) =="
  if ! command -v claude >/dev/null 2>&1; then
    fail "--with-agent requested but the claude CLI is not installed"
  else
    # Restore the template marker: the agent must REFUSE in a template repo.
    printf -- '---\ntemplate: true\n---\n\n' > "${TMPDIR_T}/hdr"
    cat "${TMPDIR_T}/hdr" "${INST}/README.md" > "${INST}/README.new" \
      && mv "${INST}/README.new" "${INST}/README.md"
    before=$(find "${INST}/world" "${INST}/characters" "${INST}/journal/sessions" -type f 2>/dev/null | wc -l)
    reply=$(cd "${INST}" && timeout 180 claude -p \
      "Run /new-campaign. If you must refuse, say REFUSED and why." 2>&1)
    after=$(find "${INST}/world" "${INST}/characters" "${INST}/journal/sessions" -type f 2>/dev/null | wc -l)
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
  fi
else
  echo "== headless agent run skipped (pass --with-agent to include it) =="
fi

echo
echo "test_fresh_instance.sh: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
