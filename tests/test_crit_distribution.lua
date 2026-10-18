-- Exercise the combined editor model through real scoring and calculators.
local FW, checks = {}, 0
for _, file in ipairs({"JSON.lua", "Stats.lua", "ProfileClasses.lua", "Core.lua", "DerivedWeights.lua"}) do
    assert(loadfile(file))("ZwykValues", FW)
end
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function close(actual, expected, message)
    checks = checks + 1
    assert(type(actual) == "number" and math.abs(actual-expected) < 1e-10,
        (message or "number") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
for _, total in ipairs({10, 0, -10, 0.016233308}) do
    for _, share in ipairs({0, 0.3, 0.5, 0.7, 1}) do
        local melee, spell = FW:DistributeCritWeight(total, share)
        close(melee + spell, total, "the combined weight is conserved")
        local actualTotal, actualShare, representable = FW:GetCritDistribution({meleeCrit=melee,spellCrit=spell}, share)
        close(actualTotal, total); close(actualShare, share); equal(representable, true)
    end
end
local total, share, representable = FW:GetCritDistribution({meleeCrit=5,spellCrit=-5}, 0.7)
equal(total, 0); equal(share, 0.7); equal(representable, false)
total, share, representable = FW:GetCritDistribution({meleeCrit=-3,spellCrit=9}, 0.5)
equal(total, 6); equal(share, 0.5); equal(representable, false)

UnitClass=function() return "Paladin", "PALADIN" end
UnitLevel=function() return 60 end
UnitStat=function() return 100,100,0,0 end
GetShapeshiftFormID=function() return 0 end
GetCritChanceFromStat=function(_, value) return value*0.0004 end
GetSpellCritChanceFromStat=function(_, value) return value*0.0002 end
C_ClassTalents={GetActiveConfigID=function() return 1 end}
C_Traits={GetNodeInfo=function() return {activeRank=0} end}
FW:Initialize()
local profile=assert(FW:CreateProfile("Hybrid", {meleeCrit=7,spellCrit=3}, {classSpec="PALADIN_SHOCKADIN"}))
local items={
    generic={meleeCrit=1,spellCrit=1},
    melee={meleeCrit=1},
    spell={spellCrit=1},
}
function FW:GetItem(link)
    local record=self.DB.cache.items[link]
    if record then return record end
    return {key=link, link=link, stats={}, percentStats=items[link],
        classID=4, subclassID=4, equipLoc="INVTYPE_HEAD", classRestrictionsKnown=true}
end
close(FW:GetScore("generic", profile), 10)
close(FW:GetScore("melee", profile), 7)
close(FW:GetScore("spell", profile), 3)
local cached=FW.DB.cache.scores.generic[profile.id]
local revision=profile.revision
assert(FW:UpdateProfile(profile.id, {classSpec="PALADIN_RETRIBUTION"}))
equal(profile.revision, revision, "class metadata alone does not change scores")
equal(FW.DB.cache.scores.generic[profile.id], cached)
close(profile.weights.meleeCrit, 7)
assert(FW:UpdateProfile(profile.id, {critMeleeShare=1}))
equal(profile.revision, revision+1, "applying a different split invalidates channel scores")
close(FW:GetScore("generic", profile), 10)
close(FW:GetScore("melee", profile), 10)
close(FW:GetScore("spell", profile), 0)
local opts={kings=false,useTalents=false}
local agility=FW:GetDerivedWeightOptions("agility", profile.weights, opts)
local intellect=FW:GetDerivedWeightOptions("intellect", profile.weights, opts)
assert(agility.available, agility.reason); assert(intellect.available, intellect.reason)
close(agility.value, 0.4, "Agility uses the allocated melee contribution")
close(intellect.value, 0, "Intellect excludes melee crit")
assert(FW:UpdateProfile(profile.id, {critMeleeShare=0}))
agility=FW:GetDerivedWeightOptions("agility", profile.weights, opts)
intellect=FW:GetDerivedWeightOptions("intellect", profile.weights, opts)
assert(agility.available, agility.reason); assert(intellect.available, intellect.reason)
close(agility.value, 0)
close(intellect.value, 0.2, "Intellect uses the allocated spell contribution")
close(FW:GetScore("generic", profile), 10)
close(FW:GetScore("melee", profile), 0)
close(FW:GetScore("spell", profile), 10)

-- Global display settings never change any profile's score revision/cache.
revision=profile.revision
cached=FW.DB.cache.scores.generic[profile.id]
equal(FW.DB.options.showProfileIcon, true)
equal(FW.DB.options.showClassIcon, true)
for _, key in ipairs({"showProfileIcon", "showClassIcon", "debugUnknownStats", "showComparisons"}) do
    assert(FW:SetGlobalOption(key, false)); equal(FW.DB.options[key], false)
    assert(FW:SetGlobalOption(key, true)); equal(FW.DB.options[key], true)
end
equal(FW:SetGlobalOption("unknown", true), nil)
equal(FW:SetGlobalOption("showClassIcon", "yes"), nil)
equal(profile.revision, revision)
equal(FW.DB.cache.scores.generic[profile.id], cached)
close(FW:GetScore("generic", profile), 10)
print("Crit distribution pipeline: " .. checks .. " checks passed.")
