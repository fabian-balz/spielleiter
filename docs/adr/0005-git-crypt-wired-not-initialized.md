# 0005 — git-crypt wired but not initialized

- Status: Accepted
- Date: 2026-08-07

## Context

The spec requires `gm/**` to be git-crypt encrypted, with a plaintext
`gm/README.md` exception, and says: if git-crypt is unavailable, scaffold
everything and mark init as a manual TODO — do not silently skip.

git-crypt *is* installable in the bootstrap environment (Ubuntu 24.04
container). The real blocker is different: this is an **ephemeral cloud
container**. `git-crypt init` generates the repository key inside the
container; there is no safe channel to hand that key to the user, and the
container is reclaimed after the session. Encrypting `gm/**` with such a
key would make those files permanently undecryptable — worse than
plaintext placeholders.

A second subtlety: with `filter=git-crypt` attributes present but no
filter driver configured, git does **not** fail — it silently commits the
files as plaintext (the `required` flag only exists after `git-crypt
init`). This failure mode is invisible unless documented loudly.

## Decision

- Ship `.gitattributes` fully wired: `gm/** filter=git-crypt
  diff=git-crypt` with negations for `gm/README.md` and `gm/secrets/.gitkeep`.
- Do **not** run `git-crypt init` in the bootstrap environment. README
  documents the manual one-time init (GPG user or exported symmetric key
  kept outside the repo), unlock on fresh clones, and re-encryption of
  pre-init files via `git-crypt status -f`.
- Warn explicitly — in README and `gm/README.md` — that until init, `gm/`
  commits land in git history as plaintext; all `gm/` content committed by
  the bootstrap is spoiler-free placeholder material.
- `examples/**` is excluded from encryption on purpose: the demo campaign
  (including its `gm/`) must stay readable in every clone without a key.

## Consequences

- One manual step per instance (init + key management) — unavoidable
  without a key-escrow mechanism, which would be worse.
- The silent-plaintext window before init is documented in three places
  but not mechanically prevented; a future pre-commit hook could close it
  (would need its own ADR).
- Demo `gm/` content is public forever; nothing secret may ever be added
  under `examples/`.

## Alternatives considered

- **Init in-container + commit encrypted files** — permanent data loss;
  rejected outright.
- **Init in-container + print/export the symmetric key into the chat or
  repo** — a secret key in chat logs or git history is not a secret.
- **Leave `.gitattributes` out until the user inits** — avoids the
  silent-plaintext trap but guarantees a forgotten setup step; wiring +
  loud warnings keeps the one-time setup to `git-crypt init` alone.
- **age/SOPS instead of git-crypt** — arguably nicer tooling, but the
  spec names git-crypt and it integrates with git's filter mechanism
  transparently.
