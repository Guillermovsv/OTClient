local UI = nil

local PROFILE = 'Default'

local FILTER_ALL = 1
local FILTER_LEARNED = 2
local FILTER_VOCATION = 3
local FILTER_ATTACK = 4
local FILTER_HEALING = 5
local FILTER_SUPPORT = 6
local FILTER_INSTANT = 7
local FILTER_CONJURE = 8

local FilterList = {
    {id = FILTER_ALL, title = 'All Spells'},
    {id = FILTER_LEARNED, title = 'Learned Only'},
    {id = FILTER_VOCATION, title = 'My Vocation'},
    {id = FILTER_ATTACK, title = 'Attack'},
    {id = FILTER_HEALING, title = 'Healing'},
    {id = FILTER_SUPPORT, title = 'Support'},
    {id = FILTER_INSTANT, title = 'Instant Spells'},
    {id = FILTER_CONJURE, title = 'Conjure / Runes'}
}

-- SpellInfo stores server vocation ids (see VocationNames), while
-- player:getVocation() returns a client vocation id, so they need translating.
local ServerVocationByClientId = {
    [VocationsClient.Sorcerer] = 1,
    [VocationsClient.Druid] = 2,
    [VocationsClient.Paladin] = 3,
    [VocationsClient.Knight] = 4,
    [VocationsClient.MasterSorcerer] = 5,
    [VocationsClient.ElderDruid] = 6,
    [VocationsClient.RoyalPaladin] = 7,
    [VocationsClient.EliteKnight] = 8,
    [VocationsClient.Monk] = 9,
    [VocationsClient.ExaltedMonk] = 10
}

local BaseVocationByPromotion = {
    [5] = 1,
    [6] = 2,
    [7] = 3,
    [8] = 4,
    [10] = 9
}

local currentFilter = FILTER_ALL
local searchText = ''
local learnedSpells = {}
local selectedSpell = nil

local function getSpellList()
    return UI.InformationBase.selectSpell.listPanel.questList
end

local function refreshLearnedSpells()
    learnedSpells = {}

    local player = g_game.getLocalPlayer()
    -- getSpells is only bound in newer builds of the client
    if not player or not player.getSpells then
        return
    end

    for _, spellId in ipairs(player:getSpells()) do
        learnedSpells[spellId] = true
    end
end

local function isLearned(info)
    return info.id ~= nil and learnedSpells[info.id] == true
end

-- a promoted character keeps the spells of its base vocation
local function getPlayerVocations()
    local player = g_game.getLocalPlayer()
    if not player then
        return nil
    end

    local vocation = ServerVocationByClientId[player:getVocation()]
    if not vocation then
        return nil
    end

    local base = BaseVocationByPromotion[vocation]
    if base then
        return {vocation, base}
    end
    return {vocation}
end

local function matchesPlayerVocation(info)
    local vocations = getPlayerVocations()
    if not vocations then
        return true
    end

    for _, vocation in ipairs(vocations) do
        if table.find(info.vocations or {}, vocation) then
            return true
        end
    end
    return false
end

local function matchesFilter(info)
    if currentFilter == FILTER_LEARNED then
        return isLearned(info)
    elseif currentFilter == FILTER_VOCATION then
        return matchesPlayerVocation(info)
    elseif currentFilter == FILTER_ATTACK then
        return info.group ~= nil and info.group[1] ~= nil
    elseif currentFilter == FILTER_HEALING then
        return info.group ~= nil and info.group[2] ~= nil
    elseif currentFilter == FILTER_SUPPORT then
        return info.group ~= nil and info.group[3] ~= nil
    elseif currentFilter == FILTER_INSTANT then
        return info.type == 'Instant'
    elseif currentFilter == FILTER_CONJURE then
        return info.type == 'Conjure'
    end
    return true
end

local function matchesSearch(spellName, info)
    if searchText == '' then
        return true
    end
    if spellName:lower():find(searchText, 1, true) then
        return true
    end
    return info.words ~= nil and info.words:lower():find(searchText, 1, true) ~= nil
end

local function formatGroups(info)
    local groups = ''
    local cooldown = ((info.exhaustion or 0) / 1000) .. 's'

    for groupId, groupName in ipairs(SpellGroups) do
        if info.group and info.group[groupId] then
            groups = groups .. (groups:len() == 0 and '' or ' / ') .. groupName
            cooldown = cooldown .. ' / ' .. (info.group[groupId] / 1000) .. 's'
        end
    end

    return (groups:len() > 0 and groups or '-'), cooldown
end

local function formatVocations(info)
    local vocations = info.vocations or {}
    local names = ''

    for _, vocation in ipairs(vocations) do
        -- collapse a promotion into its base vocation when both are listed
        local base = BaseVocationByPromotion[vocation]
        if not base or not table.find(vocations, base) then
            names = names .. (names:len() == 0 and '' or ', ') .. (VocationNames[vocation] or ('#' .. vocation))
        end
    end

    return names:len() > 0 and names or '-'
end

local function addRow(key, value)
    local row = g_ui.createWidget('MagicalArchivesRow', UI.spellAndRune.details.rows)
    row.key:setText(key .. ':')
    row.value:setText(value)
    return row
end

