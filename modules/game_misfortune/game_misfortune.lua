local MISFORTUNE_OPCODE = 231
local targetWindow = nil

local function trim(value)
    return value:match('^%s*(.-)%s*$')
end

function init()
    ProtocolGame.registerExtendedOpcode(MISFORTUNE_OPCODE, onExtendedOpcode)
    connect(g_game, {
        onGameEnd = hide
    })

    targetWindow = g_ui.displayUI('game_misfortune')
    targetWindow:hide()
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(MISFORTUNE_OPCODE)
    disconnect(g_game, {
        onGameEnd = hide
    })

    if targetWindow then
        targetWindow:destroy()
        targetWindow = nil
    end
end

function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= MISFORTUNE_OPCODE then
        return
    end

    if buffer == 'open' then
        show()
    end
end

function show()
    if not targetWindow then
        return
    end

    local nameEdit = targetWindow:getChildById('targetName')
    nameEdit:setText('')
    targetWindow:show()
    targetWindow:raise()
    targetWindow:focus()
    nameEdit:focus()
end

function hide()
    if targetWindow then
        targetWindow:hide()
    end
end

function cancel()
    hide()
end

function submit()
    if not targetWindow then
        return
    end

    local name = trim(targetWindow:getChildById('targetName'):getText())
    if name == '' then
        displayErrorBox(tr('Lottery Ticket'), tr('Enter a character name.'))
        return
    end

    local protocolGame = g_game.getProtocolGame()
    if not protocolGame then
        return
    end

    -- The server expects the raw character name on opcode 231.
    protocolGame:sendExtendedOpcode(MISFORTUNE_OPCODE, name)
    hide()
end
