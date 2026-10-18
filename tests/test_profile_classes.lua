-- Run from the addon directory: luatex --luaonly tests/test_profile_classes.lua .
local addonPath = (arg and arg[1]) or "."
local FW, passed = {}, 0
for _, file in ipairs({"JSON.lua", "Stats.lua", "ProfileClasses.lua", "Core.lua"}) do
    assert(loadfile(addonPath .. "/" .. file))("ZwykValues", FW)
end
local function check(value, message) assert(value, message or "assertion failed"); passed = passed + 1 end
local function equal(actual, expected, message)
    check(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, message) check(math.abs(actual - expected) < 0.000000001, message) end
local playerClass = "PALADIN"
UnitClass = function(unit) equal(unit, "player"); return playerClass, playerClass end

local catalog = {
    any=.5,physical=1,caster=0,healer=0,
    WARRIOR=1,WARRIOR_ARMS=1,WARRIOR_FURY=1,WARRIOR_PROTECTION=1,
    PALADIN=.5,PALADIN_HOLY=1,PALADIN_PROTECTION=.5,PALADIN_RETRIBUTION=1,PALADIN_SHOCKADIN=.7,
    HUNTER=1,HUNTER_BEASTMASTERY=1,HUNTER_MARKSMANSHIP=1,HUNTER_SURVIVAL=1,
    ROGUE=1,ROGUE_ASSASSINATION=1,ROGUE_COMBAT=1,ROGUE_SUBTLETY=1,
    PRIEST=0,PRIEST_DISCIPLINE=0,PRIEST_HOLY=0,PRIEST_SHADOW=0,
    SHAMAN=.5,SHAMAN_ELEMENTAL=0,SHAMAN_ENHANCEMENT=.5,SHAMAN_RESTORATION=0,
    MAGE=0,MAGE_ARCANE=0,MAGE_FIRE=0,MAGE_FROST=0,
    WARLOCK=0,WARLOCK_AFFLICTION=0,WARLOCK_DEMONOLOGY=0,WARLOCK_DESTRUCTION=0,
    DRUID=.5,DRUID_BALANCE=0,DRUID_FERAL=1,DRUID_RESTORATION=0,
}
local count, seen = 0, {}
for _, choice in ipairs(FW.ProfileClassChoices) do
    check(not seen[choice.key], "class choices must have unique keys")
    seen[choice.key], count = true, count + 1
    equal(FW:GetProfileClass(choice.key), choice)
    equal(choice.meleeShare, catalog[choice.key], "class/spec default")
    check(type(choice.label) == "string" and #choice.label > 0)
    check(choice.icon:match("^Interface\\Icons\\"), "use a native game texture")
end
local expectedCount = 0
for key in pairs(catalog) do expectedCount = expectedCount + 1; check(seen[key], "missing class choice " .. key) end
equal(count, expectedCount)
equal(FW:GetProfileClass("DEATHKNIGHT"), nil)
equal(FW:GetProfileClass({}), nil)
equal(FW:GetDefaultProfileClass(), "PALADIN", "talent data not ready: retain class")
playerClass = "DEMONHUNTER"
equal(FW:GetDefaultProfileClass(), "any")
playerClass = "PALADIN"

-- Match Forever's actual class-wide tree / group-currency API. Currency
-- results deliberately arrive in another order than the visible branches.
local points, activeGroup = {0, 0, 31}, 2
C_SpecializationInfo = {
    GetActiveSpecGroup = function() return activeGroup end,
    GetCombatConfigIDForSpecGroup = function(group) equal(group, activeGroup); return 912 end,
    -- Camelot's specialization index is not the three branch indices.
    GetSpecializationInfo = function() error("Do not treat three branches as three specs") end,
}
C_Traits = {
    GetConfigInfo = function(config) equal(config, 912); return {treeIDs={777}} end,
    GetGroupDisplayInfoByTreeID = function(tree)
        equal(tree, 777)
        return {{groupID=301,orderIndex=0},{groupID=302,orderIndex=1},{groupID=303,orderIndex=2}}
    end,
    GetGroupCurrencyInfo = function(config, groupIDs)
        equal(config, 912); equal(groupIDs[1], 301); equal(groupIDs[3], 303)
        return {{traitNodeGroupID=303,currencyInfos={{spent=points[3]}}},
            {traitNodeGroupID=301,currencyInfos={{spent=points[1]}}},
            {traitNodeGroupID=302,currencyInfos={{spent=points[2]}}}}
    end,
}
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "native group points select Ret")
local displayInfo = C_Traits.GetGroupDisplayInfoByTreeID
local shuffled = {{groupID=303,orderIndex=2},{groupID=301,orderIndex=0},{groupID=302,orderIndex=1}}
C_Traits.GetGroupDisplayInfoByTreeID = function() return shuffled end
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "branch order follows explicit orderIndex")
equal(shuffled[1].groupID, 303, "sorting must not mutate the API-owned display list")
C_Traits.GetGroupDisplayInfoByTreeID = displayInfo
points = {10,0,0}; equal(FW:GetDefaultProfileClass(), "PALADIN_HOLY", "enough clearly focused talents")
points = {9,0,0}; equal(FW:GetDefaultProfileClass(), "PALADIN", "too few talent points to classify")
points = {12,10,0}; equal(FW:GetDefaultProfileClass(), "PALADIN", "ambiguous branch split")
points = {12,8,0}; equal(FW:GetDefaultProfileClass(), "PALADIN", "insufficient leading margin")
points = {15,10,0}; equal(FW:GetDefaultProfileClass(), "PALADIN_HOLY", "exact 60 percent / 5 point threshold")
points = {0,25,0}; equal(FW:GetDefaultProfileClass(), "PALADIN_PROTECTION")
playerClass = "DRUID"
points = {0,31,0}; equal(FW:GetDefaultProfileClass(), "DRUID_FERAL")
playerClass = "SHAMAN"
points = {0,0,31}; equal(FW:GetDefaultProfileClass(), "SHAMAN_RESTORATION")
playerClass = "PALADIN"
local currencyInfo = C_Traits.GetGroupCurrencyInfo
C_Traits.GetGroupCurrencyInfo = function() return {} end
equal(FW:GetDefaultProfileClass(), "PALADIN", "incomplete native data has a safe class fallback")
C_Traits.GetGroupCurrencyInfo = currencyInfo
local configByGroup = C_SpecializationInfo.GetCombatConfigIDForSpecGroup
C_SpecializationInfo.GetCombatConfigIDForSpecGroup = function() return nil end
C_ClassTalents = {GetActiveConfigID=function() return 912 end}
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "active config compatibility API")
C_ClassTalents = nil
C_SpecializationInfo.GetCombatConfigIDForSpecGroup = configByGroup

