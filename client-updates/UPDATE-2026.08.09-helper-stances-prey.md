# Client update 2026.08.09 — RTC Helper, stances, prey, premium

Everything here is Lua and image assets except one file, `src/client/uiitem.cpp`.
That one change only takes effect after the client is rebuilt; the rest works on
restart. `otclient.exe` in this tree is still the 2026-08-07 build.

## RTC Helper

The mod shipped in the previous update never loaded, and once loaded it did not
survive a restart. Both are fixed, and the window has been rebuilt to match the
reference helper.

### Why it was unusable

- Mods only load if they declare `autoload` or appear in the `client_mods`
  `load-later` list. `game_helper` did neither, so it sat inert on disk. It now
  autoloads, rather than relying on `client_mods/mods.otmod`, which
  `mods/.gitignore` keeps user-local and therefore unshipped.
- `g_settings` writes a Lua array to OTML as keyed nodes (`1:`, `2:`, `3:`) and
  reads them back as **string** keys, so after the first Save `config.heals[1]`
  was nil and `populateUI` threw. That throw happened inside `init()`, and a
  module that throws while loading is removed from `package.loaded` — but the
  window it had already created stayed on screen. `modules.game_helper` was nil
  while the UI was still clickable, so every button failed. Saved rows are now
  rebuilt with real numeric indices, and every widget accessor tolerates a
  missing widget.
- `UISpinBox.create()` defaults to `maximum = 1` and `setValue()` clamps, so
  every percent written before the range was widened became 1 and persisted that
  way. The range is now declared in the style, and settings without a
  `schemaVersion` have percentages still sitting at 1 restored to their defaults.

### Layout

Sidebar with the character's outfit, preset, status and hotkeys; an icon tab
strip; and two tabs. Healing carries Spell Healing, Potion Healing, Mana
Training and Exercise Training over a rule, with two friend groups beneath.
RTCaster carries presets, five attack rows with Mana %, Creatures and Priority,
the stance grid, two rune rows and the target/shooter toggles.

Rows are icon, percent stepper and an info badge, with no per-row checkbox: a
row counts as enabled when it holds a spell or an item.

### Slots

- Spell slots draw from the spell atlas by `clientId` and open a picker listing
  only what fits that slot — haste spells for Auto Haste, Healing group spells
  for the heal rows, Attack group spells for the attack rows, stances for the
  stance grid — all narrowed to the character's vocation. A spell with
  `clientId` 0, such as Ultimate Healing, has no icon and shows its initials
  instead, with the full words in the tooltip.
- Item slots take a drag or a crosshair pick and validate what they are given
  using the item's market category: potions to potion slots, runes to rune
  slots, exercise weapons to the training slot.
- Right click on any slot opens a menu to clear it.

### Behaviour

- Potions are used **on the player**. A plain `useInventoryItem` has no target
  and the server answers "You cannot use this object", which is why potion
  healing never worked.
- Auto eat has no item id. It walks the open containers in order and uses the
  first item whose market category is Food, skipping anything whose name
  suggests it restores health or mana outright.
- The Priority column is always honoured; "Combo in priority order" controls
  whether the rest of the combo keeps firing or only the top match is cast.
- Friend healing casts Heal Friend on a named party member who drops below
  their threshold. The client only knows a creature's health while it is on
  screen, so party members out of view are not offered and cannot be healed.
- Presets, clipboard export/import, bindable hotkeys, Change Gold and a stats
  counter.

## Stances

- `game_stances` called `setSkillColor` and friends as bare globals, but
  `game_skills` is `sandboxed: true`, so those helpers live on the module table
  and were nil. Every stance activation raised "attempt to call global
  'setSkillColor' (a nil value)" and aborted before applying any colour, which
  is why stance visuals had stopped appearing. The calls now go through
  `modules.game_skills`.
- The stance icons were missing because the atlases were never extended.
  `spell-icons-32x32.png` was 189 cells wide, and the stances are assigned
  `clientId` 189-194, so every one of them clipped past the edge of the image
  and drew nothing. Both atlases are widened and the icons composited in.
