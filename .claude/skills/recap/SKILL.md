---
description: Read-only summary of the campaign so far — no files are written
allowed-tools: Read, Glob, Grep
disallowed-tools: Write, Edit, NotebookEdit, Bash, Task
---

# /recap

Summarize the campaign so far. **Strictly read-only — no file writes, no
commits, no state changes.**

This is enforced, not merely requested: `disallowed-tools` removes `Write`,
`Edit`, `NotebookEdit`, `Bash` and `Task` from the pool for this turn.
`Bash` is denied too — a shell can write files and make commits, so leaving
it available would reopen exactly the hole this skill closes. The recap is
therefore built from `Read`, `Glob` and `Grep` alone; if you find yourself
wanting `git log`, read the session files instead — they are the campaign
history in readable form.

## Steps

1. Read all `journal/sessions/session-NNN.md` in order, quest files and key
   entities in `world/`, and `characters/*.md`. Do **not** use `gm/` content
   beyond what has already been disclosed into `world/` (G6).
2. Present, in the campaign language:
   - **Die Geschichte bisher** — chronological narrative summary, weighted
     toward recent sessions (older sessions compress harder).
   - **Charaktere** — current condition and notable changes.
   - **Offene Quests** — name, status, last known lead.
   - **Lose Fäden** — unresolved hooks worth remembering.
3. End by asking whether the player wants to `/session-start`.
