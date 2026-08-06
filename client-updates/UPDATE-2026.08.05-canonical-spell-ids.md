# Client update 2026.08.05 — canonical forked and stance spells

This update is for the current OTClient 15.25 package. It keeps the native
Monk spell range unchanged and synchronizes the client spell library with the
Canary server.

## Canonical spell IDs

Do not move or replace Monk spells. IDs `273`–`297` remain unchanged.

| Server ID | Client icon slot | Spell | Words |
|---:|---:|---|---|
| 298 | 187 | Forked Thorns | `exevo fur tera` |
| 299 | 189 | Elemental Synthesis | `utito dru` |
| 300 | 190 | Shared Conservation | `utura sio` |
| 301 | 191 | Master of Flames | `uteta flam` |
| 302 | 192 | Master of Thunder | `uteta vis` |
| 303 | 193 | Master of Decay | `uteta mort` |
| 304 | 194 | Divine Defiance | `utori hur` |
| 305 | 188 | Forked Glacier | `exevo fur frigo` |

The custom range is `298`–`305`; it is not `299`–`305` because Forked Thorns
uses `298`. `clientId` is an icon-atlas slot, not a spell ID.

## Files required in the client package

The Windows package must contain the matching versions of:

```text
modules/gamelib/spells.lua
data/images/game/spells/spell-icons-32x32.png
data/images/game/spells/spell-icons-20x20.png
```

The spell table must contain exactly one record for each custom server ID.
The two atlases must contain the corresponding artwork at the icon slots shown
above. Do not substitute a visually similar standard spell icon.

If stance visual updates are enabled, also include the existing stance visual
module and its `.otmod` file. These visuals do not change spell IDs, damage,
areas, cooldowns, or target selection; Canary remains authoritative.

## Windows installation and build

From the full OTClient checkout:

```powershell
git pull --ff-only origin main
Select-String -Path modules\gamelib\spells.lua -Pattern "Forked Thorns|Elemental Synthesis|Master of Flames|Forked Glacier"
Get-Item data\images\game\spells\spell-icons-32x32.png
Get-Item data\images\game\spells\spell-icons-20x20.png
```

Expected atlas dimensions:

```text
spell-icons-32x32.png = 6240 x 32
spell-icons-20x20.png = 3900 x 20
```

Build and package the Windows client using the normal project build. Before
replacing an installed client, back up the existing `data` directory. Replace
the complete package, not only `spells.lua`; metadata and both icon atlases
must be from the same update.

## MyAAC upload

Upload the resulting Windows release through **MyAAC → Tools → Client
Uploads**. Upload the matching version manifest with the archive. A Git push
updates this instruction/asset repository only; it does not distribute or
replace the installed Windows client automatically.

## Validation checklist

1. The spell library shows Forked Thorns and Forked Glacier for Druids.
2. Sorcerer stances show the correct names, icons, words, and cooldowns.
3. Druid stances show `utito dru` and `utura sio` exactly.
4. Paladin Divine Defiance shows `utori hur` exactly.
5. Monk spells `273`–`297` still show their original names and icons.
6. Each custom spell can be assigned to an actionbar hotkey.
7. Casting uses the original server spell area and effect; the client does not
   replace one spell with another spell's sprite.

Do not apply `tibia-15.25-monk-safe/canary-tibia-15.25-monk-safe.patch` for this
release. That patch is an optional native-client compatibility path and is not
required for the current OTClient 15.25 mapping.
