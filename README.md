# OTClient release assets
This repo hosts client release assets and synchronized spell metadata used by
the desktop client installer/updater.

The current spell metadata includes server IDs `298` and `305` for Forked
Thorns and Forked Glacier, with their 6-second individual cooldowns. Druid
Elemental Synthesis/Shared Conservation and the three Master Sorcerer stances
use custom icon IDs `189` through `193`; Divine Defiance uses `194`. The
corresponding 32px and 20px spell atlases are included under
`data/images/game/spells/`.

## Why stance images can look wrong

The spell library does not load `masterofflames.png` or another image by spell
name. `modules/gamelib/spells.lua` supplies a numeric `clientId`, and the
renderer treats that number as a zero-based horizontal slot:

```text
32px library icon:    x = clientId * 32
20px cooldown icon:   x = clientId * 20
```

Both atlases must contain the same icon at the same slot. A metadata-only
change can therefore show an unrelated spell image, while an atlas-only change
can leave the cooldown icon wrong.

The current reserved slots are:

| Spell | Server ID | Client icon slot |
|---|---:|---:|
| Forked Thorns | 298 | 187 |
| Forked Glacier | 305 | 188 |
| Elemental Synthesis | 299 | 189 |
| Shared Conservation | 300 | 190 |
| Master of Flames | 301 | 191 |
| Master of Thunder | 302 | 192 |
| Master of Decay | 303 | 193 |
| Divine Defiance | 304 | 194 |

The six stance artwork sources used for the current atlas are the exact
repository-side reference files named:

```text
elementalsynthesis (2) (1).png
sharedconservation (2) (1).png
masterofflames (2) (1).png
masterofthunder (2) (1).png
masterofdecay (2) (1).png
divinedefiance (2) (1).png
```

They are resized into both atlas scales; the standalone 38x38 files are not
loaded directly by the client.

Do not replace these with the IDs of visually similar standard spells. Do not
ship the standalone reference PNGs as a substitute for the two horizontal
atlases.

## Windows synchronization and release procedure

From the Windows client checkout, pull the current metadata and atlases:

```powershell
git pull --ff-only origin main
```

Verify the files before building:

```powershell
Get-Item data\images\game\spells\spell-icons-32x32.png
Get-Item data\images\game\spells\spell-icons-20x20.png
Select-String -Path modules\gamelib\spells.lua -Pattern "Elemental Synthesis|Master of Flames|Forked Thorns"
```

The expected atlas dimensions are `6240x32` and `3900x20`. If the client
still shows old icons after updating, completely close it and replace both
files in the installed runtime's `data\images\game\spells\` directory; do not
copy only `spells.lua`.

Then rebuild/package the Windows client and upload the resulting release
through MyAAC **Tools → Client Uploads**. The server repository deployment does
not update these client assets automatically.
