local _, FW = ...

local unpack = unpack or table.unpack
local catalog, categories, dirty, eventFrame, knownIcons
local nativeLists, identities = {}, {}
local categoryOrder = { playerClass = 1, spells = 2, items = 3, other = 4 }
local categoryLabels = { playerClass = "Your class", spells = "Spells", items = "Items", other = "Other" }
local accents = {
    ["à"]="a", ["â"]="a", ["ä"]="a", ["á"]="a", ["ã"]="a", ["å"]="a",
    ["À"]="a", ["Â"]="a", ["Ä"]="a", ["Á"]="a", ["Ã"]="a", ["Å"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e", ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
    ["î"]="i", ["ï"]="i", ["í"]="i", ["ì"]="i", ["Î"]="i", ["Ï"]="i", ["Í"]="i", ["Ì"]="i",
    ["ô"]="o", ["ö"]="o", ["ó"]="o", ["ò"]="o", ["õ"]="o", ["Ô"]="o", ["Ö"]="o", ["Ó"]="o", ["Ò"]="o", ["Õ"]="o",
    ["ù"]="u", ["û"]="u", ["ü"]="u", ["ú"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u", ["Ú"]="u",
    ["ç"]="c", ["Ç"]="c", ["ñ"]="n", ["Ñ"]="n", ["œ"]="oe", ["Œ"]="oe", ["æ"]="ae", ["Æ"]="ae",
}

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function text(value)
    if readable(value) and (type(value) == "string" or type(value) == "number") then return tostring(value) end
end

local function normalize(value)
    value = text(value) or ""
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[%z\1-\127\194-\244][\128-\191]*", function(character) return accents[character] or character:lower() end)
    return value:gsub("[%p%c]", " "):gsub("%s+", " ")
end

local function pack(...) return { n = select("#", ...), ... } end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local values = pack(pcall(fn, ...))
    if values[1] then return unpack(values, 2, values.n) end
end

local function bounded(value, maximum)
    if readable(value) and type(value) == "number" and value == value then
        return math.max(0, math.min(maximum, math.floor(value)))
    end
    return 0
end

local function iconPath(value)
    if not readable(value) then return end
    if type(value) == "string" then
        value = tonumber(value) or (value:lower():match("^interface[\\/]") and value or ("Interface\\Icons\\" .. value))
    end
    return FW:ValidateProfileIcon(value)
end

local function filenameKey(value)
    return value:lower():gsub("/", "\\"):gsub("%.[bt][lg][pa]$", "")
end

local function iconKey(icon)
    return type(icon) == "string" and filenameKey(icon) or icon
end

local function buildCatalog()
    local result, seen, available = {}, {}, {}
    local className, classToken = call(UnitClass, "player")
    className, classToken = text(className), text(classToken)
    local classWord = classToken and (" " .. normalize(classToken) .. " ")

    local function identify(value)
        local icon = iconPath(value)
        if not icon then return end
        local identity = identities[iconKey(icon)]
        if identity then return icon, identity.key, identity.path end
        local path, key
        if type(icon) == "number" then
            path = text(call(C_Texture and C_Texture.GetFilenameFromFileDataID, icon)) or false
            if path == "" then path = false end
            key = path and filenameKey(path) or icon
        else
            path = icon
            local id = call(GetFileIDFromPath, icon)
            if type(id) == "number" and iconPath(id) then
                local filename = text(call(C_Texture and C_Texture.GetFilenameFromFileDataID, id))
                key = filename and filename ~= "" and filenameKey(filename) or id
            else key = filenameKey(icon) end
        end
        identities[iconKey(icon)] = { key = key, path = path }
        return icon, key, path
    end

    local function add(value, category, label, metadata, details)
        local icon, key, path = identify(value)
        if not icon then return end
        available[iconKey(icon)] = true
        local entry = seen[key]
        if not entry then
            local fallback = type(path) == "string" and path:match("([^\\/]+)$") or ("Icon " .. tostring(icon))
            fallback = fallback:gsub("%.[bt][lg][pa]$", ""):gsub("_", " ")
            entry = { icon = icon, category = category, label = fallback, categories = {}, details = {}, _parts = {}, _seen = {}, _named = false }
            seen[key], result[#result + 1] = entry, entry
        end
        entry.categories[category] = true
        if categoryOrder[category] < categoryOrder[entry.category] then entry.category = category end
        local function append(fragment)
            fragment = text(fragment)
            if fragment and fragment ~= "" and not entry._seen[fragment] then
                entry._parts[#entry._parts + 1], entry._seen[fragment] = fragment, true
            end
        end
        append(icon); append(path); append(category); append(categoryLabels[category]); append(label)
        -- Explicit class tokens in native filenames are useful even for spells
        -- the character has not learned. Shared schools such as Holy are not
        -- evidence of class ownership and never trigger this promotion.
        if classWord and type(path) == "string" and (" " .. normalize(path) .. " "):find(classWord, 1, true) then
            entry.categories.playerClass = true
            entry.category = "playerClass"
            append(className); append(classToken); append(categoryLabels.playerClass)
        end
        if label and (not entry._named or normalize(label) < normalize(entry.label)) then entry.label, entry._named = label, true end
        for _, fragment in ipairs(metadata or {}) do append(fragment) end
        for _, detail in ipairs(details or {}) do
            if not entry._seen["detail:" .. detail] then
                entry.details[#entry.details + 1], entry._seen["detail:" .. detail] = detail, true
            end
        end
        return entry
    end

    -- Blizzard's IconDataProvider uses these separate native spell/item lists.
    for _, source in ipairs({ {"GetLooseMacroIcons", "spells"}, {"GetMacroIcons", "spells"},
        {"GetLooseMacroItemIcons", "items"}, {"GetMacroItemIcons", "items"} }) do
        local enumerate = _G[source[1]]
        local cached = nativeLists[source[1]]
        if type(enumerate) == "function" and (not cached or cached.api ~= enumerate or #cached.icons == 0) then
            local icons = {}
            if pcall(enumerate, icons) then
                cached = { api = enumerate, icons = icons }
                nativeLists[source[1]] = cached
            end
        end
        for _, icon in ipairs(cached and cached.icons or {}) do add(icon, source[2]) end
    end

    local classLine = call(C_SpellBook and C_SpellBook.GetClassSkillLineInfo)
    if type(classLine) == "table" then
        local classIcon = add(classLine.iconID, "playerClass", nil, { className or "", classToken or "", text(classLine.name) or "" })
        if classIcon and not classIcon._named then classIcon.label = className or text(classLine.name) or classIcon.label end
    end

    -- Only enumerate actual spellbook slots. Never walk arbitrary spell IDs.
    -- Vanilla's first skill line is General; the remaining non-guild lines are
    -- the player's class schools, including future/off-spec spells if provided.
    local spellBook = C_SpellBook
    local modern = spellBook and type(spellBook.GetNumSpellBookSkillLines) == "function"
        and type(spellBook.GetSpellBookSkillLineInfo) == "function" and type(spellBook.GetSpellBookItemInfo) == "function"
        and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player ~= nil
    local bank = modern and Enum.SpellBookSpellBank.Player or (BOOKTYPE_SPELL or "spell")
    local count = bounded(call(modern and spellBook.GetNumSpellBookSkillLines or GetNumSpellTabs), 100)
    for index = 1, count do
        local line
        if modern then line = call(spellBook.GetSpellBookSkillLineInfo, index)
        else
            local name, icon, offset, slots, guild, offSpec, hidden, specID = call(GetSpellTabInfo, index)
            line = { name = name, iconID = icon, itemIndexOffset = offset, numSpellBookItems = slots,
                isGuild = guild, offSpecID = offSpec, shouldHide = hidden, specID = specID }
        end
        if type(line) == "table" and not line.shouldHide then
            local category = index > 1 and not line.isGuild and "playerClass" or "spells"
            local metadata = { text(line.name) or "" }
            if category == "playerClass" then
                metadata[#metadata + 1], metadata[#metadata + 2] = className or "", classToken or ""
            end
            local lineIcon = add(line.iconID, category, nil, metadata)
            if lineIcon and not lineIcon._named then lineIcon.label = text(line.name) or lineIcon.label end
            local offset, slots = bounded(line.itemIndexOffset, 10000), bounded(line.numSpellBookItems, 2000)
            for slot = offset + 1, offset + slots do
                local info, description
                if modern then
                    info = call(spellBook.GetSpellBookItemInfo, slot, bank)
                    description = call(spellBook.GetSpellBookItemDescription, slot, bank)
                else
                    local name, subName, nameSpellID = call(GetSpellBookItemName, slot, bank)
                    local itemType, spellID = call(GetSpellBookItemInfo, slot, bank)
                    if itemType ~= "SPELL" and itemType ~= "FUTURESPELL" then spellID = nil end
                    info = { name = name, subName = subName, spellID = nameSpellID or spellID,
                        iconID = call(GetSpellTexture, slot, bank) }
                end
                if type(info) == "table" then
                    local id = text(info.spellID)
                    local spellDescription = id and text(call(C_Spell and C_Spell.GetSpellDescription or GetSpellDescription, info.spellID))
                    local parts = { unpack(metadata) }
                    parts[#parts + 1], parts[#parts + 2], parts[#parts + 3], parts[#parts + 4] = text(info.subName) or "", id or "", text(description) or "", spellDescription or ""
                    add(info.iconID, category, text(info.name), parts, id and { "Spell " .. id } or nil)
                end
            end
        end
    end

    local itemSeen = {}
    local function addItem(link, icon, location)
        if not text(link) or itemSeen[link] then return end
        itemSeen[link] = true
        local name, _, _, _, _, itemType, subtype, _, equipLoc, texture = call(C_Item and C_Item.GetItemInfo or GetItemInfo, link)
        local itemID = tostring(link):match("item:(%d+)")
        local slot = text(equipLoc) and text(_G[equipLoc]) or nil
        add(texture or icon, "items", text(name), { text(itemType) or "", text(subtype) or "", slot or "",
            text(equipLoc) or "", itemID or "", location },
            { itemID and ("Item " .. itemID) or location, table.concat({ text(itemType) or "", text(subtype) or "" }, " / ") })
    end
    for slot = 0, 19 do
        local link = call(GetInventoryItemLink, "player", slot)
        if link then addItem(link, call(GetInventoryItemTexture, "player", slot), "Equipped") end
    end
    local container = C_Container
    local getSlots = container and container.GetContainerNumSlots or GetContainerNumSlots
    local getLink = container and container.GetContainerItemLink or GetContainerItemLink
    for bag = 0, bounded(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4, 10) do
        for slot = 1, bounded(call(getSlots, bag), 200) do addItem(call(getLink, bag, slot), nil, "Bags") end
    end
    for _, profile in pairs(FW.DB and FW.DB.profiles or {}) do
        if type(profile) == "table" and profile.icon then add(profile.icon, "other") end
    end

    for _, entry in ipairs(result) do
        entry.categoryLabel = categoryLabels[entry.category]
        entry.searchText = normalize(table.concat(entry._parts, " "))
        entry.sortText = normalize(entry.label)
        entry._parts, entry._seen, entry._named = nil, nil, nil
    end
    table.sort(result, function(a, b)
        if a.category ~= b.category then return categoryOrder[a.category] < categoryOrder[b.category] end
        if a.sortText ~= b.sortText then return a.sortText < b.sortText end
        return tostring(a.icon) < tostring(b.icon)
    end)
    local groups = {}
    for _, key in ipairs({ "playerClass", "spells", "items", "other" }) do groups[#groups + 1] = { key = key, label = categoryLabels[key] } end
    return result, groups, available
end

function FW:InvalidateProfileIconCatalog()
    dirty = true
end

local function watchChanges()
    if eventFrame or type(CreateFrame) ~= "function" then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function() dirty = true end)
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_TEXT_UPDATE", "PLAYER_TALENT_UPDATE",
        "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

function FW:GetProfileIconCatalog()
    watchChanges()
    if catalog and not dirty then
        for _, profile in pairs(FW.DB and FW.DB.profiles or {}) do
            local icon = type(profile) == "table" and iconPath(profile.icon)
            if icon and not knownIcons[iconKey(icon)] then dirty = true break end
        end
    end
    if not catalog or dirty then
        local nextCatalog, nextCategories, available = buildCatalog()
        categories, knownIcons, dirty = nextCategories, available, false
        -- Catalog APIs can be unavailable while their Blizzard UI is loading.
        catalog = #nextCatalog > 0 and nextCatalog or nil
        return nextCatalog, categories
    end
    return catalog, categories
end

function FW:GetProfileIconCategories()
    local _, groups = self:GetProfileIconCatalog()
    return groups
end

function FW:FilterProfileIconCatalog(entries, query, category)
    local words, matches = {}, {}
    for word in normalize(query):gmatch("%S+") do words[#words + 1] = word end
    for _, entry in ipairs(entries or {}) do
        local match = not category or category == "all" or entry.category == category or entry.categories[category]
        for _, word in ipairs(words) do
            if not entry.searchText:find(word, 1, true) then match = false break end
        end
        if match then matches[#matches + 1] = entry end
    end
    return matches
end

function FW:SearchProfileIcons(query, category)
    return self:FilterProfileIconCatalog(self:GetProfileIconCatalog(), query, category)
end
