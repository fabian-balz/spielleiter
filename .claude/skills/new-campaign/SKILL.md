---
description: Start a new campaign — interview for system, setting, safety tools, players and their characters; Spec-Gate before writing anything
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
   an empty `journal/rolls.log`, `gm/` (+ `gm/plot.md`, `gm/secrets/`
   containing an **empty `gm/secrets/.gitkeep`**),
   and `tools/roll.sh` / `tools/oracle.sh` present and executable
   (`chmod +x` if not). If the tools themselves are missing, stop and
   tell the player the instance is incomplete — do not improvise dice.

   **Placeholders are restored byte-exact, never re-authored.** The
   canonical files ship with this skill under
   `.claude/skills/new-campaign/templates/` — copy them verbatim
   (`cp`, not retyping):
   - `system/rulings.md` ← `templates/rulings.md`
     (fallback: `examples/mini-campaign/system/rulings.md`, same bytes).
   - `gm/plot.md` ← `templates/plot.md`. Never write your own plot
     placeholder — any self-authored wording, headings included, fails the
     byte check and risks smuggling content past the Spec-Gate (G6).
   - `system/tables/komplikationen.yaml`: restore **unchanged** from
     `examples/mini-campaign/system/tables/komplikationen.yaml` — the
     default system's success-with-cost rule cites this table, so a heal
     without it leaves `system.md` referencing a table that cannot roll.
   - `journal/rolls.log` stays byte-empty; `.gitkeep` files must be empty.
   - Create **no other files and no other directories** under `system/`,
     `world/`, `characters/`, `journal/`, or `gm/` before the Spec-Gate,
     and never create symlinks there — every scaffold entry is a real
     regular file or a real directory. The whole scaffold is an exact
     manifest, not a theme (ADR 0019).
   - A fresh "Use this template" instance already ships
     `world/README.md`, `characters/README.md`, `gm/README.md`, and
     `journal/sessions/.gitkeep`. These are part of the manifest: leave
     them byte-unchanged if present; do not re-author or "improve" them,
     and do not create them if absent — healing only restores the
     required entries listed above.
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

0. **Players.** How many players are at the table, and what display name
   does each go by? The name becomes the PC's `player:` frontmatter value —
   a nickname is fine, nobody has to use their real name. One player =
   solo; the per-player passes below then collapse to a single pass.
1. **Rules system.** Two paths:
   - Player provides rules text (pasted or as file) → distill it into a draft
     for `system/system.md`: dice mechanic, resolution procedure, character
     model, oracle odds section. Present the full draft for approval.
   - Player wants a default → present the existing minimal 2W6 system in
     `system/system.md` and ask for sign-off (or adjustments).
2. **Setting.** Genre, tone, starting region, one or two campaign hooks the
   player cares about.
3. **Safety tools.** Lines (never appears) and veils (fade to black),
   collected as a **group consensus**: ask every player, and the strictest
   named boundary binds the whole table — a line named by one player is a
   line for everyone, no negotiation against the person who set it. These
   go into `system/system.md` § Sicherheit. If the table declines, note
   "keine" explicitly — do not leave the section as placeholder.
4. **Characters.** One guided creation **per player**, each as its own
   pass per the agreed character model. Only the owning player decides
   anything about their PC — the others may listen and chat, but every
   choice is made by that player alone (G5). Suggest, never decide.
   Record the owner as the PC's `player:` frontmatter field.
5. **Table order (Tischordnung).** With more than one player, ask how the
   spotlight passes at this table: round-robin in seating order,
   GM-directed following the fiction, or free-form. The answer is
   persisted **after** the Spec-Gate as part of step 3 — as a citable
   § Tischordnung in the instance's `system/system.md` (G2), so the play
   loop can follow and quote it. It is campaign content: never write it
   before approval, and never into the template's default system.

## 2. Spec-Gate

Present a summary: system draft, setting, lines & veils (the table
consensus), one character sheet per player, and the agreed table order.
**Wait for explicit approval. Write no campaign-specific content before it
is given** — no rules, setting, characters, world entities or plot. The only
writes permitted before this point are the empty scaffolds from step 0, and
those must have been announced. Revise and re-present on objections.

## 3. Write skeleton (only after approval)

- `system/system.md` — approved system (keep frontmatter `language:` field
  and the Orakel odds section; the oracle tool's odds must stay documented).
  With more than one player, append the agreed table order as a
  `## Tischordnung` section so it is citable during play (G2).
- `characters/<name>.md` — one file per PC: frontmatter stats per
  character model plus the owning player's `player:` field, then prose.
- `world/` — one file per starting location/NPC/faction the interview
  established, plus one quest file (`status: open`) for the opening hook.
- `gm/plot.md` — your private campaign outline: hidden truths, prepared
  twists, NPC agendas. Never shown to the player (G6).
- `journal/sessions/session-000.md` — campaign founding entry: date, system
  choice, setting summary, introduction of every PC with its player.

## 4. Commit

`git add -A && git commit -m "feat: new campaign — <campaign name>"`.
Then offer `/session-start`.
