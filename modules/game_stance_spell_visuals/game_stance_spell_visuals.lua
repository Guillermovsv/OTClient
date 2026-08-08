local SPELL_VISUAL_OPCODE = 233

controllerStanceSpellVisuals = Controller:new()

-- Stable server spell identifiers. This is intentionally an allow-list: the
-- client never infers damage from words, icons, or the active stance.
local offensiveMasterSorcererSpells = {
    [13] = 'vis', [19] = 'flam', [22] = 'vis', [23] = 'vis', [24] = 'flam',
    [25] = 'flam', [27] = 'vis', [28] = 'flam', [32] = 'mort', [33] = 'vis',
    [55] = 'vis', [63] = 'mort', [77] = 'tera', [83] = 'mort',
    [87] = 'mort', [88] = 'vis', [89] = 'flam', [112] = 'frigo', [113] = 'tera',
    [117] = 'vis', [119] = 'vis', [138] = 'flam', [139] = 'mort', [140] = 'vis',
    [149] = 'vis', [150] = 'flam', [151] = 'vis', [154] = 'flam', [155] = 'vis',
    [169] = 'flam', [177] = 'vis', [178] = 'flam', [209] = 'mort', [240] = 'flam',
    [260] = 'mort', [298] = 'tera', [305] = 'frigo',
}

local allowedElements = { none = true, flam = true, vis = true, mort = true }
local lastSequence = 0

local function clear()
    lastSequence = 0
    g_client.clearMasterSorcererSpellVisual()
end

local function parse(buffer)
    local sequence, spellId, element, converted = buffer:match('^spell_visual|(%d+)|(%d+)|([%a]+)|([01])$')
    sequence = tonumber(sequence)
    spellId = tonumber(spellId)
    converted = converted == '1'
    if not sequence or not spellId or sequence <= lastSequence then
        return nil
    end
    if not offensiveMasterSorcererSpells[spellId] or not allowedElements[element] then
        return nil
    end
    return sequence, spellId, element, converted
end

local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= SPELL_VISUAL_OPCODE then
        return
    end

    local sequence, spellId, element, converted = parse(buffer)
    if not sequence then
        return
    end

    lastSequence = sequence
    g_client.setMasterSorcererSpellVisual(sequence, spellId, element, converted)
end

function controllerStanceSpellVisuals:onInit()
    g_shaders.createFragmentShader(
        'Master Sorcerer Stance Palette',
        '/game_shaders/shaders/fragment/stance_palette.frag'
    )
    ProtocolGame.registerExtendedOpcode(SPELL_VISUAL_OPCODE, onExtendedOpcode)
    connect(g_game, { onGameEnd = clear })
end

function controllerStanceSpellVisuals:onTerminate()
    ProtocolGame.unregisterExtendedOpcode(SPELL_VISUAL_OPCODE)
    disconnect(g_game, { onGameEnd = clear })
    clear()
end

function controllerStanceSpellVisuals.clear()
    clear()
end
