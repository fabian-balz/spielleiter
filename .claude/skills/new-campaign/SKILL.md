---
description: Start a new campaign — interview for system, setting, safety tools, and first character; Spec-Gate before writing anything
disable-model-invocation: true
---

# /new-campaign

Interview the player and bootstrap the campaign files.

**Spec-Gate:** no *campaign-specific content* — system rules, setting,
characters, world entities, plot — is written before the player approves
the distilled system. Step 0 below is the one exception and is explicitly
not campaign content: it may create **empty scaffolds** (directories,
placeholder files, an empty `rolls.log`) and fix executable bits so the
interview can run at all. If step 0 has to create anything, say so before
starting the interview.

All guardrails in CLAUDE.md apply, especially G2 (rules live in `system/`)
and G5 (the player decides everything about their character).

## 0. Instance check & scaffold (before anything else)

1. **Refuse in the template repo.** If the root `README.md` frontmatter
   contains `template: true`, stop: explain that campaigns are played in
   instances, point to README § "Starting a campaign (instantiation)", and
   do not write anything.

   **The marker is the only signal that matters.** If the README is present
   and does *not* carry `template: true`, this is an instance — proceed,
   even when the directory tree still looks template-like (only `examples/`,
   `tools/`, `CLAUDE.md`, `README.md`, no campaign scaffolds). A freshly
   instantiated template looks exactly like that until step 2 runs; missing
   scaffolds are a reason to heal (step 2), never a reason to refuse or to
   second-guess the marker's absence. Only ask the player when the marker's
   absence genuinely can't be verified — the README is missing or its
   frontmatter is unreadable.
2. **Self-heal the scaffold.** This skill must work in a fresh instance,
   even a minimal copy. Ensure these exist, creating empty/placeholder
   versions of whatever is missing: `system/` (+ `system/tables/`,
   `system/rulings.md`), `world/`, `characters/`, `journal/sessions/`,
   an empty `journal/rolls.log`, `gm/` (+ `gm/plot.md`, `gm/secrets/`),
   and `tools/roll.sh` / `tools/oracle.sh` present and executable
   (`chmod +x` if not). If the tools themselves are missing, stop and
   tell the player the instance is incomplete — do not improvise dice.
3. **Ensure `system/system.md` exists.** Step 1 below offers the default
   system as one of two paths and step 3 edits this file, so it must be
   present. If it is missing, restore the canonical default from
   `examples/mini-campaign/system/system.md` (same file, unmodified) or,
   if that is unavailable too, tell the player the instance is incomplete
   and offer to distill a system from their rules text instead — never
   invent rules silently (G2).
4. If `git-crypt` appears unconfigured (no `.git/git-crypt/`), warn the
   player once that `gm/` will commit as plaintext until the README's
   git-crypt setup is done — then continue; it's their call.

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
**Wait for explicit approval. Write no campaign-specific content before it
is given** — no rules, setting, characters, world entities or plot. The only
writes permitted before this point are the empty scaffolds from step 0, and
those must have been announced. Revise and re-present on objections.

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
