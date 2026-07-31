# Master Sorcerer client update — 2026-07-30

Canonical instructions: [UPDATE-2026.07.30.md](../UPDATE-2026.07.30.md).

This is the client-side package for the protocol-1525 Master Sorcerer
animation variants. It must be installed together with the matching server
appearance catalog. The server effect IDs are:

| Spell | Original | Energy | Flam | Mort |
|---|---:|---:|---:|---:|
| Hell's Core | 7 | 352 | 353 | 354 |
| Great Energy Beam | 38 | 355 | 356 | 357 |
| Great Fire Wave | 16 | 358 | 359 | 360 |
| Rage of the Skies | 41 | 361 | 362 | 363 |

## Contents

- Complete protocol-1525 appearance catalog with effects 352–363.
- Generated 32×32 and 64×64 sprite sheets used by those effects.
- Stance modules and the HD-mode compatibility fix.
- Full source/effect/sprite mapping and a visual preview.
- apply-client-update.sh, which backs up existing files before installation.

The animation variants preserve the original frame count, frame timing,
pattern dimensions, offsets, transparency, and sprite placement. Spell icons,
library metadata, damage, cooldowns, and targeting are not changed by this
package.

## Installation

Run from the root of the full OTClient checkout:

~~~sh
cd /path/to/OTClient
/path/to/client-updates/master-sorcerer-2026-07-30/apply-client-update.sh
~~~

Or pass the checkout path explicitly:

~~~sh
./apply-client-update.sh /path/to/OTClient
~~~

The script creates a timestamped backup under
data/things/1525/backups/master-sorcerer-2026-07-30/ before replacing files.
It validates the package catalog before installation, then validates the
installed catalog and Lua syntax after copying. An older catalog in the target
checkout is normal; it is replaced by the package catalog during installation.

## Release

After installation, build/package the desktop client using the normal launcher
pipeline. Upload the generated client archive through MyAAC **Tools →
Client Uploads**. Pushing this repository does not update the MyAAC client
volume automatically.

Test in-game with:

~~~text
uteta vis
uteta flam
uteta mort
~~~

Then cast Hell's Core, Great Energy Beam, Great Fire Wave, and Rage of the
Skies under each stance. Confirm that inactive stances use the original
effects and that other players' and monsters' effects remain unchanged.
