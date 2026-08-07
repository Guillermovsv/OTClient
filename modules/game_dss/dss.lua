DSS = Controller:new()

local dssButton = nil
local dssWindow = nil

local rowWidgets = {} -- name -> widget, cached on init
local lastCastAt = {} -- row name -> last g_game.talk timestamp (ms), simple per-row cooldown
local ROW_COOLDOWN = 1000

local DEFAULT_CONFIG = {
  helperEnabled = false,
  spellHeal = {
    { enabled = false, words = 'exura', threshold = 80 },
    { enabled = false, words = 'exura gran', threshold = 50 },
    { enabled = false, words = 'exura vita', threshold = 25 },
  },
  potionHeal = {
    { enabled = false, itemId = 266, threshold = 70 },
    { enabled = false, itemId = 268, threshold = 50 },
    { enabled = false, itemId = 239, threshold = 30 },
  },
  manaTraining = { enabled = false, words = 'exevo mas vis', threshold = 90 },
  autoHaste = { enabled = false, words = 'utani hur', castInPz = false },
  spellSlots = {
    { enabled = false, words = 'exori', manaMin = 20, priority = 1 },
    { enabled = false, words = 'exori mas', manaMin = 30, priority = 2 },
    { enabled = false, words = 'exevo gran mas flam', manaMin = 40, priority = 3 },
    { enabled = false, words = '', manaMin = 0, priority = 4 },
    { enabled = false, words = '', manaMin = 0, priority = 5 },
  },
  runeSlot = { enabled = false, itemId = 3155, manaMin = 0, priority = 1 },
  autoTarget = false,
  shooterEnabled = false,
}

local config = nil

local function deepCopy(t)
  if type(t) ~= 'table' then return t end
  local copy = {}
  for k, v in pairs(t) do copy[k] = deepCopy(v) end
  return copy
end

local function loadConfig()
  local saved = g_settings.getNode('dss')
  config = saved or deepCopy(DEFAULT_CONFIG)
  -- fill in any missing keys added by later versions of this module
  for k, v in pairs(DEFAULT_CONFIG) do
    if config[k] == nil then config[k] = deepCopy(v) end
  end
end

local function saveConfig()
  g_settings.setNode('dss', config)
end

local function bindSlotRow(rowWidget, data)
  rowWidget.enabled:setChecked(data.enabled)
  rowWidget.words:setText(data.words)
  rowWidget.threshold:setValue(data.threshold)

  rowWidget.enabled.onCheckChange = function(widget, checked)
    data.enabled = checked
    saveConfig()
  end
  rowWidget.words.onTextChange = function(widget, text)
    data.words = text
    saveConfig()
  end
  rowWidget.threshold.onValueChange = function(widget, value)
    data.threshold = value
    saveConfig()
  end
end

local function bindShooterRow(rowWidget, data, wordsAreItemId)
  rowWidget.enabled:setChecked(data.enabled)
  if wordsAreItemId then
    rowWidget.words:setText(tostring(data.itemId))
  else
    rowWidget.words:setText(data.words)
  end
  rowWidget.manaMin:setValue(data.manaMin)
  rowWidget.priority:setValue(data.priority)

  rowWidget.enabled.onCheckChange = function(widget, checked)
    data.enabled = checked
    saveConfig()
  end
  rowWidget.words.onTextChange = function(widget, text)
    if wordsAreItemId then
      data.itemId = tonumber(text) or 0
    else
      data.words = text
    end
    saveConfig()
  end
  rowWidget.manaMin.onValueChange = function(widget, value)
    data.manaMin = value
    saveConfig()
  end
  rowWidget.priority.onValueChange = function(widget, value)
    data.priority = value
    saveConfig()
  end
end

local function setupHealingTab()
  local tab = dssWindow.mainArea.healingTab

  for i = 1, 3 do
    bindSlotRow(tab['spellHeal' .. i], config.spellHeal[i])
  end
  for i = 1, 3 do
    bindSlotRow(tab['potionHeal' .. i], config.potionHeal[i])
  end

  local mt = tab.manaTrainingRow
  mt.enabled:setChecked(config.manaTraining.enabled)
  mt.words:setText(config.manaTraining.words)
  mt.threshold:setValue(config.manaTraining.threshold)
  mt.enabled.onCheckChange = function(widget, checked) config.manaTraining.enabled = checked saveConfig() end
  mt.words.onTextChange = function(widget, text) config.manaTraining.words = text saveConfig() end
  mt.threshold.onValueChange = function(widget, value) config.manaTraining.threshold = value saveConfig() end

  local haste = tab.hasteRow
  haste.enabled:setChecked(config.autoHaste.enabled)
  haste.words:setText(config.autoHaste.words)
  haste.castInPz:setChecked(config.autoHaste.castInPz)
  haste.enabled.onCheckChange = function(widget, checked) config.autoHaste.enabled = checked saveConfig() end
  haste.words.onTextChange = function(widget, text) config.autoHaste.words = text saveConfig() end
  haste.castInPz.onCheckChange = function(widget, checked) config.autoHaste.castInPz = checked saveConfig() end
