-- RTC Helper
-- Standalone in-client healing & attack assistant. It intentionally does NOT use
-- game_bot / vBot / cavebot; it drives the plain game actions directly
-- (g_game.talk / useInventoryItem / useWith / attack) from a settings UI.

helperWindow = nil
local helperButton = nil
local loopEvent = nil
local actionGate = {}
local boundHelperKey = nil
local boundTargetKey = nil

local SETTINGS_KEY = 'RTCHelper'
local PRESETS_KEY = 'RTCHelperPresets'
local TICK_MS = 200

local stats = {
  heals = 0, potions = 0, attacks = 0, runes = 0,
  hastes = 0, foods = 0, manaTrains = 0, exTrains = 0, golds = 0,
}

local function defaultConfig()
  return {
    enabled = false,
    autoHaste = false, hastePz = false, hasteWords = 'utani hur', hasteItem = 0,
    autoEat = false, foodItem = 3725,
    changeGold = false, autoReconnect = false,
    comboOrder = false, hotkeyPriority = false,
    stance = { item1 = 0, item2 = 0 },
    heals = {
      { enabled = false, words = '', hp = 80, item = 0 },
      { enabled = false, words = '', hp = 60, item = 0 },
      { enabled = false, words = '', hp = 40, item = 0 },
    },
    -- rows 1-2 drink on health percent, row 3 on mana percent
    potions = {
      { enabled = false, item = 0, pct = 70, kind = 'hp' },
      { enabled = false, item = 0, pct = 50, kind = 'hp' },
      { enabled = false, item = 0, pct = 40, kind = 'mana' },
    },
    manaTrain = { enabled = false, words = '', pct = 100, item = 0 },
    exTrain = { enabled = false, item = 0 },
    attacks = {
      { enabled = false, words = '', mana = 20, mobs = 1, prio = 1, item = 0 },
      { enabled = false, words = '', mana = 20, mobs = 1, prio = 2, item = 0 },
      { enabled = false, words = '', mana = 20, mobs = 1, prio = 3, item = 0 },
      { enabled = false, words = '', mana = 20, mobs = 1, prio = 4, item = 0 },
      { enabled = false, words = '', mana = 20, mobs = 1, prio = 5, item = 0 },
    },
    shooter = false, autoTarget = false,
    rune = { enabled = false, item = 0, mobs = 1, prio = 1 },
    helperKey = '', targetKey = '',
    schemaVersion = 2,
  }
end

local config = defaultConfig()
local currentPreset = 'Default'

-- ---------------------------------------------------------------------------
-- lifecycle
-- ---------------------------------------------------------------------------
function init()
  connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })

  helperButton = modules.client_topmenu.addRightGameToggleButton(
    'helperButton', tr('RTC Helper'), '/images/topbuttons/combatcontrols', toggle)

  local root = (modules.game_interface and modules.game_interface.getRootPanel
    and modules.game_interface.getRootPanel()) or g_ui.getRootWidget()
  helperWindow = g_ui.loadUI('styles/helper', root)
  helperWindow:hide()

  loadConfig()
  wireSteppers()
  wireCombos()
  wireSlots()
  populateUI()
  refreshPresetCombo()
  selectTab('healing')

  -- live master toggle (no need to press Save just to enable/disable)
  local enableBox = helperWindow:recursiveGetChildById('enableBox')
  if enableBox then
    enableBox.onCheckChange = function(_, checked)
      config.enabled = checked
      refreshStatus()
      saveConfig()
    end
  end

  applyHotkeys()
  loopEvent = cycleEvent(loop, TICK_MS)

  if g_game.isOnline() then onGameStart() end

end

function terminate()
  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  clearHotkeys()
  if loopEvent then loopEvent:cancel() loopEvent = nil end
  if helperButton then helperButton:destroy() helperButton = nil end
  if helperWindow then helperWindow:destroy() helperWindow = nil end
end

function onGameStart()
  local player = g_game.getLocalPlayer()
  if player and helperWindow then
    -- the character name is the sidebar panel's own title bar
    local name = helperWindow:recursiveGetChildById('sidebar')
    if name then name:setText(player:getName()) end
    local preview = helperWindow:recursiveGetChildById('charPreview')
    if preview and preview.setOutfit then
      preview:setOutfit(player:getOutfit())
      if preview.setCreatureSize then preview:setCreatureSize(64) end
    end
  end
  refreshStatus()
end

function onGameEnd()
  if helperWindow then helperWindow:hide() end
