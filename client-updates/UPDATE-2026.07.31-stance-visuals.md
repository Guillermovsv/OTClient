# Client update 2026.07.31 — stance visuals and Paladin catalog

This update keeps the spell's original effect and missile IDs. It does not add
replacement fire, energy, or death sprites. The client recolors the original
animation by luminance, preserving frame order, shape, timing, alpha, area,
impact, and projectile geometry.

## Files to install

Copy these paths from this update into the matching client checkout:

```text
modules/game_stance_spell_visuals/game_stance_spell_visuals.lua
modules/game_stance_spell_visuals/game_stance_spell_visuals.otmod
modules/game_stances/game_stances.lua
modules/game_stances/game_stances.otmod
modules/game_shaders/shaders/fragment/stance_palette.frag
modules/gamelib/spells.lua
src/client/client.cpp
src/client/client.h
src/client/effect.cpp
src/client/luafunctions.cpp
src/client/missile.cpp
```

This Git repository is a synchronized release-assets repository, not a
complete OTClient source checkout. It now includes the five changed C++ files
under `src/client/`, but it does not include the rest of `src/`, CMake files,
vcpkg dependencies, or the complete build toolchain. Copy these files into a
matching full OTClient source checkout before compiling. A binary built
without these C++ hooks will load the Lua module but cannot recolor map
effects or missiles.

No `.spr`, `.dat`, `appearances.dat`, or duplicated spell sprites are required
for this recolor implementation. Do not install the old effect-variant tables
that replace a spell's effect ID.

## Windows build and package

Use a full OTClient checkout on Windows. The release-assets repository alone
cannot be compiled. Install Visual Studio 2022 with Desktop development with
C++, CMake, Ninja, Git, and vcpkg. Then run these commands in PowerShell,
replacing the two paths:

```powershell
$FullClient = 'C:\src\otclient-full'
$ReleaseAssets = 'C:\src\OTClient'
$env:VCPKG_ROOT = 'C:\src\vcpkg'

$native = @('client.cpp', 'client.h', 'effect.cpp', 'luafunctions.cpp', 'missile.cpp')
foreach ($file in $native) {
    Copy-Item "$FullClient\src\client\$file" "$FullClient\src\client\$file.backup-stance-2026.07.31" -Force
    Copy-Item "$ReleaseAssets\src\client\$file" "$FullClient\src\client\$file" -Force
}

Copy-Item "$ReleaseAssets\modules\game_stance_spell_visuals" "$FullClient\modules\" -Recurse -Force
Copy-Item "$ReleaseAssets\modules\game_stances\game_stances.lua" "$FullClient\modules\game_stances\" -Force
Copy-Item "$ReleaseAssets\modules\game_stances\game_stances.otmod" "$FullClient\modules\game_stances\" -Force
Copy-Item "$ReleaseAssets\modules\game_shaders\shaders\fragment\stance_palette.frag" "$FullClient\modules\game_shaders\shaders\fragment\" -Force
Copy-Item "$ReleaseAssets\modules\gamelib\spells.lua" "$FullClient\modules\gamelib\" -Force

Set-Location $FullClient
cmake --preset windows-release
cmake --build --preset windows-release --parallel
```

The release executable is produced under `build\windows-release\bin\` or
the configured runtime output directory. Copy the executable together with
the full client `data/` and `modules/` tree into the package. Restart the
client completely; do not rely on a hot-reloaded module.

For a Visual Studio-generated build instead:

```powershell
Set-Location C:\src\otclient-full
cmake --preset windows-debug-msbuild
cmake --build build\windows-debug-msbuild --config Debug --parallel
```

Use the release/Ninja preset for the distributable client. Use the MSBuild
preset only when debugging from Visual Studio.

The five files in `src/client/` are complete synchronized files, not a
standalone patch. Apply them only to the same OTClient baseline from which
they were produced. If the Windows checkout has local client changes, review
the backup/diff first and merge the stance hunks instead of blindly replacing
the file. Keep the backups until the new executable has passed the smoke tests.

The `windows-release` preset declares the toolset required by this checkout.
If CMake reports that `v145` is unavailable, install the matching Visual
Studio C++ toolset through Visual Studio Installer, or use the repository's
compatible MSBuild preset. Do not silently mix an unrelated OTClient branch
with these files.

Before packaging, verify that the built executable and native module files
exist:

```powershell
Get-Item .\build\windows-release\bin\otclient.exe
Get-Item .\modules\game_stance_spell_visuals\game_stance_spell_visuals.otmod
Get-Item .\modules\game_shaders\shaders\fragment\stance_palette.frag
```

Copy the Lua/shader files into the packaged `data/modules/` tree, then upload
the complete client archive through MyAAC **Tools → Client Uploads**. Pushing
this Git repository does not replace the installed Windows executable.

The server sends opcode `233` only after a successful spell execution:

```text
spell_visual|sequence|spellId|element|converted
```

`element` is `none`, `flam`, `vis`, or `mort`. The client accepts only known
offensive spell IDs and applies the palette only to effects/missiles whose
server source is the local player. Monster and other-player effects are not
recolored.

## Required smoke tests

1. Activate `uteta flam`, cast a native fire spell, then `exevo vis hur`.
   The second spell keeps the Energy Wave shape but is recolored flam and its
   damage is fire. A second non-matching spell remains normal because the
   trigger was consumed.
2. Repeat with `uteta vis` and `uteta mort`.
3. Cast a non-matching spell without first casting the stance element; its
   damage and original colors must remain unchanged.
4. Verify Hell's Core, Great Energy Beam, Great Fire Wave, Rage of the Skies,
   area effects, impacts, and missiles retain their original silhouettes.
5. Verify another player and monsters keep their normal colors.
6. Relog and deactivate the stance; the green skill state and spell palette
   must clear.

If the client shows a different spell's animation, it is using an older server
overlay or an old client module. Check the server artifact and ensure the
current `game_stance_spell_visuals` module is loaded once.
