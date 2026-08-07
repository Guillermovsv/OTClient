# Task: serve base spell damage to the OTClient Cyclopedia over extended opcode 220

You are working in a **Canary** (or TFS-derived) Open Tibia **server** datapack. A
custom OTClient has a Cyclopedia → Magical Archives tab that shows spell details.
Every field is populated except **base damage**, which the client cannot compute
because spell formulas live in your datapack. Your job is the server half.

The client side is already finished and shipped. Do not ask for client changes —
implement to the contract below exactly.

---

## 1. The wire contract (fixed — do not change)

**Extended opcode: `220`.**

The client sends this once per session, when the Magical Archives tab is first
opened:

```json
{ "action": "spellDamage" }
```

The server must reply on the same opcode with:

```json
{
  "action": "spellDamage",
  "spells": [
    { "id": 22, "min": 12,  "max": 18,  "kind": "damage"  },
    { "id": 1,  "min": 16,  "max": 26,  "kind": "healing" }
  ]
}
```

Field rules:

| field  | meaning |
|--------|---------|
| `id`   | The spell id — the exact value the spell script passes to `spell:id()`. Must be a number. |
| `min` / `max` | Numbers. May be signed or absolute; the client takes `math.abs`, swaps them if `min > max`, and floors both. |
| `kind` | The literal string `"healing"` for healing spells. **Any other value is treated as damage.** |

Entries missing `id`, `min` or `max`, or with non-numeric values, are silently
dropped by the client. A partial list is fine — spells absent from the list just
render without a damage row. So you can ship this incrementally.

### Chunking

The client reassembles multi-packet payloads. Match this exactly:

- Payload ≤ 65000 bytes → send the **raw JSON**, no prefix.
- Larger → split into ≤65000-byte chunks and send `"S"..chunk1`, then
  `"P"..chunkN` for each middle chunk, then `"E"..lastChunk`.

For a few hundred spells the JSON is ~10–15 KB, so one packet is the normal case.

### Prerequisite: the activation handshake

The client is **only allowed to send** extended opcodes after the server has sent
it extended opcode `0` at least once. If your server does not already do this,
the client logs:

```
Unable to send extended opcode 220, extended opcodes are not enabled
```

and nothing else will work. Verify this first.

---

## 2. What "base damage" means here

**Base damage = the spell's own formula evaluated at the level and magic level
that the spell itself requires** — i.e. `spell:level()` and `spell:magicLevel()`
from that spell's script.

It is **not** what the requesting player would actually hit for. It is a fixed
characteristic of the spell, identical for every character. Do **not** use
`player:getLevel()` or `player:getMagicLevel()` to produce these numbers.

Example — for a spell with `spell:level(23)`, `spell:magicLevel(0)` and:

```lua
function onGetFormulaValues(player, level, magicLevel)
    local min = (level / 5) + (magicLevel * 1.4) + 8
    local max = (level / 5) + (magicLevel * 2.2) + 14
    return -min, -max
end
```

base damage is `min = 23/5 + 0 + 8 = 12.6 → 12`, `max = 23/5 + 0 + 14 = 18.6 → 18`.
Report `{ id = <spell id>, min = 12.6, max = 18.6, kind = "damage" }`; the client
floors.

---

## 3. The hard part

**Canary does not expose a spell's combat formula to Lua.** The formula lives
inside the `Combat` object each spell script builds — via `combat:setFormula(...)`
or the `CALLBACK_PARAM_LEVELMAGICVALUE` callback — and there is no accessor to
read it back out. So the server **cannot enumerate spell damage automatically**.

Pick one of these approaches. State clearly which you chose and why.

### Approach A — explicit formula table (simplest, no datapack edits)

A single new script holds a table keyed by spell id, each entry carrying the
spell's base level, base magic level, and a copy of its formula:

```lua
[22] = {
    level = 23,
    magicLevel = 0,
    formula = function(player, level, magicLevel)
        local min = (level / 5) + (magicLevel * 1.4) + 8
        local max = (level / 5) + (magicLevel * 2.2) + 14
        return -min, -max
    end
},
```

The signature deliberately matches `onGetFormulaValues(player, level, magicLevel)`
so the datapack's function can be pasted in verbatim. Call it with the requesting
player (so any `player:...` calls inside still work) but with the **spell's** base
level and magic level as the numeric arguments.

Downside: the formulas are duplicated, so they can drift when spells are
rebalanced.

### Approach B — spell scripts publish their own formulas (no duplication)

Add one line to each attack/healing spell script, after its formula is defined:

```lua
CyclopediaSpellDamage.register(spellId, spellLevel, spellMagicLevel, onGetFormulaValues)
```

The opcode handler then just iterates the registry. No duplication and it cannot
drift, but it touches every spell script.

**Recommended:** A to get it working and validated, then migrate to B if the
duplication becomes a maintenance problem.

### Approach C — intercept `Combat` at load time

Wrapping `Combat.setFormula` / `Combat.setCallback` to capture formulas as scripts
load. Avoid unless A and B are both unacceptable — associating a captured Combat
back to its Spell is fragile and version-dependent.

---

## 4. Spells that have no meaningful base damage

Knight and paladin attack spells (e.g. **Annihilation**, `exori gran ico`, spell
id 62) use `CALLBACK_PARAM_SKILLVALUE` — their damage is driven by **weapon skill
and weapon attack**, not by level and magic level. "Base damage at the required
level and magic level" is not a meaningful quantity for them.

**Omit these spells from the response.** The client renders no damage row for
them, which is the correct outcome. Do not invent a number by assuming a weapon.

Flag in your summary which spells you skipped for this reason.

---

## 5. Reference implementation

A working implementation of Approach A already exists at
`modules/game_cyclopedia/serverSIDE/data/scripts/cyclopedia_spell_damage.lua`
in the client repo. It handles the opcode, the JSON, the chunking, the login
registration and the `pcall` guards — but ships with an **empty** `formulas`
table (two worked examples are commented out).

You may use it as your starting point. If you do, your job reduces to:

1. Copy it to `data/scripts/`.
2. Ensure the json lib is loaded — `data/lib/lib.lua` must contain
   `dofile('data/lib/json.lua')`.
3. **Fill in the `formulas` table** from your own spell scripts. This is the
   actual work.
4. Confirm the server sends extended opcode `0` on login (see §1).

---

## 6. Deliverables

1. The script(s), installed in the right place for this datapack.
2. A populated formula table covering, at minimum, every sorcerer and druid
   attack and healing spell.
3. A list of spells deliberately skipped, with the reason.
4. Confirmation that the activation handshake (opcode `0`) is sent.
5. A note on how you verified it — e.g. log the JSON payload once and check a
   couple of values by hand against the spell scripts.

## 7. Acceptance test

Log in with a **sorcerer** and open Cyclopedia → Magical Archives → select
**Energy Beam** (`exevo vis lux`, spell id 22). A row reading **`Base damage:
12 - 18`** should appear (exact numbers depend on your datapack's formula).

Then check the same spell on a level 8 character and a level 500 character: the
numbers must be **identical**. If they differ, you are computing live damage
instead of base damage.