end

function selectTab(which)
  if not helperWindow then return end
  local healing = which == 'healing'
  local function vis(id, on)
    local x = helperWindow:recursiveGetChildById(id)
    if x then x:setVisible(on) end
  end
  local function on(id, state)
    local x = helperWindow:recursiveGetChildById(id)
    if x and x.setOn then x:setOn(state) end
  end
  vis('healingPanel', healing)
  vis('casterPanel', not healing)
  on('healingTabBtn', healing)
  on('casterTabBtn', not healing)
  local title = helperWindow:recursiveGetChildById('tabTitle')
  if title then title:setText(healing and 'Healing' or 'RTCaster') end
end

-- ---------------------------------------------------------------------------
-- window helpers
-- ---------------------------------------------------------------------------
function toggle()
  if not helperWindow then return end
  if helperWindow:isVisible() then hide() else show() end
end

function show()
  if not helperWindow then return end
  helperWindow:show()
  helperWindow:raise()
  helperWindow:focus()
  if helperButton then helperButton:setOn(true) end
end

function hide()
  if not helperWindow then return end
  helperWindow:hide()
  if helperButton then helperButton:setOn(false) end
end

function refreshStatus()
  if not helperWindow then return end
  -- statusLabel is nested inside the window's panel, so the direct-children
  -- lookup returns nil and every call errored out before the UI could show.
  local label = helperWindow:recursiveGetChildById('statusLabel')
  if not label then return end
  if config.enabled then
    label:setText('Helper Status: Enabled')
    label:setColor('#44cc44')
  else
    label:setText('Helper Status: Disabled')
    label:setColor('#cc4444')
  end
  local preset = helperWindow:recursiveGetChildById('presetLabel')
  if preset then preset:setText('Preset: ' .. currentPreset) end

  local hk = helperWindow:recursiveGetChildById('helperKeyLabel')
  if hk then
    hk:setText('Helper: ' ..
      ((config.helperKey ~= '' and config.helperKey) or 'none'))
  end
  local tk = helperWindow:recursiveGetChildById('targetKeyLabel')
  if tk then
    tk:setText('Target / Shooter: ' ..
      ((config.targetKey ~= '' and config.targetKey) or 'none'))
  end
end

-- ---------------------------------------------------------------------------
-- persistence
-- ---------------------------------------------------------------------------
-- g_settings serializes a Lua array to OTML as keyed nodes (1:, 2:, 3:) and
-- reads them back as STRING keys, so config.heals[1] came back nil and took the
-- whole module down on the next start. Rebuild rows with real numeric indices.
local function normalizeRows(saved, defaults)
  local out = {}
  for i = 1, #defaults do
    local row = table.copy(defaults[i])
    local savedRow = nil
    if type(saved) == 'table' then
      savedRow = saved[i] or saved[tostring(i)]
    end
    if type(savedRow) == 'table' then
      for k, v in pairs(savedRow) do
        if row[k] ~= nil then row[k] = v end
      end
    end
    out[i] = row
  end
  return out
end

local function normalizeGroup(saved, defaults)
  local out = table.copy(defaults)
  if type(saved) == 'table' then
    for k, v in pairs(saved) do
      if out[k] ~= nil then out[k] = v end
    end
  end
  return out
end

