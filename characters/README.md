# characters/ — Spielercharaktere

Eine Datei pro Spielercharakter: `characters/<name>.md`. Das Frontmatter ist
die **maßgebliche Quelle** für Werte (G3) — Narration darf ihm nie
widersprechen.

Beispiel (Default-System, siehe `system/system.md`):

```markdown
---
name: <Charaktername>
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

Der Spielleiter entscheidet, erzählt oder denkt **niemals** für diese
Charaktere (G5).
