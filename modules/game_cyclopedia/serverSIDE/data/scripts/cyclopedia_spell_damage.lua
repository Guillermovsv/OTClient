--[[
    Cyclopedia -> Magical Archives: base spell damage.

    The client asks for spell damage when the Magical Archives tab is opened and
    renders whatever this script answers with.

    This reports BASE damage: each spell's formula evaluated at the level and
    magic level the spell itself requires. It is a fixed property of the spell,
    identical for every character - it is not what the logged in player would
    actually hit for.

    IMPORTANT - read before using:

    Canary does not expose a spell's combat formula to Lua. The formula lives in
    the Combat object built inside each spell script (setFormula, or the
    CALLBACK_PARAM_LEVELMAGICVALUE callback), and there is no accessor to read it
    back. So this script cannot discover damage automatically - the formulas
    below have to be mirrored from your own spell scripts.

    That is a one-time copy per spell you care about, and spells with no entry
    simply render without a damage row on the client, so you can fill this in
    incrementally.

    Because the answer is character independent, it is computed once and reused
    for every player that asks.

    Install:
      1. copy this file to  data/scripts/
      2. make sure the json lib is loaded (data/lib/lib.lua -> dofile('data/lib/json.lua'))
      3. reload scripts, or restart the server
]]

local OPCODE = 220
local MAX_PACKET_SIZE = 65000

-- [spellId] = { level = <spell:level()>, magicLevel = <spell:magicLevel()>,
--               formula = function(player, level, magicLevel) return min, max end }
--
-- spellId is the same id your script passes to spell:id().
--
-- level and magicLevel are the spell's own requirements, copied from the same
-- script - they are the point the formula gets evaluated at, which is what makes
-- the result "base" damage.
--
-- formula deliberately takes the same (player, level, magicLevel) signature as
-- onGetFormulaValues, so you can paste that function in verbatim, or reference
-- it directly if your datapack exposes it. It is called with the requesting
-- player - so any player:... calls inside still work - but with the spell's base
-- level and magic level rather than the player's, which is what makes the result
-- character independent.
--
-- Return damage as negative numbers and healing as positive numbers, exactly
-- like onGetFormulaValues does, and the client will label it accordingly.
--
-- The entries below are only here to show the shape - verify them against your
-- datapack before trusting the numbers they produce.
local formulas = {
    -- Example, mirroring data/scripts/spells/attack/energy_beam.lua:
    --
    --   spell:level(23)
    --   spell:magicLevel(0)
    --   function onGetFormulaValues(player, level, magicLevel)
    --       local min = (level / 5) + (magicLevel * 1.4) + 8
    --       local max = (level / 5) + (magicLevel * 2.2) + 14
    --       return -min, -max
    --   end
    --
    -- [22] = {
    --     level = 23,
    --     magicLevel = 0,
    --     formula = function(player, level, magicLevel)
    --         local min = (level / 5) + (magicLevel * 1.4) + 8
    --         local max = (level / 5) + (magicLevel * 2.2) + 14
    --         return -min, -max
    --     end
    -- },

    -- Healing works the same way, returning positive values:
    --
    -- [1] = {
    --     level = 8,
    --     magicLevel = 0,
    --     formula = function(player, level, magicLevel)
    --         local min = (level / 5) + (magicLevel * 3) + 15
    --         local max = (level / 5) + (magicLevel * 4) + 25
    --         return min, max
    --     end
    -- },
}

-- Not cached: a formula is free to read player state, and caching the first
-- caller's result would leak it to everyone else. Evaluating a few hundred
-- arithmetic expressions per request is not worth the risk.
local function buildPayload(player)
    local spells = {}

    for spellId, entry in pairs(formulas) do
        local level = entry.level or 0
        local magicLevel = entry.magicLevel or 0

        -- the player is passed through, but the level/magic level are the
        -- spell's own requirements, not the player's
        local ok, min, max = pcall(entry.formula, player, level, magicLevel)
        if ok and type(min) == "number" and type(max) == "number" then
            spells[#spells + 1] = {
                id = spellId,
                min = math.abs(min),
                max = math.abs(max),
                -- negative means damage, positive means healing
                kind = (min < 0 or max < 0) and "damage" or "healing"
            }
        end
    end

    return json.encode({
        action = "spellDamage",
        spells = spells
    })
end

-- mirrors the client's chunking in modules/gamelib/protocolgame.lua:
-- a single message is sent raw, longer payloads are split into S / P / E parts
local function sendBuffer(player, buffer)
    if #buffer <= MAX_PACKET_SIZE then
        player:sendExtendedOpcode(OPCODE, buffer)
        return
    end

    local parts = {}
    for i = 1, #buffer, MAX_PACKET_SIZE do
        parts[#parts + 1] = buffer:sub(i, i + MAX_PACKET_SIZE - 1)
    end

    player:sendExtendedOpcode(OPCODE, "S" .. parts[1])
    for i = 2, #parts - 1 do
        player:sendExtendedOpcode(OPCODE, "P" .. parts[i])
    end
    player:sendExtendedOpcode(OPCODE, "E" .. parts[#parts])
end

local spellDamageOpcode = CreatureEvent("CyclopediaSpellDamage")

function spellDamageOpcode.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then
        return true
    end

    local ok, request = pcall(json.decode, buffer)
    if not ok or type(request) ~= "table" or request.action ~= "spellDamage" then
        return true
    end

    sendBuffer(player, buildPayload(player))
    return true
end

spellDamageOpcode:type("extendedopcode")
spellDamageOpcode:register()

local spellDamageLogin = CreatureEvent("CyclopediaSpellDamageLogin")

function spellDamageLogin.onLogin(player)
    player:registerEvent("CyclopediaSpellDamage")
    return true
end

spellDamageLogin:type("login")
spellDamageLogin:register()
