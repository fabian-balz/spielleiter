# 0006 — Template/instance separation

- Status: Accepted
- Date: 2026-08-07

## Context

"The repository is the campaign world" invites a category mistake: playing
a campaign *in this repository*. This repo is a reusable **template**; a
real campaign is a separate, typically private, **instance** created from
it. Without an enforced boundary, campaign content (sessions, characters,
secrets) would accumulate in the template, breaking every future
instantiation and leaking one campaign's material into all others.

## Decision

1. **The template root ships only scaffolds**: the labeled default system,
   convention READMEs in `world/`/`characters/`, an empty
   `journal/rolls.log`, no session files, placeholder-only `gm/`. The one
   full campaign in the repo lives under `examples/mini-campaign/` as a
   curated, read-only demo.
2. **Instances are created from the template**, never played in it:
   GitHub "Use this template" (or clone + re-init git) → `git-crypt init`
   + key setup → `/new-campaign`. README documents this flow.
3. **`/new-campaign` must work in a fresh instance**: its first step
   verifies/creates the scaffold (directories, `rolls.log`, placeholder
   files) so even a minimal copy self-heals; it also refuses to run in
   the template repo itself (detected via the `template: true` marker in
   the root README frontmatter, which the instantiation flow says to
   remove; ambiguity → ask the player).
4. **Cleanliness is enforced, not aspirational**:
   `evals/test_template_clean.sh` fails if the template root contains
   campaign content (session files, non-empty `rolls.log`, entity files
   in `world/`/`characters/` beyond the READMEs, non-placeholder `gm/`).
   The demo under `examples/` is exempt.

## Consequences

- The template stays instantiable forever; campaign privacy is the
  instance's concern (private repo + git-crypt).
- One more marker to maintain (`template: true` in README frontmatter) and
  the instantiation flow must mention removing it.
- Template development and campaign play are distinct modes; CLAUDE.md
  states which applies where, and ADR discipline binds template work.
- The mini-campaign is duplicated relative to a "real" instance layout by
  design — it is documentation, not a playable save-game.

## Alternatives considered

- **Branch-per-campaign in one repo** — mixes template evolution with
  campaign history; git-crypt keys and access control don't split by
  branch; rejected.
- **Campaigns as subdirectories** (`campaigns/<name>/`) — every path in
  CLAUDE.md, tools, and skills would need a campaign-root indirection;
  the "repo = world, git history = campaign history" principle dies.
- **Detection via remote URL or repo name** instead of a README marker —
  brittle (forks, renames, self-hosted remotes); an explicit marker the
  instantiation flow removes is dumb and reliable.
- **No mechanical enforcement** — the eval costs little and catches the
  most likely failure mode (an absent-minded `/session-start` in the
  template checkout).