local function normalizeConfig(saved)
  local base = defaultConfig()
  if type(saved) ~= 'table' then return base end

  for _, key in ipairs({ 'enabled', 'autoHaste', 'hastePz', 'hasteWords', 'hasteItem',
                         'autoEat', 'foodItem', 'changeGold', 'autoReconnect',
                         'comboOrder', 'hotkeyPriority', 'shooter', 'autoTarget',
                         'helperKey', 'targetKey' }) do
    if saved[key] ~= nil then base[key] = saved[key] end
  end
  base.stance = normalizeGroup(saved.stance, base.stance)

  base.heals     = normalizeRows(saved.heals, base.heals)
  base.attacks   = normalizeRows(saved.attacks, base.attacks)
  base.potions   = normalizeRows(saved.potions, base.potions)
  base.manaTrain = normalizeGroup(saved.manaTrain, base.manaTrain)

  -- Carry the old two-potion schema (potHp / potMana) into the three rows.
  if not saved.potions then
    if type(saved.potHp) == 'table' then
      base.potions[1].item    = saved.potHp.item or 0
      base.potions[1].enabled = saved.potHp.enabled or false
      if (saved.potHp.hp or 0) > 1 then base.potions[1].pct = saved.potHp.hp end
    end
    if type(saved.potMana) == 'table' then
      base.potions[3].item    = saved.potMana.item or 0
      base.potions[3].enabled = saved.potMana.enabled or false
      if (saved.potMana.mana or 0) > 1 then base.potions[3].pct = saved.potMana.mana end
    end
  end

  -- Settings written before the spin range was fixed had every percent clamped
  -- to 1. Restore the defaults for those so the UI does not come back full of
  -- 1s; anything saved after the fix carries schemaVersion and is left alone.
  if (tonumber(saved.schemaVersion) or 1) < 2 then
    local fresh = defaultConfig()
    for i, row in ipairs(base.heals) do
      if row.hp == 1 then row.hp = fresh.heals[i].hp end
    end
    for i, row in ipairs(base.potions) do
      if row.pct == 1 then row.pct = fresh.potions[i].pct end
    end
    for i, row in ipairs(base.attacks) do
      if row.mana == 1 then row.mana = fresh.attacks[i].mana end
    end
    if base.manaTrain.pct == 1 then base.manaTrain.pct = fresh.manaTrain.pct end
  end
  base.schemaVersion = 2
  base.exTrain   = normalizeGroup(saved.exTrain, base.exTrain)
  base.rune      = normalizeGroup(saved.rune, base.rune)
  return base
end

function loadConfig()
  config = normalizeConfig(g_settings.getNode(SETTINGS_KEY))
  local presets = g_settings.getNode(PRESETS_KEY)
  if type(presets) == 'table' and type(presets.current) == 'string' then
    currentPreset = presets.current
  end
end

function saveConfig()
  g_settings.setNode(SETTINGS_KEY, config)
  local presets = g_settings.getNode(PRESETS_KEY)
  if type(presets) ~= 'table' then presets = { list = {} } end
  if type(presets.list) ~= 'table' then presets.list = {} end
  presets.current = currentPreset
  presets.list[currentPreset] = config
  g_settings.setNode(PRESETS_KEY, presets)
  g_settings.save()
end

local function presetNames()
  local presets = g_settings.getNode(PRESETS_KEY)
  local names = {}
  if type(presets) == 'table' and type(presets.list) == 'table' then
    for name in pairs(presets.list) do table.insert(names, name) end
  end
  if #names == 0 then table.insert(names, 'Default') end
  table.sort(names)
  return names
end

-- ---------------------------------------------------------------------------
-- UI <-> config
-- ---------------------------------------------------------------------------
local function w(id)
  if not helperWindow then return nil end
  return helperWindow:recursiveGetChildById(id)
end

-- Every accessor tolerates a missing widget. A single id typo used to raise
-- inside init(), and a module that throws while loading is removed from
-- package.loaded -- leaving the already-created window on screen with
-- modules.game_helper nil, so every button then failed too.
local function setText(id, v)
  local x = w(id); if x then x:setText(tostring(v ~= nil and v or '')) end
end
local function getText(id)
  local x = w(id); return x and x:getText() or ''
end
local function setChecked(id, v)
  local x = w(id); if x and x.setChecked then x:setChecked(v and true or false) end
end
local function isChecked(id)
  local x = w(id); return (x and x.isChecked and x:isChecked()) and true or false
end
local function setSpin(id, v)
  local x = w(id); if x and x.setValue then x:setValue(tonumber(v) or 0) end
end
local function getSpin(id, fallback)
  local x = w(id)
  if x and x.getValue then return x:getValue() end
  return fallback or 0
end

-- RTCStepper is a composite: the number lives in its 'spin' child.
local function stepper(id)
  local x = w(id)
  return x and x:getChildById('spin') or nil
end
local function setStepper(id, v)
  local s = stepper(id); if s and s.setValue then s:setValue(tonumber(v) or 0) end
end
local function getStepper(id, fallback)
  local s = stepper(id)
  if s and s.getValue then return s:getValue() end
  return fallback or 0
end

-- An empty slot must be cleared AND hidden. UIItem treats id 0 as a real thing
-- type and tries to draw it, flooding the log with "Invalid thing type client
-- id 0 in category 4" on every frame the window is visible.
local function setSlot(id, itemId)
  local x = w(id)
  if not x or not x.setItemId then return end
  itemId = tonumber(itemId) or 0
  if itemId > 0 then
    x:setItemId(itemId)
    if x.setItemVisible then x:setItemVisible(true) end
  else
    if x.clearItem then x:clearItem() end
    if x.setItemVisible then x:setItemVisible(false) end
  end
  -- dotted placeholder only while the slot is empty
  local ph = x:getChildById('placeholder')
  if ph then ph:setVisible(itemId <= 0) end
