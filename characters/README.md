# characters/ — Spielercharaktere

Eine Datei pro Spielercharakter: `characters/<name>.md`. Das Frontmatter ist
die **maßgebliche Quelle** für Werte (G3) — Narration darf ihm nie
widersprechen.

Beispiel (Default-System, siehe `system/system.md`):

```markdown
---
name: <Charaktername>
player: <Spielername>
type: pc
koerper: 1
geist: 2
charme: 0
belastung: 3        # aktuelle Belastungspunkte (max. 3)
inventar:
  - <Gegenstand>
  - <Gegenstand>
---

Hintergrund, Aussehen, Bindungen …
```

`player:` ordnet den PC genau **einem** Spieler zu (G5): ein frei
gewählter Anzeigename — Spitzname genügt, niemand muss seinen Realnamen
eintragen. Im Solo-Spiel darf das Feld entfallen. In `--reason` der
Würfel-Tools steht weiterhin der **PC-Name** (pro Spieler eindeutig);
der Spielername gehört ins Frontmatter, nicht ins Log.

Der Spielleiter entscheidet, erzählt oder denkt **niemals** für diese
Charaktere (G5).
