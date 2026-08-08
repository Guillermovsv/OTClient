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
  enableBox.onCheckChange = function(_, checked)
    config.enabled = checked
    refreshStatus()
    saveConfig()
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
    helperWindow:recursiveGetChildById('charName'):setText(player:getName())
  end
  refreshStatus()
end

function selectTab(which)
  if not helperWindow then return end
  local healing = which == 'healing'
  helperWindow:recursiveGetChildById('healingPanel'):setVisible(healing)
  helperWindow:recursiveGetChildById('casterPanel'):setVisible(not healing)
  helperWindow:recursiveGetChildById('healingTabBtn'):setOn(healing)
  helperWindow:recursiveGetChildById('casterTabBtn'):setOn(not healing)
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
  local label = helperWindow:getChildById('statusLabel')
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
function loadConfig()
  local saved = g_settings.getNode(SETTINGS_KEY)
  if type(saved) == 'table' then
    -- merge saved over defaults so new fields survive upgrades
    local base = defaultConfig()
    table.merge(base, saved)
    config = base
  else
    config = defaultConfig()
  end
end

function saveConfig()
  g_settings.setNode(SETTINGS_KEY, config)
  g_settings.save()
end

-- ---------------------------------------------------------------------------
-- UI <-> config
-- ---------------------------------------------------------------------------
local function w(id) return helperWindow:recursiveGetChildById(id) end

function populateUI()
  if not helperWindow then return end

  w('enableBox'):setChecked(config.enabled)
  w('autoHasteBox'):setChecked(config.autoHaste)
  w('hastePzBox'):setChecked(config.hastePz)
  w('hasteWords'):setText(config.hasteWords or '')
  w('autoEatBox'):setChecked(config.autoEat)
  w('foodItem'):setText(tostring(config.foodItem or 0))

  for i = 1, 3 do
    w('heal' .. i .. 'Words'):setText(config.heals[i].words or '')
    w('heal' .. i .. 'Hp'):setValue(config.heals[i].hp or 0)
    w('heal' .. i .. 'Box'):setChecked(config.heals[i].enabled)
  end

  w('pot1Item'):setText(tostring(config.potHp.item or 0))
  w('pot1Hp'):setValue(config.potHp.hp or 0)
  w('pot1Box'):setChecked(config.potHp.enabled)
  w('pot2Item'):setText(tostring(config.potMana.item or 0))
  w('pot2Mana'):setValue(config.potMana.mana or 0)
  w('pot2Box'):setChecked(config.potMana.enabled)

  for i = 1, 5 do
    w('atk' .. i .. 'Words'):setText(config.attacks[i].words or '')
    w('atk' .. i .. 'Mana'):setValue(config.attacks[i].mana or 0)
    w('atk' .. i .. 'Mobs'):setValue(config.attacks[i].mobs or 0)
    w('atk' .. i .. 'Box'):setChecked(config.attacks[i].enabled)
  end

  w('shooterBox'):setChecked(config.shooter)
  w('autoTargetBox'):setChecked(config.autoTarget)
  w('runeItem'):setText(tostring(config.rune.item or 0))
  w('runeBox'):setChecked(config.rune.enabled)

  refreshStatus()
end

local function num(id)
  return tonumber(w(id):getText()) or 0
end

function saveFromUI()
  if not helperWindow then return end

  config.enabled   = w('enableBox'):isChecked()
  config.autoHaste = w('autoHasteBox'):isChecked()
  config.hastePz   = w('hastePzBox'):isChecked()
  config.hasteWords = w('hasteWords'):getText()
  config.autoEat   = w('autoEatBox'):isChecked()
  config.foodItem  = num('foodItem')

  for i = 1, 3 do
    config.heals[i].words   = w('heal' .. i .. 'Words'):getText()
    config.heals[i].hp      = w('heal' .. i .. 'Hp'):getValue()
    config.heals[i].enabled = w('heal' .. i .. 'Box'):isChecked()
  end

  config.potHp.item    = num('pot1Item')
  config.potHp.hp      = w('pot1Hp'):getValue()
  config.potHp.enabled = w('pot1Box'):isChecked()
  config.potMana.item    = num('pot2Item')
  config.potMana.mana    = w('pot2Mana'):getValue()
  config.potMana.enabled = w('pot2Box'):isChecked()

  for i = 1, 5 do
    config.attacks[i].words   = w('atk' .. i .. 'Words'):getText()
    config.attacks[i].mana    = w('atk' .. i .. 'Mana'):getValue()
    config.attacks[i].mobs    = w('atk' .. i .. 'Mobs'):getValue()
    config.attacks[i].enabled = w('atk' .. i .. 'Box'):isChecked()
  end

  config.shooter    = w('shooterBox'):isChecked()
  config.autoTarget = w('autoTargetBox'):isChecked()
  config.rune.item    = num('runeItem')
  config.rune.enabled = w('runeBox'):isChecked()

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
