-- Run from the addon directory: luatex --luaonly tests/test_icon_catalog.lua
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local counters, frame, className, classToken, useSpellbook
local function count(key)
    counters[key] = (counters[key] or 0) + 1
end
local function total()
    local result = 0
    for _, value in pairs(counters) do result = result + value end
    return result
end
local paths = {
    [100] = "Interface/Icons/Spell_Holy_HolyBolt.blp",
    [200] = "Interface/Icons/Ability_Warrior_BattleShout.blp",
    [300] = "Interface/Icons/INV_Chest_Plate01.blp",
    [400] = "", -- Some native IDs have no resolvable filename.
    [500] = "",
    [600] = "Interface/Icons/INV_Misc_Herb_01.blp",
}
local function newCatalog()
    counters, frame, className, classToken, useSpellbook = {}, nil, "Paladin", "PALADIN", true
    GetFileIDFromPath = function(path)
        count("path")
        path = path:lower():gsub("/", "\\"):gsub("%.blp$", "")
        for id, filename in pairs(paths) do
            if filename:lower():gsub("/", "\\"):gsub("%.blp$", "") == path then return id end
        end
        return 0
    end
    C_Texture = { GetFilenameFromFileDataID = function(id) count("filename"); return paths[id] end }
    GetLooseMacroIcons = function(icons)
        count("macro")
        icons[1], icons[2], icons[3], icons[4] = 200, 100, 400, 500
    end
    GetMacroIcons = function(icons)
        count("macro")
        icons[1], icons[2], icons[3] = "Spell_Holy_HolyBolt", "spell_holy_holybolt.blp", "INV_Shared_Ability"
    end
    GetLooseMacroItemIcons = function(icons)
        count("macro")
        icons[1], icons[2], icons[3] = 300, 600, "INV_Shared_Ability"
    end
    GetMacroItemIcons = function(icons) count("macro"); icons[1] = "INV_Chest_Plate01" end
    UnitClass = function() count("class"); return className, classToken end
    Enum = { SpellBookSpellBank = { Player = 0 } }
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() count("lines"); return useSpellbook and 2 or 0 end,
        GetSpellBookSkillLineInfo = function(index)
            count("lineInfo")
            return index == 1 and { name = "General", itemIndexOffset = 0, numSpellBookItems = 1 }
                or { name = "Holy", iconID = 100, itemIndexOffset = 1, numSpellBookItems = 2 }
        end,
        GetSpellBookItemInfo = function(slot, bank)
            equal(bank, 0, "modern spellbook uses native player bank")
            count("spell")
            if slot == 1 then return { name = "Herbalism", subName = "Apprentice", iconID = 600, spellID = 2366 } end
            if slot == 2 then return { name = "Lumière sacrée", subName = "Rang 1", iconID = 100, spellID = 635 } end
            return { name = "Éclair lumineux", subName = "Rang 2", iconID = 100, spellID = 19750, isOffSpec = true }
        end,
        GetSpellBookItemDescription = function(slot)
            count("description")
            return slot > 1 and "Rend des points de vie à une cible alliée." or "Find herbs on the minimap."
        end,
    }
    GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemName, GetSpellBookItemInfo, GetSpellTexture = nil, nil, nil, nil, nil
    C_Spell = { GetSpellDescription = function(id)
        count("spellDescription")
        return id == 635 and "Restores health to a friendly target." or nil
    end }
    GetSpellDescription = nil
    GetInventoryItemLink = function(_, slot) count("inventory"); return slot == 5 and "item:1234" or nil end
    GetInventoryItemTexture = function() return 300 end
    C_Container = {
        GetContainerNumSlots = function(bag) count("bag"); return bag == 0 and 1 or 0 end,
        GetContainerItemLink = function() return "item:5678" end,
    }
    NUM_BAG_SLOTS = 4
    C_Item = { GetItemInfo = function(link)
        count("item")
        return link == "item:1234" and "Tortoise Armor" or "Emerald Vest", link, 2, 20, 10, "Armor", "Mail", 1, "INVTYPE_CHEST", 300
    end }
    INVTYPE_CHEST = "Chest"
    CreateFrame = function()
        frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(script, callback) self[script] = callback end
        return frame
    end
    local addon = { DB = { profiles = { one = { icon = "Interface\\Icons\\Custom_Profile_Icon" } } } }
    assert(loadfile("Core.lua"))("ZwykValues", addon)
    assert(loadfile("IconCatalog.lua"))("ZwykValues", addon)
    return addon
