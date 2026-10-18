local _, FW = ...

-- Stable keys keep profile metadata independent from the client's locale.
-- Icons are Blizzard textures; profile artwork remains a separate setting.
local choices, byKey, trees = {}, {}, {}
local function add(key, label, icon, meleeShare, class, tree, group)
    local entry = {key=key, label=label, icon="Interface\\Icons\\" .. icon,
        meleeShare=meleeShare, class=class, group=group}
    choices[#choices + 1], byKey[key] = entry, entry
    if tree then
        trees[class] = trees[class] or {}
        trees[class][tree] = key
    end
end
local function class(key, label, icon, share)
    add(key, label, icon, share, key)
end
local function spec(classKey, key, label, icon, share, tree)
    add(classKey .. "_" .. key, byKey[classKey].label .. ": " .. label, icon, share, classKey, tree)
end

add("any", "Any", "INV_Misc_QuestionMark", 0.5, nil, nil, true)
add("physical", "Physical", "Ability_MeleeDamage", 1, nil, nil, true)
add("caster", "Caster", "Spell_Fire_FireBolt02", 0, nil, nil, true)
add("healer", "Healer", "Spell_Holy_FlashHeal", 0, nil, nil, true)
class("WARRIOR", "Warrior", "ClassIcon_Warrior", 1)
spec("WARRIOR", "ARMS", "Arms", "Ability_Warrior_SavageBlow", 1, 1)
spec("WARRIOR", "FURY", "Fury", "Ability_Warrior_InnerRage", 1, 2)
spec("WARRIOR", "PROTECTION", "Protection", "Ability_Warrior_DefensiveStance", 1, 3)
class("PALADIN", "Paladin", "ClassIcon_Paladin", 0.5)
spec("PALADIN", "HOLY", "Holy", "Spell_Holy_HolyBolt", 1, 1)
spec("PALADIN", "PROTECTION", "Protection", "Spell_Holy_DevotionAura", 0.5, 2)
spec("PALADIN", "RETRIBUTION", "Retribution", "Spell_Holy_AuraOfLight", 1, 3)
spec("PALADIN", "SHOCKADIN", "Shockadin (Holy / Retribution)", "Spell_Holy_SearingLight", 0.7)
class("HUNTER", "Hunter", "ClassIcon_Hunter", 1)
spec("HUNTER", "BEASTMASTERY", "Beast Mastery", "Ability_Hunter_BeastTaming", 1, 1)
spec("HUNTER", "MARKSMANSHIP", "Marksmanship", "Ability_Marksmanship", 1, 2)
spec("HUNTER", "SURVIVAL", "Survival", "Ability_Hunter_SwiftStrike", 1, 3)
class("ROGUE", "Rogue", "ClassIcon_Rogue", 1)
spec("ROGUE", "ASSASSINATION", "Assassination", "Ability_Rogue_Eviscerate", 1, 1)
spec("ROGUE", "COMBAT", "Combat", "Ability_BackStab", 1, 2)
spec("ROGUE", "SUBTLETY", "Subtlety", "Ability_Stealth", 1, 3)
class("PRIEST", "Priest", "ClassIcon_Priest", 0)
spec("PRIEST", "DISCIPLINE", "Discipline", "Spell_Holy_WordFortitude", 0, 1)
spec("PRIEST", "HOLY", "Holy", "Spell_Holy_GuardianSpirit", 0, 2)
spec("PRIEST", "SHADOW", "Shadow", "Spell_Shadow_ShadowWordPain", 0, 3)
class("SHAMAN", "Shaman", "ClassIcon_Shaman", 0.5)
spec("SHAMAN", "ELEMENTAL", "Elemental", "Spell_Nature_Lightning", 0, 1)
spec("SHAMAN", "ENHANCEMENT", "Enhancement", "Spell_Nature_LightningShield", 0.5, 2)
spec("SHAMAN", "RESTORATION", "Restoration", "Spell_Nature_MagicImmunity", 0, 3)
class("MAGE", "Mage", "ClassIcon_Mage", 0)
spec("MAGE", "ARCANE", "Arcane", "Spell_Holy_MagicalSentry", 0, 1)
spec("MAGE", "FIRE", "Fire", "Spell_Fire_FireBolt02", 0, 2)
spec("MAGE", "FROST", "Frost", "Spell_Frost_FrostBolt02", 0, 3)
class("WARLOCK", "Warlock", "ClassIcon_Warlock", 0)
spec("WARLOCK", "AFFLICTION", "Affliction", "Spell_Shadow_DeathCoil", 0, 1)
spec("WARLOCK", "DEMONOLOGY", "Demonology", "Spell_Shadow_Metamorphosis", 0, 2)
spec("WARLOCK", "DESTRUCTION", "Destruction", "Spell_Shadow_RainOfFire", 0, 3)
class("DRUID", "Druid", "ClassIcon_Druid", 0.5)
spec("DRUID", "BALANCE", "Balance", "Spell_Nature_StarFall", 0, 1)
spec("DRUID", "FERAL", "Feral", "Ability_Racial_BearForm", 1, 2)
spec("DRUID", "RESTORATION", "Restoration", "Spell_Nature_HealingTouch", 0, 3)

FW.ProfileClassChoices = choices

function FW:GetProfileClass(key)
    if issecretvalue and issecretvalue(key) then return nil end
    return type(key) == "string" and byKey[key] or nil
end

local unpack = unpack or table.unpack
local function pack(...) return {n=select("#", ...), ...} end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local result = pack(pcall(fn, ...))
    if result[1] then return unpack(result, 2, result.n) end
end
local function finite(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "number"
        and value == value and value ~= math.huge and value ~= -math.huge
end

local function readableTable(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "table"
end

local function currentTreePoints(activeGroup)
    -- Camelot has one class-wide trait tree. Its three branches are node
    -- groups, not three specialization IDs. Follow RefreshTreeHeaders and
    -- ClassTalentTreeHeaderMixin:Setup in Blizzard's actual Forever UI.
    -- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua
    local config = call(C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup, activeGroup)
    if not finite(config) then config = call(C_ClassTalents and C_ClassTalents.GetActiveConfigID) end
    if not finite(config) then return end
    local configInfo = call(C_Traits and C_Traits.GetConfigInfo, config)
    if not readableTable(configInfo) or not readableTable(configInfo.treeIDs) then return end
    local treeID = configInfo.treeIDs[1]
    if not finite(treeID) then return end
    local displayInfos = call(C_Traits and C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if not readableTable(displayInfos) or #displayInfos ~= 3 then return end
    local branches, orderSeen, sortable = {}, {}, true
    for index, info in ipairs(displayInfos) do
        if not readableTable(info) or not finite(info.groupID) then return end
        branches[index] = info
        if not finite(info.orderIndex) or orderSeen[info.orderIndex] then sortable = false
        else orderSeen[info.orderIndex] = true end
    end
    -- Preserve the API-owned list. Explicit order metadata also handles a
    -- shuffled return list and does not assume indices start at zero or one.
    if sortable then table.sort(branches, function(left, right) return left.orderIndex < right.orderIndex end) end
    local groupIDs, groupSeen = {}, {}
    for index, info in ipairs(branches) do
        if groupSeen[info.groupID] then return end
        groupIDs[index], groupSeen[info.groupID] = info.groupID, true
    end
    local groupInfos = call(C_Traits and C_Traits.GetGroupCurrencyInfo, config, groupIDs)
    if not readableTable(groupInfos) then return end
    local points = {}
    for index, groupID in ipairs(groupIDs) do
        for _, info in ipairs(groupInfos) do
            if readableTable(info) and finite(info.traitNodeGroupID) and info.traitNodeGroupID == groupID
                and readableTable(info.currencyInfos) and readableTable(info.currencyInfos[1]) then
                local spent = info.currencyInfos[1].spent
                if finite(spent) and spent >= 0 then points[index] = spent end
            end
        end
        if points[index] == nil then return end
    end
    return points
end

local function legacyTreePoints(activeGroup)
    local points = {}
    for index = 1, 3 do
    -- Legacy Classic clients have either a specID/name/... tuple (points at
    -- 5) or a name/icon/points tuple. Old tuples may have trailing background
    -- and preview values, so return count cannot distinguish their shapes.
        local result = pack(call(GetTalentTabInfo, index, false, false, activeGroup))
        local firstIsName = (not issecretvalue or not issecretvalue(result[1])) and type(result[1]) == "string"
        local spent = firstIsName and result[3] or result[5]
        if not finite(spent) or spent < 0 then return end
        points[index] = spent
    end
    return points
end

function FW:GetDefaultProfileClass()
    local _, playerClass = call(UnitClass, "player")
    if not self:GetProfileClass(playerClass) or not trees[playerClass] then return "any" end
    local group = call(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup)
    if not finite(group) then group = call(GetActiveTalentGroup) end
    if not finite(group) then group = 1 end
    local treePoints = currentTreePoints(group) or legacyTreePoints(group)
    if not treePoints then return playerClass end
    local total, best, second, winner = 0, -1, -1
    for index = 1, 3 do
        local points = treePoints[index]
        total = total + points
        if points > best then second, best, winner = best, points, index
        elseif points > second then second = points end
    end
    if total >= 10 and best >= total * 0.6 and best - second >= 5 then
        return trees[playerClass][winner]
    end
    return playerClass
end
