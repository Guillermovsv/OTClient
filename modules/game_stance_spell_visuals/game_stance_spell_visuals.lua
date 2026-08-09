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

-- TEMPORARY DIAGNOSTIC. Logs every spell-visual packet and why one is dropped,
-- so it is possible to tell whether the server is sending opcode 233 at all.
-- Remove this flag and the log lines once the recolouring is confirmed.
local DEBUG_SPELL_VISUAL = false

local function debugLog(fmt, ...)
    if DEBUG_SPELL_VISUAL then
        g_logger.info('[STANCE-VISUAL] ' .. string.format(fmt, ...))
    end
end

local function parse(buffer)
    local sequence, spellId, element, converted = buffer:match('^spell_visual|(%d+)|(%d+)|([%a]+)|([01])$')
    if not sequence then
        debugLog('unparsed payload: %s', tostring(buffer))
        return nil
    end

    sequence = tonumber(sequence)
    spellId = tonumber(spellId)
    converted = converted == '1'

    debugLog('packet seq=%s spellId=%s element=%s converted=%s (natural element %s)',
        tostring(sequence), tostring(spellId), tostring(element), tostring(converted),
        tostring(offensiveMasterSorcererSpells[spellId] or 'unlisted'))

    if not sequence or not spellId or sequence <= lastSequence then
        debugLog('dropped: stale sequence (%s <= %s)', tostring(sequence), tostring(lastSequence))
        return nil
    end
    if not offensiveMasterSorcererSpells[spellId] then
        debugLog('dropped: spell %s is not in the recolour allow-list', tostring(spellId))
        return nil
    end
    if not allowedElements[element] then
        debugLog('dropped: element %s is not one of none/flam/vis/mort', tostring(element))
        return nil
    end
    return sequence, spellId, element, converted
end

local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= SPELL_VISUAL_OPCODE then
        return
    end

    debugLog('opcode %d received', opcode)

    local sequence, spellId, element, converted = parse(buffer)
    if not sequence then
        return
    end

    lastSequence = sequence
    debugLog('recolouring spell %d to %s (converted=%s)', spellId, element, tostring(converted))
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
