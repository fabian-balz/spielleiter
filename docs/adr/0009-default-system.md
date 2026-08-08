# 0009 — A minimal default system ships with the template

- Status: Accepted
- Date: 2026-08-08 (documenting a decision made during M0)

## Context

Spielleiter is system-agnostic: `/new-campaign` distills the player's own
rules text into `system/system.md`. But G2 requires every rules decision to
cite something under `system/`, so an empty `system/` makes the agent
unable to resolve anything — a fresh instance would be unplayable until the
player supplied a full ruleset. The spec allows generating "a minimal
default system requiring sign-off".

## Decision

Ship a deliberately small default in `system/system.md`, labeled as such,
covering exactly what the play loop needs:

- **Resolution:** 2d6 + attribute vs. a target number (7 / 9 / 11 for
  easy / normal / hard), with success, success-at-a-cost (exact tie), and
  failure. Explicit "no roll without uncertainty".
- **Character model:** three attributes (Körper / Geist / Charme) at
  +2/+1/+0, and a 3-point Belastung (stress/condition) track.
- **Oracle odds** (ADR 0008) and the random-table format (ADR 0003).
- **Safety tools** section (lines & veils) left empty for the interview to
  fill.

2d6+mod was chosen because the three-tier target numbers map onto a bell
curve with intuitive odds (58 % / 28 % / 8 % at +0), and because a
tie-equals-cost rule gives the "yes, but" texture the oracle already has —
one tonal vocabulary across both subsystems.

The file is explicitly marked as the default and `/new-campaign` requires
sign-off before it is used, so accepting it is a *player decision*, not a
silent default. `evals/test_template_clean.sh` asserts the label is still
present, so a campaign-specific system can't masquerade as the template
default.

## Consequences

- A fresh instance is playable immediately, and G2 always has something to
  cite.
- The default is opinionated (three attributes, a stress track) and will
  fit some genres poorly — that is acceptable because replacing it is the
  expected path, not an edge case.
- It has no combat, damage, equipment, or advancement rules. That is
  intentional (the rules gate, eval 2, exercises exactly this gap), but it
  means players will hit `[Improvisierte Regelung]` early. `system/rulings.md`
  is the pressure valve.

## Alternatives considered

- **Ship nothing** (`system/system.md` as a pure template) — cleanest
  system-agnosticism, but every instance starts unplayable and the rules
  gate has nothing to cite; rejected.
- **Ship a well-known SRD** (OSR/5e/Fate) — instantly familiar, but drags
  in licensing questions and a lot of text the agent must read every turn;
  rejected for v1.
- **A d20 default**, matching the oracle's die — considered, but the flat
  distribution makes target numbers feel swingy at low modifiers, and 2d6
  keeps the character sheet to three small numbers.
- **Ship several default systems to choose from** — more choice, more
  maintenance, and the interview already supports "bring your own".
