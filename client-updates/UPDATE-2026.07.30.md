# Client update 2026.07.30

This is the canonical installation and release instruction for this client
update. Future updates must create a new file named
UPDATE-YYYY.MM.DD.md under client-updates/ and link it from the root README.

## Update identity

| Field | Value |
|---|---|
| Update | 2026.07.30 |
| Client protocol | 1525 |
| Package | master-sorcerer-2026-07-30 |
| Server branch | dudantas/allow-large-npc-sales |
| Server commit | da11e5baa874d0bc27d049027c601797721337e |

## Files included

Install the files from
client-updates/master-sorcerer-2026-07-30/:

- otclient/modules/game_stance_spell_visuals/game_stance_spell_visuals.lua
- otclient/modules/game_stance_spell_visuals/game_stance_spell_visuals.otmod
- otclient/modules/game_stances/game_stances.lua
- otclient/modules/game_stances/game_stances.otmod
- otclient/modules/client_options/data_options.lua
- otclient/data/things/1525/appearances-custom01.dat
- otclient/data/things/1525/catalog-content.json
- otclient/data/things/1525/assets.json.sha256
- otclient/data/things/1525/sprites-master-sorcerer-*.bmp.lzma
- otclient/data/things/1525/master-sorcerer-effect-mapping.json

The package also contains MASTER_SORCERER_EFFECTS.md,
MASTER_SORCERER_EFFECTS_PREVIEW.png, SHA256SUMS, and the
apply-client-update.sh installer.

## Windows installation

Use Git Bash from the root of the full OTClient source checkout:

~~~sh
./client-updates/master-sorcerer-2026-07-30/apply-client-update.sh .
~~~

Or run the script by absolute path:

~~~sh
/c/path/to/OTClient/client-updates/master-sorcerer-2026-07-30/apply-client-update.sh /c/path/to/OTClient
~~~

The installer backs up every replaced file under:

~~~text
data/things/1525/backups/master-sorcerer-2026-07-30/<UTC-timestamp>/
~~~

It first verifies that the catalog shipped inside the package matches the
package's `assets.json.sha256`, then copies the files, and finally verifies the
catalog in the updated checkout. The existing checkout may have an older
catalog hash; that is expected during an update and must not be compared to
the new package hash before copying. It also runs Lua syntax checks when luac
is available. Do not copy only the Lua modules; the appearance catalog and
sprite sheets are required for effects 352–363.

If a separate updater reports a mismatch between the old target
`catalog-content.json` and this package's `assets.json.sha256` before copying,
stop using that updater and run the package's `apply-client-update.sh` instead.
The package hash is `5b96ce562288b91666c7758171bdfe072cc6556e035809407b2744a3f48f1b7f`.

## Required effect mapping

| Spell | Original | Energy | Flam | Mort |
|---|---:|---:|---:|---:|
| Hell's Core | 7 | 352 | 353 | 354 |
| Great Energy Beam | 38 | 355 | 356 | 357 |
| Great Fire Wave | 16 | 358 | 359 | 360 |
| Rage of the Skies | 41 | 361 | 362 | 363 |

## Build and upload

After installation, rebuild/package the Windows client using the normal
launcher pipeline. Upload the generated client archive through MyAAC
Tools → Client Uploads. Pushing this GitHub repository does not update the
MyAAC client volume by itself.

The server must be deployed with the matching protocol-1525
appearances.dat; otherwise the client may load the spell library but the cast
effect will be missing or incorrect.

## Verification

Test these commands:

~~~text
uteta vis
uteta flam
uteta mort
~~~

For every stance, cast Hell's Core, Great Energy Beam, Great Fire Wave, and
Rage of the Skies. Verify:

- all frames and area tiles render;
- inactive stance uses the original effect;
- icons and cooldowns remain correct;
- other players' and monsters' effects are unchanged;
- changing stance or relogging does not leave stale visual state.

## Standard for future updates

Every future client release must include:

1. A new versioned file under client-updates/UPDATE-YYYY.MM.DD.md.
2. A package directory containing all required runtime files.
3. SHA256 checksums for package files.
4. Backup and rollback instructions.
5. The matching server commit, protocol, asset IDs, and client upload steps.
6. A link from the root README to the new update document.
