---
description: Read-only summary of the campaign so far — no files are written
allowed-tools: Read, Glob, Grep
disallowed-tools: Write, Edit, NotebookEdit, Bash, Task, Agent
---

# /recap

Summarize the campaign so far. **Strictly read-only — no file writes, no
commits, no state changes.**

This is enforced, not merely requested: `disallowed-tools` removes `Write`,
`Edit`, `NotebookEdit`, `Bash`, `Task` and `Agent` from the pool for this
turn. `Bash` is denied because a shell writes files and makes commits.
The subagent tool is denied under **both** names — it is `Task` in the
published skills documentation and `Agent` in current harnesses, and a
subagent would run with its own tool pool, reopening the hole indirectly.

The recap is therefore built from `Read`, `Glob` and `Grep` alone; if you
find yourself wanting `git log`, read the session files instead — they are
the campaign history in readable form.

**Verify, don't assume.** Tool names are a moving target across harnesses.
If a write-capable tool is available to you during this skill despite the
list above, stop and tell the player that the read-only guarantee is not
holding in this environment, rather than proceeding on trust.

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
