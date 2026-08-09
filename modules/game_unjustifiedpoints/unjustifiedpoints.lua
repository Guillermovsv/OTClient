unjustifiedPointsWindow = nil
unjustifiedPointsButton = nil
contentsPanel = nil

openPvpSituationsLabel = nil
currentSkullWidget = nil
skullTimeLabel = nil

dayProgressBar = nil
weekProgressBar = nil
monthProgressBar = nil

dayProgressBarBackground = nil
weekProgressBarBackground = nil
monthProgressBarBackground = nil

daySkullWidget = nil
weekSkullWidget = nil
monthSkullWidget = nil

function init()
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onUnjustifiedPointsChange = onUnjustifiedPointsChange,
        onOpenPvpSituationsChange = onOpenPvpSituationsChange,
        onAttackingCreatureChange = onAttack
    })
    connect(LocalPlayer, {
        onSkullChange = onSkullChange
    })

    unjustifiedPointsWindow = g_ui.loadUI('unjustifiedpoints')
    unjustifiedPointsWindow:disableResize()
    unjustifiedPointsWindow:setup()

    contentsPanel = unjustifiedPointsWindow:getChildById('contentsPanel')

    -- Set the title and icon in the header elements
    local titleWidget = unjustifiedPointsWindow:getChildById('miniwindowTitle')
    if titleWidget then
        titleWidget:setText('Unjustified Points')
    else
        -- Fallback to old method if miniwindowTitle doesn't exist
        unjustifiedPointsWindow:setText('Unjustified Points')
    end

    local iconWidget = unjustifiedPointsWindow:getChildById('miniwindowIcon')
    if iconWidget then
        iconWidget:setImageSource('/images/icons/icon-unjustified-points-widget')
    end

    openPvpSituationsLabel = contentsPanel:getChildById('openPvpSituationsLabel')
    currentSkullWidget = contentsPanel:getChildById('currentSkullWidget')
    skullTimeLabel = contentsPanel:getChildById('skullTimeLabel')

    dayProgressBar = contentsPanel:getChildById('dayProgressBar')
    weekProgressBar = contentsPanel:getChildById('weekProgressBar')
    monthProgressBar = contentsPanel:getChildById('monthProgressBar')
    
    dayProgressBarBackground = contentsPanel:getChildById('dayProgressBarBackground')
    weekProgressBarBackground = contentsPanel:getChildById('weekProgressBarBackground')
    monthProgressBarBackground = contentsPanel:getChildById('monthProgressBarBackground')
    
    daySkullWidget = contentsPanel:getChildById('daySkullWidget')
    weekSkullWidget = contentsPanel:getChildById('weekSkullWidget')
    monthSkullWidget = contentsPanel:getChildById('monthSkullWidget')

    -- Hide buttons as requested
    local toggleFilterButton = unjustifiedPointsWindow:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
    end
    
    local contextMenuButton = unjustifiedPointsWindow:recursiveGetChildById('contextMenuButton')
    if contextMenuButton then
        contextMenuButton:setVisible(false)
    end
    
    local newWindowButton = unjustifiedPointsWindow:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton:setVisible(false)
    end

    -- Position lockButton where toggleFilterButton was (to the left of minimize button)
    local lockButton = unjustifiedPointsWindow:recursiveGetChildById('lockButton')
    local minimizeButton = unjustifiedPointsWindow:recursiveGetChildById('minimizeButton')
    
    if lockButton and minimizeButton then
        lockButton:breakAnchors()
        lockButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
        lockButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
        lockButton:setMarginRight(7)  -- Same margin as toggleFilterButton had
        lockButton:setMarginTop(0)
    end

    if unjustifiedPointsButton then
        unjustifiedPointsButton:setOn(true)
    end

    if g_game.isOnline() then
        online()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onUnjustifiedPointsChange = onUnjustifiedPointsChange,
        onOpenPvpSituationsChange = onOpenPvpSituationsChange,
        onAttackingCreatureChange = onOpenPvpSituationsChange
    })
    disconnect(LocalPlayer, {
        onSkullChange = onSkullChange
    })

    unjustifiedPointsWindow:destroy()
    if unjustifiedPointsButton then
        unjustifiedPointsButton:destroy()
        unjustifiedPointsButton = nil
    end
end

function onMiniWindowOpen()
    if unjustifiedPointsButton then
        unjustifiedPointsButton:setOn(true)
    end
end

function onMiniWindowClose()
    if unjustifiedPointsButton then
        unjustifiedPointsButton:setOn(false)
    end
end

