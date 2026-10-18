-- Run from the addon directory: luatex --luaonly tests/test_external_imports.lua
local FW, checks = {}, 0
for _, file in ipairs({"JSON.lua", "Stats.lua", "Imports.lua", "Core.lua"}) do
    assert(loadfile(file))("ZwykValues", FW)
end
local function check(value, message)
    checks = checks + 1
    assert(value, message or "assertion failed")
end
local function equal(actual, expected, message)
    check(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function approx(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-9),
        (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function contains(value, expected)
    check(type(value) == "string" and value:find(expected, 1, true), "Expected '" .. expected .. "' in " .. tostring(value))
end
local function parse(source, options)
    local profile, failure, warnings = FW:ParseExternalWeights(source, options)
    check(profile, failure)
    check(type(warnings) == "table", "external imports return their warnings")
    equal(failure, nil)
    equal(profile.secondaryUnit, "percent", "external values are normalized before saving")
    return profile, warnings
end
local function reject(source, expected, options)
    local profile, failure = FW:ParseExternalWeights(source, options)
    equal(profile, nil, "invalid external input must not produce a profile")
    contains(failure, expected)
end
local url = "https://sixtyupgrades.com/forever/ep/import?name=Retribution%20WoWSims%20Weights&strength=0.619&agility=0.633&intellect=0.764&spellDamage=1.000&attackPower=0.258&hit=22.488&crit=13.600&haste=1.711&expertise=11.132&dps=3.398"
local pawn = '( Pawn: v1: "Retribution WoWSims Weights": Class=Paladin,Strength=0.619,Agility=0.633,Intellect=0.764,SpellDamage=1.000,Ap=0.258,HitRating=2.249,CritRating=0.971,HasteRating=0.171,ExpertiseRating=1.113,MeleeDps=3.398 )'
local sixty, sixtyWarnings = parse(url)
equal(sixty.name, "Retribution WoWSims Weights")
equal(sixty.secondaryDisplayUnit, "percent")
for key, expected in pairs({strength=.619, agility=.633, intellect=.764, spellDamage=1, attackPower=.258,
    hit=22.488, crit=13.6, haste=1.711, expertise=11.132, dps=3.398}) do
    approx(sixty.weights[key], expected)
end
equal(sixty.weights.mana, nil, "missing stats stay absent instead of being derived")
equal(sixty.weights.meleeCrit, nil, "Core owns the legacy combined crit split")
local fromPawn, pawnWarnings = parse(pawn)
equal(fromPawn.name, sixty.name)
equal(fromPawn.secondaryDisplayUnit, "rating")
approx(fromPawn.weights.hit, 22.49)
approx(fromPawn.weights.crit, 13.594)
approx(fromPawn.weights.haste, 1.71)
approx(fromPawn.weights.expertise, 11.13)
contains(table.concat(pawnWarnings, " "), "shared crit")
for key, expected in pairs(sixty.weights) do
    approx(fromPawn.weights[key], expected, .007, "three-decimal export rounding for " .. key)
end

local markdown = "[" .. url .. "](" .. url:gsub("&", "\\&") .. ")"
local fromMarkdown = parse(markdown)
equal(fromMarkdown.weights.crit, sixty.weights.crit)
equal(parse("<" .. url .. ">").weights.hit, sixty.weights.hit)
equal(parse(url:gsub("&", "&amp;")).weights.hit, sixty.weights.hit)
equal(parse("https://www.sixtyupgrades.com/forever/ep/import?name=F%C3%A9lix+Weights&strength=0").name, "Félix Weights")
equal(parse("https://sixtyupgrades.com/forever/ep/import?strength=0").weights.strength, 0, "known zero weights are retained")
equal(parse('https://sixtyupgrades.com/forever/ep/import?strength=-.5&healing=+1e-3').weights.strength, -.5)
equal(parse('https://sixtyupgrades.com/forever/ep/import?strength=1&physicalDamage=0').weights.physicalDamage, nil)

local allRatings = parse('(Pawn:v2:"Tank":DefenseRating=3,DodgeRating=2,ParryRating=4,BlockRating=5,CritRating=1,HitRating=2,HasteRating=3,ExpertiseRating=4)')
for key, expected in pairs({defense=3, dodge=24, parry=60, block=25, crit=14, hit=20, haste=30, expertise=40}) do
    approx(allRatings.weights[key], expected)
end
local scoped, scopedWarnings = parse('(Pawn:v1:"Caster":CritRating=1,SpellCritRating=3)')
equal(scoped.weights.crit, nil)
approx(scoped.weights.meleeCrit, 14)
approx(scoped.weights.spellCrit, 42)
contains(table.concat(scopedWarnings, " "), "melee crit")
local melee = parse('(Pawn:v1:"Attack":CritRating=1)', {pawnCritMode="separate"})
equal(melee.weights.crit, nil)
approx(melee.weights.meleeCrit, 14)
local shared = parse('(Pawn:v1:"Renamed":CritRating=1)', {pawnCritMode="shared"})
approx(shared.weights.crit, 14, nil, "shared semantics do not depend on the scale name")
local classicPawn = parse('(Pawn:v1:"Classic":CritRating=10,SpellCritRating=20,HitRating=5)', {pawnCritMode="separate", pawnUnit="percent"})
equal(classicPawn.weights.meleeCrit, 10)
equal(classicPawn.weights.spellCrit, 20)
equal(classicPawn.weights.hit, 5)
equal(classicPawn.secondaryDisplayUnit, "percent")
local metadata = parse('(Pawn:v2:"A \\\"quoted\\\" name":ClassID=2,SpecID=70,Color="ff804020",Strength=1)')
equal(metadata.name, 'A "quoted" name')
approx(metadata.color.r, 128 / 255)
approx(metadata.color.g, 64 / 255)
approx(metadata.color.b, 32 / 255)
local common = parse('(Pawn:v1:"Other":Hp5=0,Mp5=.2,FeralAp=1,Rap=2,SpellHealing=3,SpellPenetration=4,ArcaneSpellDamage=5,FireResist=6,Armor2=7,RangedDps=8,Unsupported=0)')
equal(common.weights.hp5, 0)
equal(common.weights.mp5, .2)
equal(common.weights.feralAttackPower, 1)
equal(common.weights.rangedAttackPower, 2)
equal(common.weights.healing, 3)
equal(common.weights.spellPen, 4)
equal(common.weights.arcaneDamage, 5)
equal(common.weights.fireResist, 6)
equal(common.weights.armorBonus, 7)
equal(common.weights.rangedDps, 8)
equal(common.weights.Unsupported, nil)

for _, input in ipairs({'{}', '{"name":"Pawn", "weights":{}}', '[]', 'not an external export', '42', ''}) do
    local result, failure, warnings = FW:ParseExternalWeights(input)
    equal(result, nil); equal(failure, nil); equal(warnings, nil)
end
reject("https://sixtyupgrades.com/tbc/ep/import?strength=1", "complete Sixty Upgrades Forever")
reject("https://sixtyupgrades.com.evil.example/forever/ep/import?strength=1", "complete Sixty Upgrades Forever")
reject("https://sixtyupgrades.com/forever/ep/import?strength=1&strength=2", "Duplicate")
reject("https://sixtyupgrades.com/forever/ep/import?Strength=1&strength=2", "Duplicate")
reject("https://sixtyupgrades.com/forever/ep/import?name=a&name=b&strength=1", "Duplicate")
reject("https://sixtyupgrades.com/forever/ep/import?strength=1&physicalDamage=2", "cannot represent")
reject("https://sixtyupgrades.com/forever/ep/import?strength=1&crit=2&spellCrit=3", "Combined crit")
reject("https://sixtyupgrades.com/forever/ep/import?name=%00&strength=1", "invalid percent encoding")
reject("https://sixtyupgrades.com/forever/ep/import?name=%F&strength=1", "invalid percent encoding")
reject("https://sixtyupgrades.com/forever/ep/import?name=%FF&strength=1", "invalid percent encoding")
reject("https://sixtyupgrades.com/forever/ep/import?strength=1&", "empty query field")
reject("https://sixtyupgrades.com/forever/ep/import?name=NoStats", "no supported stat weights")
reject("https://sixtyupgrades.com/forever/ep/import?name=&strength=1", "name is empty")
reject('(Pawn:v1:"A":Strength=1,Strength=2)', "Duplicate")
reject('(Pawn:v1:"A":Strength=1,strength=2)', "Duplicate")
reject('(Pawn:v1:"A":Healing=1,SpellHealing=2)', "Duplicate")
reject('(Pawn:v1:"A":CritRating=1,MeleeCritRating=2)', "mixed")
reject('(Pawn:v1:"A":CritRating=1,SpellCritRating=2)', "mixed", {pawnCritMode="shared"})
reject('(Pawn:v1:"A":CritRating=1,MeleeCritRating=2)', "Duplicate", {pawnCritMode="separate"})
reject('(Pawn:v1:"A":ResilienceRating=1)', "cannot represent")
reject('(Pawn:v1:"A":HitRating=1,SpellHitRating=2)', "cannot represent")
reject('(Pawn:v1:"A":Class=Paladin)', "no supported stat weights")
reject('(Pawn:v3:"A":Strength=1)', "Unsupported Pawn scale version")
reject('Pawn:v1:"A":Strength=1', "complete Pawn scale string")
reject('(Pawn:v1:"A":Strength=1,)', "Each Pawn field")
reject('(Pawn:v1:"A":Strength=1,,Agility=2)', "Each Pawn field")
reject('(Pawn:v1:"A":Color="oops",Strength=1)', "Pawn Color")
reject('(Pawn:v1:"A":ClassID=2.5,Strength=1)', "whole number")
reject('(Pawn:v1:"A":Strength=1)', "Pawn crit mode", {pawnCritMode="guess"})
reject('(Pawn:v1:"A":Strength=1)', "Pawn source unit", {pawnUnit="guess"})
reject('(Pawn:v1:"A":Strength=1)', "Pawn source unit", {pawnUnit=false})
reject('(Pawn:v1:"A":Strength=1)', "options must be a table", false)
reject('(Pawn:v1:"A":IsOffHand=X,Strength=1)', "item exclusion")
reject('(Pawn:v1:"A":CritRating=1e308)', "overflows")
reject('(Pawn:v1:"' .. string.char(255) .. '":Strength=1)', "valid UTF-8")
reject('https://sixtyupgrades.com/forever/ep/import?name=' .. string.char(255) .. '&strength=1', "valid UTF-8")
for _, invalid in ipairs({'NaN', 'Infinity', '-inf', '1e999', '0x10', '1+2', '1e', '--1', '1..2', '1%','"2"'}) do
    reject('(Pawn:v1:"A":Strength=' .. invalid .. ')', "finite decimal")
    reject('https://sixtyupgrades.com/forever/ep/import?strength=' .. invalid:gsub("%%", "%%25"), "finite decimal")
end
_G.ZwykValuesImportExecuted = false
reject('(Pawn:v1:"A":Strength=(function() ZwykValuesImportExecuted=true return 2 end)())', "finite decimal")
equal(_G.ZwykValuesImportExecuted, false, "scale text is never executed")

-- Core integration: imported values reach scoring once; there are no automatic
-- primary-stat calculations and no raw-rating score inflation.
FW:Initialize()
local sixtyProfile, sixtyFailure, allWarnings = FW:ImportProfile(url)
check(sixtyProfile, sixtyFailure)
equal(sixtyProfile.weights.mana, 0)
approx(sixtyProfile.weights.intellect, .764)
approx(sixtyProfile.weights.meleeCrit, 6.8)
approx(sixtyProfile.weights.spellCrit, 6.8)
local pawnProfile, pawnFailure = FW:ImportProfile(pawn, nil, {pawnCritMode="shared"})
check(pawnProfile, pawnFailure)
equal(assert(FW:ImportProfile(pawn, "Custom profile name")).name, "Custom profile name", "the explicit import name overrides the source name")
local classicProfile = assert(FW:ImportProfile('(Pawn:v1:"Classic":CritRating=10,SpellCritRating=20)', nil, {pawnCritMode="separate", pawnUnit="percent"}))
equal(classicProfile.weights.meleeCrit, 10)
equal(classicProfile.weights.spellCrit, 20)
local sample = {strength=7, intellect=7, meleeCrit=.5, spellCrit=.5, hit=.2, dps=5}
local sixtyScore = assert(FW:ScoreStats(sixtyProfile, sample))
local pawnScore = assert(FW:ScoreStats(pawnProfile, sample))
approx(sixtyScore, pawnScore, .007, "sample exports produce matching item scores within their rounding")
equal(sixtyProfile.secondaryDisplayUnit, "percent")
equal(pawnProfile.secondaryDisplayUnit, "rating")
contains(table.concat(allWarnings, " "), "Sixty Upgrades")
local before = #FW:GetProfiles()
local invalidProfile, failure = FW:ImportProfile('(Pawn:v1:"A":ResilienceRating=1)')
equal(invalidProfile, nil)
contains(failure, "cannot represent")
equal(#FW:GetProfiles(), before, "failed external imports never create partial profiles")

print("External import tests passed: " .. checks .. " checks")