-- Both documented Classic legacy tuples remain usable without modern traits.
C_Traits = nil
GetTalentTabInfo = function(index, inspect, pet, group)
    equal(inspect, false); equal(pet, false); equal(group, activeGroup)
    return index, "Tab " .. index, "Description", 135943, points[index], "background", 50, true
end
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "use committed points, not preview")
GetTalentTabInfo = function(index) return "Tab " .. index, "Icon", points[index] end
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "original Classic three-return tuple")
GetTalentTabInfo = function(index) return "Tab " .. index, "Icon", points[index], "Background", 999 end
equal(FW:GetDefaultProfileClass(), "PALADIN_RETRIBUTION", "legacy trailing preview does not replace committed points")
GetTalentTabInfo = function() error("not available") end
equal(FW:GetDefaultProfileClass(), "PALADIN", "API errors do not break profile creation")
local secretClass = {}
issecretvalue = function(value) return value == secretClass end
UnitClass = function() return "Unavailable", secretClass end
equal(FW:GetDefaultProfileClass(), "any", "never inspect a secret class")
issecretvalue = nil
UnitClass = function() return playerClass, playerClass end
GetTalentTabInfo = function(index) return "Tab " .. index, "Icon", points[index] end

ZwykValuesDB, ZwykPointsDB, ForeverWeightsDB, FW.DB = nil, nil, nil, nil
FW:Initialize()
local initial = FW:GetProfiles()[1]
equal(initial.classSpec, "PALADIN_RETRIBUTION")
equal(initial.critMeleeShare, 1, "zero weights remember a meaningful default")
local generic = assert(FW:CreateProfile("Ret", {crit=10}))
equal(generic.weights.meleeCrit, 10); equal(generic.weights.spellCrit, 0)
local custom = assert(FW:CreateProfile("Shockadin", {crit=10}, {classSpec="PALADIN_SHOCKADIN"}))
equal(custom.classSpec, "PALADIN_SHOCKADIN"); equal(custom.weights.meleeCrit, 7); equal(custom.weights.spellCrit, 3)
equal(custom.critMeleeShare, .7)
local explicit = assert(FW:CreateProfile("Explicit", {meleeCrit=2,spellCrit=8}, {classSpec="ROGUE"}))
equal(explicit.critMeleeShare, .2, "explicit channels take priority over a class preset")
local opposite = assert(FW:CreateProfile("Opposite", {meleeCrit=-4,spellCrit=2}, {classSpec="healer",critMeleeShare=.3}))
equal(opposite.weights.meleeCrit, -4); equal(opposite.weights.spellCrit, 2); equal(opposite.critMeleeShare, .3)

