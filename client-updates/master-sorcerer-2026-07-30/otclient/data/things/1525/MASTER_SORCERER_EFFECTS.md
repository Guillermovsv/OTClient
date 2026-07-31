# Master Sorcerer spell effect variants

Protocol 1525 uses the following server/client appearance mapping. The full
source and generated sprite-ID lists are in
`master-sorcerer-effect-mapping.json`.

| Spell | Original effect | Energy | Flam | Mort | Frames | Tile size | Server file |
|---|---:|---:|---:|---:|---:|---|---|
| Hell's Core | 7 | 352 | 353 | 354 | 14 | 64x64 | `hells_core.lua` |
| Great Energy Beam | 38 | 355 | 356 | 357 | 11 | 32x32 | `great_energy_beam.lua` |
| Great Fire Wave | 16 | 358 | 359 | 360 | 9 | 64x64 | `great_fire_wave.lua` |
| Rage of the Skies | 41 | 361 | 362 | 363 | 17 | 64x64, 2x2 pattern | `rage_of_the_skies.lua` |

Each variant is a clone of the original appearance metadata. Frame timing,
loop behavior, pattern dimensions, bounding boxes, sprite order, and alpha
values are unchanged. The generated sprite IDs are `289800–289913` for the
64x64 sheets and `289920–289952` for the 32x32 sheet.

The original client files were backed up before generation under:

```text
data/things/1525/backups/master-sorcerer-20260730/
```

The server selects the variant only for a local player with an active Master
of Thunder, Master of Flames, or Master of Decay stance. With no matching
stance, it sends the original effect ID. Damage formulas, areas, cooldowns,
mana, range, target selection, and conditions are unchanged.
