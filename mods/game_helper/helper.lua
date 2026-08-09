-- RTC Helper
-- Standalone in-client healing & attack assistant. It intentionally does NOT use
-- game_bot / vBot / cavebot; it drives the plain game actions directly
-- (g_game.talk / useInventoryItem / useWith / attack) from a simple settings UI.

helperWindow = nil
local helperButton = nil
local loopEvent = nil
local actionGate = {}

local SETTINGS_KEY = 'RTCHelper'
local TICK_MS = 200

local function defaultConfig()
  return {
    enabled = false,
    autoHaste = false, hastePz = false, hasteWords = 'utani hur',
    autoEat = false, foodItem = 3725,
    heals = {
      { enabled = false, words = '', hp = 80 },
      { enabled = false, words = '', hp = 60 },
      { enabled = false, words = '', hp = 40 },
    },
    potHp   = { enabled = false, item = 0, hp = 50 },
    potMana = { enabled = false, item = 0, mana = 40 },
    attacks = {
      { enabled = false, words = '', mana = 20, mobs = 1 },
      { enabled = false, words = '', mana = 20, mobs = 1 },
      { enabled = false, words = '', mana = 20, mobs = 1 },
      { enabled = false, words = '', mana = 20, mobs = 1 },
      { enabled = false, words = '', mana = 20, mobs = 1 },
    },
    shooter = false, autoTarget = false, rune = { enabled = false, item = 0 },
  }
end

local config = defaultConfig()

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
  populateUI()
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

  loopEvent = cycleEvent(loop, TICK_MS)

  if g_game.isOnline() then onGameStart() end
end

function terminate()
  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  if loopEvent then loopEvent:cancel() loopEvent = nil end
  if helperButton then helperButton:destroy() helperButton = nil end
  if helperWindow then helperWindow:destroy() helperWindow = nil end
end

function onGameStart()
  local player = g_game.getLocalPlayer()
  if player and helperWindow then
    local name = helperWindow:recursiveGetChildById('charName')
    if name then name:setText(player:getName()) end
  end
  refreshStatus()
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
end

function onGameEnd()
  if helperWindow then helperWindow:hide() end
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
end

-- ---------------------------------------------------------------------------
-- persistence
-- ---------------------------------------------------------------------------
-- g_settings round-trips tables through a string-keyed representation, so a
-- saved array comes back as { ["1"] = {...} } and config.heals[1] is nil. That
-- crashed populateUI on the next start ("attempt to index a nil value") and
-- took the whole module down with it. Rebuild every row list with real numeric
-- indices, padded to the length the UI expects and merged over the defaults.
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

function loadConfig()
  local base = defaultConfig()
  local saved = g_settings.getNode(SETTINGS_KEY)
  if type(saved) ~= 'table' then
    config = base
    return
  end

  for _, key in ipairs({ 'enabled', 'autoHaste', 'hastePz', 'hasteWords',
                         'autoEat', 'foodItem', 'shooter', 'autoTarget' }) do
    if saved[key] ~= nil then base[key] = saved[key] end
  end

  base.heals   = normalizeRows(saved.heals, base.heals)
  base.attacks = normalizeRows(saved.attacks, base.attacks)
  base.potHp   = normalizeGroup(saved.potHp, base.potHp)
  base.potMana = normalizeGroup(saved.potMana, base.potMana)
  base.rune    = normalizeGroup(saved.rune, base.rune)

  config = base
end

function saveConfig()
  g_settings.setNode(SETTINGS_KEY, config)
  g_settings.save()
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
local function setValue(id, v)
  local x = w(id); if x and x.setValue then x:setValue(tonumber(v) or 0) end
end
local function setChecked(id, v)
  local x = w(id); if x and x.setChecked then x:setChecked(v and true or false) end
end
local function getText(id)
  local x = w(id); return x and x:getText() or ''
end
local function getValue(id, fallback)
  local x = w(id)
  if x and x.getValue then return x:getValue() end
  return fallback or 0
end
local function isChecked(id)
  local x = w(id); return (x and x.isChecked and x:isChecked()) and true or false
end

