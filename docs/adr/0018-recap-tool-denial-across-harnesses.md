# 0018 — Deny the subagent tool under every name it goes by

- Status: Accepted
- Date: 2026-08-09
- Supersedes: 0015

## Context

ADR 0015 made `/recap` read-only by denying `Write`, `Edit`, `NotebookEdit`,
`Bash` and `Task`. The third review pointed out that **the tool is not called
`Task` in current harnesses — it is `Agent`.** A deny list naming only `Task`
therefore may not deny anything at all: a subagent could be spawned, and it
would run with its own tool pool, able to write files on the skill's behalf.

This is the third variation of the same mistake in this branch:

- Round 1: `allowed-tools` was assumed to deny (it only pre-approves).
- Round 2: the editing tools were denied while `Bash` stayed available.
- Round 3: the subagent tool was denied under a name the harness does not use.

Each time the *shape* of the fix was right and the *binding to reality* was
not. The pattern is worth naming: **security properties asserted against
identifiers that vary across environments must be verified in the
environment, not derived from documentation.**

## Decision

- `/recap` denies the subagent tool under **both** known names:
  `disallowed-tools: Write, Edit, NotebookEdit, Bash, Task, Agent`.
- The skill body instructs the agent to **verify rather than assume**: if a
  write-capable tool is in fact available during `/recap`, it must stop and
  tell the player the read-only guarantee is not holding in this
  environment, instead of proceeding on trust. A guarantee that silently
  degrades is worse than one the player knows is absent.
- The claim in documentation is scoped to what is actually enforced:
  `disallowed-tools` binds this skill's turn. Campaigns wanting a persistent
  boundary should additionally deny those tools in `.claude/settings.json`.

An automated test that a subagent call is refused mid-skill was requested.
It is **not** included: asserting on tool-permission behaviour requires
driving the harness through a skill invocation and observing a denial, which
`claude -p` does not expose in a stable, machine-checkable form. Rather than
ship a test that would pass vacuously — the exact failure this review round
already found twice — the runtime self-check above is the mitigation, and
`evals/MANUAL.md` carries it as a documented manual check.

## Consequences

- Two names are denied for one tool; harmless if one is unknown to the
  harness, and it survives a rename in either direction.
- The read-only claim now has a runtime fallback rather than resting purely
  on frontmatter that a future harness might interpret differently.
- Any future skill asserting a tool boundary must enumerate aliases and
  carry the same self-check. This generalizes beyond `/recap`.

## Alternatives considered

- **Deny only `Agent`** (the name this harness uses) — breaks if the
  published `Task` name is what a given harness honours; denying both costs
  nothing.
- **A `PreToolUse` hook denying writes during `/recap`** — a genuinely
  stronger boundary, and still worth adding; but hooks live in settings that
  a fresh instance may not carry, so it cannot be the primary mechanism for
  a template (same objection as ADR 0011). Deferred.
- **Dropping the "read-only by construction" claim entirely** and relying on
  instructions — honest, but gives up an enforcement mechanism that does
  work for the tools whose names are stable.
- **Shipping the requested integration test anyway** — it could not be made
  to fail on a real violation with the tooling available, and an
  always-green test counted as coverage is precisely what this branch has
  been punished for three times.
