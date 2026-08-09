---
language: de
system: Einfaches 2W6 (Default)
version: 0.1
---

# System: Einfaches 2W6 (Default)

> Dies ist das minimale Default-System von Spielleiter. `/new-campaign`
> ersetzt oder erweitert diese Datei nach Absprache mit dem Spieler.
> Jede Regelentscheidung des Spielleiters muss einen Abschnitt dieser Datei
> (oder `system/rulings.md`) zitieren — siehe CLAUDE.md G2.

## Proben

Wenn der Ausgang einer Handlung ungewiss und ein Scheitern interessant ist,
wird gewürfelt: **2d6 + Attribut** gegen eine Schwierigkeit.

| Schwierigkeit | Zielwert |
|---|---|
| Leicht | 7 |
| Normal | 9 |
| Schwer | 11 |

Die drei Ergebnisse sind überschneidungsfrei — genau einer der Fälle trifft zu:

- **Erfolg:** Ergebnis **>** Zielwert. Es gelingt wie beabsichtigt.
- **Erfolg mit Haken:** Ergebnis **=** Zielwert (Gleichstand). Es gelingt,
  aber mit Kosten oder Komplikation (Spielleiter darf
  `tools/oracle.sh table komplikationen` befragen).
- **Fehlschlag:** Ergebnis **<** Zielwert. Die Situation verschlechtert sich;
  ein bloßes "nichts passiert" ist kein Fehlschlag.
- Kein Wurf ohne Ungewissheit: Triviales gelingt automatisch, Unmögliches
  scheitert automatisch.

## Charaktermodell

Drei Attribute, bei Charaktererschaffung verteilt als **+2, +1, +0**:

| Attribut | Deckt ab |
|---|---|
| **Körper** | Kraft, Geschick, Zähigkeit, Kampf |
| **Geist** | Wissen, Wahrnehmung, Willenskraft |
| **Charme** | Überzeugen, Täuschen, Auftreten |

- **Zustand:** Charaktere haben 3 Belastungspunkte. Ein Fehlschlag in
  gefährlicher Lage kann 1 Punkt kosten. Bei 0 Punkten ist der Charakter
  außer Gefecht (nicht automatisch tot — der Spieltisch entscheidet).
- Erholung: eine sichere Rast stellt alle Belastungspunkte wieder her.
- Frontmatter der Charakterdatei (`characters/<name>.md`) ist die maßgebliche
  Quelle für Werte (G3).

## Orakel (Solo-Spiel)

Fragen an die Spielwelt, die keine Probe sind, beantwortet
`tools/oracle.sh yesno` mit einem 1d20-Wurf. Exakte Odds:

| Likelihood | Yes | Yes-but | No-but | No |
|---|---|---|---|---|
| `likely`   | 1–11 (55 %) | 12–13 (10 %) | 14–15 (10 %) | 16–20 (25 %) |
| `even`     | 1–8 (40 %)  | 9–10 (10 %)  | 11–12 (10 %) | 13–20 (40 %) |
| `unlikely` | 1–5 (25 %)  | 6–7 (10 %)   | 8–9 (10 %)   | 10–20 (55 %) |

- **Yes-but:** Ja, aber mit Einschränkung oder Preis.
- **No-but:** Nein, aber mit Trostpreis oder neuer Gelegenheit.
- Die Likelihood wählt der Spielleiter offen und begründet sie kurz.

## Zufallstabellen

`system/tables/<id>.yaml`, aufgelöst ausschließlich über
`tools/oracle.sh table <id>` (G1). Format:

```yaml
id: <table-id>
die: <NdM-Ausdruck>
entries:
  1-2: "Eintragstext"
  3: "Eintragstext"
```

## Sicherheit (Lines & Veils)

> Von `/new-campaign` im Interview gefüllt.

- **Lines** (kommt nicht vor): —
- **Veils** (nur abgeblendet): —
