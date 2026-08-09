# 0015 — `/recap` is made read-only by denying tools, including Bash

- Status: Accepted
- Date: 2026-08-09
- Supersedes: 0004 (the `/recap` enforcement claim; the skills-over-commands
  decision itself stands)

## Context

ADR 0004 claimed that `allowed-tools: Read, Glob, Grep, Bash(git log *), …`
made `/recap` "read-only by construction". Two review rounds dismantled
this in stages:

1. **`allowed-tools` is not a deny boundary.** Verified against the Claude
   Code skills documentation: it *pre-approves* the listed tools (they skip
   permission prompts); tools not listed remain available under baseline
   permissions. `disallowed-tools` is the field that removes tools from the
   pool. 0004's claim was simply wrong.
2. **The first fix was still incomplete.** Adding
   `disallowed-tools: Write, Edit, NotebookEdit` while keeping
   `Bash(git log *)` in `allowed-tools` left `Bash` available — and a shell
   writes files and makes commits. Denying the file-editing tools while
   leaving a shell open is not a boundary; it is a speed bump.

## Decision

`/recap` declares:

```yaml
allowed-tools: Read, Glob, Grep
disallowed-tools: Write, Edit, NotebookEdit, Bash, Task
```

`Bash` is denied outright, so the recap is built from `Read`, `Glob` and
`Grep` alone. `Task` is denied too: a subagent would run with its own tool
pool and could write on the skill's behalf, which would reopen the hole
indirectly. The skill body states the constraint and points readers at the
session files instead of `git log`, since the journal *is* the campaign
history in readable form.

The scope is stated honestly in the skill and here: `disallowed-tools` binds
the skill's turn. A campaign wanting a persistent boundary should also deny
those tools in `.claude/settings.json`.

## Consequences

- `/recap` cannot show commit-level history (dates, hashes). Acceptable:
  the recap is a narrative summary for a player, not a repo audit.
- Losing `Bash` also loses `git log` as a cheap chronological index; the
  skill must read `journal/sessions/` in filename order instead. That is
  the authoritative order anyway.
- The general lesson, applied beyond this skill: **a deny list that leaves a
  general-purpose execution tool available denies nothing.** Any future
  read-only skill must deny `Bash` and `Task`, not just the editing tools.

## Alternatives considered

- **Keep `Bash(git log *)` narrowly scoped** — the `Bash(pattern)` form
  constrains *pre-approval*, not availability; it does not prevent other
  `Bash` calls from being requested. This misreading is what produced the
  incomplete first fix.
- **A restricted subagent for the recap** — a real boundary, but heavier,
  and the subagent's own tool pool becomes the thing to get right; the
  `Task` denial here is the cheaper half of the same idea.
- **A `PreToolUse` hook denying writes during recap** — persistent and
  robust, but hooks live in settings that a fresh instance may not carry
  (the same objection as in 0011). Worth adding as defence in depth later.
- **Accept prompt discipline** ("do not write files") — this is what the
  original claim effectively reduced to, and it is not enforcement.
