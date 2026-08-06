# Client update 2026.08.05 — stance and Forked spell library

This update makes the following spells available in the action-bar hotkey
assignment library:

| Server ID | Spell | Words | Vocations |
|---:|---|---|---|
| 298 | Forked Thorns | `exevo fur tera` | Druid / Elder Druid |
| 299 | Elemental Synthesis | `utito dru` | Druid / Elder Druid |
| 300 | Shared Conservation | `utura sio` | Druid / Elder Druid |
| 301 | Master of Flames | `uteta flam` | Sorcerer / Master Sorcerer |
| 302 | Master of Thunder | `uteta vis` | Sorcerer / Master Sorcerer |
| 303 | Master of Decay | `uteta mort` | Sorcerer / Master Sorcerer |
| 304 | Divine Defiance | `utori hur` | Paladin / Royal Paladin |
| 305 | Forked Glacier | `exevo fur frigo` | Druid / Elder Druid |

## What changed

The action-bar spell selector reads the static table in:

```text
modules/gamelib/spells.lua
```

The entries use the existing server IDs and spell icon slots. No spell
damage, cooldown, target selection, or animation behavior is changed by this
client metadata update. The three Master Sorcerer words are exactly `uteta`
and the Druid stance word is exactly `utito dru`.

The server overlay uses `toggleLearnSpells = false` and normalizes the stance
scripts to `spell:needLearn(false)`. After the server redeploy, characters can
cast these spells when their level and vocation requirements are met; NPC
spell learning is not required.

## Windows client procedure

Use a full Windows OTClient checkout for compilation. This relay repository is
release metadata/assets and is not itself a complete C++ build checkout.

```powershell
$FullClient = 'C:\src\otclient-full'
$ReleaseAssets = 'C:\src\OTClient'

git -C $ReleaseAssets pull --ff-only origin main
Copy-Item "$ReleaseAssets\modules\gamelib\spells.lua" `
  "$FullClient\modules\gamelib\spells.lua" -Force

Select-String -Path "$FullClient\modules\gamelib\spells.lua" `
  -Pattern 'Forked Thorns|Elemental Synthesis|Master of Flames|Forked Glacier'

Set-Location $FullClient
cmake --preset windows-release
cmake --build --preset windows-release --parallel
```

Keep a backup of the original `modules/gamelib/spells.lua` before copying.
Package the resulting Windows executable together with the complete runtime
`data/`, `modules/`, `mods/`, `init.lua`, `otclientrc.lua`, `config.ini`, and
`cacert.pem` files. Do not distribute only the executable or only the Lua
file.

## Publish through MyAAC

Upload the finished ZIP through:

```text
MyAAC → Tools → Client Uploads → Tibia 15.25 Vanilla Client (OTC)
```

Publish a new version number and upload `client-windows.zip`. The public
paths are:

```text
https://delyriumzot.com/client/otc/client-windows.zip
https://delyriumzot.com/client/otc/version.txt
```

The launcher checks `version.txt`; completely close the old client before
testing the replacement. Existing installations may need both the executable
and the `modules/gamelib/spells.lua` file replaced.

## Verification

1. Open the action-bar assignment window.
2. Search for `Master of Flames`, `Master of Thunder`, `Master of Decay`,
   `Elemental Synthesis`, `Shared Conservation`, `Forked Thorns`, and
   `Forked Glacier`.
3. Confirm each spell appears only for its correct vocation.
4. Assign a hotkey and verify that it sends the exact words from the table.
5. Test `uteta flam`, `uteta vis`, `uteta mort`, `utito dru`, `utura sio`,
   `exevo fur tera`, and `exevo fur frigo` in game.

If a spell appears in the library but the server rejects it, verify that the
Canary deployment is using the latest `otserver-push/main` overlay and that
the server container was recreated after the push. A stale client only hides
the library entry; it cannot cause the server's learning check.