local revision = custom.revision
assert(FW:UpdateProfile(custom.id, {classSpec="MAGE"}))
equal(custom.weights.meleeCrit, 7, "metadata changes alone preserve existing weights")
equal(custom.critMeleeShare, .7)
equal(custom.revision, revision, "metadata changes alone keep cached scores")
assert(FW:UpdateProfile(custom.id, {critMeleeShare=.25}))
equal(custom.weights.meleeCrit, 2.5); equal(custom.weights.spellCrit, 7.5)
equal(custom.revision, revision + 1, "distribution edits invalidate scores")
assert(FW:UpdateProfile(custom.id, {weights={strength=2},critMeleeShare=.4}))
equal(custom.weights.strength, 2); equal(custom.weights.meleeCrit, 4); equal(custom.weights.spellCrit, 6)
assert(FW:UpdateProfile(custom.id, {weights={meleeCrit=3}}))
near(custom.critMeleeShare, 1/3, "partial channel edits infer the resulting distribution")
local before = custom.name
equal(FW:UpdateProfile(custom.id, {name="Invalid",classSpec="MONK"}), nil)
equal(custom.name, before, "invalid class metadata rejects the update atomically")
for _, invalid in ipairs({-1,1.1,math.huge,false,".5",{}}) do
    equal(FW:UpdateProfile(custom.id, {name="Invalid",critMeleeShare=invalid}), nil)
    equal(custom.name, before)
end
equal(FW:UpdateProfile(custom.id, {name="Invalid",weights={meleeCrit=2,spellCrit=8},critMeleeShare=.7}), nil)
equal(custom.name, before, "inconsistent weights and distribution are rejected atomically")
equal(FW:CreateProfile("Invalid", {}, {classSpec="MONK"}), nil)
equal(FW:CreateProfile("Invalid", {}, {critMeleeShare=2}), nil)

assert(FW:UpdateProfile(custom.id, {weights={meleeCrit=0,spellCrit=0},critMeleeShare=.73}))
equal(custom.critMeleeShare, .73, "zero total retains the chosen ratio")
local copy = assert(FW:CopyProfile(custom.id))
equal(copy.classSpec, "MAGE"); equal(copy.critMeleeShare, .73)
local exported = assert(FW:ExportProfile(custom.id))
local decoded = assert(FW.JSON.Decode(exported))
equal(decoded.classSpec, "MAGE"); equal(decoded.critMeleeShare, .73)
local imported = assert(FW:ImportProfile(exported))
equal(imported.classSpec, "MAGE"); equal(imported.critMeleeShare, .73)
local oppositeImported = assert(FW:ImportProfile(assert(FW:ExportProfile(opposite.id))))
equal(oppositeImported.weights.meleeCrit, -4); equal(oppositeImported.weights.spellCrit, 2)
equal(oppositeImported.critMeleeShare, .3, "unrepresentable signed pairs survive full import")

local oldImport = assert(FW:ImportProfile('{"crit":10}'))
equal(oldImport.classSpec, "any", "bare imported weights must not acquire the current character's identity")
equal(oldImport.weights.meleeCrit, 5); equal(oldImport.weights.spellCrit, 5)
local oldEnvelope = assert(FW:ImportProfile('{"format":"ZwykValues","version":1,"name":"Old","weights":{"crit":10}}'))
equal(oldEnvelope.classSpec, "any"); equal(oldEnvelope.weights.meleeCrit, 5)
local newEnvelope, _, allocationWarnings = FW:ImportProfile('{"format":"ZwykValues","version":1,"name":"New crit","classSpec":"PALADIN_RETRIBUTION","critMeleeShare":1,"weights":{"crit":10}}')
check(newEnvelope); equal(newEnvelope.weights.meleeCrit, 10); equal(newEnvelope.weights.spellCrit, 0)
check(table.concat(allocationWarnings, " "):find("100%% Melee / 0%% Spell"), "contextual import warning describes the actual allocation")
decoded.critMeleeShare = -1
local profileCount = #FW:GetProfiles()
equal(FW:ImportProfile(assert(FW.JSON.Encode(decoded))), nil)
equal(#FW:GetProfiles(), profileCount, "invalid import creates no partial profile")

-- Migration adds metadata while leaving both real channel weights untouched.
ZwykValuesDB = {profiles={old={name="Old",weights={meleeCrit=2,spellCrit=8},revision=7},
    zero={name="Zero",classSpec="physical",critMeleeShare=.8,weights={meleeCrit=0,spellCrit=0},revision=3},
    bad={name="Bad metadata",classSpec="DEATHKNIGHT",critMeleeShare=math.huge,weights={meleeCrit=0,spellCrit=0}}},
    profileOrder={"old","zero","bad"}}
FW.DB = nil
FW:Initialize()
local old = FW.DB.profiles.old
equal(old.classSpec, "any"); equal(old.critMeleeShare, .2)
equal(old.weights.meleeCrit, 2); equal(old.weights.spellCrit, 8); equal(old.revision, 7)
equal(FW.DB.profiles.zero.classSpec, "physical"); equal(FW.DB.profiles.zero.critMeleeShare, .8)
equal(FW.DB.profiles.bad.classSpec, "any"); equal(FW.DB.profiles.bad.critMeleeShare, .5)

print("Profile class / metadata tests passed: " .. passed .. " checks")