end

local function setupShooterTab()
  local tab = dssWindow.mainArea.shooterTab

  for i = 1, 5 do
    bindShooterRow(tab['spellSlot' .. i], config.spellSlots[i], false)
  end
  bindShooterRow(tab.runeSlot, config.runeSlot, true)

  tab.stanceOffensive.onClick = function() g_game.setFightMode(FightOffensive) end
  tab.stanceBalanced.onClick = function() g_game.setFightMode(FightBalanced) end
  tab.stanceDefensive.onClick = function() g_game.setFightMode(FightDefensive) end

  tab.autoTarget:setChecked(config.autoTarget)
  tab.autoTarget.onCheckChange = function(widget, checked) config.autoTarget = checked saveConfig() end

  tab.shooterEnabled:setChecked(config.shooterEnabled)
  tab.shooterEnabled.onCheckChange = function(widget, checked) config.shooterEnabled = checked saveConfig() end
end

local function switchTab(tabName)
  local sidebar = dssWindow.sidebar
  local mainArea = dssWindow.mainArea

  local healing = tabName == 'healing'
  mainArea.healingTab:setVisible(healing)
  mainArea.shooterTab:setVisible(not healing)
  sidebar.tabHealingButton:setChecked(healing)
  sidebar.tabShooterButton:setChecked(not healing)
end

local function canCastRow(rowName, cooldown)
  local now = g_clock.millis()
  local last = lastCastAt[rowName]
  if last and (now - last) < (cooldown or ROW_COOLDOWN) then
    return false
  end
  return true
end

local function markCast(rowName)
  lastCastAt[rowName] = g_clock.millis()
end

local function findNearestMonster()
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  local spectators = g_map.getSpectators(player:getPosition(), false, true) or {}
  local nearest, nearestDist = nil, math.huge
  local playerPos = player:getPosition()
  for _, creature in ipairs(spectators) do
    if creature ~= player and creature:isMonster() then
      local pos = creature:getPosition()
      local dist = math.max(math.abs(playerPos.x - pos.x), math.abs(playerPos.y - pos.y))
      if dist < nearestDist then
        nearest, nearestDist = creature, dist
      end
    end
  end
  return nearest
end

local function runHealingLogic()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local hpPercent = player:getHealthPercent()
  local manaPercent = player:getMaxMana() > 0 and math.floor(player:getMana() / player:getMaxMana() * 100) or 0

  for i, row in ipairs(config.spellHeal) do
    local name = 'spellHeal' .. i
    if row.enabled and row.words ~= '' and hpPercent <= row.threshold and canCastRow(name) then
      g_game.talk(row.words)
      markCast(name)
      return
    end
  end

  for i, row in ipairs(config.potionHeal) do
    local name = 'potionHeal' .. i
    if row.enabled and row.itemId and row.itemId > 0 and hpPercent <= row.threshold and canCastRow(name, 500) then
      g_game.useInventoryItem(row.itemId)
      markCast(name)
      return
    end
  end

  if config.manaTraining.enabled and config.manaTraining.words ~= ''
      and manaPercent <= config.manaTraining.threshold and canCastRow('manaTraining', 2000) then
    g_game.talk(config.manaTraining.words)
    markCast('manaTraining')
    return
  end

  if config.autoHaste.enabled and config.autoHaste.words ~= '' and canCastRow('autoHaste', 2000) then
    local inPz = player:hasState(PlayerStates.Pz)
    if (config.autoHaste.castInPz or not inPz) and not player:hasState(PlayerStates.Haste) then
      g_game.talk(config.autoHaste.words)
      markCast('autoHaste')
    end
  end
end