end
local function getSlot(id, fallback)
  local x = w(id)
  if x and x.getItemId then return x:getItemId() end
  return fallback or 0
end

-- Wire the < > buttons of every stepper to nudge its spin box.
function wireSteppers()
  if not helperWindow then return end
  local ids = { 'heal1Hp', 'heal2Hp', 'heal3Hp', 'pot1Hp', 'pot2Hp', 'pot3Mana',
                'manaTrainPct', 'atk1Mana', 'atk2Mana', 'atk3Mana',
                'atk4Mana', 'atk5Mana' }
  for _, id in ipairs(ids) do
    local box = w(id)
    if box then
      local spin = box:getChildById('spin')
      local dec = box:getChildById('dec')
      local inc = box:getChildById('inc')
      if spin and spin.setMinimum then spin:setMinimum(0) spin:setMaximum(100) end
      if dec and spin then
        dec.onClick = function() spin:setValue(math.max(0, spin:getValue() - 1)) end
      end
      if inc and spin then
        inc.onClick = function() spin:setValue(math.min(100, spin:getValue() + 1)) end
      end
    end
  end
end

-- Drag an item from your inventory/containers onto a slot to bind it; right
-- click a slot to clear it. Mirrors how the action bar accepts drops.
local SLOT_IDS = {
  'hasteSlot', 'heal1Slot', 'heal2Slot', 'heal3Slot',
  'pot1Slot', 'pot2Slot', 'pot3Slot', 'manaTrainSlot', 'exTrainSlot',
  'atk1Slot', 'atk2Slot', 'atk3Slot', 'atk4Slot', 'atk5Slot', 'runeSlot',
  'stance1Slot', 'stance2Slot',
}

-- Creatures and Priority are dropdowns, shown as "1+" and "1st" like the
-- reference. Options carry the plain number as their data.
local ORDINALS = { '1st', '2nd', '3rd', '4th', '5th' }

local function fillCombo(id, texts)
  local combo = w(id)
  if not combo or not combo.clearOptions then return end
  combo:clearOptions()
  for i, text in ipairs(texts) do combo:addOption(text, i) end
end

local function setCombo(id, value)
  local combo = w(id)
  if not combo or not combo.setCurrentOptionByData then return end
  combo:setCurrentOptionByData(tonumber(value) or 1, true)
end

local function getCombo(id, fallback)
  local combo = w(id)
  if not combo or not combo.getCurrentOption then return fallback or 1 end
  local opt = combo:getCurrentOption()
  return (opt and tonumber(opt.data)) or fallback or 1
end

function wireCombos()
  if not helperWindow then return end
  local counts = {}
  for i = 1, 8 do counts[i] = i .. '+' end
  for i = 1, 5 do
    fillCombo('atk' .. i .. 'Mobs', counts)
    fillCombo('atk' .. i .. 'Prio', ORDINALS)
  end
  fillCombo('runeMobs', counts)
  fillCombo('runePrio', ORDINALS)
end

function wireSlots()
  if not helperWindow then return end
  for _, id in ipairs(SLOT_IDS) do
    local slot = w(id)
    if slot then
      slot:setDraggable(false)
      slot.onDrop = function(self, draggedWidget)
        local thing = draggedWidget and draggedWidget.currentDragThing
        if not thing or not thing.getId then return false end
        setSlot(id, thing:getId())
        return true
      end
      slot.onMouseRelease = function(self, _, mouseButton)
        if mouseButton == MouseRightButton then
          setSlot(id, 0)
          return true
        end
        return false
      end
    end
  end
end

