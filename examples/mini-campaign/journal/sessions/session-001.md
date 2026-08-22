# Session 001 — Ins Moor

- Datum: 2026-08-07
- Beteiligt: Kaya (Spieler), Spielleiter

## Beats

### 1. Almas Hütte

Kaya erreicht Eschenau am späten Nachmittag und geht direkt zu Almas Hütte:
Tür offen, Tisch umgeworfen, Kräuterbündel am Boden. Spieler: „Ich lese die
Spuren — was ist hier passiert?"

**Probe** (Regel: `system/system.md` § Proben, Geist, Schwierigkeit
Normal 9): `2d6+2` → Würfel [3,3], **gesamt 8** — Fehlschlag.
(rolls.log: `2026-08-07T18:48:50Z | 2d6+2 | dice=[3,3] | total=8`)

Konsequenz: Kaya verliert sich im Durcheinander der Hütte; als sie die
Schleifspuren hinter dem Haus endlich bemerkt, ist das Tageslicht fast
aufgebraucht. Die Suche beginnt in der Dämmerung.

### 2. Die Spuren

Spielleiter-Frage ans Orakel (Regel: `system/system.md` § Orakel):
„Führen die Schleifspuren Richtung Moor?" — likelihood `likely`, Wurf
[12] → **Yes-but**.
(rolls.log: `oracle:yesno(likely) | dice=[12] | total=12 | result=Yes-but`)

Ja — aber der Regen der letzten Nacht hat sie halb verwaschen; ab dem
Moorrand sind sie kaum noch zu halten.

### 3. Unterwegs

Ereigniswurf (Regel: `system/system.md` § Zufallstabellen), Tabelle
`komplikationen`: Wurf [2] → „Etwas geht zu Bruch oder verloren – ein
Ausrüstungsgegenstand ist betroffen."
(rolls.log: `table:komplikationen | dice=[2] | total=2`)

Beim Übersetzen über den Bachlauf schlägt Kayas Laterne gegen einen Stein —
Glas und Docht sind hin. Weiter geht es im letzten Dämmerlicht.
→ Zustandsänderung: `characters/kaya.md`, Laterne aus dem Inventar.

### 4. Das Moor

Der Boden gibt unter Kaya nach. Spieler: „Ich springe zurück auf den
Grasbuckel!"

**Probe** (Körper, gefährliche Lage, Schwierigkeit Normal 9): `2d6+1` →
Würfel [3,1], **gesamt 5** — Fehlschlag.
(rolls.log: `2d6+1 | dice=[3,1] | total=5`)

Konsequenz (Regel: `system/system.md` § Charaktermodell, Zustand): Kaya
bricht bis zur Hüfte ein und schlägt sich das Knie auf — **1 Belastung**
(3 → 2). → `characters/kaya.md` aktualisiert. Aus dem Schilf vor ihr:
ein schwaches Rufen.

### 5. Alma

Dem Rufen folgend findet Kaya Alma in einer Senke, das linke Bein unter
einem gestürzten Wurzelteller eingeklemmt. Orakel: „Ist Alma unverletzt?" —
likelihood `unlikely`, Wurf [10] → **No**.
(rolls.log: `oracle:yesno(unlikely) | dice=[10] | total=10 | result=No`)

Das Bein ist vermutlich gebrochen, Alma unterkühlt und kaum ansprechbar.
Kaya bekommt sie frei und schleppt sie Richtung Moorrand.
→ `world/alma.md`: gefunden, verletzt.

### 6. Der Köhler

Am Meiler des Köhlers Bren will Kaya Hilfe holen. Bren starrt die beiden
an, als sähe er Gespenster. Spieler: „Ich rede ruhig mit ihm — wir brauchen
nur sein Feuer und einen Schlitten."

**Probe** (Charme, Schwierigkeit Leicht 7): `2d6+0` → Würfel [3,2],
**gesamt 5** — Fehlschlag.
(rolls.log: `2d6+0 | dice=[3,2] | total=5`)

Konsequenz: Bren weicht zurück — „Ich hab nichts gesehen, nicht bei dem
Licht!" — und flieht in die Dunkelheit. Kaya bleibt sein Feuer, aber keine
Hilfe. → `world/bren.md` angelegt.

## Zusammenfassung

Kaya hat Alma lebend aus dem Moor geholt — verletzt, unterkühlt, und ohne
Erklärung, wie sie dorthin kam. Die Hütte zeigt Kampfspuren, die Spuren
führten ins Moor, und der Köhler Bren ist vor irgendetwas geflohen, das er
„das Licht" nennt. Quest `vermisste-kraeuterfrau`: **active**.

Würfe dieser Session: 6 (siehe `journal/rolls.log`, alle mit reason).
Belastung Kaya: 2/3. Verloren: Laterne.

Offene Fäden: Wer oder was brachte Alma ins Moor? Was hat Bren gesehen?