end

local FW = newCatalog()
equal(total(), 0, "loading addon does not enumerate icons, spells or items")
equal(frame, nil, "watcher is also lazy")
local catalog, groups = FW:GetProfileIconCatalog()
equal(groups[1].key, "playerClass"); equal(groups[2].key, "spells"); equal(groups[3].key, "items"); equal(groups[4].key, "other")
equal(catalog[1].category, "playerClass", "class spells precede all other icons")
equal(catalog[1].icon, 100, "texture IDs and native filenames are deduplicated")
equal(catalog[1].label, "Éclair lumineux", "a skillline label never replaces actual spell names")
equal(#FW:SearchProfileIcons("lumie sac"), 1, "accent insensitive partial words match across a spell name")
equal(#FW:SearchProfileIcons("ÉCLAIR"), 1, "uppercase accented queries match")
equal(#FW:SearchProfileIcons("19750"), 1, "shared icons retain every spell ID")
equal(#FW:SearchProfileIcons("635"), 1, "first spell ID remains searchable")
equal(#FW:SearchProfileIcons("rang 2"), 1, "ranks remain searchable")
equal(#FW:SearchProfileIcons("cible allie"), 1, "native spell descriptions are indexed")
equal(#FW:SearchProfileIcons("friendly target"), 1, "actual spell text is indexed alongside spellbook descriptions")
equal(#FW:SearchProfileIcons("palad"), 1, "class names and class tokens are indexed")
equal(#FW:SearchProfileIcons("holy bolt"), 1, "numeric icon filenames are searchable")
equal(#FW:SearchProfileIcons("100"), 1, "texture IDs are also searchable")
equal(#FW:SearchProfileIcons("tortoise"), 1, "equipped item names are indexed")
equal(#FW:SearchProfileIcons("emerald"), 1, "bag item names merge into the same icon")
equal(#FW:SearchProfileIcons("5678 mail chest"), 1, "item IDs, subtype and equipment slot combine")
equal(#FW:SearchProfileIcons("armor", "items"), 1, "category filtering preserves metadata searches")
equal(#FW:SearchProfileIcons("herbal" , "playerClass"), 0, "general spellbook professions are not misclassified as class abilities")
equal(#FW:SearchProfileIcons("herbal" , "spells"), 1, "profession spell names remain searchable")
equal(#FW:SearchProfileIcons("shared", "spells"), 1)
equal(#FW:SearchProfileIcons("shared", "items"), 1, "a shared native icon is available under either source category")
equal(#FW:SearchProfileIcons("custom", "other"), 1, "custom profile icons remain available")
equal(#FW:SearchProfileIcons("400"), 1)
equal(#FW:SearchProfileIcons("500"), 1, "empty filenames do not collapse unrelated numeric icons")
equal(#FW:SearchProfileIcons("does not exist"), 0)
equal(#FW:SearchProfileIcons("", "all"), #catalog)
equal(#FW:SearchProfileIcons("% . ["), #catalog, "query punctuation is literal input, never a Lua pattern")
local afterBuild = total()
local macros, filenames, reversePaths = counters.macro, counters.filename, counters.path
equal(FW:GetProfileIconCatalog(), catalog, "opening again reuses the catalog")
for _ = 1, 20 do FW:FilterProfileIconCatalog(catalog, "lumi rang", "all") end
equal(total(), afterBuild, "typing and reopening a clean picker perform no native API scans")
equal(frame.events.SPELLS_CHANGED, true); equal(frame.events.SPELL_TEXT_UPDATE, true)
equal(frame.events.BAG_UPDATE_DELAYED, true); equal(frame.OnUpdate, nil)
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
equal(total(), afterBuild, "events only mark the catalog dirty without background work")
local rebuilt = FW:GetProfileIconCatalog()
equal(rebuilt == catalog, false, "next opening rebuilds invalidated metadata")
equal(total() > afterBuild, true)
equal(rebuilt[1].icon, catalog[1].icon, "sorting is stable across rebuilds")
equal(counters.macro, macros, "bag changes reuse the native icon lists")
equal(counters.filename, filenames, "bag changes reuse numeric filenames")
equal(counters.path, reversePaths, "bag changes reuse filename identities")
frame.OnEvent(frame, "GET_ITEM_INFO_RECEIVED")
FW:GetProfileIconCatalog()
equal(counters.macro, macros, "normal item cache events never re-enumerate the static icon lists")
equal(counters.filename, filenames)
equal(counters.path, reversePaths)
local cachedItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(link)
    local _, itemLink, rarity, level, minimum, itemType, subtype, stack, equipLoc, icon = cachedItemInfo(link)
    return "Newly Named Chest", itemLink, rarity, level, minimum, itemType, subtype, stack, equipLoc, icon
end
frame.OnEvent(frame, "GET_ITEM_INFO_RECEIVED")
equal(#FW:SearchProfileIcons("newly named"), 1, "newly available dynamic item names are indexed on the next opening")
equal(counters.macro, macros)
equal(counters.filename, filenames)
equal(counters.path, reversePaths)

C_SpellBook.GetClassSkillLineInfo = function() return { name = "Paladin", iconID = 700 } end
FW:InvalidateProfileIconCatalog()
equal(#FW:SearchProfileIcons("paladin 700", "playerClass"), 1, "the native class crest is included")
equal(counters.macro, macros)

FW.DB.profiles.new = { icon = "Interface\\Icons\\New_Imported_Icon" }
equal(#FW:SearchProfileIcons("new imported", "other"), 1, "a newly imported custom icon joins an existing catalog")
equal(counters.macro, macros, "importing a custom icon reuses native catalogs")
local beforeKnownSelection = total()
FW.DB.profiles.new.icon = 100
FW:GetProfileIconCatalog()
equal(total(), beforeKnownSelection, "selecting a known native icon does not rebuild metadata")

GetMacroIcons = function(icons)
    count("macro")
    icons[1], icons[2], icons[3], icons[4] = 800, "Ability_Paladin_UnknownStrike", "Ability_Priest_UnknownStrike", "ClassIcon_Paladin"
end
FW:InvalidateProfileIconCatalog()
equal(#FW:SearchProfileIcons("800"), 1, "a replacement catalog API is refreshed")
equal(counters.macro, macros + 1, "only the changed native source is re-enumerated")
equal(#FW:SearchProfileIcons("unknownstrike", "playerClass"), 1, "explicit current-class filenames are prioritized without requiring a learned spell")
equal(#FW:SearchProfileIcons("priest unknownstrike", "playerClass"), 0, "other-class filenames are not promoted")
equal(#FW:SearchProfileIcons("paladin unknownstrike", "spells"), 1, "class promotion retains the original spell category")
equal(#FW:SearchProfileIcons("classicon paladin", "playerClass"), 1, "explicit native class icons are prioritized")
equal(#FW:SearchProfileIcons("warrior", "playerClass"), 0, "class ownership is not inferred from a different class token")

-- Fallback clients use the same bounded Vanilla spellbook ranges as Blizzard.
FW = newCatalog()
C_SpellBook, C_Spell, Enum, GetFileIDFromPath, C_Texture, C_Item, GetInventoryItemLink, C_Container = nil, nil, nil, nil, nil, nil, nil, nil
GetNumSpellTabs = function() return 2 end
GetSpellTabInfo = function(index)
    if index == 1 then return "General", nil, 0, 0, false end
    return "Retribution", nil, 0, 2, false
end
GetSpellBookItemName = function(slot, bank)
    equal(bank, "spell")
    return slot == 1 and "Crusader Strike" or "Divine Storm", "Rank 1", slot == 1 and 35395 or 53385
end
GetSpellBookItemInfo = function(slot) return "SPELL", slot == 1 and 35395 or 53385 end
GetSpellTexture = function() return "Spell_Holy_HolyBolt" end
GetSpellDescription = function() return "Deals Holy damage." end
local legacy = FW:GetProfileIconCatalog()
equal(legacy[1].category, "playerClass")
equal(legacy[1].label, "Crusader Strike")
equal(#FW:SearchProfileIcons("divine"), 1, "legacy shared texture retains alternate spell names")
equal(#FW:SearchProfileIcons("53385 damage"), 1, "legacy descriptions and IDs are indexed")

FW = newCatalog()
GetLooseMacroIcons, GetMacroIcons, GetLooseMacroItemIcons, GetMacroItemIcons = nil, nil, nil, nil
useSpellbook, GetInventoryItemLink, C_Container = false, nil, nil
FW.DB.profiles = {}
equal(#FW:GetProfileIconCatalog(), 0, "loading UI catalog APIs may temporarily have no icons")
GetMacroIcons = function(icons) icons[1] = 123456 end
equal(#FW:GetProfileIconCatalog(), 1, "an empty early catalog is not cached permanently")

print("Icon catalog: " .. checks .. " checks passed.")