function populateUI()
  if not helperWindow then return end

  setChecked('enableBox', config.enabled)
  setChecked('autoHasteBox', config.autoHaste)
  setChecked('hastePzBox', config.hastePz)
  setText('hasteWords', config.hasteWords or '')
  setSlot('hasteSlot', config.hasteItem)
  setChecked('autoEatBox', config.autoEat)
  setText('foodItem', config.foodItem or 0)
  setChecked('changeGoldBox', config.changeGold)
  setChecked('autoReconnectBox', config.autoReconnect)
  setChecked('comboOrderBox', config.comboOrder)
  setChecked('hotkeyPriorityBox', config.hotkeyPriority)
  setSlot('stance1Slot', config.stance.item1)
  setSlot('stance2Slot', config.stance.item2)

  for i = 1, #config.heals do
    local h = config.heals[i]
    setText('heal' .. i .. 'Words', h.words or '')
    setStepper('heal' .. i .. 'Hp', h.hp or 0)
    setChecked('heal' .. i .. 'Box', h.enabled)
    setSlot('heal' .. i .. 'Slot', h.item)
  end

  local potStepper = { 'pot1Hp', 'pot2Hp', 'pot3Mana' }
  for i, p in ipairs(config.potions) do
    setSlot('pot' .. i .. 'Slot', p.item)
    setStepper(potStepper[i], p.pct or 0)
    setChecked('pot' .. i .. 'Box', p.enabled)
  end

  setChecked('manaTrainBox', config.manaTrain.enabled)
  setText('manaTrainWords', config.manaTrain.words or '')
  setStepper('manaTrainPct', config.manaTrain.pct or 100)
  setSlot('manaTrainSlot', config.manaTrain.item)

  setChecked('exTrainBox', config.exTrain.enabled)
  setSlot('exTrainSlot', config.exTrain.item)

  for i = 1, #config.attacks do
    local a = config.attacks[i]
    setText('atk' .. i .. 'Words', a.words or '')
    setStepper('atk' .. i .. 'Mana', a.mana or 0)
    setCombo('atk' .. i .. 'Mobs', a.mobs or 1)
    setCombo('atk' .. i .. 'Prio', a.prio or i)
    setChecked('atk' .. i .. 'Box', a.enabled)
    setSlot('atk' .. i .. 'Slot', a.item)
  end

  setChecked('shooterBox', config.shooter)
  setChecked('autoTargetBox', config.autoTarget)
  setSlot('runeSlot', config.rune.item)
  setCombo('runeMobs', config.rune.mobs or 1)
  setCombo('runePrio', config.rune.prio or 1)
  setChecked('runeBox', config.rune.enabled)

  refreshStatus()
end

local function num(id)
  return tonumber(getText(id)) or 0
end

function saveFromUI()
  if not helperWindow then return end

  config.enabled   = isChecked('enableBox')
  config.autoHaste = isChecked('autoHasteBox')
  config.hastePz   = isChecked('hastePzBox')
  config.hasteWords = getText('hasteWords')
  config.hasteItem = getSlot('hasteSlot', config.hasteItem)
  config.autoEat   = isChecked('autoEatBox')
  config.foodItem  = num('foodItem')
  config.changeGold = isChecked('changeGoldBox')
  config.autoReconnect = isChecked('autoReconnectBox')
  config.comboOrder = isChecked('comboOrderBox')
  config.hotkeyPriority = isChecked('hotkeyPriorityBox')
  config.stance.item1 = getSlot('stance1Slot', config.stance.item1)
  config.stance.item2 = getSlot('stance2Slot', config.stance.item2)

  for i = 1, #config.heals do
    config.heals[i].words   = getText('heal' .. i .. 'Words')
    config.heals[i].hp      = getStepper('heal' .. i .. 'Hp', config.heals[i].hp)
    config.heals[i].enabled = isChecked('heal' .. i .. 'Box')
    config.heals[i].item    = getSlot('heal' .. i .. 'Slot', config.heals[i].item)
  end

  local potStepperIds = { 'pot1Hp', 'pot2Hp', 'pot3Mana' }
  for i, p in ipairs(config.potions) do
    p.item    = getSlot('pot' .. i .. 'Slot', p.item)
    p.pct     = getStepper(potStepperIds[i], p.pct)
    p.enabled = isChecked('pot' .. i .. 'Box')
  end

  config.manaTrain.enabled = isChecked('manaTrainBox')
  config.manaTrain.words   = getText('manaTrainWords')
  config.manaTrain.pct     = getStepper('manaTrainPct', config.manaTrain.pct)
  config.manaTrain.item    = getSlot('manaTrainSlot', config.manaTrain.item)

  config.exTrain.enabled = isChecked('exTrainBox')
  config.exTrain.item    = getSlot('exTrainSlot', config.exTrain.item)

  for i = 1, #config.attacks do
    config.attacks[i].words   = getText('atk' .. i .. 'Words')
    config.attacks[i].mana    = getStepper('atk' .. i .. 'Mana', config.attacks[i].mana)
    config.attacks[i].mobs    = getCombo('atk' .. i .. 'Mobs', config.attacks[i].mobs)
    config.attacks[i].prio    = getCombo('atk' .. i .. 'Prio', config.attacks[i].prio)
    config.attacks[i].enabled = isChecked('atk' .. i .. 'Box')
    config.attacks[i].item    = getSlot('atk' .. i .. 'Slot', config.attacks[i].item)
  end

  config.shooter    = isChecked('shooterBox')
  config.autoTarget = isChecked('autoTargetBox')
  config.rune.item    = getSlot('runeSlot', config.rune.item)
  config.rune.mobs    = getCombo('runeMobs', config.rune.mobs)
  config.rune.prio    = getCombo('runePrio', config.rune.prio)
  config.rune.enabled = isChecked('runeBox')

  saveConfig()
  applyHotkeys()
  refreshStatus()