- **Aura of Exposed Weakness** and **Aura of Sapped Strength** were listed as
  required in the stance bundle's `AGENT_INSTRUCTIONS.md` but had never been
  added. Both are now in `SpellInfo` with the bundle's values (ids 243 and 244,
  `exori moe tempo` and `exori kor tempo`, level 175, mana 1500, sorcerer only)
  and icons in new atlas slots 195 and 196.
- The helper's stance grid offers one stance per group: everything except the
  two Auras is one group, the Auras another. A knight, paladin or druid holds a
  single stance; a sorcerer holds one Master stance plus one Aura. Per vocation
  the list is Knight 2, Paladin 2, Druid 2, Sorcerer 5.
- The client and the spell library number vocations differently.
  `getVocation()` returns `VocationsClient` — Knight 1, Paladin 2, Sorcerer 3,
  Druid 4 — while `SpellInfo.vocations` uses Sorcerer 1/5, Druid 2/6,
  Paladin 3/7, Knight 4/8. Comparing them raw meant a sorcerer matched the
  paladin list. The helper maps between them; note `game_spelllist` compares
  them raw in the same way and has the same defect.

## Combat controls

The Attack, Balanced and Defensive buttons are hidden in both inventory
layouts, since the stances replace what they did, and the posture controls move
into the space they occupied. They are hidden rather than deleted because other
anchors reference them and `selectCombat()` still sets their state.

## Prey

- Every creature in the selection grid was painted with an alternating grey
  background, so each monster sat in its own box. The real client draws them
  flat; only the selected one is outlined. Selection is now a white border over
  a faint white wash, and the first creature starts selected.
- The outfits were drawn at sprite size inside a 60px cell and now scale to fill
  it. The cells cannot grow without redesigning the window: the slot panels are
  210px inside a 688px window.
- The free reroll drew a solid amber bar. `onPreyTimeUntilFreeReroll` worked the
  percentage out from `timeUntilFreeReroll` and only clamped the value on the
  next line, so the bar was driven by the unclamped number and pinned at full.

## Premium

The server runs free premium but still reports `subStatus` Free, `premDays` 0
and `premium=false`, so the client correctly displayed "Free Account" and
in-game premium checks treated the player as free. `FORCE_PREMIUM_ACCOUNT` in
`gamelib/const.lua` presents the account as premium in the character list and
makes `LocalPlayer:isPremium()` report true.
`LocalPlayer:isPremiumReportedByServer()` still returns the unmodified flag.

Note that "You need a premium account" does not exist anywhere in the client —
that message comes from the server, and no client setting can change what the
server refuses.

## Inventory slots

`UIItem::setItem()` only refreshed the widget's cached item id when handed a
real item, so `setItem(nil)` dropped the sprite but left `m_itemId` pointing at
whatever used to be in the slot. `drawSelf` forces `m_item` back to `m_itemId`,
so a stale id could redraw equipment that had been taken off. The inventory now
clears with `clearItem()`, which resets both and needs no rebuild;
`src/client/uiitem.cpp` is corrected as well and applies to every other UIItem
once the client is rebuilt.

## Diagnostics

`game_stances` and `game_stance_spell_visuals` carry logging for extended
opcodes 232 and 233, both off by default behind `DEBUG_STANCE` and
`DEBUG_SPELL_VISUAL`. Opcode 232 has been observed arriving; whether the server
sends 233, which is what drives the Master Sorcerer spell recolouring, is still
unconfirmed. Turn both on, cast offensive spells under a Master stance, and the
log will show each packet or the reason it was dropped.

## Still open

- Spell recolouring is unverified pending an opcode 233 capture.
- The Gran Sio friend rows cast the same Heal Friend as the Sio rows; there is
  no gran-sio spell in the library.
- The auras are recast on a timer because `game_stances` reports only one
  active stance.
