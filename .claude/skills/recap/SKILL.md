---
description: Read-only summary of the campaign so far — no files are written
allowed-tools: Read, Glob, Grep, Bash(git log *), Bash(git diff *), Bash(git show *)
disallowed-tools: Write, Edit, NotebookEdit
---

# /recap

Summarize the campaign so far. **Strictly read-only — no file writes, no
commits, no state changes.**

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