end

-- ---------------------------------------------------------------------------
-- presets
-- ---------------------------------------------------------------------------
function refreshPresetCombo()
  local combo = w('presetCombo')
  if not combo or not combo.clearOptions then return end
  combo:clearOptions()
  for _, name in ipairs(presetNames()) do
    combo:addOption(name)
  end
  if combo.setCurrentOption then combo:setCurrentOption(currentPreset, true) end
  combo.onOptionChange = function(_, text)
    if text and text ~= currentPreset then loadPreset(text) end
  end
end

function loadPreset(name)
  local presets = g_settings.getNode(PRESETS_KEY)
  if type(presets) == 'table' and type(presets.list) == 'table' and presets.list[name] then
    config = normalizeConfig(presets.list[name])
  else
    config = defaultConfig()
  end
  currentPreset = name
  populateUI()
  applyHotkeys()
  saveConfig()
end

-- displayTextInputBox calls okCallback(unpack(results)) -- the field values
-- only, with no widget argument in front.
function newPreset()
  displayTextInputBox(tr('New Preset'), tr('Preset name:'), function(name)
    if not name or name == '' then return end
    currentPreset = name
    saveConfig()
    refreshPresetCombo()
    refreshStatus()
  end)
end

function renamePreset()
  local old = currentPreset
  displayTextInputBox(tr('Rename Preset'), tr('New name:'), function(name)
    if not name or name == '' or name == old then return end
    local presets = g_settings.getNode(PRESETS_KEY)
    if type(presets) == 'table' and type(presets.list) == 'table' then
      presets.list[old] = nil
      g_settings.setNode(PRESETS_KEY, presets)
    end
    currentPreset = name
    saveConfig()
    refreshPresetCombo()
    refreshStatus()
  end)
end

function deletePreset()
  if currentPreset == 'Default' then
    displayInfoBox(tr('RTC Helper'), tr('The Default preset cannot be deleted.'))
    return
  end
  local presets = g_settings.getNode(PRESETS_KEY)
  if type(presets) == 'table' and type(presets.list) == 'table' then
    presets.list[currentPreset] = nil
    presets.current = 'Default'
    g_settings.setNode(PRESETS_KEY, presets)
    g_settings.save()
  end
  loadPreset('Default')
  refreshPresetCombo()
end

-- ---------------------------------------------------------------------------
-- export / import
-- ---------------------------------------------------------------------------
local function serialize(value, indent)
  indent = indent or ''
  local t = type(value)
  if t == 'table' then
    local parts = { '{\n' }
    local keys = {}
    for k in pairs(value) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local key = type(k) == 'number' and ('[' .. k .. ']') or ('["' .. tostring(k) .. '"]')
      table.insert(parts, indent .. '  ' .. key .. ' = ' ..
        serialize(value[k], indent .. '  ') .. ',\n')
    end
    table.insert(parts, indent .. '}')
    return table.concat(parts)
  elseif t == 'string' then
    return string.format('%q', value)
  end
  return tostring(value)
end

function exportConfig()
  saveFromUI()
  g_window.setClipboardText('return ' .. serialize(config))
  displayInfoBox(tr('RTC Helper'),
    tr('The current preset was copied to your clipboard.'))
end

function importConfig()
  local text = g_window.getClipboardText()
  if not text or text == '' then
    displayErrorBox(tr('RTC Helper'), tr('Your clipboard is empty.'))
    return
  end
  local chunk = loadstring(text)
  if not chunk then
    displayErrorBox(tr('RTC Helper'), tr('The clipboard does not contain a valid preset.'))
    return
  end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= 'table' then
    displayErrorBox(tr('RTC Helper'), tr('The clipboard does not contain a valid preset.'))
    return
  end
  config = normalizeConfig(data)
  populateUI()
  applyHotkeys()
  saveConfig()
  displayInfoBox(tr('RTC Helper'), tr('Preset imported.'))
