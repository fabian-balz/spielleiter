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
# The skill's documented restore path (step 3) copies the canonical default
# system from examples/mini-campaign/. Include it so that path is exercisable.
mkdir -p "${INST}/examples/mini-campaign/system"
cp "${REPO_ROOT}/examples/mini-campaign/system/system.md" \
   "${INST}/examples/mini-campaign/system/system.md"
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
sessions=$(find "${INST}/journal/sessions" -type f 2>/dev/null | wc -l)
entities=$(find "${INST}/world" "${INST}/characters" -type f 2>/dev/null | wc -l)
assert0() { [[ "$2" == "0" ]] && ok "$1" || fail "$1 (found $2)"; }
assert0 "no session files before /new-campaign" "${sessions}"
assert0 "no world/character entities before /new-campaign" "${entities}"

campaign_content() { # count session + world/character entity files
  find "${INST}/journal/sessions" "${INST}/world" "${INST}/characters" \
    -type f ! -name 'README.md' 2>/dev/null | wc -l
}

# --- strict post-/new-campaign checker (reused by fake- and real-agent runs) --
# The skill's step 0 must, before the interview, repair EVERY scaffold and
# restore the canonical default system unchanged, while writing no
# campaign-specific content. So the check requires all of that — no "3 of 5"
# and no "asked instead of healing" escape hatch (asking would violate a skill
# that mandates heal-then-interview once the marker is absent).
SL_REQUIRED_DIRS=(system system/tables world characters journal journal/sessions gm gm/secrets)
SL_REQUIRED_FILES=(system/system.md system/rulings.md journal/rolls.log gm/plot.md)

# check_instance_healed <dir> — 0 iff fully healed AND Spec-Gate held.
# Prints each defect to stdout; callers redirect if they only want the verdict.
check_instance_healed() {
  local d=$1 good=1 p cc
  cc=$(find "${d}/journal/sessions" "${d}/world" "${d}/characters" \
         -type f ! -name 'README.md' 2>/dev/null | wc -l)
  if [[ "${cc}" != "0" ]]; then
    echo "    Spec-Gate breach: ${cc} campaign file(s) before approval"; good=0
  fi
  for p in "${SL_REQUIRED_DIRS[@]}"; do
    [[ -d "${d}/${p}" ]] || { echo "    missing directory: ${p}"; good=0; }
  done
  for p in "${SL_REQUIRED_FILES[@]}"; do
    [[ -f "${d}/${p}" ]] || { echo "    missing file: ${p}"; good=0; }
  done
  if [[ -f "${d}/system/system.md" ]] \
     && ! diff -q "${d}/system/system.md" "${REPO_ROOT}/system/system.md" >/dev/null 2>&1; then
    echo "    system/system.md is not the canonical default (must be restored unchanged)"; good=0
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
  ok "a complete heal is accepted"
else
  fail "a complete heal was rejected — checker has a false negative"
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
    reply=$(cd "${INST}" && sl_timeout 240 claude -p --permission-mode acceptEdits \
      "Run /new-campaign. Perform the step-0 scaffold repair — recreate EVERY missing directory and placeholder and restore the default system/system.md unchanged — then begin the interview. Do NOT write any campaign-specific content yet; stop at the first question." 2>&1)
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
