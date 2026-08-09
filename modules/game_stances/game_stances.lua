local STANCE_OPCODE = 232

-- Set to true to log every stance packet; pairs with DEBUG_SPELL_VISUAL in
-- game_stance_spell_visuals for diagnosing the spell recolouring.
local DEBUG_STANCE = false

controllerStances = Controller:new()
local activeStance = nil

local stanceVisuals = {
    blood_rage = {
        name = 'Blood Rage',
        skills = { 'skillId0', 'skillId1', 'skillId2', 'skillId3' },
        tooltip = '+30% Melee skills.\n+15% Damage received.'
    },
    protector = {
        name = 'Protector',
        skills = { 'skillId5' },
        tooltip = '+30% Shielding.\n-15% Damage dealt.\n-15% Damage received.'
    },
    shared_conservation = {
        name = 'Shared Conservation',
        magic = true,
        tooltip = '+10% Healing dealt.'
    },
    elemental_synthesis = {
        name = 'Elemental Synthesis',
        magic = true,
        tooltip = '+10 Ice and Earth Magic level.'
    },
    divine_defiance = {
        name = 'Divine Defiance',
        skills = { 'skillId4' },
        magic = true,
        tooltip = 'Grants 6% of Distance Fighting as holy and healing magic level, as well as 12% Dodge against non adjacent enemies.'
    },
    master_of_flames = {
        name = 'Master of Flames',
        magic = true,
        tooltip = '+4% Fire spell damage.\nThe next non-Fire spell can be converted to Fire.'
    },
    master_of_thunder = {
        name = 'Master of Thunder',
        magic = true,
        tooltip = '+4% Energy critical chance.\nThe next non-Energy spell can be converted to Energy.'
    },
    master_of_decay = {
        name = 'Master of Decay',
        magic = true,
        tooltip = '+30% Death critical extra damage.\nThe next non-Death spell can be converted to Death.'
    }
}

-- game_skills is a sandboxed module, so its helpers are NOT globals here: they
-- live on the module table. Calling them as bare globals raised
-- "attempt to call global 'setSkillColor' (a nil value)" on every stance
-- activation, which meant stance colors and tooltips were never applied.
local function skills()
    return modules.game_skills
end

local function refreshBaseSkills()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local sk = skills()
    if not sk then
        return
    end

    sk.onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    for skill = Skill.Fist, Skill.Transcendence do
        sk.onSkillChange(player, skill, player:getSkillLevel(skill), player:getSkillLevelPercent(skill))
    end
end

-- Every skill any stance can touch. Switching stances has to wipe the previous
-- one's marks first, otherwise the notes from both stances sit on the skills
-- at once and the hover shows an effect the player no longer has.
local function clearStanceMarks()
    local sk = skills()
    if not sk then
        return
    end

    local touched = { magiclevel = true }
    for _, visual in pairs(stanceVisuals) do
        for _, skillId in ipairs(visual.skills or {}) do
            touched[skillId] = true
        end
    end

    for skillId in pairs(touched) do
        sk.setSkillTooltip(skillId, nil)
    end
    refreshBaseSkills()
end

local function applyVisuals()
    local visual = activeStance and stanceVisuals[activeStance]

    -- start from a clean slate every time, so only the active stance is marked
    clearStanceMarks()

    if not visual then
        return
    end

    local sk = skills()
    if not sk then
        return
    end

    if visual.magic then
        sk.setSkillColor('magiclevel', '#008b00')
        sk.setSkillTooltip('magiclevel', visual.name .. ': ' .. visual.tooltip)
    end
    for _, skillId in ipairs(visual.skills or {}) do
        sk.setSkillColor(skillId, '#008b00')
        sk.setSkillTooltip(skillId, visual.name .. ': ' .. visual.tooltip)
    end
end

function refresh()
    if activeStance then
        applyVisuals()
    end
end

-- The stance the server currently reports as active, or nil. Read by the RTC
-- Helper so it can tell whether the stance you picked is already up.
function getActiveStance()
    return activeStance
end

function controllerStances:onInit()
    ProtocolGame.registerExtendedOpcode(STANCE_OPCODE, function(protocol, opcode, buffer)
        -- Diagnostic for the stance channel, paired with the one in
        -- game_stance_spell_visuals. Flip DEBUG_STANCE to true to see the
        -- stance packets arriving while chasing a silent spell recolour.
        if DEBUG_STANCE then
            g_logger.info('[STANCE] opcode ' .. tostring(opcode) .. ' payload ' .. tostring(buffer))
        end
        local state, stanceId = buffer:match('^(%a+)|(.+)$')
        if buffer == 'inactive|' then
            state = 'inactive'
            stanceId = ''
        end
        if state == 'active' and stanceVisuals[stanceId] then
            if activeStance ~= stanceId and modules.game_stance_spell_visuals then
                modules.game_stance_spell_visuals.clear()
            end
            activeStance = stanceId
            applyVisuals()
        elseif state == 'inactive' then
            activeStance = nil
            if modules.game_stance_spell_visuals then
                modules.game_stance_spell_visuals.clear()
            end
            refreshBaseSkills()
        end
    end)
end

function controllerStances:onTerminate()
    ProtocolGame.unregisterExtendedOpcode(STANCE_OPCODE)
    activeStance = nil
end
