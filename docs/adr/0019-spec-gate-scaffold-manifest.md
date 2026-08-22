# 0019 — The pre-approval scaffold is a byte-exact, default-deny manifest

- Status: Accepted
- Date: 2026-08-21

## Context

Seven review rounds attacked the fresh-instance Spec-Gate checker
(`check_instance_healed` in `evals/test_fresh_instance.sh`), and every
round found the same class of hole in a new place: the checker enumerated
*known-bad* states (campaign files in three counted directories, plot
content in `gm/plot.md`, a ruling after the separator …) and attackers
moved to the nearest *unenumerated* neighbor — `system/house-rules.md`,
`gm/twist.md`, `journal/hidden.md`, a tampered `world/README.md`, content
in headings, content before separators, content in `.gitkeep`, symlinked
directories, nested symlinks.

A denylist of observed attacks cannot converge: the space of "places to
put campaign content under five writable roots" is unbounded, and each fix
certified only that yesterday's attack no longer works.

A second, independent defect: the skill and the checker described the
"empty placeholder" state differently. The skill permitted self-authored
rulings headers and free-form plot placeholders while the checker demanded
byte-exact template files — an agent could follow the skill faithfully and
still fail the check.

## Decision

1. **The state immediately before the Spec-Gate is specified as a closed
   manifest**, not as the absence of known-bad content. Under the
   protected roots `system/`, `world/`, `characters/`, `journal/`, `gm/`
   exactly these entries may exist:

   | Entry | Type | Content | Presence |
   |---|---|---|---|
   | `system/`, `system/tables/`, `world/`, `characters/`, `journal/`, `journal/sessions/`, `gm/`, `gm/secrets/` | directory | — | required |
   | `system/system.md`, `system/rulings.md`, `system/tables/komplikationen.yaml`, `gm/plot.md` | regular file | byte-identical to the canonical template file | required |
   | `journal/rolls.log`, `gm/secrets/.gitkeep` | regular file | byte-empty | required |
   | `world/README.md`, `characters/README.md`, `gm/README.md` | regular file | byte-identical to the template | optional |
   | `journal/sessions/.gitkeep` | regular file | byte-empty | optional |

   Everything else is rejected by default: extra regular files, extra
   directories (even empty ones — a name can carry content), symlinks at
   any depth (even when the target is byte-identical to the canonical
   file), and non-regular file types (FIFOs, sockets, devices).

2. **The checker walks every entry, classifies it against the manifest,
   and fails closed.** The walk uses `find` without a `-type` filter;
   symlink tests run before `-f`/`-d` (which follow links); unknown paths
   — including names mangled by embedded newlines — are breaches. `cmp`
   is only reached for entries proven to be regular files, so special
   files cannot hang the check.

3. **Two shapes are accepted and pinned by positive controls**: the
   minimal scaffold `/new-campaign` step 0 heals (required entries only)
   and a fresh, unmodified "Use this template" tree (required plus
   optional entries). The optional set exists precisely so both are legal.

4. **The skill mandates what the checker verifies.** `/new-campaign`
   restores canonical files verbatim (`cp`, never retyping), creates
   nothing outside the manifest, never creates symlinks, and leaves
   optional template files byte-unchanged. Skill and checker share one
   definition of "empty scaffold"; the canonical bytes ship in three
   byte-identical places (template root, the skill's `templates/`,
   `examples/mini-campaign/`).

5. **Every manifest rule has an isolated negative control** that must fail
   for its stated reason (asserted against the specific defect message,
   per ADR 0016/0017), covering at minimum: extra files in each root,
   tampered optional files, non-empty `.gitkeep`s, type confusions
   (file-for-directory, directory-for-file, FIFO), and file/directory
   symlinks at multiple depths.

## Consequences

- Whitelisting replaces blacklisting: a new attack path must now defeat
  the manifest itself, not merely avoid an enumerated pattern.
- Byte-exactness makes the placeholder files part of the public contract:
  changing any canonical scaffold file requires updating it in all shipped
  copies. Mechanically pinned today: `system/system.md` and the default
  table via the sha256 snapshots, `gm/plot.md` and `system/rulings.md` via
  the bundled-skill-template comparison in `test_template_clean.sh`. The
  optional READMEs are template documentation; changing them is an
  ordinary reviewed template edit and automatically moves the reference
  the instance checker compares against.
- Instances that legitimately customize README files before running
  `/new-campaign` will be flagged. Accepted: customization is campaign
  content and belongs after the Spec-Gate.
- The checker depends on a clean template checkout as its byte reference —
  the same assumption `test_template_clean.sh` already makes.

## Alternatives considered

- **Keep extending the denylist per review finding** — demonstrably
  non-convergent over seven rounds; rejected.
- **Content-pattern scanning ("does this file look like campaign
  content?")** — undecidable in general and trivially evadable (encodings,
  languages, steganography in formatting); rejected.
- **A single tree hash over the protected roots** — byte-exact and simple,
  but cannot express the optional set (minimal vs. full shape would need
  2^n enumerated hashes), collapses every defect into one opaque
  "mismatch", and portable deterministic tree hashing (ordering, `find`
  output differences) is exactly the class of BSD/GNU pitfall ADR 0014
  avoids; rejected.
- **Making the optional files required** — would force the heal step to
  create README content in a minimal instance, growing the write surface
  before approval for zero safety gain; rejected.
