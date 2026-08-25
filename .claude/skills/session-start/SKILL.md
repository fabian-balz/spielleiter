---
description: Start a play session — recap from the journal, list open quests, open the first scene
disable-model-invocation: true
---

# /session-start

Open a play session. All guardrails in CLAUDE.md apply.

## Steps

0. **Instance check**: if the root `README.md` frontmatter contains
   `template: true`, refuse — this is the Spielleiter template, not a
   campaign; point to README § "Starting a campaign (instantiation)".
   If no campaign exists yet (no `characters/*.md` beyond the README),
   suggest `/new-campaign` instead.
1. **Read state** (files win over memory):
   - latest `journal/sessions/session-NNN.md`
   - all quest files in `world/` (`type: quest`)
   - `characters/*.md` for current stats/condition and each PC's
     `player:` assignment
   - `system/system.md` § Tischordnung, if present — the agreed table
     order the spotlight follows (G2)
   - `gm/plot.md` for your private prep (never revealed — G6)
2. **Clarify attendance** (skip in solo): ask which players and PCs are
   at the table today. Absent players' PCs stay in the background —
   neither you nor the present players act, speak, or decide for them
   (G5); agree with the table how the fiction parks them.
3. **Determine session number**: highest existing NNN + 1. Create
   `journal/sessions/session-NNN.md` with a header (number, ISO date,
   attending players/PCs) — this file is appended to during play, never
   rewritten (G4).
4. **Recap** to the table, in the campaign language: 3–6 sentences of where
   things stand, then the open quests as a short list (name + status),
   then one line per attending PC: current condition (Belastung) and
   anything notable carried over. Public knowledge only — nothing from
   `gm/`.
5. **Opening scene**: narrate per CLAUDE.md Language & Tone, grounded in the
   current world state, and end with a clear prompt to a **named**
   player/PC — following § Tischordnung if the table agreed on one.

From here on, run the Play Loop from CLAUDE.md for every exchange, and
journal noteworthy beats into the session file as they happen.
