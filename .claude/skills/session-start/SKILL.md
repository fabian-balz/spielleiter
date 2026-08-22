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
   - `characters/*.md` for current stats/condition
   - `gm/plot.md` for your private prep (never revealed — G6)
2. **Determine session number**: highest existing NNN + 1. Create
   `journal/sessions/session-NNN.md` with a header (number, ISO date) — this
   file is appended to during play, never rewritten (G4).
3. **Recap** to the player, in the campaign language: 3–6 sentences of where
   things stand, then the open quests as a short list (name + status).
   Public knowledge only — nothing from `gm/`.
4. **Opening scene**: narrate per CLAUDE.md Language & Tone, grounded in the
   current world state, and end with a clear prompt for player action.

From here on, run the Play Loop from CLAUDE.md for every exchange, and
journal noteworthy beats into the session file as they happen.