end

-- ---------------------------------------------------------------------------
-- hotkeys
-- ---------------------------------------------------------------------------
function clearHotkeys()
  if boundHelperKey then g_keyboard.unbindKeyDown(boundHelperKey) boundHelperKey = nil end
  if boundTargetKey then g_keyboard.unbindKeyDown(boundTargetKey) boundTargetKey = nil end
end

function applyHotkeys()
  clearHotkeys()
  if config.helperKey and config.helperKey ~= '' then
    boundHelperKey = config.helperKey
    g_keyboard.bindKeyDown(boundHelperKey, function()
      config.enabled = not config.enabled
      setChecked('enableBox', config.enabled)
      refreshStatus()
      saveConfig()
    end)
  end
  if config.targetKey and config.targetKey ~= '' then
    boundTargetKey = config.targetKey
    g_keyboard.bindKeyDown(boundTargetKey, function()
      config.shooter = not config.shooter
      config.autoTarget = config.shooter
      setChecked('shooterBox', config.shooter)
      setChecked('autoTargetBox', config.autoTarget)
      saveConfig()
    end)
  end
end

local function askKey(title, apply)
  displayTextInputBox(title, tr('Key (for example F5, Ctrl+H). Empty clears it:'),
    function(key)
      apply(key or '')
      saveConfig()
      applyHotkeys()
    end)
end

function setHelperKey()
  askKey(tr('Set Helper Key'), function(k) config.helperKey = k end)
end

function setTargetKey()
  askKey(tr('Set Key (Target / Shooter)'), function(k) config.targetKey = k end)
end

-- ---------------------------------------------------------------------------
-- stats
-- ---------------------------------------------------------------------------
function showStats()
  displayInfoBox(tr('Helper Stats'), table.concat({
    tr('Heal spells cast: %d', stats.heals),
    tr('Potions used: %d', stats.potions),
    tr('Attack spells cast: %d', stats.attacks),
    tr('Runes used: %d', stats.runes),
    tr('Hastes cast: %d', stats.hastes),
    tr('Food eaten: %d', stats.foods),
    tr('Mana training casts: %d', stats.manaTrains),
    tr('Exercise training uses: %d', stats.exTrains),
    tr('Gold exchanges: %d', stats.golds),
  }, '\n'))
end

-- ---------------------------------------------------------------------------
-- engine
-- ---------------------------------------------------------------------------
local function ready(key, now, cooldown)
  local last = actionGate[key]
  if last and (now - last) < cooldown then return false end
  return true
end

local function fire(key, now) actionGate[key] = now end

local function manaPercent(player)
  local maxMana = player:getMaxMana()
  if maxMana <= 0 then return 100 end
  return math.floor((player:getMana() * 100) / maxMana)
end

local function isActive(states, state)
  return Player.isStateActive(states, state)
end

local function monsters(player)
  local pos = player:getPosition()
  local out = {}
  for _, c in ipairs(g_map.getSpectatorsInRange(pos, false, 7, 5)) do
    if c ~= player and c:isMonster() and not c:isDead() then
      table.insert(out, c)
    end
  end
  return out
end

local function nearestMonster(player, list)
  local pos = player:getPosition()
  local best, bestDist
  for _, c in ipairs(list) do
    local cp = c:getPosition()
    local d = math.max(math.abs(cp.x - pos.x), math.abs(cp.y - pos.y))
    if not bestDist or d < bestDist then best, bestDist = c, d end
  end
  return best
end

-- Rows in the order the caster should try them: by the Priority column when
-- "Combo in priority order" is on, otherwise in list order.
local function attackOrder()
  local rows = {}
  for i, a in ipairs(config.attacks) do
    table.insert(rows, { idx = i, row = a })
  end
  if config.comboOrder then
    table.sort(rows, function(x, y)
      return (x.row.prio or x.idx) < (y.row.prio or y.idx)
    end)
  end
  return rows
end

