# world/ — Öffentlicher Weltzustand

Eine Datei pro Entität (Ort, NSC, Fraktion, Quest): `world/<entity>.md`.
YAML-Frontmatter trägt maschinenlesbare Felder, der Body Prosa. Alles hier
ist **dem Spieler bekanntes Wissen** — Geheimnisse gehören nach `gm/` (G6).

Beispiel:

```markdown
---
type: npc            # location | npc | faction | quest
name: Mira Steinfeld
status: alive        # Quests: open | active | done | failed
tags: [haendlerin, dorf-eschenau]
---

Kurzbeschreibung und bekannte Fakten …
```

Zustandsänderungen erfolgen ausschließlich durch Edits an diesen Dateien
(G3); Narration darf Dateizustand nie widersprechen.
