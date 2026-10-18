-- Rating is a display/import unit; the same canonical weights score once.
local FW = {}
for _, file in ipairs({"JSON.lua", "Stats.lua", "Core.lua"}) do assert(loadfile(file))("ZwykValues", FW) end
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function approx(actual, expected)
    checks = checks + 1
    assert(math.abs(actual - expected) < 1e-12, tostring(actual) .. " ~= " .. tostring(expected))
end
local factors = {meleeCrit=14, spellCrit=14, hit=10, haste=10, expertise=10, defense=1, dodge=12, parry=15, block=5}
for key, factor in pairs(factors) do
    equal(FW:GetRatingPerPercent(key), factor)
    approx(FW:WeightToDisplay(key, 28, "rating"), 28 / factor)
    approx(FW:WeightFromDisplay(key, 28 / factor, "rating"), 28)
    equal(FW:WeightToDisplay(key, -3.25, "percent"), -3.25)
end
equal(FW:WeightToDisplay("intellect", 0.764, "rating"), 0.764)
equal(FW:WeightFromDisplay("spellDamage", 1, "rating"), 1)
FW:Initialize()
local profile = assert(FW:CreateProfile("Converted weights", {hit=22.488, meleeCrit=6.8, spellCrit=6.8, haste=1.711}))
equal(profile.secondaryDisplayUnit, "percent")
local record = {key="item:1", link="item:1", classID=4, subclassID=4, equipLoc="INVTYPE_HEAD", stats={},
    percentStats={hit=1, meleeCrit=1, spellCrit=1, haste=1}, ratingStats={hit=10, meleeCrit=14, spellCrit=14, haste=10}}
function FW:GetItem() return record end
local initialScore = assert(FW:GetScore(record.link, profile))
approx(initialScore, 37.799)
local scoreEntry = FW.DB.cache.scores[record.key][profile.id]
local revision = profile.revision
assert(FW:UpdateProfile(profile.id, {secondaryDisplayUnit="rating"}))
equal(profile.secondaryUnit, "percent")
equal(profile.secondaryDisplayUnit, "rating")
equal(profile.revision, revision, "display preference does not invalidate scores")
equal(FW.DB.cache.scores[record.key][profile.id], scoreEntry)
equal(FW:GetScore(record.link, profile), initialScore)
approx(FW:WeightToDisplay("hit", profile.weights.hit, profile.secondaryDisplayUnit), 2.2488)
approx(FW:WeightToDisplay("meleeCrit", profile.weights.meleeCrit, profile.secondaryDisplayUnit), 6.8 / 14)
local copy = assert(FW:CopyProfile(profile.id))
equal(copy.secondaryDisplayUnit, "rating")
local encoded = assert(FW:ExportProfile(profile.id))
local decoded = assert(FW.JSON.Decode(encoded))
equal(decoded.secondaryUnit, "percent")
equal(decoded.secondaryDisplayUnit, "rating")
equal(decoded.weights.hit, 22.488, "export weights stay canonical, regardless of display")
local imported = assert(FW:ImportProfile(encoded))
equal(imported.secondaryDisplayUnit, "rating")
equal(imported.weights.hit, profile.weights.hit)
local bare = assert(FW:ImportProfile(assert(FW:ExportProfile(profile.id, true)), "Bare"))
equal(bare.secondaryDisplayUnit, "percent", "bare exports are percentage weights")
equal(bare.weights.hit, profile.weights.hit)
local count = #FW:GetProfiles()
decoded.secondaryDisplayUnit = "invalid"
equal(FW:ImportProfile(assert(FW.JSON.Encode(decoded))), nil)
equal(#FW:GetProfiles(), count, "invalid imports are atomic")
equal(FW:UpdateProfile(profile.id, {secondaryDisplayUnit="guessed", weights={hit=999}}), nil)
equal(profile.weights.hit, 22.488)
FW.DB = nil
FW:Initialize()
equal(profile.secondaryDisplayUnit, "rating", "display preference survives reload")
equal(profile.weights.hit, 22.488)
assert(FW:UpdateProfile(profile.id, {secondaryDisplayUnit="percent"}))
equal(FW:GetScore(record.link, profile), initialScore)
print("Display units: " .. checks .. " checks passed.")