local function runCaster(player, states, now)
  if isActive(states, PlayerStates.Pz) then return end -- never attack in protection zone

  local mobs = monsters(player)

  local target = g_game.getAttackingCreature()
  if target and target:isDead() then target = nil end
  if config.autoTarget and not target and #mobs > 0 then
    target = nearestMonster(player, mobs)
    if target then g_game.attack(target) end
  end

  if not config.shooter then return end
  if not target then return end

  local mana = manaPercent(player)
  local count = #mobs

  -- attack spells: first matching row, one cast per tick
  for _, entry in ipairs(attackOrder()) do
    local a = entry.row
    if a.enabled and a.words ~= '' and mana >= a.mana and count >= a.mobs
        and ready('atk' .. entry.idx, now, TICK_MS) then
      g_game.talk(a.words)
      fire('atk' .. entry.idx, now)
      stats.attacks = stats.attacks + 1
      return
    end
  end

  -- rune on target
  if config.rune.enabled and config.rune.item > 0 and count >= (config.rune.mobs or 1)
      and ready('rune', now, 500) then
    g_game.useInventoryItemWith(config.rune.item, target)
    fire('rune', now)
    stats.runes = stats.runes + 1
  end
end

-- Exchange 100 gold -> platinum -> crystal by using the stacked coin on itself.
-- Player:getItem() cannot be used here: it forwards to g_game.findPlayerItem,
-- which is not bound in this client. Player:getItems() is plain Lua and works.
local GOLD_COIN, PLATINUM_COIN = 3031, 3035
local function runChangeGold(player, now)
  if not ready('gold', now, 2000) then return end
  for _, id in ipairs({ GOLD_COIN, PLATINUM_COIN }) do
    for _, item in ipairs(player:getItems(id)) do
      if item:getCount() >= 100 then
        g_game.useWith(item, item)
        fire('gold', now)
        stats.golds = stats.golds + 1
        return
      end
    end
  end
end

function loop()
  if not config.enabled or not g_game.isOnline() then return end
  local player = g_game.getLocalPlayer()
  if not player or player:isDead() then return end

  local now = g_clock.millis()
  local hp = player:getHealthPercent()
  local states = player:getStates()
  local inPz = isActive(states, PlayerStates.Pz)

  -- 1) spell healing (priority order, one per tick)
  local healed = false
  for i, h in ipairs(config.heals) do
    if h.enabled and h.words ~= '' and hp <= h.hp and ready('heal', now, TICK_MS) then
      g_game.talk(h.words)
      fire('heal', now)
      stats.heals = stats.heals + 1
      healed = true
      break
    end
  end

  -- 2) potions: health rows first (only if a heal spell did not already fire),
  -- then the mana row, each on its own cooldown.
  local mana = manaPercent(player)
  local drankHealth = false
  for i, p in ipairs(config.potions) do
    local isMana = p.kind == 'mana'
    local level = isMana and mana or hp
    local blocked = isMana and false or (healed or drankHealth)
    if p.enabled and p.item > 0 and not blocked and level <= p.pct
        and ready('pot' .. i, now, 1000) then
      g_game.useInventoryItem(p.item)
      fire('pot' .. i, now)
      stats.potions = stats.potions + 1
      if not isMana then drankHealth = true end
    end
  end

  -- 4) auto haste
  if config.autoHaste and config.hasteWords ~= '' and not isActive(states, PlayerStates.Haste) then
    if (not inPz or config.hastePz) and ready('haste', now, 1000) then
      g_game.talk(config.hasteWords)
      fire('haste', now)
      stats.hastes = stats.hastes + 1
    end
  end

  -- 5) auto eat food
  if config.autoEat and config.foodItem > 0 and ready('eat', now, 30000) then
    g_game.useInventoryItem(config.foodItem)
    fire('eat', now)
    stats.foods = stats.foods + 1
  end

  -- 6) change gold
  if config.changeGold then runChangeGold(player, now) end

  -- 7) mana training: only while safe in a protection zone, above the chosen
  -- mana threshold, so it never competes with combat for mana.
  if config.manaTrain.enabled and inPz and config.manaTrain.words ~= ''
      and manaPercent(player) >= (config.manaTrain.pct or 100)
      and ready('manaTrain', now, 2000) then
    g_game.talk(config.manaTrain.words)
    fire('manaTrain', now)
    stats.manaTrains = stats.manaTrains + 1
  end

  -- 8) exercise training: use the exercise weapon on yourself (training dummy
  -- users target the dummy manually; the item handles the rest).
  if config.exTrain.enabled and config.exTrain.item > 0 and inPz
      and ready('exTrain', now, 2000) then
    g_game.useInventoryItemWith(config.exTrain.item, player)
    fire('exTrain', now)
    stats.exTrains = stats.exTrains + 1
  end

  -- 9) attack / shooter / auto target
  runCaster(player, states, now)
end