local function clearDetails()
    selectedSpell = nil
    UI.spellAndRune.details:setVisible(false)
    UI.spellAndRune.details.rows:destroyChildren()
    UI.spellAndRune.hint:setVisible(true)
end

local function showDetails(spellName)
    local info = SpellInfo[PROFILE][spellName]
    if not info then
        return clearDetails()
    end

    selectedSpell = spellName

    local details = UI.spellAndRune.details
    UI.spellAndRune.hint:setVisible(false)
    details:setVisible(true)

    details.header.name:setText(spellName)
    details.header.words:setText("'" .. (info.words or '') .. "'")

    local iconId = tonumber(info.clientId)
    if iconId then
        details.header.icon:setImageSource(Spells.getIconFileByProfile(PROFILE))
        details.header.icon:setImageClip(Spells.getImageClip(iconId, PROFILE))
    end

    local learned = isLearned(info)
    details.header.status:setText(learned and tr('Learned') or tr('Not learned'))
    details.header.status:setColor(learned and '#4EA24E' or '#A24E4E')

    local groups, cooldown = formatGroups(info)

    details.rows:destroyChildren()
    addRow(tr('Type'), info.type or '-')
    addRow(tr('Group'), groups)
    addRow(tr('Cooldown'), cooldown)

    -- the spell's damage at its own level/magic level requirements, pushed by
    -- the server; absent until it answers
    local damage = Spells.getDamageInfo(info.id)
    if damage then
        addRow(damage.kind == 'healing' and tr('Base healing') or tr('Base damage'),
            damage.min .. ' - ' .. damage.max)
    end

    addRow(tr('Level'), info.level or 0)
    addRow(tr('Mana'), info.mana or 0)
    addRow(tr('Soul'), info.soul or 0)
    addRow(tr('Magic Level'), info.maglevel or 0)
    addRow(tr('Vocations'), formatVocations(info))
    addRow(tr('Premium'), info.premium and tr('yes') or tr('no'))

    if info.needTarget then
        addRow(tr('Target'), tr('required'))
    end
    if info.range and info.range > 0 then
        addRow(tr('Range'), info.range)
    end
end

local function applyFilters()
    local list = getSpellList()
    local visibleSelected = false

    for _, widget in ipairs(list:getChildren()) do
        local spellName = widget:getId()
        local info = SpellInfo[PROFILE][spellName]
        local visible = info ~= nil and matchesFilter(info) and matchesSearch(spellName, info)

        widget:setVisible(visible)
        if visible and spellName == selectedSpell then
            visibleSelected = true
        end
    end

    if selectedSpell and not visibleSelected then
        clearDetails()
    end
end

local function buildSpellList()
    local list = getSpellList()
    list:destroyChildren()

    local spellNames = {}
    for spellName in pairs(SpellInfo[PROFILE]) do
        table.insert(spellNames, spellName)
    end
    table.sort(spellNames)

    local iconFile = Spells.getIconFileByProfile(PROFILE)
    for _, spellName in ipairs(spellNames) do
        local info = SpellInfo[PROFILE][spellName]
        -- the colour has to come from the style, otherwise the focus state
        -- reapplies the base style and wipes it
        local style = isLearned(info) and 'MagicalArchivesSpell' or 'MagicalArchivesSpellLocked'
        local widget = g_ui.createWidget(style, list)
        widget:setId(spellName)
        widget:setText(spellName .. "\n'" .. (info.words or '') .. "'")

        local iconId = tonumber(info.clientId)
        if iconId then
            widget:setImageSource(iconFile)
            widget:setImageClip(Spells.getImageClip(iconId, PROFILE))
        end
    end

    connect(list, {
        onChildFocusChange = function(self, focusedChild)
            if focusedChild == nil then
                return
            end
            showDetails(focusedChild:getId())
        end
    })
end

-- called when the server answers the spell damage request, which can land after
-- the tab is already open
function Cyclopedia.refreshMagicalArchivesDamage()
    if not UI or UI:isDestroyed() or not selectedSpell then
        return
    end
    showDetails(selectedSpell)
end

function showMagicalArchives()
    UI = g_ui.loadUI("/game_cyclopedia/tab/magicalArchives/magicalArchives", contentContainer)
    UI:show()
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end

    currentFilter = FILTER_ALL
    searchText = ''
    selectedSpell = nil

    refreshLearnedSpells()
    -- base damage does not change with the character, so fetch it once
    if not Spells.hasDamageInfo() then
        Spells.requestDamageInfo()
    end
    buildSpellList()

    local filterOption = UI.InformationBase.selectSpell.filterOption
    filterOption:clearOptions()
    for _, filter in ipairs(FilterList) do
        filterOption:addOption(tr(filter.title), filter.id)
    end
    filterOption.onOptionChange = function(widget, text, data)
        currentFilter = data
        applyFilters()
    end

    -- TextEditQuestLog wires @onTextChange to a global the cyclopedia does not
    -- define, so the handler has to be replaced here
    UI.InformationBase.selectSpell.searchPanel.SearchEdit.onTextChange = function(widget, text)
        searchText = text:lower()
        applyFilters()
    end

    clearDetails()
    applyFilters()

    -- the list auto-focuses its first entry, so keep the details panel in sync
    local focused = getSpellList():getFocusedChild()
    if focused and focused:isVisible() then
        showDetails(focused:getId())
    end
end
