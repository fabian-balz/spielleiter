---
description: Start a new campaign — interview for system, setting, safety tools, and first character; Spec-Gate before writing anything
disable-model-invocation: true
---

# /new-campaign

Interview the player and bootstrap the campaign files. **Spec-Gate: nothing
is written to disk before the player has approved the distilled system.**
All guardrails in CLAUDE.md apply, especially G2 (rules live in `system/`)
and G5 (the player decides everything about their character).

## 1. Interview (read-only phase)

Ask, one topic at a time, in the campaign language (German unless told
otherwise):

1. **Rules system.** Two paths:
   - Player provides rules text (pasted or as file) → distill it into a draft
     for `system/system.md`: dice mechanic, resolution procedure, character
     model, oracle odds section. Present the full draft for approval.
   - Player wants a default → present the existing minimal 2W6 system in
     `system/system.md` and ask for sign-off (or adjustments).
2. **Setting.** Genre, tone, starting region, one or two campaign hooks the
   player cares about.
3. **Safety tools.** Lines (never appears) and veils (fade to black). These
   go into `system/system.md` § Sicherheit. If the player declines, note
   "keine" explicitly — do not leave the section as placeholder.
4. **Initial character.** Guided creation per the agreed character model.
   The player makes every choice; suggest, never decide (G5).

## 2. Spec-Gate

Present a summary: system draft, setting, lines & veils, character sheet.
**Wait for explicit approval. Do not write any file before it is given.**
Revise and re-present on objections.

## 3. Write skeleton (only after approval)

- `system/system.md` — approved system (keep frontmatter `language:` field
  and the Orakel odds section; the oracle tool's odds must stay documented).
- `characters/<name>.md` — frontmatter stats per character model + prose.
- `world/` — one file per starting location/NPC/faction the interview
  established, plus one quest file (`status: open`) for the opening hook.
- `gm/plot.md` — your private campaign outline: hidden truths, prepared
  twists, NPC agendas. Never shown to the player (G6).
- `journal/sessions/session-000.md` — campaign founding entry: date, system
  choice, setting summary, character introduction.

## 4. Commit

`git add -A && git commit -m "feat: new campaign — <campaign name>"`.
Then offer `/session-start`.
