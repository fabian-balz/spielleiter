# Spielleiter

An agentic Game Master for pen & paper RPGs, running inside
[Claude Code](https://claude.com/claude-code). The repository itself is the
campaign world: all state lives in versioned files, git history is campaign
history. v1 targets **solo play** and is system-agnostic.

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
└── examples/              # Demo mini-campaign with one full solo session
```

## Requirements

bash, coreutils, git — plus git-crypt and gpg for the `gm/` directory.
No other runtime dependencies.

## Quickstart

1. Clone, then complete the [git-crypt setup](#git-crypt-setup) below.
2. Open the repository in Claude Code.
3. `/new-campaign` — interview: rules system, setting, safety tools (lines &
   veils), first character. Nothing is written before you approve the
   distilled system.
4. `/session-start` — recap + opening scene. Play.
5. `/session-end` — session summary, quest updates, one commit per session.
6. `/recap` — read-only campaign summary any time.

### Dice & oracle (also usable by hand)

```
tools/roll.sh 2d6+3 --reason "Probe: Klettern"     # NdM, NdM±K, NdMkhX
tools/oracle.sh yesno --likelihood unlikely --reason "Regnet es?"
tools/oracle.sh table komplikationen
```

Every invocation appends one line to `journal/rolls.log` and prints it. A
`--seed N` flag makes results reproducible (used by the tests).

## git-crypt setup

`gm/` holds spoilers: plot, hidden stats, prepared twists. `.gitattributes`
marks `gm/**` for git-crypt encryption (with a plaintext exception for
`gm/README.md`).

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
```

Behavioral acceptance tests for the agent itself (dice integrity, rules gate,
player agency, secret leakage) are documented in `evals/MANUAL.md`.
