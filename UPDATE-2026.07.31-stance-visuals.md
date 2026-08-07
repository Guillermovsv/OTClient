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

No `.spr`, `.dat`, `appearances.dat`, or duplicated spell sprites are required
for this recolor implementation. Do not install the old effect-variant tables
that replace a spell's effect ID.

## Build and package

From the client source root on Windows, rebuild the executable after copying
the C++ files. Copy the Lua/shader files into the packaged `data/modules/`
tree. Restart the client completely; do not rely on a hot-reloaded module.

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
