---
description: End a play session — summary to the journal, quest updates in world/, one structured commit
disable-model-invocation: true
---

# /session-end

Close the current play session. All guardrails apply, especially G4
(append-only journal).

## Steps

1. **Session summary**: append a `## Zusammenfassung` section to the current
   `journal/sessions/session-NNN.md` — events, decisions, consequences,
   rolls that mattered (reference their `rolls.log` reasons), open threads.
   Append only; never rewrite earlier parts of the file (G4).
2. **Quest states**: update the `status:` field of affected quest files in
   `world/` (`open` → `active` → `done`/`failed`) and add a short progress
   note to each body. New quests discovered this session get their own file.
3. **Other state**: verify `characters/` and `world/` reflect everything
   that happened (G3 says this was done during play — this is a final
   consistency check, not a batch update). Fix discrepancies via file edits
   and note the correction in the session file.
4. **Commit** everything in one commit:

   ```
   git add -A && git commit -m "session-NNN: <one-line summary>"
   ```

5. Confirm to the player with the one-line summary and, if fitting, a hook
   for next time.
