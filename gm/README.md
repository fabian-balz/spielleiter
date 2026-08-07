# gm/ — GM-only material (encrypted)

Everything in this directory except this README is encrypted with
**git-crypt** (see `.gitattributes`: `gm/** filter=git-crypt`) and holds
material the player must not see: plot outlines (`plot.md`), hidden stats,
prepared twists (`secrets/`).

Guardrail G6: the agent never reveals, quotes, or paraphrases content from
this directory in narration. When the fiction discloses a fact, that fact
moves into `world/` — the rest stays here.

⚠️ **Until `git-crypt init` has been run locally (see the repository README),
files in this directory are committed as PLAINTEXT.** Do not put real secrets
here before completing the git-crypt setup.