function populateUI()
  if not helperWindow then return end

  setChecked('enableBox', config.enabled)
  setChecked('autoHasteBox', config.autoHaste)
  setChecked('hastePzBox', config.hastePz)
  setText('hasteWords', config.hasteWords or '')
  setChecked('autoEatBox', config.autoEat)
  setText('foodItem', config.foodItem or 0)

  for i = 1, #config.heals do
    local h = config.heals[i]
    setText('heal' .. i .. 'Words', h.words or '')
    setValue('heal' .. i .. 'Hp', h.hp or 0)
    setChecked('heal' .. i .. 'Box', h.enabled)
  end

  setText('pot1Item', config.potHp.item or 0)
  setValue('pot1Hp', config.potHp.hp or 0)
  setChecked('pot1Box', config.potHp.enabled)
  setText('pot2Item', config.potMana.item or 0)
  setValue('pot2Mana', config.potMana.mana or 0)
  setChecked('pot2Box', config.potMana.enabled)

  for i = 1, #config.attacks do
    local a = config.attacks[i]
    setText('atk' .. i .. 'Words', a.words or '')
    setValue('atk' .. i .. 'Mana', a.mana or 0)
    setValue('atk' .. i .. 'Mobs', a.mobs or 0)
    setChecked('atk' .. i .. 'Box', a.enabled)
  end

  setChecked('shooterBox', config.shooter)
  setChecked('autoTargetBox', config.autoTarget)
  setText('runeItem', config.rune.item or 0)
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
  config.autoEat   = isChecked('autoEatBox')
  config.foodItem  = num('foodItem')

  for i = 1, #config.heals do
    config.heals[i].words   = getText('heal' .. i .. 'Words')
    config.heals[i].hp      = getValue('heal' .. i .. 'Hp', config.heals[i].hp)
    config.heals[i].enabled = isChecked('heal' .. i .. 'Box')
  end

  config.potHp.item    = num('pot1Item')
  config.potHp.hp      = getValue('pot1Hp', config.potHp.hp)
  config.potHp.enabled = isChecked('pot1Box')
  config.potMana.item    = num('pot2Item')
  config.potMana.mana    = getValue('pot2Mana', config.potMana.mana)
  config.potMana.enabled = isChecked('pot2Box')

  for i = 1, #config.attacks do
    config.attacks[i].words   = getText('atk' .. i .. 'Words')
    config.attacks[i].mana    = getValue('atk' .. i .. 'Mana', config.attacks[i].mana)
    config.attacks[i].mobs    = getValue('atk' .. i .. 'Mobs', config.attacks[i].mobs)
    config.attacks[i].enabled = isChecked('atk' .. i .. 'Box')
  end

  config.shooter    = isChecked('shooterBox')
  config.autoTarget = isChecked('autoTargetBox')
  config.rune.item    = num('runeItem')
  config.rune.enabled = isChecked('runeBox')

  saveConfig()
  refreshStatus()
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

  -- attack spells: first matching row in priority order, one cast per tick
  for i, a in ipairs(config.attacks) do
    if a.enabled and a.words ~= '' and mana >= a.mana and count >= a.mobs
        and ready('atk' .. i, now, TICK_MS) then
      g_game.talk(a.words)
      fire('atk' .. i, now)
      return
    end
  end

  -- rune on target
  if config.rune.enabled and config.rune.item > 0 and ready('rune', now, 500) then
    g_game.useInventoryItemWith(config.rune.item, target)
    fire('rune', now)
  end
end

function loop()
  if not config.enabled or not g_game.isOnline() then return end
  local player = g_game.getLocalPlayer()
  if not player or player:isDead() then return end

  local now = g_clock.millis()
  local hp = player:getHealthPercent()
  local states = player:getStates()

  -- 1) spell healing (priority order, one per tick)
  local healed = false
  for i, h in ipairs(config.heals) do
    if h.enabled and h.words ~= '' and hp <= h.hp and ready('heal', now, TICK_MS) then
      g_game.talk(h.words)
      fire('heal', now)
      healed = true
      break
    end
  end

  -- 2) potion healing (HP)
  if not healed and config.potHp.enabled and config.potHp.item > 0
      and hp <= config.potHp.hp and ready('potHp', now, 1000) then
    g_game.useInventoryItem(config.potHp.item)
    fire('potHp', now)
  end

  -- 3) mana potion
  if config.potMana.enabled and config.potMana.item > 0
      and manaPercent(player) <= config.potMana.mana and ready('potMana', now, 1000) then
    g_game.useInventoryItem(config.potMana.item)
    fire('potMana', now)
  end

  -- 4) auto haste
  if config.autoHaste and config.hasteWords ~= '' and not isActive(states, PlayerStates.Haste) then
    local inPz = isActive(states, PlayerStates.Pz)
    if (not inPz or config.hastePz) and ready('haste', now, 1000) then
      g_game.talk(config.hasteWords)
      fire('haste', now)
    end
  end

  -- 5) auto eat food
  if config.autoEat and config.foodItem > 0 and ready('eat', now, 30000) then
    g_game.useInventoryItem(config.foodItem)
    fire('eat', now)
  end

  -- 6) attack / shooter / auto target
  runCaster(player, states, now)
end