function toggle()
    if unjustifiedPointsButton:isOn() then
        unjustifiedPointsWindow:close()
        unjustifiedPointsButton:setOn(false)
    else
        if not unjustifiedPointsWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(unjustifiedPointsWindow, unjustifiedPointsWindow:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(unjustifiedPointsWindow)
        end
        unjustifiedPointsWindow:open()
        unjustifiedPointsButton:setOn(true)
    end
end

function online()
    if g_game.getFeature(GameUnjustifiedPoints) and not unjustifiedPointsButton then
        unjustifiedPointsWindow:setupOnStart() -- load character window configuration
        unjustifiedPointsButton = modules.game_mainpanel.addToggleButton('unjustifiedPointsButton',
        tr('Unjustified Points'), '/images/options/button_frags', toggle)
        unjustifiedPointsButton:setOn(false)
    end

    refresh()
end

function offline()
    if g_game.getFeature(GameUnjustifiedPoints) then
        unjustifiedPointsWindow:setParent(nil, true)
    end
end

function refresh()
    local localPlayer = g_game.getLocalPlayer()

    local unjustifiedPoints = g_game.getUnjustifiedPoints()
    onUnjustifiedPointsChange(unjustifiedPoints)

    onSkullChange(localPlayer, localPlayer:getSkull())
    onOpenPvpSituationsChange(g_game.getOpenPvpSituations())
end

function onSkullChange(localPlayer, skull)
    if not localPlayer:isLocalPlayer() then
        return
    end

    if skull == SkullRed or skull == SkullBlack then
        currentSkullWidget:setIcon(getSkullImagePath(skull))
        currentSkullWidget:setTooltip('Remaining skull time')
    else
        currentSkullWidget:setIcon('')
        currentSkullWidget:setTooltip('You have no skull')
    end

    daySkullWidget:setIcon(getSkullImagePath(getNextSkullId(skull)))
    weekSkullWidget:setIcon(getSkullImagePath(getNextSkullId(skull)))
    monthSkullWidget:setIcon(getSkullImagePath(getNextSkullId(skull)))
end

function onOpenPvpSituationsChange(amount)
    -- This shows the actual open PvP situations count
    local validAmount = tonumber(amount) or 0
    openPvpSituationsLabel:setText('Open: ' .. validAmount)
end

-- The bar fills and colours from the progress the server reports, so it is
-- empty at zero and works its way up to whatever limit that server applies.
local function getImageByProgress(percent)
    if percent <= 100 / 3 then
        return '/images/ui/unjustified-points-bar-texture-green'
    elseif percent <= 200 / 3 then
        return '/images/ui/unjustified-points-bar-texture-yellow'
    end
    return '/images/ui/unjustified-points-bar-texture-red'
end

local function setProgressBarImage(progressBar, progressBarBackground, percent, tooltip)
    -- Set tooltip on both progress bar and background so it's always visible
    progressBar:setTooltip(tooltip)
    if progressBarBackground then
        progressBarBackground:setTooltip(tooltip)
    end

    percent = math.max(0, math.min(100, tonumber(percent) or 0))

    -- Nothing gained in this period: leave the bar empty rather than filled
    if percent <= 0 then
        progressBar:setImageSource('')
        progressBar:setVisible(false)
        return
    end

    progressBar:setVisible(true)

    local backgroundWidth = progressBarBackground:getWidth()
    local foregroundWidth = math.max(1, math.floor(backgroundWidth * percent / 100))

    -- Break current anchors and set fixed width
    progressBar:breakAnchors()
    progressBar:addAnchor(AnchorTop, progressBarBackground:getId(), AnchorTop)
    progressBar:addAnchor(AnchorLeft, progressBarBackground:getId(), AnchorLeft)
    progressBar:setWidth(foregroundWidth)
    progressBar:setHeight(progressBarBackground:getHeight())

    progressBar:setImageSource(getImageByProgress(percent))
    progressBar:setImageBorder(1)
    progressBar:setImageBorderTop(1)
    progressBar:setImageBorderBottom(1)
end

function onUnjustifiedPointsChange(unjustifiedPoints)    
    if unjustifiedPoints.skullTime == 0 then
        skullTimeLabel:setText('0 days')
        skullTimeLabel:setTooltip('No Skull time active')
    else
        skullTimeLabel:setText(unjustifiedPoints.skullTime .. ' days')
        skullTimeLabel:setTooltip('Remaining skull time')
    end

    -- killsDay/Week/Month are the progress the server reports for each period,
    -- as a percentage of that server's own limit -- see the protocol parse,
    -- which labels them dayProgress %. They were being ignored in favour of
    -- rebuilding a count from hardcoded limits of 3, 5 and 10, so a character
    -- with nothing to answer for came out at full and every bar showed red.
    local function killsLeft(remaining)
        remaining = tonumber(remaining) or 0
        return string.format('%i kill%s left.', remaining, remaining == 1 and '' or 's')
    end

    setProgressBarImage(dayProgressBar, dayProgressBarBackground,
        unjustifiedPoints.killsDay,
        'Unjustified points gained during the last 24 hours.\n' ..
        killsLeft(unjustifiedPoints.killsDayRemaining))

    setProgressBarImage(weekProgressBar, weekProgressBarBackground,
        unjustifiedPoints.killsWeek,
        'Unjustified points gained during the last 7 days.\n' ..
        killsLeft(unjustifiedPoints.killsWeekRemaining))

    setProgressBarImage(monthProgressBar, monthProgressBarBackground,
        unjustifiedPoints.killsMonth,
        'Unjustified points gained during the last 30 days.\n' ..
        killsLeft(unjustifiedPoints.killsMonthRemaining))
end
