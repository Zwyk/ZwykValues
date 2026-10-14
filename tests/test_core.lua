-- Run from the addon directory: lua tests/test_core.lua .
local addonPath = (arg and arg[1]) or "."
local FW = {}
assert(loadfile(addonPath .. "/JSON.lua"))("ZwykValues", FW)
assert(loadfile(addonPath .. "/Stats.lua"))("ZwykValues", FW)
assert(loadfile(addonPath .. "/Core.lua"))("ZwykValues", FW)

local passed = 0
local function check(value, message)
    assert(value, message or "assertion failed")
    passed = passed + 1
end
local function equal(actual, expected, message)
    check(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function contains(value, pattern)
    check(type(value) == "string" and value:find(pattern, 1, true), "Expected error containing '" .. pattern .. "', got " .. tostring(value))
end
local function reset()
    ZwykValuesDB, ZwykPointsDB, ForeverWeightsDB, FW.DB = nil, nil, nil, nil
    FW:Initialize()
end

local json = FW.JSON
local decoded, errorMessage = json.Decode('{"text":"Félix \\uD83D\\uDE00","array":[null,false,0],"empty":{}}')
check(decoded, errorMessage)
equal(decoded.text, "Félix " .. string.char(0xF0, 0x9F, 0x98, 0x80))
equal(decoded.array[1], json.null)
equal(decoded.array[2], false)
equal(decoded.array[3], 0)
local encoded = assert(json.Encode(decoded))
local roundtrip = assert(json.Decode(encoded))
equal(#roundtrip.array, 3)
equal(assert(json.Encode(roundtrip.empty)), "{}")
equal(assert(json.Encode(json.array())), "[]")
local malformed = {
    '{"strength":1,"strength":2}', '{"strength":1,}', '[1,]', '01', '-01',
    '1.', '.5', '1e', '1e999', 'NaN', 'true false', '"\\uD800"', '"\\uDC00"',
    '"\\x12"', '"' .. string.char(0xC0, 0xAF) .. '"',
}
for _, source in ipairs(malformed) do
    local value, parseError = json.Decode(source)
    equal(value, nil, "malformed JSON must be rejected: " .. source)
    check(type(parseError) == "string")
end
local circular = {}
circular.self = circular
equal(json.Encode(circular), nil)
equal(json.Encode({ value = math.huge }), nil)

reset()
local default = FW:GetProfiles()[1]
equal(default.name, "My profile")
equal(default.secondaryUnit, "percent")
equal(default.icon, nil, "profiles start without an optional icon")
equal(#FW:GetProfiles(true), 1)
for _, definition in ipairs(FW.StatDefinitions) do equal(default.weights[definition.key], 0) end

local profile = assert(FW:CreateProfile("  My weights  ", { strength = 2, agility = -0.5, hit = 3 }))
equal(profile.name, "My weights")
equal(FW:ScoreStats(profile, { strength = 12, agility = 4, hit = 1 }), 25)
local revision = profile.revision
assert(FW:UpdateProfile(profile.id, { name = "Renamed", color = { r = 1, g = 0, b = 0 } }))
equal(profile.revision, revision, "display edits keep cached scores valid")
assert(FW:UpdateProfile(profile.id, { weights = { strength = 3 } }))
equal(profile.weights.agility, -0.5, "partial weight edits preserve other weights")
equal(profile.revision, revision + 1)
local before = profile.name
local result, updateError = FW:UpdateProfile(profile.id, { name = "Mutation", weights = { unknown = 1 } })
equal(result, nil)
contains(updateError, "Unknown stat")
equal(profile.name, before, "invalid updates are atomic")
equal(FW:CreateProfile("Invalid", { strength = math.huge }), nil)
equal(FW:UpdateProfile(profile.id, { color = { r = 2, g = 0, b = 0 } }), nil)

-- Icons are display metadata: validate atomically and keep score revisions.
local iconRevision = profile.revision
assert(FW:UpdateProfile(profile.id, { icon = 135943 }))
equal(profile.icon, 135943, "game texture file IDs are retained")
equal(profile.revision, iconRevision, "icon edits keep cached scores valid")
local secretIcon = {}
issecretvalue = function(value) return value == secretIcon end
equal(FW:ValidateProfileIcon(secretIcon), nil, "secret icon values are rejected before inspecting them")
issecretvalue = nil
assert(FW:UpdateProfile(profile.id, { icon = "interface/icons/INV_Misc_QuestionMark.blp" }))
equal(profile.icon, "Interface\\Icons\\INV_Misc_QuestionMark.blp", "game icon paths are normalized")
local iconPath = profile.icon
local invalidIcons = {
    0, -1, 1.5, math.huge, 4294967296, true, {}, json.null, "", "135943",
    "INV_Misc_QuestionMark", "Interface\\AddOns\\Other\\Icon",
    "Interface\\Icons\\..\\Other", "Interface\\Icons\\INV_Icon|cffffffff",
    "Interface\\Icons\\INV_Icon.png", "Interface\\Icons\\" .. string.rep("A", 250),
}
for _, icon in ipairs(invalidIcons) do
    local value, failure = FW:UpdateProfile(profile.id, { name = "Must not change", icon = icon })
    equal(value, nil, "invalid icons are rejected")
    contains(failure, "Profile icon")
    equal(profile.icon, iconPath, "invalid updates preserve the icon")
    equal(profile.name, "Renamed", "invalid icon updates preserve other fields")
end
assert(FW:UpdateProfile(profile.id, { icon = false }))
equal(profile.icon, nil, "false clears an optional icon")
equal(assert(json.Decode(assert(FW:ExportProfile(profile.id)))).icon, nil, "unset icons are omitted from profile exports")
assert(FW:UpdateProfile(profile.id, { icon = 135943 }))

local bare = assert(FW:ExportProfile(profile.id, true))
local bareObject = assert(json.Decode(bare))
local keyCount = 0
for key in pairs(bareObject) do
    check(FW.StatByKey[key], "export contains only canonical keys")
    keyCount = keyCount + 1
end
equal(keyCount, #FW.StatDefinitions, "exports retain every zero-weight stat")
local imported, importError, warnings = FW:ImportProfile(bare, "Imported")
check(imported, importError)
equal(imported.weights.strength, 3)
equal(imported.name, "Imported")
equal(imported.icon, nil, "bare weights do not inherit display metadata")
check(#warnings > 0, "bare imports explain unit assumptions")
assert(FW:UpdateProfile(profile.id, { secondaryUnit = "rating", active = false }))
equal(profile.secondaryUnit, "percent", "legacy update requests cannot enable rating mode")
local envelope = assert(FW:ExportProfile(profile.id))
equal(assert(json.Decode(envelope)).format, "ZwykValues", "new exports use the renamed format")
local restored = assert(FW:ImportProfile(envelope))
equal(restored.name, profile.name)
equal(restored.secondaryUnit, "percent")
equal(restored.color.r, 1)
equal(restored.icon, 135943, "full profiles round-trip texture file IDs")
local pathEnvelope = assert(json.Decode(envelope))
pathEnvelope.icon = "Interface\\Icons\\Ability_Paladin_DivineStorm.tga"
local pathImport = assert(FW:ImportProfile(assert(json.Encode(pathEnvelope))))
equal(pathImport.icon, pathEnvelope.icon, "full profiles round-trip game icon paths")
pathEnvelope.icon = nil
equal(assert(FW:ImportProfile(assert(json.Encode(pathEnvelope)))).icon, nil, "old full profiles remain valid without an icon")
for _, legacyFormat in ipairs({ "ZwykPoints", "ForeverWeights" }) do
    local legacyEnvelope = envelope:gsub('"format":"ZwykValues"', '"format":"' .. legacyFormat .. '"')
    legacyEnvelope = legacyEnvelope:gsub('"secondaryUnit":"percent"', '"secondaryUnit":"rating"')
    local legacy, _, legacyWarnings = FW:ImportProfile(legacyEnvelope)
    check(legacy)
    equal(legacy.name, profile.name, "legacy profile names are preserved")
    equal(legacy.weights.strength, 3, "legacy profile weights are preserved")
    equal(legacy.secondaryUnit, "percent", "legacy rating profiles import as percentages")
    contains(table.concat(legacyWarnings, " "), "numeric weights are unchanged")
    equal(legacy.color.r, 1, "legacy profile colors are preserved")
    equal(legacy.icon, 135943, "legacy format envelopes preserve optional icons")
    equal(assert(json.Decode(assert(FW:ExportProfile(legacy.id)))).format, "ZwykValues", "legacy imports re-export with the new format")
end
local empty = assert(FW:ImportProfile("{}", "Empty"))
equal(FW:ScoreStats(empty, { strength = 100 }), 0)
local badImports = {
    '[]', 'null', 'false', '{"spellingMistake":1}', '{"strength":null}', '{"strength":"2"}',
    '{"format":"ZwykValues","version":2,"weights":{}}',
    '{"format":"ZwykValues","version":1,"weights":{},"secondaryUnit":"guessed"}',
    '{"format":"ZwykValues","version":1,"weights":{},"icon":false}',
    '{"format":"ZwykValues","version":1,"weights":{},"icon":null}',
    '{"format":"ZwykValues","version":1,"weights":{},"icon":"Interface/Icons/../Other"}',
}
for _, source in ipairs(badImports) do
    local count = #FW:GetProfiles()
    local value, importFailure = FW:ImportProfile(source)
    equal(value, nil)
    check(type(importFailure) == "string", "invalid imports explain failure")
    equal(#FW:GetProfiles(), count, "invalid imports do not create profiles")
end
local copied = assert(FW:CopyProfile(profile.id))
check(copied.id ~= profile.id)
equal(copied.secondaryUnit, profile.secondaryUnit)
equal(copied.active, false)
equal(copied.icon, profile.icon, "profile copies preserve the optional icon")
assert(FW:UpdateProfile(copied.id, { icon = false }))
equal(profile.icon, 135943, "clearing a copy's icon preserves the original")
copied.weights.strength = 123
equal(profile.weights.strength, 3, "copies own their weight table")
copied.color.g = 1
equal(profile.color.g, 0, "copies own their color table")
assert(FW:DeleteProfile(copied.id))
equal(FW.DB.profiles[copied.id], nil)
local longNamed = assert(FW:CreateProfile("A" .. string.rep("é", 79), {}))
local longCopy = assert(FW:CopyProfile(longNamed.id))
check(FW:ExportProfile(longCopy.id), "copying a long Unicode name does not split its UTF-8 characters")

local legacyDB = FW.DB
legacyDB.options.debugUnknownStats = true
local legacyProfile = legacyDB.profiles[profile.id]
legacyProfile.secondaryUnit = "rating"
local legacyRevision = legacyProfile.revision
ForeverWeightsDB, ZwykValuesDB, FW.DB = legacyDB, nil, nil
FW:Initialize()
check(FW.DB ~= legacyDB, "legacy migration creates an independent database")
check(FW.DB.profiles[profile.id] ~= legacyProfile, "migrated profiles are independent")
equal(FW.DB.profiles[profile.id].weights.strength, 3, "legacy migration preserves weights")
equal(FW.DB.profiles[profile.id].secondaryUnit, "percent", "legacy migration normalizes rating profiles")
equal(FW.DB.profiles[profile.id].revision, legacyRevision + 1, "unit migration invalidates old rating totals")
equal(legacyProfile.secondaryUnit, "rating", "legacy migration does not mutate the source database")
equal(FW.DB.profiles[profile.id].active, false, "legacy migration preserves activation")
equal(FW.DB.profiles[profile.id].icon, 135943, "legacy migration preserves valid icons")
equal(FW.DB.options.debugUnknownStats, true, "legacy migration preserves options")
assert(FW:UpdateProfile(profile.id, { weights = { strength = 42 }, color = { r = 0, g = 1, b = 0 } }))
equal(legacyProfile.weights.strength, 3, "migrated edits do not modify the old weights")
equal(legacyProfile.color.r, 1, "migrated edits do not modify the old colors")
local migratedDB = FW.DB
FW.DB = nil
FW:Initialize()
equal(FW.DB, migratedDB, "an existing ZwykValues database takes precedence over legacy data")
equal(FW.DB.profiles[profile.id].weights.strength, 42, "reinitializing does not reimport legacy weights")

-- The immediately previous addon database takes precedence over the original.
ZwykPointsDB, ZwykValuesDB, FW.DB = migratedDB, nil, nil
FW:Initialize()
check(FW.DB ~= ZwykPointsDB, "ZwykPoints migration creates an independent database")
equal(FW.DB.profiles[profile.id].weights.strength, 42, "ZwykPoints takes precedence over ForeverWeights")
check(FW.DB.options ~= ZwykPointsDB.options, "migrated options are independent")
check(FW.DB.cache ~= ZwykPointsDB.cache, "migrated cache is independent")
assert(FW:UpdateProfile(profile.id, { weights = { strength = 50 } }))
equal(ZwykPointsDB.profiles[profile.id].weights.strength, 42, "migrated edits do not modify ZwykPoints weights")
FW.DB = nil
FW:Initialize()
equal(FW.DB.profiles[profile.id].weights.strength, 50, "existing ZwykValues takes precedence over both legacy databases")

local savedProfiles = FW:GetProfiles()
savedProfiles[1].icon = "interface/icons/INV_Misc_QuestionMark"
savedProfiles[2].icon = "Interface\\AddOns\\Other\\Icon"
savedProfiles[3].icon = false
savedProfiles[4].icon = 0
FW.DB = nil
FW:Initialize()
equal(savedProfiles[1].icon, "Interface\\Icons\\INV_Misc_QuestionMark", "saved game icon paths are normalized")
equal(savedProfiles[2].icon, nil, "invalid saved icon paths are discarded")
equal(savedProfiles[3].icon, nil, "legacy false icon fields become unset")
equal(savedProfiles[4].icon, nil, "invalid saved numeric icons are discarded")

reset()
local records, itemReads, scoreCalls = {}, 0, 0
function FW:ItemKey(link) return link end
function FW:GetItem(link)
    local cached = self.DB.cache.items[link]
    if cached then return cached end
    itemReads = itemReads + 1
    if records[link] then
        records[link].equipLoc = "INVTYPE_HEAD"
        records[link].classID, records[link].subclassID = 4, 4
    end
    return records[link], records[link] and nil or "Item is loading."
end
local baseScoreStats = FW.ScoreStats
function FW:ScoreStats(selectedProfile, stats)
    scoreCalls = scoreCalls + 1
    return baseScoreStats(self, selectedProfile, stats)
end
local weighted = assert(FW:CreateProfile("Test", { strength = 2, hit = 10 }))
records.itemA = { key = "itemA", link = "itemA", stats = { strength = 4 }, percentStats = { hit = 1 }, ratingStats = { hit = 12 }, warnings = {} }
local score, record = FW:GetScore("itemA", weighted)
equal(score, 18)
equal(record, records.itemA)
equal(FW:GetScore("itemA", weighted), 18)
equal(scoreCalls, 1, "repeat tooltip scores use the local cache")
equal(itemReads, 1, "item cache is reused")
assert(FW:UpdateProfile(weighted.id, { color = { r = 0, g = 1, b = 0 } }))
equal(FW:GetScore("itemA", weighted), 18)
equal(scoreCalls, 1, "color edits do not calculate another score")
assert(FW:UpdateProfile(weighted.id, { icon = 135943 }))
equal(FW:GetScore("itemA", weighted), 18)
equal(scoreCalls, 1, "icon edits do not calculate another score")
assert(FW:UpdateProfile(weighted.id, { icon = false }))
equal(FW:GetScore("itemA", weighted), 18)
equal(scoreCalls, 1, "clearing an icon does not calculate another score")
assert(FW:UpdateProfile(weighted.id, { weights = { strength = 3 } }))
equal(FW:GetScore("itemA", weighted), 22)
equal(scoreCalls, 2, "weight edits invalidate score without reparsing item")
equal(itemReads, 1)
assert(FW:UpdateProfile(weighted.id, { secondaryUnit = "rating" }))
equal(weighted.secondaryUnit, "percent", "rating updates retain percentage mode")
equal(FW:GetScore("itemA", weighted), 22)
weighted.secondaryUnit = "rating"
FW.DB.cache.scores.itemA[weighted.id] = nil
equal(FW:GetScore("itemA", weighted), 22, "scoring uses percentage points even if a caller mutates the profile field")
equal(records.itemA.profileScores[weighted.id].secondaryUnit, "percent", "diagnostics describe the unit actually scored")
assert(FW:UpdateProfile(weighted.id, { icon = 135943 }))
equal(weighted.secondaryUnit, "percent", "display edits also normalize legacy profile fields")
local second = assert(FW:CreateProfile("Second", { strength = 1 }))
equal(FW:GetScore("itemA", second), 4)
equal(FW:GetScore("itemA", weighted), 22)
equal(FW.DB.cache.scores.itemA[weighted.id].score, 22)
equal(FW.DB.cache.scores.itemA[second.id].score, 4, "scores are independent for each profile")

records.noSecondary = { key = "noSecondary", stats = { strength = 2 }, percentStats = {}, ratingStats = {}, warnings = {} }
equal(FW:GetScore("noSecondary", weighted), 6, "a stat absent from an item contributes zero")
records.percentOnly = { key = "percentOnly", stats = {}, percentStats = { hit = 1 }, ratingStats = {}, warnings = {} }
equal(FW:GetScore("percentOnly", weighted), 10, "percentage-only secondary stats are sufficient")
records.ratingOnly = { key = "ratingOnly", stats = {}, percentStats = {}, ratingStats = { hit = 12 }, warnings = {} }
local unavailable, unavailableError = FW:GetScore("ratingOnly", weighted)
equal(unavailable, 0, "known subtotal is shown when the selected secondary unit is missing")
contains(FW:ItemIssueSummary(unavailableError, weighted), "percentage points")
check(not unavailableError.partial, "a profile unit mismatch does not corrupt the parsed item record")
check(FW:ItemHasIssues(unavailableError, weighted), "the affected profile receives a score-specific warning")
check(not FW:ItemHasIssues(unavailableError, second), "an unweighted unit mismatch does not affect a different profile")
equal(FW.DB.cache.scores.ratingOnly, nil, "partial unit calculations are never cached")
records.unresolved = { key = "unresolved", stats = {}, percentStats = {}, ratingStats = {}, unresolvedStats = { hit = true }, partial = true, warnings = { "Unknown hit unit" } }
local unresolvedScore, unresolvedError = FW:GetScore("unresolved", weighted)
equal(unresolvedScore, 0)
contains(FW:ItemIssueSummary(unresolvedError, weighted), "unavailable")
equal(FW:GetScore("unresolved", second), 0, "unweighted unknown secondary stats do not prevent scoring")
records.partial = { key = "partial", stats = { strength = 5 }, percentStats = {}, ratingStats = {}, partial = true, warnings = { "Proc is unweighted" } }
local partialScore, partialRecord = FW:GetScore("partial", second)
equal(partialScore, 5)
check(partialRecord.partial, "item warnings remain available to the tooltip")
equal(FW.DB.cache.items.partial, nil, "partial item reads are not persisted")
equal(FW.DB.cache.scores.partial, nil, "partial scores are not persisted")
local partialReadsBefore, partialCallsBefore = itemReads, scoreCalls
equal(FW:GetScore("partial", second), 5)
equal(itemReads, partialReadsBefore + 1, "partial item data is read again")
equal(scoreCalls, partialCallsBefore + 1, "partial totals are recalculated as data becomes available")
records.unresolvedBase = { key = "unresolvedBase", stats = {}, percentStats = {}, ratingStats = {}, unresolvedStats = { strength = true }, partial = true }
local baseFailure, baseError = FW:GetScore("unresolvedBase", second)
equal(baseFailure, 0, "an unavailable base stat contributes zero to the known subtotal")
contains(FW:ItemIssueSummary(baseError, second), "could not be read completely")
records.knownBase = { key = "knownBase", stats = { strength = 3 }, unresolvedStats = { strength = true }, partial = true }
local knownSubtotal, knownRecord = FW:GetScore("knownBase", second)
equal(knownSubtotal, 3, "reliable API values survive a partially unreadable tooltip for the same stat")
check(knownRecord.scoreIssues[second.id].missingStats.strength)
local report = FW:GetIssueReport()
equal(report.format, "ZwykValuesIssues")
check(report.itemCount >= 5, "all encountered issue variants are journaled")
local knownEntry = FW.DB.itemIssues.knownBase
equal(knownEntry.profileScores[second.id].score, 3, "export contains the calculated known subtotal")
equal(knownEntry.profileScores[second.id].name, second.name)
equal(knownEntry.profileScores[second.id].revision, second.revision)
equal(knownEntry.profileScores[second.id].partial, true)
check(json.Encode(report), "combined diagnostics are valid JSON")
records.resolvedUnit = { key = "resolvedUnit", stats = { strength = 2 }, ratingStats = { hit = 12 },
    percentStats = {}, unresolvedStats = { hit = true }, partial = true, warnings = { "Unknown API field" } }
local unitFixProfile = assert(FW:CreateProfile("Fix units", { strength = 1, hit = 2 }))
equal(FW:GetScore("resolvedUnit", unitFixProfile), 2)
check(FW.DB.itemIssues.resolvedUnit.scoreIssues[unitFixProfile.id], "missing percentage contribution is recorded")
assert(FW:UpdateProfile(unitFixProfile.id, { secondaryUnit = "rating" }))
equal(FW:GetScore("resolvedUnit", unitFixProfile), 2, "legacy requests never substitute rating values")
check(FW.DB.itemIssues.resolvedUnit.scoreIssues[unitFixProfile.id], "rating-only values remain unavailable")
records.resolvedUnit.percentStats.hit = 1
equal(FW:GetScore("resolvedUnit", unitFixProfile), 4)
equal(FW.DB.itemIssues.resolvedUnit.scoreIssues[unitFixProfile.id], nil, "recomputed successful unit selection removes the old profile warning")
equal(FW.DB.itemIssues.resolvedUnit.profileScores[unitFixProfile.id].score, 4)
local missing, missingError = FW:GetScore("notLoaded", second)
equal(missing, nil)
contains(missingError, "loading")

local savedDB, readsBefore, callsBefore = FW.DB, itemReads, scoreCalls
FW.DB = nil
FW:Initialize()
equal(FW.DB, savedDB)
equal(FW:GetScore("itemA", weighted), 22)
equal(scoreCalls, callsBefore, "persistent scores survive reinitialization")
equal(itemReads, readsBefore)
check(FW:InvalidateItem("itemA"))
equal(FW.DB.cache.items.itemA, nil)
equal(FW.DB.cache.scores.itemA, nil)
equal(FW:GetScore("itemA", weighted), 22)
equal(itemReads, readsBefore + 1)
FW:InvalidateCache()
equal(FW:GetCacheCount(), 0)
equal(next(FW.DB.cache.scores), nil)
equal(FW.DB.itemIssues.knownBase.profileScores[second.id].score, 3, "clearing the normal cache preserves problem items")

for index = 1, FW.CACHE_LIMIT + 5 do
    local key = "bounded" .. index
    records[key] = { key = key, stats = { strength = index }, percentStats = {}, ratingStats = {}, warnings = {} }
    equal(FW:GetScore(key, second), index)
end
equal(FW:GetCacheCount(), FW.CACHE_LIMIT)
equal(#FW.DB.cache.itemOrder, FW.CACHE_LIMIT)
equal(FW.DB.cache.items.bounded1, nil)
equal(FW.DB.cache.scores.bounded1, nil, "evicting an item also evicts its profile scores")
check(FW.DB.cache.items.bounded2005)
check(FW.DB.itemIssues.knownBase, "normal cache eviction preserves diagnostic history")
assert(FW:DeleteProfile(second.id))
for _, scores in pairs(FW.DB.cache.scores) do equal(scores[second.id], nil) end
FW:ClearItemIssues()
equal(FW:GetIssueReport().itemCount, 0)
contains(assert(json.Encode(FW:GetIssueReport())), '"items":[]')

print("Core/JSON: " .. passed .. " checks passed.")
