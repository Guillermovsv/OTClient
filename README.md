# DelyriumzOT Client (OTClient - Redemption)

This repo now hosts the **full buildable DelyriumzOT client source** — the
OTClient-Redemption tree wired to our server — alongside the release assets,
synchronized spell metadata, and the native hook patch used by the desktop
installer/updater.

> Runtime game assets under `data/things/` (sprites) and `data/sounds/` are
> **not** committed — they are fetched automatically on first launch by the
> `clientAssets` downloader configured in `init.lua`. Everything required to
> **compile** is in the repo.

## Building the client

See **[`WINDOWS_BUILD.md`](WINDOWS_BUILD.md)** for the full Windows recipe
(VS 2022 + vcpkg + the `windows-release-vs2022` CMake preset). Short version,
from *Developer PowerShell for VS 2022* in the repo root:

```powershell
cmake --preset windows-release-vs2022
cmake --build --preset windows-release-vs2022
# output: build\windows-release-vs2022\bin\otclient.exe
```

## Connecting to the server

`init.lua` is preconfigured for our server via the HTTP login webservice:

```lua
["http://game.delyriumzot.com:8088/login"] = {
    port = 7172, protocol = 1525, httpLogin = true, useAuthenticator = false
}
```

The login endpoint, game port, and **Dokploy/Cloudflare raw-TCP proxy**
requirements (port `7172` must be DNS-only / not HTTP-proxied) are documented in
[`client-updates/TIBIA-15.25-CONNECTION.md`](client-updates/TIBIA-15.25-CONNECTION.md).
Do **not** point the game connection at `7171` — that is Canary's legacy login
port and this client uses HTTP login on `8088` instead.

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

## Compatibility fixes for the stance module

`game_stances.otmod` is intentionally not sandboxed because it uses the
existing `game_skills` functions `setSkillColor` and `setSkillTooltip`. If the
module remains sandboxed, the client logs `attempt to call global
'setSkillColor' (a nil value)` when a stance update arrives.

Some older Windows builds also lack the optional `g_things.setHdMode` binding.
Guard that call in `modules/client_options/data_options.lua` before packaging:

```lua
if g_things and type(g_things.setHdMode) == 'function' then
    g_things.setHdMode(value)
end
```

These are client compatibility fixes; they do not change spell IDs, words, or
server-side damage behavior.

## Versioned client update instructions

Every client release must have one canonical, versioned instruction file under
`client-updates/UPDATE-YYYY.MM.DD.md`. The current release is:

- [UPDATE-2026.07.30.md](client-updates/UPDATE-2026.07.30.md)
- [UPDATE-2026.07.31-stance-visuals.md](client-updates/UPDATE-2026.07.31-stance-visuals.md)
- [UPDATE-2026.08.05-spell-library.md](client-updates/UPDATE-2026.08.05-spell-library.md)
- [UPDATE-2026.08.05-canonical-spell-ids.md](client-updates/UPDATE-2026.08.05-canonical-spell-ids.md)
- [UPDATE-2026.08.05-native-monk-safe.md](client-updates/UPDATE-2026.08.05-native-monk-safe.md)
- [Master Sorcerer package](client-updates/master-sorcerer-2026-07-30/)

Each package must include the runtime files, SHA256 checksums, a backup-aware
installer, the matching server commit/protocol, and MyAAC upload instructions.
Do not publish a client package without updating the versioned instruction
file and linking it here.

The native stance recolor hooks are published under `src/client/`. Copy those
five files into the matching full OTClient checkout and follow the Windows
CMake instructions in
[`UPDATE-2026.07.31-stance-visuals.md`](client-updates/UPDATE-2026.07.31-stance-visuals.md)
before building. A Git push updates this repository only; it does not compile
or upload the Windows client binary.
