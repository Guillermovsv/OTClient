local STANCE_OPCODE = 232

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
        tooltip = '+10 Earth element damage.\n+10 Ice element damage.'
    },
    divine_defiance = {
        name = 'Divine Defiance',
        skills = { 'skillId4' },
        magic = true,
        tooltip = 'Distance power contributes to Holy Magic.\nDistance power contributes to Healing Magic.\nDodge chance is increased.'
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

local function refreshBaseSkills()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    for skill = Skill.Fist, Skill.Transcendence do
        onSkillChange(player, skill, player:getSkillLevel(skill), player:getSkillLevelPercent(skill))
    end
end

local function applyVisuals()
    local visual = activeStance and stanceVisuals[activeStance]
    if not visual then
        refreshBaseSkills()
        return
    end

    if visual.magic then
        setSkillColor('magiclevel', '#008b00')
        setSkillTooltip('magiclevel', visual.name .. ': ' .. visual.tooltip)
    end
    for _, skillId in ipairs(visual.skills or {}) do
        setSkillColor(skillId, '#008b00')
        setSkillTooltip(skillId, visual.name .. ': ' .. visual.tooltip)
    end
end

function refresh()
    if activeStance then
        applyVisuals()
    end
end

function controllerStances:onInit()
    ProtocolGame.registerExtendedOpcode(STANCE_OPCODE, function(protocol, opcode, buffer)
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
