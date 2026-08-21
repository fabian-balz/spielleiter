---
template: true
---

# Spielleiter

An agentic Game Master for pen & paper RPGs, running inside
[Claude Code](https://claude.com/claude-code). A campaign repository is the
campaign world: all state lives in versioned files, git history is campaign
history. v1 targets **solo play** and is system-agnostic.

> **This repository is a template, not a campaign.** You don't play here —
> you create a private *instance* per campaign (see
> [Starting a campaign](#starting-a-campaign-instantiation)) and play
> there. No campaign content ever lands in the template; an executable
> check (`evals/test_template_clean.sh`) enforces this, and `/new-campaign`
> refuses to run while the `template: true` marker at the top of this file
> is present. The only campaign in this repo is the curated demo under
> `examples/mini-campaign/`.

**Core principle:** the agent narrates and interprets. It never generates
randomness (dice come from `tools/`), never invents rules (rules live in
`system/`), never mutates state outside of structured file edits. The
guardrails are defined in [CLAUDE.md](CLAUDE.md).

## Layout

```
spielleiter/
├── CLAUDE.md              # GM persona + guardrails G1–G6 + play loop
├── system/                # Rules-as-data (per campaign)
│   ├── system.md          # Dice mechanic, resolution, character model, oracle odds
│   ├── tables/            # Random tables (YAML: id, die, entries)
│   └── rulings.md         # Accepted improvised rulings (append-only)
├── world/                 # Public world state (one .md per entity)
├── characters/            # Player characters (frontmatter = stats)
├── journal/
│   ├── sessions/          # session-NNN.md, append-only
│   └── rolls.log          # Machine-written by tools, never hand-edited
├── gm/                    # GM-only material (git-crypt encrypted)
├── tools/
│   ├── roll.sh            # Dice roller
│   └── oracle.sh          # Solo-play oracle + table lookup
├── evals/                 # Acceptance tests (executable + manual scenarios)
├── examples/              # Demo mini-campaign with one full solo session
└── docs/adr/              # Architecture Decision Records (template development)
```

## Requirements

- **bash 3.2+.** The tools deliberately avoid bash-4-only features
  (`mapfile`/`readarray`, associative arrays, `${var^^}`) and use the
  regex-in-variable form that bash 3.2 requires, so they should run on the
  `/bin/bash` macOS ships. Caveat: this is a code-level guarantee, not a
  tested one — CI here only has bash 5.2. If you hit a 3.2 problem, please
  report it; the fix is in scope.
- **coreutils**: `date`, `od`, `sort`, `head`, `tr`, `wc`, `mktemp`,
  `find`, `printf`.
- **POSIX text utilities** used by the tools and evals: `sed`, `grep`.
  The runtime tools (`roll.sh`, `oracle.sh`) parse YAML in pure bash — no
  `awk`, `yq`, `jq`, or python.
- **git**, plus **git-crypt** and **gpg** for the `gm/` directory.

No other runtime dependencies; nothing is installed or downloaded at
runtime.

## Starting a campaign (instantiation)

1. **Create your instance** — either click **Use this template** on GitHub
   (choose *private* for a real campaign), or clone and re-init:

   ```sh
   git clone <template-url> my-campaign && cd my-campaign
   rm -rf .git && git init && git add -A && git commit -m "chore: instance from spielleiter template"
   ```

2. **Mark it as an instance**: delete the `template: true` frontmatter at
   the top of this README (and, ideally, this whole instantiation section).
   `/new-campaign` checks for the marker and will not create campaign
   content while it is present.
3. **Set up encryption** for `gm/`: complete the
   [git-crypt setup](#git-crypt-setup) below *before* any real secrets
   exist.
4. Open the instance in Claude Code and run `/new-campaign` — interview:
   rules system, setting, safety tools (lines & veils), first character.
   **Spec-Gate:** no campaign-specific content — rules, setting, characters,
   world, plot — is written before you approve the distilled system. If the
   instance is missing directories or placeholder files, `/new-campaign`
   repairs that scaffold first and tells you it did; empty scaffolding is
   explicitly not campaign content.

## Playing

- `/session-start` — recap + opening scene. Play.
- `/session-end` — session summary, quest updates, one commit per session.
- `/recap` — read-only campaign summary any time.

### Dice & oracle (also usable by hand)

```
tools/roll.sh 2d6+3 --reason "Probe: Klettern"     # NdM, NdM±K, NdMkhX
tools/oracle.sh yesno --likelihood unlikely --reason "Regnet es?"
tools/oracle.sh table komplikationen --reason "Reiseereignis"
```

Every invocation appends one line to `journal/rolls.log` and prints it. A
`--seed N` flag makes results reproducible (used by the tests).

`--reason` is **required**: it must be a single line and must not contain
`|`. This is an integrity guard, not pedantry — a newline in the reason
would append a second physical log line, i.e. a forged roll (G1). Table ids
are bare names (`komplikationen`), never paths.

## git-crypt setup

`gm/` holds spoilers: plot, hidden stats, prepared twists. `.gitattributes`
marks `gm/**` for git-crypt encryption, with two deliberate plaintext
exceptions: `gm/README.md` (explains the directory) and
`gm/secrets/.gitkeep` (empty directory placeholder).

> ⚠️ **Manual step required (TODO).** This repository was scaffolded in an
> environment where running `git-crypt init` would have generated a key that
> could not be handed to you — so git-crypt is **wired but not initialized**.
> Until you complete the steps below, the filters are inert and anything you
> commit under `gm/` lands in git history as **plaintext**. The placeholder
> content currently in `gm/` is spoiler-free on purpose. Do not put real
> secrets there before finishing this setup.

One-time initialization (on your machine):

```sh
brew install git-crypt          # macOS; Debian/Ubuntu: apt install git-crypt
git-crypt init

# Option A — GPG (recommended, per-user):
git-crypt add-gpg-user <your-gpg-key-id>

# Option B — symmetric key file (keep it OUTSIDE the repo!):
git-crypt export-key ~/spielleiter.key

# Re-encrypt the files that were committed before init:
git-crypt status -f
git add -A && git commit -m "chore: encrypt gm/ with git-crypt"
```

On a fresh clone:

```sh
git-crypt unlock                    # GPG
git-crypt unlock ~/spielleiter.key  # symmetric key
```

Note: the demo campaign under `examples/` keeps its `gm/` directory
deliberately unencrypted (see `.gitattributes`) so the example stays readable.

## Tests

```sh
evals/test_roll.sh
evals/test_oracle.sh
evals/test_journal_append.sh
evals/test_journal_states.sh      # negative controls: 13 journal states, 9 must fail
evals/test_template_clean.sh      # template repo only: no campaign content in root
evals/test_fresh_instance.sh      # minimal-instance lifecycle preconditions
evals/test_secret_leak.sh --self-test          # proves the G6 leak detector works
evals/test_secret_leak.sh <transcript-file>    # scans narration for GM-only markers
```

One mode is opt-in because it is slow, nondeterministic and needs
credentials:

```sh
evals/test_fresh_instance.sh --with-agent   # drives headless Claude Code
```

`--with-agent` additionally needs the `claude` CLI and, for a bounded run,
`timeout` (GNU) or `gtimeout` (macOS `coreutils`); without either it runs
unbounded. It drives two headless turns: the agent must refuse in a template
repo, and in an instance it must self-heal the scaffold while writing no
campaign content before approval.

Test-only dependencies beyond the runtime list: `git`, `diff` and `cmp`
(`diffutils` on GNU systems), and either `sha256sum` (GNU coreutils) or
`shasum` (macOS) — the snapshot check accepts both.

Behavioral acceptance tests for the agent itself (dice integrity, rules gate,
player agency, secret leakage) are documented in `evals/MANUAL.md`.

## Continuous integration

`.github/workflows/evals.yml` runs the deterministic suites and a
`shellcheck` lint (warning severity) on every push and pull request. The
opt-in `--with-agent` lifecycle mode and the manual behavioral evals
(`evals/MANUAL.md`) are not part of CI — the former needs credentials, the
latter need a human.

## Developing the template

Architectural decisions are recorded as ADRs in `docs/adr/` — at decision
time, not retroactively (see `docs/adr/README.md`).
