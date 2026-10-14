-- Run from the addon directory: luatex --luaonly tests/test_crit_units.lua
-- The screenshot shows a 0.5% crit tooltip and a score of 81.35. Its raw API
-- table was not supplied: 7 rating is the value inferred from that score.
-- Percentages now always drive scores. Raw ratings remain diagnostic data;
-- this fixture checks their exclusion, legacy migration and comparison caches.
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function approx(actual, expected, message)
    checks = checks + 1
    assert(actual and math.abs(actual - expected) < 0.000001,
        (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local candidate, baseline = "item:273042", "item:200001"
local fixtures = {
    [candidate] = {
        name = "Manascale Treads", raw = {
            RESISTANCE0_NAME = 157, ITEM_MOD_STRENGTH_SHORT = 7, ITEM_MOD_INTELLECT_SHORT = 7,
            ITEM_MOD_CRIT_RATING_SHORT = 7, ITEM_MOD_CRIT_RATING = 7,
            ITEM_MOD_CRIT_MELEE_RATING_SHORT = 7, ITEM_MOD_CRIT_SPELL_RATING_SHORT = 7,
            ITEM_MOD_CRIT_RANGED_RATING_SHORT = 7,
        }, lines = {
            "157 Armor", "+7 Strength", "+7 Intellect",
            "Equip: Improves your chance to get a critical strike by 0.5%.",
        },
    },
    [baseline] = {
        name = "Equipped caster boots", raw = {ITEM_MOD_SPELL_POWER_SHORT = 20},
        lines = {"Equip: Increases damage and healing done by magical spells and effects by up to 20."},
    },
}
local reads, scans, scoreCalls = 0, 0, 0
GetBuildInfo = function() return "1.60.1", "70291", "Oct 7 2026", 16001 end
GetLocale = function() return "enUS" end
UnitLevel = function() return 30 end
UnitClass = function() return "Paladin", "PALADIN", 2 end
GetTime, GetItemInfoInstant, GetItemStats, CreateFrame = nil, nil, nil, nil
local function fixture(link)
    return assert(fixtures[link], "Unexpected item " .. tostring(link))
end
GetItemInfo = function(link)
    local item = fixture(link)
    return item.name, link, 3, 33, 28, "Armor", "Mail", 1, "INVTYPE_FEET", 123, 0, 4, 3
end
GetInventoryItemLink = function(_, slot) if slot == 8 then return baseline end end
C_Item = {
    GetItemInfo = GetItemInfo,
    IsItemDataCachedByID = function() return true end,
    GetItemStats = function(link) reads = reads + 1; return fixture(link).raw end,
}
C_TooltipInfo = {GetHyperlink = function(link)
    scans = scans + 1
    local item = fixture(link)
    local lines = {{leftText = item.name, type = 22}}
    for _, text in ipairs(item.lines) do lines[#lines + 1] = {leftText = text, type = 0} end
    return {lines = lines}
end}
ZwykValuesDB, ZwykPointsDB, ForeverWeightsDB = nil, nil, nil
local FW = {}
for _, file in ipairs({"JSON.lua", "Stats.lua", "Core.lua", "Items.lua", "Compare.lua", "Upgrades.lua"}) do
    assert(loadfile(file))("ZwykValues", FW)
end
FW:Initialize()
local scoreStats = FW.ScoreStats
function FW:ScoreStats(profile, stats)
    scoreCalls = scoreCalls + 1
    return scoreStats(self, profile, stats)
end
local weights = {
    agility = 0.01, armor = 0.05, armorBonus = 0.05, attackPower = 0.1,
    block = 0.01, blockValue = 0.1, blockValueBonus = 0.1, crit = 10,
    defense = 0.01, dodge = 0.01, dps = 1, expertise = 10, haste = 10, hit = 10,
    holyDamage = 1, intellect = 0.3, parry = 0.01, spellDamage = 1,
    spellPen = 0.1, spirit = 0.01, stamina = 0.01, strength = 0.2,
}
local profile, importError, warnings = FW:ImportProfile(assert(FW.JSON.Encode({
    format = "ZwykValues", version = 1, name = "Mageladin",
    secondaryUnit = "rating", weights = weights,
})))
assert(profile, importError)
equal(profile.secondaryUnit, "percent", "legacy rating imports use percentages")
equal(profile.weights.crit, 10, "legacy import preserves numeric weights")
equal(#warnings, 1, "legacy rating import explains its normalization")
local oldRevision = profile.revision
assert(FW:UpdateProfile(profile.id, {secondaryUnit = "rating"}))
equal(profile.secondaryUnit, "percent", "legacy rating update cannot select rating scoring")
equal(profile.revision, oldRevision, "normalizing an already-percent profile does not change its score revision")
assert(FW:SetMainProfile(profile.id))
local score, item, detail = FW:GetScore(candidate, profile)
equal(detail, nil)
equal(item.partial, false)
equal(item.ratingStats.crit, 7, "generic, scoped and unsuffixed aliases count once")
equal(item.percentStats.crit, 0.5, "tooltip percentage stays separate from native rating")
equal(item.percentStats.hit, nil, "critical strike does not supply hit chance")
equal(item.stats.crit, nil)
approx(score, 16.35, "11.35 static + 0.5 percentage point times 10")
approx(FW:GetScore(candidate, profile), 16.35)
equal(reads, 1); equal(scans, 1); equal(scoreCalls, 1, "repeated score is cached")
local comparison = assert(FW:CompareItem(candidate, profile))
approx(comparison.comparisons[1].baseline, 20)
approx(comparison.comparisons[1].delta, -3.65)
equal(comparison.comparisons[1].status, "downgrade")
equal(FW:IsMainProfileUpgrade(candidate), false)
equal(FW:IsMainProfileUpgrade(candidate), false)
equal(reads, 2); equal(scans, 2); equal(scoreCalls, 2)

-- Seed SavedVariables and the upgrade memo as the prior rating-based version
-- could have left them. Migration must reject that old 81.35 cached score.
profile.secondaryUnit = "rating"
FW.DB.cache.scores[item.key][profile.id] = {revision = oldRevision, score = 81.35}
FW:InvalidateUpgradeComparisons()
equal(FW:IsMainProfileUpgrade(candidate), true, "legacy cache establishes the stale upgrade decision")
local saved = FW.DB
FW.DB, ZwykValuesDB = nil, saved
FW:Initialize()
profile = FW.DB.profiles[profile.id]
equal(profile.secondaryUnit, "percent", "SavedVariables migration normalizes rating profiles")
equal(profile.revision, oldRevision + 1)
equal(profile.weights.crit, 10, "migration never rewrites numeric weights")
approx(FW:GetScore(candidate, profile), 16.35, "migration invalidates the inflated rating score")
comparison = assert(FW:CompareItem(candidate, profile))
approx(comparison.comparisons[1].baseline, 20)
approx(comparison.comparisons[1].delta, -3.65)
equal(comparison.comparisons[1].status, "downgrade")
equal(FW:IsMainProfileUpgrade(candidate), false, "legacy upgrade memo is invalidated by the migrated revision")
equal(FW:IsMainProfileUpgrade(candidate), false)
equal(reads, 2); equal(scans, 2); equal(scoreCalls, 4)
equal(FW.DB.cache.scores[item.key][profile.id].revision, profile.revision)
equal(FW:GetIssueReport().itemCount, 0)

oldRevision = profile.revision
FW.DB = nil
FW:Initialize()
equal(profile.revision, oldRevision, "reinitialization does not migrate the same profile twice")

-- Native API ratings can change without changing the displayed percentage.
-- They must never leak into the weighted value or establish an upgrade.
for key in pairs(fixtures[candidate].raw) do
    if key:find("CRIT", 1, true) then fixtures[candidate].raw[key] = 999 end
end
assert(FW:InvalidateItem(candidate))
score, item, detail = FW:GetScore(candidate, profile)
equal(item.ratingStats.crit, 999, "raw rating remains available for diagnostics")
equal(item.percentStats.crit, 0.5)
equal(detail, nil)
approx(score, 16.35, "raw rating changes never alter percentage scoring")
equal(FW:IsMainProfileUpgrade(candidate), false)
equal(reads, 3); equal(scans, 3); equal(scoreCalls, 5)
local exported = assert(FW.JSON.Decode(assert(FW:ExportProfile(profile.id))))
equal(exported.secondaryUnit, "percent", "exports cannot reintroduce rating mode")
print("Crit unit tests passed (" .. checks .. " checks)")
