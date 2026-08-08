# Client update 2026.08.08 — RTC Helper, movement/level fixes, chase fix

All changes in this update are Lua/OTUI only. No client recompile is required;
`otclient.exe` is unchanged from the previous build.

## What is included

### 1. RTC Helper (`mods/game_helper`)

Standalone in-client healing and attack assistant with two tabs:

- **Healing** — three spell-heal rows (cast at an HP% threshold), HP and mana
  potions by item id + threshold, auto-haste (with a cast-in-PZ toggle), and
  auto-eat food.
- **RTCaster** — five attack-spell rows (cast by mana% and a minimum monster
  count, in priority order), auto-target nearest monster, shooter toggle, and
  rune-on-target.

It drives plain game actions (`g_game.talk` / `useInventoryItem` /
`useInventoryItemWith` / `attack`) on a ~200 ms tick with per-action cooldowns.
It does **not** use or enable `game_bot`, vBot, or cavebot. A master
*Helper Enabled* toggle gates everything, and settings persist via `g_settings`.

### 2. Fast-movement black tiles

Predictive pre-walk is now gated on the visible **leading-edge** tile being
streamed in (`modules/game_walk/walk.lua`). Previously pre-walk only checked the
immediate next tile, so at high speed the camera outran the map stream and the
leading edge of the viewport rendered black. Prediction now pauses at the stream
boundary and the server-confirmed walk drives the camera instead.

### 3. Level progress bar accuracy

The percentage is derived from the authoritative uint64 experience value
(`getReliableLevelPercent` in `game_skills`) instead of the server's cached
`levelPercent` byte, which goes stale on non-experience stat updates and
intermittently showed a wrong amount. Applied to the skills window, the top
stats bar, and the XP analyser. The *XP for next level* tooltip also no longer
blanks out mid-hunt.

### 4. Attacking no longer forces Follow

The Stand/Follow posture in the inventory panel *is* the chase mode. The server
can push a chase mode back at the client — on login, on any player-modes packet,
and when a new attack target is set. When that happened the panel kept showing
**Stand** while the character chased the target anyway, so attacking always
behaved as **Follow**.

`modules/game_inventory/inventory.lua` now remembers the posture the player
explicitly picked and re-asserts it whenever the effective chase mode drifts
from that choice, including on `onAttackingCreatureChange`. A re-entrancy guard
keeps the `setChaseMode` → `onChaseModeChange` → `combatEvent` path from
looping.

Behavior after the fix:

| Posture selected | While attacking |
|---|---|
| Stand | character holds position |
| Follow | character chases the target (unchanged) |

The existing `autoChaseOverride` option is untouched: walking manually while
attacking still switches the posture to Stand.

## Deployment layout

| Tree | RTC Helper | Notes |
|---|---|---|
| `work/OTC-client` | `mods/game_helper` (active) | full OTC client |
| `work/standard-client` | `mods-disabled/game_helper` (staged, not loaded) | Vanilla default UI stays clean per project `AGENTS.md` |

The four module fixes (inventory, walk, skills, statsbar, XP analyser) are
applied to **both** trees.

## Publishing

| Variant | Package | Manifest version |
|---|---|---|
| OTC | `uploads-ready/OTC/client-windows.zip` | `2026.08.08.01` |
| OTC-Vanilla | `uploads-ready/OTC-Vanilla/client-windows.zip` | `2026.08.08.02` |

Upload each `client-windows.zip` with its matching `version.txt` to the
corresponding MyAAC slot. `OtLauncher.exe` does not need to be re-uploaded for
this change. The OTCv8 variant is not affected by this update.

The previous packages are retained alongside as
`client-windows.zip.backup-<timestamp>` in case a rollback is needed.
