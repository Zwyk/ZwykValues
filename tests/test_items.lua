-- Plain Lua 5.1+ tests; execute from the ZwykValues project directory.
local source = "./"
if not io.open("Stats.lua", "r") then source = "../" end
local function equal(actual, expected, message)
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function approx(actual, expected)
    assert(actual and math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. expected)
end
local current, locale, cached, modernCalls, legacyCalls, loads, tooltipCalls
local weaponSlots = { INVTYPE_WEAPON=true, INVTYPE_WEAPONMAINHAND=true, INVTYPE_WEAPONOFFHAND=true,
    INVTYPE_2HWEAPON=true, INVTYPE_RANGED=true, INVTYPE_RANGEDRIGHT=true, INVTYPE_THROWN=true }
local function newReader(item)
    current, locale, cached, modernCalls, legacyCalls, loads, tooltipCalls = item, "enUS", true, 0, 0, 0, 0
    GetBuildInfo = function() return "1.60.0", "12345", "today", 16000 end
    UnitLevel = function() return 60 end
    GetLocale = function() return locale end
    GetItemInfo = function(link)
        if not cached then return nil end
        local equipLoc = current.equipLoc or "INVTYPE_HEAD"
        local classID = current.classID or (weaponSlots[equipLoc] and 2 or 4)
        local subclassID = current.subclassID or (classID == 2 and 7 or 4)
        return current.name or "Test Item", link, 4, 60, 60, classID == 2 and "Weapon" or "Armor",
            classID == 2 and "Sword" or "Plate", 1, equipLoc, nil, nil, classID, subclassID
    end
    GetItemInfoInstant = nil
    GetItemStats = function() legacyCalls = legacyCalls + 1; return current.legacy end
    C_Item = {
        IsItemDataCachedByID = function() return cached end,
        RequestLoadItemDataByID = function() loads = loads + 1 end,
        GetItemStats = function() modernCalls = modernCalls + 1; return current.raw end,
    }
    C_TooltipInfo = {
        GetHyperlink = function()
            tooltipCalls = tooltipCalls + 1
            if not current.lines then return nil end
            local lines = {}
            for _, text in ipairs(current.lines) do lines[#lines + 1] = { leftText = text } end
            return { lines = lines }
        end,
    }
    CreateFrame = nil
    RETRIEVING_ITEM_INFO, RETRIEVING_DATA = "Retrieving item information", "Retrieving data"
    ZwykValuesDB, ZwykPointsDB, ForeverWeightsDB = nil, nil, nil
    local FW = {}
    assert(loadfile(source .. "JSON.lua"))("ZwykValues", FW)
    assert(loadfile(source .. "Stats.lua"))("ZwykValues", FW)
    assert(loadfile(source .. "Core.lua"))("ZwykValues", FW)
    assert(loadfile(source .. "Items.lua"))("ZwykValues", FW)
    FW:Initialize()
    return FW
end

local FW = newReader({ raw = {
    ITEM_MOD_STRENGTH_SHORT = 20, ITEM_MOD_HIT_MELEE_RATING_SHORT = 14,
    ITEM_MOD_HIT_SPELL_RATING_SHORT = 14, ITEM_MOD_HIT_RANGED_RATING_SHORT = 14,
    ITEM_MOD_CRIT_RATING_SHORT = 8,
}, lines = { "Test Item", "+20 Strength", "Equip: Increases your chance to hit with melee attacks by 1%.",
    "Equip: Increases your chance to hit with spells by 1%.", "Critical Strike +0.5%" } })
local item = assert(FW:GetItem("item:100:0:0:0:0:0:7:99"))
equal(item.stats.strength, 20)
equal(item.ratingStats.hit, 14, "merged hit counted once")
equal(item.percentStats.hit, 1, "merged percentage counted once")
equal(item.percentStats.meleeCrit, 0.5); equal(item.percentStats.spellCrit, 0.5)
equal(item.partial, false)
equal(item.unresolvedStats.hit, nil)
local cachedItem = FW:GetItem("item:100:0:0:0:0:0:7:99")
equal(cachedItem, item, "persisted record reused")
equal(modernCalls, 1, "cache skips item extraction")
local second = assert(FW:GetItem("item:100:3:0:0:0:0:7:99"))
assert(second.key ~= item.key, "enchant variants need distinct keys")
assert(FW:ItemKey("item:100:3:4:0:0:0:7:99") ~= second.key, "gem variants need distinct keys")
local before = FW:ItemKey("item:100")
locale = "frFR"
assert(FW:ItemKey("item:100") ~= before, "locale affects item key")
locale = "enUS"
UnitLevel = function() return 59 end
assert(FW:ItemKey("item:100") ~= before, "level affects item key")

FW = newReader({ raw = nil, legacy = { ITEM_MOD_AGILITY_SHORT = 11 }, lines = { "Test Item", "+11 Agility" } })
item = assert(FW:GetItem("item:101"))
equal(item.stats.agility, 11)
equal(legacyCalls, 1, "nil modern API falls back")

FW = newReader({ raw = {}, lines = { "Test Item", "Binds when picked up" } })
cached = false
local missing, message = FW:GetItem("item:102")
equal(missing, nil)
assert(message:find("loading"))
equal(loads, 1)
equal(next(FW.DB.cache.items), nil, "unloaded data is never cached")
FW:GetItem("item:102")
equal(loads, 1, "load request is deduplicated")
cached = true
item = assert(FW:GetItem("item:102"))
equal(item.partial, false, "loaded statless items remain valid")
assert(FW.DB.cache.items[item.key], "statless item caches once loaded")

FW = newReader({ raw = {}, equipLoc = "INVTYPE_WEAPON", lines = {
    "Test Sword", "20 - 40 Damage", "Speed 2.00", "(15.0 damage per second)",
    "Equip: Increases damage done by Holy spells and effects by up to 12.",
    "Equip: Restores 4 mana per 5 sec.",
} })
item = assert(FW:GetItem("item:103"))
equal(item.stats.lowDamage, 20); equal(item.stats.highDamage, 40)
equal(item.stats.weaponDamage, nil, "base weapon average is not a flat damage bonus"); equal(item.stats.speed, 2)
equal(item.stats.dps, 15); equal(item.stats.holyDamage, 12); equal(item.stats.mp5, 4)
equal(item.stats.spellDamage, nil, "school damage doesn't become generic damage")

FW = newReader({ raw = {}, equipLoc = "INVTYPE_RANGEDRIGHT", lines = {
    "Test Bow", "10 - 20 Damage", "Speed 1.50",
} })
item = assert(FW:GetItem("item:104"))
equal(item.stats.rangedSpeed, 1.5); equal(item.stats.rangedDps, 10)
equal(item.stats.dps, nil, "ranged DPS kept distinct")

FW = newReader({ raw = { ITEM_MOD_SPELL_POWER_SHORT = 30 }, lines = {
    "Test Wand", "Équipé : Augmente les dégâts et les soins produits par les sorts et effets magiques de 30 au maximum.",
    "+10 Intelligence", "Équipé : Augmente vos chances d'infliger un coup critique de 1,5%.",
    "Équipé : Rend 6 points de mana toutes les 5 sec.",
    "Équipé : Augmente la compétence de défense de 5.",
} })
locale = "frFR"
item = assert(FW:GetItem("item:105"))
equal(item.stats.intellect, 10); equal(item.stats.spellDamage, 30); equal(item.stats.healing, 30)
equal(item.stats.mp5, 6); equal(item.percentStats.defense, 5)
approx(item.percentStats.meleeCrit, 1.5); approx(item.percentStats.spellCrit, 1.5); equal(item.partial, false)

FW = newReader({ raw = { ITEM_MOD_HASTE_RATING_SHORT = 12 }, lines = {
    "Test Item", "Equip: Increases your haste rating by 12.",
} })
item = assert(FW:GetItem("item:106"))
equal(item.ratingStats.haste, 12); equal(item.percentStats.haste, nil)
equal(item.unresolvedStats.haste, true, "no guessed rating conversion")
equal(item.partial, false, "valid raw rating can be cached")

FW = newReader({ raw = {}, lines = { "Test Item", "+8 Strength",
    "Use: Increases Strength by 100 for 20 sec.",
    "Equip: Has a chance to increase your attack power by 200.",
    "Equip: Increases your critical strike chance by 10% while in Bear Form.",
    "(2) Set: Increases your chance to hit by 2%.",
} })
item = assert(FW:GetItem("item:107"))
equal(item.stats.strength, 8); equal(item.stats.attackPower, nil)
equal(item.percentStats.meleeCrit, nil); equal(item.percentStats.spellCrit, nil); equal(item.percentStats.hit, nil)
equal(#item.unrecognizedLines, 0, "procs and conditional effects don't become debug stat warnings")

FW = newReader({ raw = { ITEM_MOD_STRENGTH_SHORT = 5 }, lines = {
    "Test Item", "+5 Strength", "Magister's Regalia (2/8)", "Equip: Increases your chance to hit by 2%.",
} })
item = assert(FW:GetItem("item:108"))
equal(item.percentStats.hit, nil, "set section excluded")

FW = newReader({ raw = { ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_FUTURE_SHORT = 10 }, lines = {
    "Test Item", "+3 Strength and +1% Dodge", "+10 Weapon Skill", "+5 Mana", "Requires Level 60", "Durability 10 / 10",
} })
item = assert(FW:GetItem("item:109"))
equal(item.partial, true)
equal(#item.unrecognizedLines, 2)
equal(item.stats.mana, 5, "flat Mana is a supported resource stat")
equal(item.unrecognizedLines[1].text, "+3 Strength and +1% Dodge")
equal(next(FW.DB.cache.items), nil, "incomplete extraction is not persisted")
equal(FW:GetIssueReport().itemCount, 1, "issue item is persisted independently of the normal cache")
local journal = FW:GetIssueReport().items[1]
equal(journal.name, "Test Item")
equal(journal.raw.ITEM_MOD_FUTURE_SHORT, 10)
equal(journal.tooltipLines[2], "+3 Strength and +1% Dodge")
equal(journal.tooltipDetails[2].leftText, "+3 Strength and +1% Dodge")
equal(journal.tooltipSource, "C_TooltipInfo")
equal(journal.source, "C_Item.GetItemStats")
equal(journal.build.build, "12345")
equal(journal.locale, "enUS")
equal(journal.stats.strength, 3)
FW:GetItem("item:109")
equal(FW:GetIssueReport().itemCount, 1, "repeated reads update one diagnostic entry per variant")
FW:GetItem("item:109:1")
equal(FW:GetIssueReport().itemCount, 2, "item variants receive distinct diagnostic entries")
local diagnostic = assert(FW:GetRawItemStats("item:109"))
equal(diagnostic.unknownKeys[1], "ITEM_MOD_FUTURE_SHORT")
assert(FW:IsPotentialStatLine("+4 Unknown stat"))
equal(FW:IsPotentialStatLine("Use: +4 Strength for 20 sec."), false)

FW = newReader({ raw = { ITEM_MOD_STAMINA_SHORT = 20, RESISTANCE0_NAME = 300, ITEM_MOD_EXTRA_ARMOR_SHORT = 50 },
    lines = { "Test Item", "+20 Stamina", "300 Armor" } })
item = assert(FW:GetItem("item:110"))
equal(item.stats.armor, 250); equal(item.stats.armorBonus, 50)
equal(item.stats.health, nil, "derived stamina health is not counted")

FW = newReader({ raw = {}, lines = { "Test Item" } })
item = assert(FW:GetItem("item:111"))
equal(item.partial, true)
equal(next(FW.DB.cache.items), nil, "empty incomplete tooltip is not cached")

FW = newReader({ raw = { ITEM_MOD_STRENGTH_SHORT = 1 }, lines = { "Test Item", "+1 Strength" } })
for id = 1, 2002 do assert(FW:GetItem("item:" .. (1000 + id))) end
equal(#FW.DB.cache.itemOrder, 2000, "cache is bounded")
equal(FW.DB.cache.items[FW:ItemKey("item:1001")], nil, "oldest cache entry evicted")
assert(FW.DB.cache.items[FW:ItemKey("item:3002")])

FW = newReader({ raw = { ITEM_MOD_CRIT_RATING_SHORT = 14 }, lines = {
    "Test Item", "Critical Strike +1%", "Equip: Increases your chance to critically hit with spells by 1%.",
} })
item = assert(FW:GetItem("item:112"))
equal(item.percentStats.meleeCrit, 1, "generic crit contributes to attack chance")
equal(item.percentStats.spellCrit, 2, "distinct generic and spell effect rows add, even at the same amount")
equal(item.percentStats.hit, nil, "critically hit is not ordinary hit chance")

FW = newReader({ raw = {}, lines = {
    "Test Item", "Equip: Increases your chance to critically hit with spells by 0.5%.",
} })
item = assert(FW:GetItem("item:1121"))
equal(item.percentStats.spellCrit, 0.5, "a standalone critically hit with spells line supplies spell crit")
equal(item.percentStats.meleeCrit, nil, "spell-only chance cannot supply melee crit")
equal(item.percentStats.hit, nil)
equal(item.partial, false)
local criticalProfile = assert(FW:CreateProfile("Crit wording", {spellCrit=10,meleeCrit=50,hit=100}))
equal(FW:GetScore("item:1121",criticalProfile), 5, "crit wording cannot acquire an extra hit contribution")

FW = newReader({ raw = { ITEM_MOD_SPELL_DAMAGE_DONE = 20, ITEM_MOD_POWER_REGEN0_SHORT = 4 }, lines = {
    "Test Item", "Equip: Increases Fire spell damage by up to 20.", "Equip: Restores 4 mana per 5 sec.",
} })
item = assert(FW:GetItem("item:113"))
equal(item.stats.fireDamage, 20); equal(item.stats.spellDamage, nil)
equal(item.stats.mp5, 4, "POWER_REGEN0 API maps to mana per five")

FW = newReader({ raw = {}, lines = { "Test Item", "Retrieving item information" } })
missing = FW:GetItem("item:114")
equal(missing, nil, "tooltip placeholder is still loading")
equal(next(FW.DB.cache.items), nil)
equal(loads, 1)

FW = newReader({ raw = {}, equipLoc = "INVTYPE_WEAPON", lines = { "Test Item", "20 - 40 Damage", "Speed 2.00", "+5 Weapon Damage" } })
item = assert(FW:GetItem("item:115"))
equal(item.stats.weaponDamage, 5, "flat damage bonus parsed separately from ranges")
equal(item.stats.dps, 15)

FW = newReader({ raw = {}, lines = { "Test Item", "1,234 Armor" } })
item = assert(FW:GetItem("item:116"))
equal(item.stats.armor, 1234, "English thousands separators")

FW = newReader({ raw = {}, lines = { "Test Item", "1\194\160234 Armure", "Critique +1,5%" } })
locale = "frFR"
item = assert(FW:GetItem("item:117"))
equal(item.stats.armor, 1234, "French thousands separators")
equal(item.percentStats.meleeCrit, 1.5, "French decimal separators")
equal(item.percentStats.spellCrit, 1.5)

FW = newReader({ raw = {}, lines = { "Test Item", "Equip: Reduces the chance for your attacks to be dodged or parried by 1%." } })
item = assert(FW:GetItem("item:118"))
equal(item.percentStats.expertise, 1)
equal(item.percentStats.dodge, nil); equal(item.percentStats.parry, nil)

FW = newReader({ raw = {}, lines = { "Test Item", "Équipé : Réduit les chances que vos attaques soient esquivées ou parées de 1,5%." } })
locale = "frFR"
item = assert(FW:GetItem("item:119"))
equal(item.percentStats.expertise, 1.5)

FW = newReader({ raw = { ITEM_MOD_STRENGTH_SHORT = 0 / 0,
    ITEM_MOD_FUTURE_SHORT = function() end, [1] = math.huge, [false] = "Unexpected key" }, lines = { "Test Item", "+2 Strength" } })
item = assert(FW:GetItem("item:120"))
local badAPIProfile = assert(FW:CreateProfile("Known subtotal", { strength = 2 }))
equal(FW:GetScore("item:120", badAPIProfile), 4, "known tooltip values remain usable after an invalid API value")
local exported = assert(FW.JSON.Encode(FW:GetIssueReport()))
local exportedReport = assert(FW.JSON.Decode(exported))
equal(exportedReport.items[1].raw.ITEM_MOD_STRENGTH_SHORT, "[non-finite number]", "invalid raw values cannot break combined export")
equal(exportedReport.items[1].raw.ITEM_MOD_FUTURE_SHORT, "[function value unavailable]")
equal(exportedReport.items[1].raw["1"], "[non-finite number]")
equal(exportedReport.items[1].raw["false"], "Unexpected key", "unexpected API key types are still exportable")
equal(exportedReport.items[1].profileScores[badAPIProfile.id].score, 4)
equal(FW:GetIssueReport().itemCount, 1)
FW:InvalidateCache()
equal(FW:GetIssueReport().itemCount, 1, "debug export survives explicit score-cache clearing")
local preservedDB = FW.DB
FW.DB = nil
FW:Initialize()
equal(FW.DB, preservedDB)
equal(FW:GetIssueReport().itemCount, 1, "diagnostics persist through reinitialization")

FW = newReader({ raw = { ITEM_MOD_HIT_RATING_SHORT = 12 }, lines = { "Test Item", "Hit Rating +12" } })
local mismatchProfile = assert(FW:CreateProfile("Percent", { hit = 5 }))
item = assert(FW:GetItem("item:121"))
equal(item.partial, false, "native rating extraction remains valid")
equal(FW:GetIssueReport().itemCount, 0, "valid native ratings are not automatically parser failures")
local mismatchScore, mismatchRecord, mismatchWarning = FW:GetScore("item:121", mismatchProfile)
equal(mismatchScore, 0)
assert(mismatchWarning:find("percentage points", 1, true))
equal(mismatchRecord.partial, false)
assert(FW:ItemHasIssues(mismatchRecord, mismatchProfile))
equal(FW:GetIssueReport().itemCount, 1, "unit-specific scoring failures are also exportable")
assert(FW.JSON.Encode(FW:GetIssueReport()))

local protected = setmetatable({}, { __tostring = function() error("secret value must not be stringified") end })
issecretvalue = function(value) return value == protected end
FW = newReader({ raw = { ITEM_MOD_STRENGTH_SHORT = protected, [protected] = 8 },
    lines = { "Test Item", "+5 Strength" } })
item = assert(FW:GetItem("item:122"))
local secretReport = assert(FW.JSON.Decode(assert(FW.JSON.Encode(FW:GetIssueReport()))))
equal(secretReport.items[1].raw.ITEM_MOD_STRENGTH_SHORT, "[secret value unavailable]")
equal(secretReport.items[1].raw["[secret key unavailable]"], 8)
issecretvalue = nil

-- Regression cases taken from the six-item Forever 1.60.1 issue export.
local foreverCases = {
    { id = 15493, name = "Bloodspattered Loincloth of the Knight", equipLoc = "INVTYPE_LEGS",
        raw = { ITEM_MOD_SPELL_POWER_SHORT = 2, ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_STRENGTH_SHORT = 2, RESISTANCE0_NAME = 141 },
        lines = { "141 Armor", "+2 Strength", "+4 Stamina",
            "Equip: Increases damage and healing done by magical spells and effects by up to 2.",
            "Enchanted: Stamina +2 and Armor +16" },
        expected = { armor = 157, strength = 2, stamina = 6, spellDamage = 2, healing = 2 } },
    { id = 15509, name = "Grunt's Handwraps of Magic", equipLoc = "INVTYPE_HAND",
        raw = { ITEM_MOD_SPELL_POWER_SHORT = 6, RESISTANCE0_NAME = 107 },
        lines = { "107 Armor", "Equip: Increases damage and healing done by magical spells and effects by up to 6.",
            "Enchanted: Stamina +2 and Armor +16" },
        expected = { armor = 123, stamina = 2, spellDamage = 6, healing = 6 } },
    { id = 15510, name = "Grunt's Belt of the Physician", equipLoc = "INVTYPE_WAIST",
        raw = { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1,
            ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4, ITEM_MOD_SPIRIT_SHORT = 2, RESISTANCE0_NAME = 94 },
        lines = { "94 Armor", "+4 Intellect", "+2 Spirit",
            "Equip: Increases healing done by up to 4 and damage done by up to 1 for all magical spells and effects." },
        expected = { armor = 94, intellect = 4, spirit = 2, spellDamage = 1, healing = 4 } },
    { id = 250621, name = "Strange Copper Boots", equipLoc = "INVTYPE_FEET",
        raw = { ITEM_MOD_SPELL_POWER_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 4, RESISTANCE0_NAME = 109 },
        lines = { "109 Armor", "+4 Stamina", "Equip: Increases damage and healing done by magical spells and effects by up to 5.",
            "Enchanted: Stamina +2 and Armor +16", "<Made by Zwyk Zw>" },
        expected = { armor = 125, stamina = 6, spellDamage = 5, healing = 5 } },
    { id = 270023, name = "Tanned Shoulderpads", equipLoc = "INVTYPE_SHOULDER",
        raw = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 3, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 9,
            ITEM_MOD_STAMINA_SHORT = 9, RESISTANCE0_NAME = 73 },
        lines = { "73 Armor", "+9 Stamina",
            "Equip: Increases healing done by up to 9 and damage done by up to 3 for all magical spells and effects." },
        expected = { armor = 73, stamina = 9, spellDamage = 3, healing = 9 } },
    { id = 9779, name = "Bandit Cloak of the Hierophant", equipLoc = "INVTYPE_CLOAK",
        raw = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 2,
            ITEM_MOD_SPIRIT_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 2, RESISTANCE0_NAME = 16 },
        lines = { "16 Armor", "+2 Stamina", "+1 Spirit",
            "Equip: Increases healing done by up to 2 and damage done by up to 1 for all magical spells and effects." },
        expected = { armor = 16, stamina = 2, spirit = 1, spellDamage = 1, healing = 2 } },
}
for _, sample in ipairs(foreverCases) do
    table.insert(sample.lines, 1, sample.name)
    FW = newReader(sample)
    item = assert(FW:GetItem("item:" .. sample.id .. ":8481"))
    for key, value in pairs(sample.expected) do equal(item.stats[key], value, sample.name .. " " .. key) end
    for key, value in pairs(item.stats) do equal(value, sample.expected[key], sample.name .. " unexpected " .. key) end
    equal(item.partial, false, sample.name .. " resolves without warnings")
    equal(#item.unrecognizedLines, 0)
    equal(next(item.unresolvedStats), nil)
    equal(FW:GetIssueReport().itemCount, 0)
    equal(FW:GetItem("item:" .. sample.id .. ":8481"), item, "resolved item caches")
    equal(item.parserVersion, 11, "old persisted parser results receive a new key")
end

FW = newReader({ raw = { RESISTANCE0_NAME = 141, ITEM_MOD_STAMINA_SHORT = 4 },
    lines = { "Test Item", "157 Armor", "+4 Stamina", "Enchanted: Stamina +2 and Armor +16" } })
item = assert(FW:GetItem("item:123:8481"))
equal(item.stats.armor, 157, "a displayed total that includes an armor enchant is not increased twice")
equal(item.stats.stamina, 6)

FW = newReader({ raw = { ITEM_MOD_STAMINA_SHORT = 4 },
    lines = { "Test Item", "Enchanted: Stamina +2" } })
item = assert(FW:GetItem("item:124:8481"))
equal(item.stats.stamina, 6, "an enchant supplements API base stats even without a normal stat line")

FW = newReader({ raw = {}, lines = { "Test Item",
    "Equip: Increases healing done by up to 9 and damage done by up to 3 for all magical spells and effects." } })
item = assert(FW:GetItem("item:125"))
equal(item.stats.healing, 9); equal(item.stats.spellDamage, 3)
equal(item.partial, false, "combined healing and spell damage can be read without API values")

FW = newReader({ raw = { ITEM_MOD_STAMINA_SHORT = 4 },
    lines = { "Test Item", "+4 Stamina", "Enchanted: Stamina +2 and Armor +16 and Mystery Flux +7" } })
item = assert(FW:GetItem("item:126:8481"))
equal(item.stats.stamina, 6); equal(item.stats.armor, 16)
equal(item.partial, true, "recognized enchant clauses cannot hide an unknown clause")
equal(#item.unrecognizedLines, 1)
equal(item.unresolvedStats.stamina, nil, "a fully recognized clause is not marked unresolved")
equal(next(FW.DB.cache.items), nil)
assert(FW:IsPotentialStatLine("Enchanted: Grants 7 Mystery Flux"))

FW = newReader({ raw = {}, lines = { "Test Item",
    "Equip: Increases healing done by up to 9 and damage done by up to 3 for all magical spells and effects and grants 7 Mystery Flux." } })
item = assert(FW:GetItem("item:127"))
equal(item.partial, true, "combined spell wording must match the entire effect")
equal(item.stats.healing, nil); equal(item.stats.spellDamage, nil)

FW = newReader({ raw = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 20 }, lines = { "Test Item",
    "Equip: Increases Fire spell damage by up to 20.", "Enchanted: Spell Damage +5" } })
item = assert(FW:GetItem("item:128:1"))
equal(item.stats.fireDamage, 20)
equal(item.stats.spellDamage, 5, "an enchant cannot preserve a false generic alias for school-only damage")
equal(item.partial, false)

-- Ammunition is an explicit scoring exception and contributes ranged DPS,
-- without requiring a weapon's damage range or attack speed.
local originalAmmoFormat = ITEM_AMMO_DAMAGE_TEMPLATE
for index, sample in ipairs({
    {raw={},line="Adds 7.5 damage per second",expected=7.5},
    {raw={},line="Ajoute 7,5 points de dégâts par seconde",locale="frFR",expected=7.5},
    {raw={},line="Ajoute 8 dégâts par seconde",locale="frFR",expected=8},
    {raw={},line="Projectile DPS: 9.5",format="Projectile DPS: %1$.1f",expected=9.5},
    {raw={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=7.5,ITEM_MOD_DAMAGE_PER_SECOND=7.5},
        line="Adds 7.5 damage per second",expected=7.5},
    {raw={ITEM_MOD_DAMAGE_PER_SECOND=0},line="Arrow",expected=0},
    {raw={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=6},line="Bullet",expected=6},
}) do
    ITEM_AMMO_DAMAGE_TEMPLATE = sample.format
    FW = newReader({raw=sample.raw,classID=6,subclassID=2,equipLoc="INVTYPE_AMMO",lines={"Test Arrow",sample.line}})
    locale = sample.locale or "enUS"
    item = assert(FW:GetItem("item:" .. (500+index)))
    equal(item.stats.rangedDps,sample.expected)
    equal(item.stats.dps,nil,"ammo DPS is never melee DPS")
    equal(item.stats.rangedSpeed,nil); equal(item.stats.lowDamage,nil); equal(item.stats.highDamage,nil)
    equal(item.partial,false,"ammo does not need weapon speed or damage range")
    equal(next(item.unresolvedStats),nil); equal(#item.warnings,0)
    local weights = assert(FW:CreateProfile("Ammo",{rangedDps=2,dps=100}))
    equal(FW:GetScore(item.link,weights),sample.expected*2,"only the ranged DPS weight applies")
    equal(FW:GetBaseScore(item.link,weights),sample.expected*2)
end
ITEM_AMMO_DAMAGE_TEMPLATE = originalAmmoFormat

FW = newReader({raw={},classID=6,subclassID=3,equipLoc="INVTYPE_AMMO",lines={"Unreadable Bullet","Bullet"}})
item = assert(FW:GetItem("item:510"))
equal(item.partial,true); equal(item.unresolvedStats.rangedDps,true)
equal(FW.DB.cache.items[item.key],nil,"missing ammo DPS is never cached as a complete zero")

FW = newReader({raw={},classID=6,subclassID=2,equipLoc="INVTYPE_AMMO",lines={"Arrow","Adds 7.5 damage per second"}})
local ammoProfile = assert(FW:CreateProfile("Cache migration",{rangedDps=2,dps=100}))
local oldAmmoKey = FW:ItemKey("item:511"):gsub("^11|","4|")
FW.DB.cache.items[oldAmmoKey] = {key=oldAmmoKey,stats={dps=7.5},equipLoc="INVTYPE_AMMO"}
FW.DB.cache.scores[oldAmmoKey] = {[ammoProfile.id]={revision=ammoProfile.revision,score=750}}
equal(FW:GetScore("item:511",ammoProfile),15,"parser update ignores ammo previously cached as melee DPS")
equal(modernCalls,1,"stale ammo stats are read again")

FW = newReader({raw={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=7.5},classID=6,subclassID=2,equipLoc="INVTYPE_AMMO"})
item = assert(FW:GetItem("item:512"))
equal(item.stats.rangedDps,7.5)
for _, key in ipairs({"dps","lowDamage","highDamage","weaponDamage","speed","rangedSpeed"}) do
    equal(item.unresolvedStats[key],nil,"ammo never requires weapon fields, even without a tooltip")
end
local apiAmmoProfile = assert(FW:CreateProfile("API ammo",{rangedDps=2,rangedSpeed=10,dps=100}))
local apiAmmoScore, _, apiAmmoNote = FW:GetScore(item.link,apiAmmoProfile)
equal(apiAmmoScore,15)
assert(not apiAmmoNote:find("speed",1,true),"missing ammo tooltip must not invent a speed warning")

-- Excluded item types stop at metadata. Positive API/tooltip stats on a recipe,
-- crafting output or malformed equipment category must never trigger parsing.
for index, sample in ipairs({
    {name="Recipe: Mithril Shield Spike",classID=9,subclassID=4,equipLoc=""},
    {name="Mithril Shield Spike",classID=7,subclassID=1,equipLoc=""},
    {name="Flint and Tinder",classID=15,subclassID=0,equipLoc=""},
    {name="Strength Potion",classID=0,subclassID=1,equipLoc=""},
    {name="Quest Prop",classID=12,subclassID=0,equipLoc="INVTYPE_HOLDABLE"},
    {name="Unsupported Armor",classID=4,subclassID=99,equipLoc="INVTYPE_HEAD"},
    {name="Unsupported Weapon",classID=2,subclassID=99,equipLoc="INVTYPE_WEAPON"},
    {name="Armor With Invalid Slot",classID=4,subclassID=4,equipLoc="INVTYPE_UNKNOWN"},
    {name="Bag",classID=1,subclassID=0,equipLoc="INVTYPE_BAG"},
}) do
    sample.raw = {ITEM_MOD_STRENGTH_SHORT=99}
    sample.lines = {sample.name,"+99 Strength","Equip: Grants 3 Mystery Flux."}
    FW = newReader(sample)
    local link = "item:" .. (600+index) .. ":42:0"
    local raw = assert(FW:GetRawItemStats(link))
    equal(raw.ready,true); equal(raw.excluded,true,sample.name .. " is excluded from the raw reader")
    equal(next(raw.raw),nil); equal(#raw.tooltipLines,0); equal(#raw.tooltipDetails,0)
    equal(modernCalls,0); equal(legacyCalls,0); equal(tooltipCalls,0,
        sample.name .. " never scans a tooltip")
    item = assert(FW:GetItem(link))
    equal(next(item.stats),nil); equal(item.partial,false); equal(#item.warnings,0)
    local profile = assert(FW:CreateProfile("No non-gear values",{strength=1}))
    local total, record, status = FW:GetScore(link,profile)
    equal(total,nil); equal(record.name,sample.name); equal(status,"excluded")
    -- Simulate a validly keyed SavedVariables record from earlier code that
    -- already contains a positive score; classification still wins over it.
    item.stats = {strength=99}
    FW.DB.cache.items[item.key] = item
    FW.DB.cache.scores[item.key] = {[profile.id]={revision=profile.revision,score=99}}
    total, record, status = FW:GetScore(link,profile,true)
    equal(total,nil); equal(record,item); equal(status,"excluded",
        "cached non-gear cannot score through the equipped-baseline bypass")
    equal(FW:GetBaseScore(link,profile),nil,"non-gear Base scores stay excluded")
    equal(modernCalls,0); equal(legacyCalls,0); equal(tooltipCalls,0,
        sample.name .. " never reads API stats or tooltips, including cached/Base paths")
end

-- Profile exclusions also stop unread candidates before stat/tooltip APIs,
-- without placing an empty record in the shared item cache. Other profiles and
-- equipped baselines must still read the real stats from the same variants.
FW = newReader({name="Unread plate helmet",classID=4,subclassID=4,equipLoc="INVTYPE_HEAD",
    raw={ITEM_MOD_STRENGTH_SHORT=99},lines={"Unread plate helmet","+99 Strength"}})
local unchecked = assert(FW:CreateProfile("Plate unchecked",{strength=1}))
local included = assert(FW:CreateProfile("Plate included",{strength=1}))
assert(FW:UpdateProfile(unchecked.id,{itemFilters={armor={["4"]=false}}}))
local unreadLink, unreadBase = "item:790:42:0", "item:790:0:0"
local total, metadata, status = FW:GetScore(unreadLink,unchecked)
equal(total,nil); equal(status,"excluded"); equal(next(metadata.stats),nil)
equal(modernCalls,0); equal(legacyCalls,0); equal(tooltipCalls,0,
    "unchecked unread candidates avoid stat APIs and tooltip scans")
equal(FW.DB.cache.items[FW:ItemKey(unreadLink)],nil,"profile-excluded metadata is never cached as an empty shared item")
equal(FW.DB.cache.scores[FW:ItemKey(unreadLink)],nil)
total, metadata, status = FW:GetBaseScore(unreadLink,unchecked)
equal(total,nil); equal(status,"excluded")
equal(modernCalls,0); equal(tooltipCalls,0,"unchecked fresh Base variant also stops before parsing")
equal(FW.DB.cache.items[FW:ItemKey(unreadBase)],nil)
equal(FW:GetScore(unreadLink,included),99,"another profile reads actual stats after an unread exclusion")
equal(modernCalls,1); equal(tooltipCalls,1)
equal(FW.DB.cache.items[FW:ItemKey(unreadLink)].stats.strength,99)
equal(FW:GetScore(unreadLink,unchecked,true),99,"equipped baseline bypass uses the real shared item stats")
local freshBaselineLink = "item:791:43:0"
equal(FW:GetScore(freshBaselineLink,unchecked,true),99,"uncached equipped baseline bypass also reads real stats")
equal(modernCalls,2); equal(tooltipCalls,2)
equal(FW:GetBaseScore(freshBaselineLink,unchecked),nil)
equal(modernCalls,2); equal(tooltipCalls,2,"unchecked second Base variant does not scan")
equal(FW.DB.cache.items[FW:ItemKey("item:791:0:0")],nil)
equal(FW:GetBaseScore(freshBaselineLink,included),99,"included profile can later parse a previously excluded Base variant")
equal(modernCalls,3); equal(tooltipCalls,3)

-- Flat Mana is independent from Intellect and from Mana per 5 seconds. API
-- aliases and matching tooltip text describe the same stat, not extra copies.
FW = newReader({raw={ITEM_MOD_MANA_SHORT=100,ITEM_MOD_MANA=100,ITEM_MOD_INTELLECT_SHORT=5},
    lines={"Mana ring","+100 Mana","+5 Intellect","Equip: Restores 4 mana per 5 sec."}})
local manaProfile = assert(FW:CreateProfile("Mana resources",{mana=0.4,mp5=2,intellect=1}))
item = assert(FW:GetItem("item:800"))
equal(item.stats.mana,100); equal(item.stats.mp5,4); equal(item.stats.intellect,5)
equal(item.partial,false); equal(#item.diagnostic.ignoredKeys,0)
equal(FW:GetScore(item.link,manaProfile),53,"Mana is scored once separately from Intellect and MP5")

for index, text in ipairs({"+80 points de mana","Mana +80","+80 mana maximum","+80 Maximum Mana"}) do
    FW = newReader({raw={},lines={"Mana ring",text}})
    locale = (index == 1 or index == 3) and "frFR" or "enUS"
    item = assert(FW:GetItem("item:" .. (810+index)))
    equal(item.stats.mana,80,"English/French flat Mana: " .. text)
    equal(item.partial,false)
end
local previousManaLabel = ITEM_MOD_MANA_SHORT
ITEM_MOD_MANA_SHORT = "Magicka"
FW = newReader({raw={},lines={"Localized resource ring","+45 Magicka"}})
item = assert(FW:GetItem("item:820"))
equal(item.stats.mana,45,"native localized Mana labels are available to tooltip parsing")
ITEM_MOD_MANA_SHORT = previousManaLabel

FW = newReader({raw={ITEM_MOD_INTELLECT_SHORT=10},lines={"Intellect ring","+10 Intellect",
    "Equip: Restores 5 mana per 5 sec.","Use: Restores 300 mana over 10 sec. (2 Min Cooldown)"}})
item = assert(FW:GetItem("item:821"))
equal(item.stats.mana,nil,"Intellect, MP5 and resource restoration never become flat Mana")
equal(item.stats.mp5,5); equal(item.onUseStats.mana,nil,"restoring Mana is not a temporary flat-stat buff")

-- Enchant and averaged-use paths reuse the same flat-stat handling as Health.
FW = newReader({raw={ITEM_MOD_MANA_SHORT=100},lines={"Mana trinket","+100 Mana"}})
C_TooltipInfo.GetHyperlink = function(link)
    local lines={{leftText="Mana trinket"},{leftText="+100 Mana"},
        {leftText="Use: Increases your maximum mana by 120 for 10 sec. (2 Min Cooldown)"}}
    if link:match("item:822:42") then lines[#lines+1]={leftText="Enchanted: Mana +20"} end
    return {lines=lines}
end
manaProfile = assert(FW:CreateProfile("Flat Mana variants",{mana=0.4}))
item = assert(FW:GetItem("item:822:42:0"))
equal(item.stats.mana,120,"flat Mana enchants add once to the base stat")
equal(item.onUseStats.mana,10,"flat maximum-Mana buffs are averaged from duration and cooldown")
equal(item.partial,false)
equal(FW:GetScore(item.link,manaProfile),48)
equal(FW:GetBaseScore(item.link,manaProfile),40,"Base strips the enchant but retains inherent Mana")
equal(FW:GetAverageUseScore(item.link,manaProfile),44,"average-use Mana is added to unenchanted Base")

FW = newReader({raw={ITEM_MOD_MANA_SHORT=60},lines={"Bijou de mana","+60 points de mana",
    "Enchanté : +15 points de mana",
    "Utiliser : Augmente votre mana maximum de 120 pendant 10 sec. (2 min de recharge)"}})
locale = "frFR"
item = assert(FW:GetItem("item:8221:42:0"))
equal(item.stats.mana,75,"French Mana enchants share the flat-resource path")
equal(item.onUseStats.mana,10,"French maximum-Mana buffs use the same uptime calculation")
equal(item.partial,false)

FW = newReader({raw={ITEM_MOD_MANA_SHORT="unavailable"},lines={"Unread Mana ring","+2 Intellect"}})
manaProfile = assert(FW:CreateProfile("Unread Mana",{mana=1}))
item = assert(FW:GetItem("item:823"))
equal(item.unresolvedStats.mana,true,"unavailable native Mana values remain unresolved")
equal(item.partial,true)
local manaSubtotal, manaRecord = FW:GetScore(item.link,manaProfile)
equal(manaSubtotal,0,"unread Mana contributes only its known subtotal")
assert(manaRecord.scoreIssues[manaProfile.id].missingStats.mana)

FW = newReader({raw={ITEM_MOD_MANA_SHORT=60},lines={"Mana ring","+60 Mana"}})
manaProfile = assert(FW:CreateProfile("Mana cache migration",{mana=1}))
local oldManaKey = FW:ItemKey("item:824"):gsub("^11|","9|")
FW.DB.cache.items[oldManaKey] = {key=oldManaKey,stats={},equipLoc="INVTYPE_HEAD",classID=4,subclassID=4}
FW.DB.cache.scores[oldManaKey] = {[manaProfile.id]={revision=manaProfile.revision,score=0}}
equal(FW:GetScore("item:824",manaProfile),60,"old complete records that ignored Mana are reparsed")
equal(modernCalls,1)

-- Critical chance has two independent percentage channels. A generic effect
-- contributes once to each; scoped tooltip rows remain separate effects.
for index,sample in ipairs({
    {"Critical Strike +1%",1,1},
    {"Spell Critical Strike +2%",nil,2},
    {"Melee Critical Strike +3%",3,nil},
    {"Ranged Critical Strike +4%",4,nil},
    {"Physical Critical Strike Chance +5%",5,nil},
    {"Equip: Improves your chance to get a critical strike with spells by 1%.",nil,1},
    {"Equip: Improves your chance to get a critical strike with attacks by 2%.",2,nil},
    {"Equip: Increases your chance to critically hit with ranged attacks by 3%.",3,nil},
    {"Equip: Increases the critical strike chance of your spells by 4%.",nil,4},
    {"Equip: Increases your chance to get a critical strike with melee and ranged attacks by 2%.",2,nil},
    {"Equip: Increases your chance to critically hit with attacks and spells by 3%.",3,3},
    {"Critique +1,5%",1.5,1.5,"frFR"},
    {"Coup critique des sorts +2,5%",nil,2.5,"frFR"},
    {"Chances de coup critique en mêlée +3,5%",3.5,nil,"frFR"},
    {"Équipé : Augmente vos chances d'infliger un coup critique avec les sorts de 1,5%.",nil,1.5,"frFR"},
    {"Équipé : Augmente vos chances d’infliger un coup critique avec vos attaques de 2,5%.",2.5,nil,"frFR"},
    {"Équipé : Augmente les chances de coup critique de vos sorts de 4,5%.",nil,4.5,"frFR"},
}) do
    FW = newReader({raw={},lines={"Critical ring",sample[1]}})
    locale = sample[4] or "enUS"
    item = assert(FW:GetItem("item:" .. (900+index)))
    equal(item.percentStats.meleeCrit,sample[2],sample[1] .. " melee channel")
    equal(item.percentStats.spellCrit,sample[3],sample[1] .. " spell channel")
    equal(item.percentStats.crit,nil,"the merged parser key is retired")
    equal(item.percentStats.hit,nil,"critical hits are never ordinary Hit")
    equal(item.partial,false,sample[1] .. " complete extraction")
    equal(next(item.unresolvedStats),nil)
end

FW = newReader({raw={ITEM_MOD_CRIT_RATING_SHORT=14,ITEM_MOD_CRIT_RATING=14,
    ITEM_MOD_CRIT_MELEE_RATING_SHORT=14,ITEM_MOD_CRIT_RANGED_RATING_SHORT=14,
    ITEM_MOD_CRIT_SPELL_RATING_SHORT=20,ITEM_MOD_SPELL_CRIT_RATING=20},lines={"Critical ring",
    "Critical Strike +1%","Equip: Increases your spell critical strike chance by 1%.",
    "Equip: Increases your melee critical strike chance by 2%."}})
item = assert(FW:GetItem("item:930"))
equal(item.ratingStats.meleeCrit,14,"API melee/ranged/generic rating aliases do not add")
equal(item.ratingStats.spellCrit,20,"API spell rating remains separate and aliases do not add")
equal(item.percentStats.meleeCrit,3); equal(item.percentStats.spellCrit,2)
equal(item.unresolvedStats.meleeCrit,nil); equal(item.unresolvedStats.spellCrit,nil)
local splitProfile = assert(FW:CreateProfile("Asymmetric crit",{meleeCrit=2,spellCrit=7,hit=100}))
equal(FW:GetScore(item.link,splitProfile),20,"native rating never duplicates readable percentage chance")
equal(next(item.diagnostic.unknownKeys),nil)

for index,sample in ipairs({
    {{ITEM_MOD_CRIT_SPELL_SHORT=2},nil,true},
    {{ITEM_MOD_CRIT_MELEE_SHORT=2},true,nil},
    {{ITEM_MOD_CRIT_RANGED_SHORT=2},true,nil},
    {{ITEM_MOD_CRIT_SHORT=2},true,true},
    {{ITEM_MOD_CRIT_SPELL_RATING_SHORT="unavailable"},nil,true},
}) do
    FW = newReader({raw=sample[1],lines={"Unread critical ring","+1 Strength"}})
    item = assert(FW:GetItem("item:" .. (940+index)))
    equal(item.unresolvedStats.meleeCrit,sample[2],"scoped API unresolved melee")
    equal(item.unresolvedStats.spellCrit,sample[3],"scoped API unresolved spell")
    equal(item.unresolvedStats.crit,nil)
end

for index,sample in ipairs({
    {"Equip: Increases your spell critical strike rating by 20.",nil,20},
    {"Equip: Increases your melee critical strike rating by 10.",10,nil},
    {"Equip: Increases your critical strike rating by 30.",30,30},
    {"Équipé : Augmente votre score de coup critique des sorts de 25.",nil,25,"frFR"},
}) do
    FW = newReader({raw={},lines={"Rating ring",sample[1]}})
    locale = sample[4] or "enUS"
    item = assert(FW:GetItem("item:" .. (950+index)))
    equal(item.ratingStats.meleeCrit,sample[2]); equal(item.ratingStats.spellCrit,sample[3])
    equal(next(item.percentStats),nil,"ratings cannot be guessed into percentages")
end

FW = newReader({raw={},lines={"Spell mystery ring",
    "Equip: Improves your spell critical strike chance by an unknown amount."}})
item = assert(FW:GetItem("item:960"))
equal(item.unresolvedStats.spellCrit,true); equal(item.unresolvedStats.meleeCrit,nil)

FW = newReader({raw={},lines={"Unsafe critical ring",
    "Equip: Increases your critical strike damage by 20%.",
    "Equip: Increases your spell critical strike chance by 10% while casting.",
    "Equip: Has a chance to increase your spell critical strike chance by 5%.",
    "Use: Increases your spell critical strike chance by 20% for 10 sec.",
    "(2) Set: Increases your critical strike chance by 5%."}})
item = assert(FW:GetItem("item:961"))
equal(next(item.percentStats),nil,"critical damage, conditional effects and set bonuses are not static chance")
equal(item.percentStats.hit,nil)
equal(next(item.unresolvedStats),nil,"critical damage cannot mark missing critical chance")
equal(item.partial,false,"a known out-of-schema damage multiplier does not block upgrades")
equal(item.ignoredTooltipStats[1].reason,"Critical damage bonuses have no stat in the weight schema.")
FW = newReader({raw={},lines={"Bague critique","Équipé : Augmente les dégâts de vos coups critiques de 20%."}})
locale="frFR"
item=assert(FW:GetItem("item:962"))
equal(next(item.percentStats),nil); equal(next(item.unresolvedStats),nil); equal(item.partial,false)

-- Enchants use the same channels but remain absent from the Base variant.
FW = newReader({raw={},lines={"Enchanted critical ring","Critical Strike +1%"}})
C_TooltipInfo.GetHyperlink = function(link)
    local rows={{leftText="Enchanted critical ring"},{leftText="Critical Strike +1%"}}
    if link:match("item:970:42") then rows[#rows+1]={leftText="Enchanted: Spell Critical Strike +2% and Melee Critical Strike +3%"} end
    return {lines=rows}
end
splitProfile = assert(FW:CreateProfile("Crit variants",{meleeCrit=2,spellCrit=7}))
item = assert(FW:GetItem("item:970:42:0"))
equal(item.percentStats.meleeCrit,4); equal(item.percentStats.spellCrit,3)
equal(item.partial,false)
equal(FW:GetScore(item.link,splitProfile),29)
equal(FW:GetBaseScore(item.link,splitProfile),9,"Base excludes both enchant critical channels")
FW = newReader({raw={ITEM_MOD_CRIT_MELEE_RATING_SHORT=10},lines={"Enchanted rating ring",
    "Enchanted: Spell Critical Strike Rating +6 and Melee Critical Strike Rating +4"}})
item = assert(FW:GetItem("item:971:42"))
equal(item.ratingStats.meleeCrit,14); equal(item.ratingStats.spellCrit,6)
equal(item.unresolvedStats.meleeCrit,true); equal(item.unresolvedStats.spellCrit,true)
equal(item.partial,false)
FW = newReader({raw={ITEM_MOD_CRIT_RATING_SHORT=10},lines={"Unknown base critical ring",
    "Enchanted: Spell Critical Strike +1%"}})
item = assert(FW:GetItem("item:972:42"))
equal(item.percentStats.spellCrit,1,"known enchant percentage is retained as a subtotal")
equal(item.unresolvedStats.spellCrit,true,"an enchant cannot resolve unknown base spell critical chance")
equal(item.unresolvedStats.meleeCrit,true,"a spell enchant cannot resolve melee chance")
FW = newReader({raw={ITEM_MOD_CRIT_RATING_SHORT=10},lines={"Known spell base critical ring",
    "Spell Critical Strike +2%","Enchanted: Spell Critical Strike +1%"}})
item = assert(FW:GetItem("item:973:42"))
equal(item.percentStats.spellCrit,3)
equal(item.unresolvedStats.spellCrit,nil,"an inherent percentage does resolve its own API unit")
equal(item.unresolvedStats.meleeCrit,true,"spell percentages do not resolve unknown melee ratings")

FW = newReader({raw={},lines={"Physical scope ring","Critical Strike +1%",
    "Physical Critical Strike +2%","Melee Critical Strike +1%","Melee Critical Strike +2%",
    "Ranged Critical Strike +3%"}})
item=assert(FW:GetItem("item:974"))
equal(item.percentStats.meleeCrit,6,"generic plus all-attack bonuses add to the largest attack-specific total")
equal(item.percentStats.spellCrit,1,"physical scope bonuses never leak into spell chance")
FW = newReader({raw={},lines={"Matching attack scopes","Melee Critical Strike +1%","Ranged Critical Strike +1%"}})
item=assert(FW:GetItem("item:975"))
equal(item.percentStats.meleeCrit,1,"one percent to melee and ranged is one percent, not two")
equal(item.percentStats.spellCrit,nil)
FW = newReader({raw={},lines={"Enchanted attack scopes","Critical Strike +1%",
    "Enchanted: Melee Critical Strike +1% and Ranged Critical Strike +1%"}})
item=assert(FW:GetItem("item:976:42"))
equal(item.percentStats.meleeCrit,2,"enchant attack scopes use the same maximum")
equal(item.percentStats.spellCrit,1)
FW = newReader({raw={},lines={"Combined enchant scope","Enchanted: Melee and Ranged Critical Strike +1%"}})
item=assert(FW:GetItem("item:977:42"))
equal(item.percentStats.meleeCrit,1); equal(item.percentStats.spellCrit,nil)
equal(item.partial,false,"an attack-scope conjunction is not an enchant clause separator")

FW = newReader({raw={ITEM_MOD_CRIT_SPELL_RATING_SHORT=8,ITEM_MOD_CRIT_MELEE_RATING_SHORT=14},
    lines={"Rating scopes","Critical Strike Rating +5","Spell Critical Strike Rating +7",
        "Melee Critical Strike Rating +2","Ranged Critical Strike Rating +2","Melee Critical Strike Rating +3"}})
item=assert(FW:GetItem("item:978"))
equal(item.ratingStats.meleeCrit,14,"API aliases max against the aggregated tooltip total")
equal(item.ratingStats.spellCrit,12,"distinct generic and spell rating rows add before the API maximum")
equal(item.unresolvedStats.meleeCrit,true);equal(item.unresolvedStats.spellCrit,true)
FW = newReader({raw={},lines={"Mixed crit units","Critical Strike +1%","Spell Critical Strike Rating +6"}})
item=assert(FW:GetItem("item:979"))
equal(item.percentStats.spellCrit,1);equal(item.unresolvedStats.spellCrit,true,"known % cannot resolve another rating effect")
equal(item.unresolvedStats.meleeCrit,nil)
FW = newReader({raw={},lines={"Enchanted mixed units","Critical Strike +1%","Enchanted: Spell Critical Strike Rating +6"}})
item=assert(FW:GetItem("item:980:42"))
equal(item.percentStats.spellCrit,1);equal(item.unresolvedStats.spellCrit,true,"known base % cannot resolve an enchant rating")
equal(item.unresolvedStats.meleeCrit,nil)

print("Items tests passed")
