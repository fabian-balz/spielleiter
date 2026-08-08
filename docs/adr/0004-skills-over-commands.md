# 0004 — Skills over legacy commands

- Status: Accepted
- Date: 2026-08-07

## Context

The spec requires `/new-campaign`, `/session-start`, `/session-end`,
`/recap` as Claude Code slash commands and explicitly says to verify the
current mechanism (`.claude/commands/` vs skills) against installed
documentation rather than guess. Verification against current Claude Code
docs (done in Phase 0) showed: both mechanisms are supported and both give
`/name` invocation; `.claude/commands/<name>.md` is the legacy format;
`.claude/skills/<name>/SKILL.md` is the recommended format and additionally
supports per-skill supporting files and frontmatter like `allowed-tools`
and `disable-model-invocation`.

## Decision

Implement all four commands as project skills:
`.claude/skills/<name>/SKILL.md`.

Frontmatter is used as a guardrail surface, not just metadata:

- `/recap` declares **`disallowed-tools: Write, Edit, NotebookEdit`** —
  this is the field that actually removes tools from the pool — plus
  `allowed-tools` for the read-only tools it does need, so those don't
  prompt.
- The three lifecycle skills set `disable-model-invocation: true` so the
  agent cannot trigger session bookkeeping on its own; starting and ending
  sessions is the player's call.

**Correction (2026-08-08, PR review):** an earlier revision of this ADR
claimed `allowed-tools` alone made `/recap` "read-only by construction".
That was wrong. Per the Claude Code skills documentation, `allowed-tools`
only *pre-approves* the listed tools (they skip permission prompts); other
baseline-permitted tools such as `Write` remain available. `disallowed-tools`
is the field that removes tools from Claude's pool. `/recap` now sets both.

## Consequences

- Follows the current recommended convention; room to grow (a skill can
  later bundle checklists or helper files).
- `/recap` is read-only via `disallowed-tools` (turn-scoped tool removal),
  not via prompt discipline. Note the scope: this binds the skill's turn.
  A campaign that wants a hard, persistent boundary can additionally deny
  the same tools in `.claude/settings.json`.
- If Claude Code ever drops legacy commands, nothing here changes.

## Alternatives considered

- **`.claude/commands/*.md`** — still functional but documented as legacy;
  no supporting-files story; no reason to prefer it for a new repo.
- **Both in parallel** — duplication with drift risk; rejected.
