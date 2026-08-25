# 0020 — Multiplayer interaction model: hotseat

- Status: Accepted
- Date: 2026-08-25

## Context

v1 of Spielleiter targets solo play: one player, one PC, one Claude session
per campaign repository. Sprint 2 adds support for multiple players. The
implementation tickets (data model, guardrail wording, an assist rule,
skill interviews) all depend on one prior architectural choice: *how do
several players interact with one campaign?*

The v1 hardening established invariants that any multiplayer model must
not break:

- **G1** rests on the assumption that only the GM session writes
  `journal/rolls.log` — a log line from a foreign clone is
  indistinguishable from a forged roll.
- **G4** is enforced as a byte-prefix check (`test_journal_append.sh`,
  ADR 0011/0016/0017): if two branches independently append to the same
  `journal/sessions/session-NNN.md`, the pre-merge content is no longer a
  byte prefix of the merged file — the check fails, and correctly so.
- **G6** relies on git-crypt for `gm/`; with symmetric git-crypt there is
  no role separation, so anyone who can unlock the repo can read the plot.

A distributed model (each player in their own clone, turns via git) would
have to re-engineer all three. A hotseat model touches none of them.

## Decision

1. **Multiplayer v1 is hotseat**: several player characters, **one**
   Claude session, **one** repository, one shared table. Players take
   turns at the same device — for example, one person reads the narration
   aloud and players announce their PCs' actions in seating order.
2. **The GM session remains the single writer** for `journal/` and
   `journal/rolls.log`. Players announce actions; the GM session invokes
   the dice tools and journals the results. G1 (no foreign log lines) and
   G4 (byte-prefix append) therefore hold **unchanged** — no new
   enforcement machinery is needed.
3. **Scope of multiplayer v1**: a `player:` frontmatter field assigning
   each PC to exactly one player, per-player agency wording in G5 and the
   play loop, a minimal assist ("Helfen") rule in the default system, and
   a table order ("Tischordnung") agreed in the `/new-campaign` interview
   and persisted citably in the instance's `system/system.md` (G2).
4. **Distributed play is explicitly deferred**, not designed here. The
   known blockers are recorded in the backlog epic (issue #9): parallel
   appends from independent clones break the G4 byte-prefix check;
   player-written `rolls.log` lines are forgeable, so G1 would need a
   trust model (signatures or GM-side execution); and git-crypt key
   distribution must stay GM-only, which symmetric git-crypt cannot
   express for mixed-role clones. A future spike produces its own ADR
   with a model decision before any implementation ticket exists.

## Consequences

- **G6 at the hotseat table is a trust convention, not a mechanism.** On
  the table device, `gm/` is necessarily decrypted so the GM session can
  read it. git-crypt protects the *remote* repository; G6 protects the
  *narration*. Anyone at the table who looks into the file system can
  spoil themselves. The convention **"only the chat is the game table"**
  is accepted deliberately as a trust assumption among people sharing a
  physical table, and is documented in the README's Playing section
  rather than enforced by tooling.
- Solo play becomes the special case N=1 of the same model; existing
  campaigns and the shipped demo remain valid without changes.
- `--reason` in tool invocations continues to name the **PC** (unique per
  player); the player name lives in character frontmatter, not in the
  log. The log format is unchanged.
- The guardrails G1–G6 keep their enforcement machinery unchanged; only
  wording is sharpened (G5: a PC belongs to exactly one player).
- Anything multiplayer beyond one shared device — remote players, player
  clones, PR-based turns — is out of scope until the deferred spike
  decides a model.

## Alternatives considered

- **Distributed play via git (per-player clones, turns as commits or
  PRs)** — the architecturally interesting option, and the reason this
  ADR exists: it breaks G4's byte-prefix append on merge, makes G1's log
  trust assumption false, and has no answer for role-separated git-crypt
  keys. Deferred to the spike epic (#9) rather than half-solved here.
- **Players roll their own dice (physical or own tool invocations)** —
  physical dice produce narrated numbers with no `rolls.log` line, which
  G1 defines as a critical failure; player-side tool runs make the log
  multi-writer and forgeable. Rejected: announcements go to the GM
  session, which rolls.
- **Multiple Claude sessions against one working copy** — two sessions
  appending to the same session file interleave writes and violate the
  single-writer assumption behind G4's diff-based enforcement; nothing
  arbitrates state edits (G3). Rejected.
- **One repository per player, GM merges** — fragments world state across
  repos, contradicting "the repository is the campaign world", and
  inherits every distributed-mode blocker on top. Rejected.
