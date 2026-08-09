# 0004 — Skills over legacy commands

- Status: Superseded by 0015
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

- `/recap` declares `allowed-tools: Read, Glob, Grep, Bash(git log *),
  Bash(git diff *), Bash(git show *)` — read-only by construction.
- The three lifecycle skills set `disable-model-invocation: true` so the
  agent cannot trigger session bookkeeping on its own; starting and ending
  sessions is the player's call.

## Consequences

- Follows the current recommended convention; room to grow (a skill can
  later bundle checklists or helper files).
- Tool restrictions enforce "read-only" mechanically for `/recap` instead
  of relying on prompt discipline.
- If Claude Code ever drops legacy commands, nothing here changes.

## Alternatives considered

- **`.claude/commands/*.md`** — still functional but documented as legacy;
  no supporting-files story; no reason to prefer it for a new repo.
- **Both in parallel** — duplication with drift risk; rejected.
