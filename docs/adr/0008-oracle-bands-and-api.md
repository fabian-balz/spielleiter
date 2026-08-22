# 0008 — Oracle bands and API

- Status: Accepted
- Date: 2026-08-08 (documenting a decision made during M1)

## Context

Solo play needs a way to answer questions the rules don't cover ("Is the
guard bribable?") without the GM inventing the answer — that would be the
LLM deciding world facts, the same failure mode G1 forbids for dice. The
spec asked for a Mythic-GME-style yes/no oracle with Yes / No / Yes-but /
No-but and three likelihood settings, with the exact odds documented in
`system.md`.

## Decision

`oracle.sh yesno [--likelihood likely|even|unlikely]` rolls **1d20** and
maps the result to four outcomes with these bands:

| Likelihood | Yes | Yes-but | No-but | No |
|---|---|---|---|---|
| `likely`   | 1–11 (55 %) | 12–13 (10 %) | 14–15 (10 %) | 16–20 (25 %) |
| `even`     | 1–8 (40 %)  | 9–10 (10 %)  | 11–12 (10 %) | 13–20 (40 %) |
| `unlikely` | 1–5 (25 %)  | 6–7 (10 %)   | 8–9 (10 %)   | 10–20 (55 %) |

Design points:

- **1d20, not 1d100.** Twenty steps are enough granularity for three
  likelihood tiers, and a d20 is a die every RPG group owns — a player can
  reproduce the oracle at the table by hand.
- **"but" bands are a flat 10 % each**, independent of likelihood: the
  chance of a complication doesn't depend on how likely the answer was,
  only the yes/no split does. This keeps the table readable and the bands
  memorable.
- **`even` is symmetric** (40/10/10/40); `likely` and `unlikely` are exact
  mirrors of each other (55/10/10/25 ↔ 25/10/10/55).
- The odds live in `system/system.md` § Orakel, and `evals/test_oracle.sh`
  re-derives the expected result from the rolled number over 120 seeds —
  so the documentation and the implementation cannot drift apart silently.
- The GM picks the likelihood **openly and justifies it briefly**, so the
  player can object; a hidden likelihood choice would smuggle GM judgement
  back in.

## Consequences

- Three tiers only. A "very likely / very unlikely" extension would need
  new bands and a superseding ADR.
- Because the bands are hard-coded in `oracle.sh`, a campaign that wants
  different odds must edit the script *and* `system.md` — the test will
  fail until both agree, which is the intended forcing function.
- The oracle answers *questions about the world*, never *what a PC does*
  (G5); nothing in the tool enforces that — it is a CLAUDE.md rule.

## Alternatives considered

- **Mythic's full Fate Chart** (rank × odds matrix with doubles for random
  events) — richer, but needs a chaos-factor state variable that would have
  to live in a file and be updated every scene; too much machinery for v1.
- **2d6 oracle** (as used by many PbtA-adjacent solo systems) — the bell
  curve makes flat 10 % "but" bands impossible without ugly fractions.
- **1d100 with percentage bands** — trivially readable odds, but not a die
  most tables roll by hand, and the extra granularity buys nothing at three
  tiers.
- **Letting the model answer directly** — rejected outright: this is the
  G1 problem in a different costume.