local function runShooterLogic()
  if not config.shooterEnabled then return end

  local target = g_game.getAttackingCreature()
  if not target and config.autoTarget then
    local nearest = findNearestMonster()
    if nearest then
      g_game.attack(nearest)
      target = nearest
    end
  end
  if not target then return end

  local player = g_game.getLocalPlayer()
  if not player then return end
  local manaPercent = player:getMaxMana() > 0 and math.floor(player:getMana() / player:getMaxMana() * 100) or 0

  local sorted = {}
  for i, row in ipairs(config.spellSlots) do
    table.insert(sorted, { index = i, row = row })
  end
  table.sort(sorted, function(a, b) return a.row.priority < b.row.priority end)

  for _, entry in ipairs(sorted) do
    local i, row = entry.index, entry.row
    local name = 'spellSlot' .. i
    if row.enabled and row.words ~= '' and manaPercent >= row.manaMin and canCastRow(name, 2000) then
      g_game.talk(row.words)
      markCast(name)
      return
    end
  end

  local rune = config.runeSlot
  if rune.enabled and rune.itemId and rune.itemId > 0 and manaPercent >= rune.manaMin and canCastRow('runeSlot', 2000) then
    g_game.useInventoryItemWith(rune.itemId, target, 0)
    markCast('runeSlot')
  end
end

local function onTick()
  if not g_game.isOnline() then return end
  if not config.helperEnabled then return end

  -- Without this, a dead player's health sits at/near 0% forever, which is
  -- below every heal threshold - the helper would keep spamming heal
  -- spell/potion actions every tick on a corpse, and that talk spam is
  -- exactly what gets players kicked by the server's flood protection.
  local player = g_game.getLocalPlayer()
  if not player or player:isDead() then return end

  runHealingLogic()
  runShooterLogic()
end

local function buildWindow()
  g_ui.importStyle('dss')
  dssWindow = g_ui.createWidget('DSSMainWindow', rootWidget)
  dssWindow:hide()

  local sidebar = dssWindow.sidebar
  sidebar.helperEnabled:setChecked(config.helperEnabled)
  sidebar.helperEnabled.onCheckChange = function(widget, checked)
    config.helperEnabled = checked
    saveConfig()
  end
  sidebar.tabHealingButton.onClick = function() switchTab('healing') end
  sidebar.tabShooterButton.onClick = function() switchTab('shooter') end

  setupHealingTab()
  setupShooterTab()
end

-- Standalone button, created once and parented directly to rootWidget - not
-- routed through game_mainpanel's "Manage Control Buttons" displayed/
-- available list at all, since that system proved unreliable to guarantee
-- visibility through (its state depends on other saved client config this
-- module has no control over). This way DSS only ever depends on itself.
local function buildButton()
  dssButton = g_ui.createWidget('DSSFloatingButton', rootWidget)
  dssButton:hide()
  dssButton:setTooltip(tr('Dely Spell Shooter'))
  dssButton.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
      DSS.toggle()
      return true
    end
  end
end

function DSS:onInit()
  loadConfig()

  -- If the window UI has any issue, it must not be able to take the button
  -- down with it - a Lua error here would otherwise abort the rest of
  -- Controller:init(), including the onGameStart wiring the button needs.
  local ok, err = pcall(buildWindow)
  if not ok then
    g_logger.error('[DSS] failed to build window UI: ' .. tostring(err))
    dssWindow = nil
  end

  local buttonOk, buttonErr = pcall(buildButton)
  if not buttonOk then
    g_logger.error('[DSS] failed to build floating button: ' .. tostring(buttonErr))
    dssButton = nil
  end
end

function DSS:onTerminate()
  if dssButton then
    dssButton:destroy()
    dssButton = nil
  end

  if dssWindow then
    dssWindow:destroy()
    dssWindow = nil
  end
end

function DSS:onGameStart()
  if dssButton then
    dssButton:show()
    dssButton:raise()
    g_logger.info('[DSS] floating button shown')
  else
    g_logger.error('[DSS] onGameStart fired but dssButton is nil (failed at onInit)')
  end

  local player = g_game.getLocalPlayer()
  if player and dssWindow then
    dssWindow.sidebar.charName:setText(player:getName())
  end

  DSS:cycleEvent(onTick, 250)
end

function DSS:onGameEnd()
  if dssButton then
    dssButton:hide()
  end
  if dssWindow then
    dssWindow:hide()
  end
end

function DSS.toggle()
  if not dssWindow then return end
  if dssWindow:isVisible() then
    DSS.hide()
  else
    DSS.show()
  end
end

function DSS.show()
  dssWindow:show()
  dssWindow:raise()
  dssWindow:focus()
  if dssButton then dssButton:setOn(true) end
end

function DSS.hide()
  dssWindow:hide()
  if dssButton then dssButton:setOn(false) end
end
