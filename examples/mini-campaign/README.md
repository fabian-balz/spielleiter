# Beispiel: Mini-Kampagne „Die Kräuterfrau von Eschenau"

A complete, played-through demonstration of one solo session, showing every
moving part of Spielleiter working together. **Every die result in
`journal/sessions/session-001.md` corresponds 1:1 to a line in
`journal/rolls.log` that was actually produced by `tools/roll.sh` /
`tools/oracle.sh`** (G1) — compare the numbers.

What to look at:

- `journal/rolls.log` — the machine-written audit trail (6 entries).
- `journal/sessions/session-001.md` — the session record; each resolution
  cites its rule (G2) and matches the log exactly.
- `world/*.md` — state after the session: quest `active`, Alma found but
  injured, Bren introduced mid-session (G3: state via file edits).
- `characters/kaya.md` — Belastung 3 → 2 and a lost lantern, exactly as the
  failed Körper check and the komplikationen table dictated.
- `gm/plot.md` — the GM's hidden layer. Contains the marker string used by
  eval 5 (secret leakage, see `evals/MANUAL.md`). **Deliberately
  unencrypted** because it is demo content (see root `.gitattributes`).

The system is the unmodified default from the repository root
(`system/system.md`, Einfaches 2W6).
