local _, FW = ...

-- Read-only Equipment Manager integration. Resolve stored locations to complete
-- links so enchants and random suffixes are retained; item IDs alone are unsafe.
-- API shape and location decoding follow the Forever FrameXML EquipmentManager.
local baselineRevision = 0
local optionsCache, contexts = nil, {}

local function playerGUID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    return ok and type(guid) == "string" and guid or nil
end

local function call(getter, ...)
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, ...)
    return ok and value or nil
end

local function equipmentAPI()
    return C_EquipmentSet and type(C_EquipmentSet.GetEquipmentSetIDs) == "function" and
        type(C_EquipmentSet.GetEquipmentSetInfo) == "function" and C_EquipmentSet or nil
end

function FW:InvalidateEquipmentSetBaselines()
    baselineRevision = baselineRevision + 1
    optionsCache, contexts = nil, {}
end

function FW:GetEquipmentSetOptions()
    if optionsCache then return optionsCache.options, optionsCache.error end
    local api, guid = equipmentAPI(), playerGUID()
    local options, errorText = {}, nil
    if not api or not guid then
        errorText = "Equipment Manager sets are unavailable on this character."
    else
        local ids = call(api.GetEquipmentSetIDs)
        if type(ids) ~= "table" then
            errorText = "Equipment Manager set data is loading."
        else
            for _, id in ipairs(ids) do
                if type(id) == "number" then
                    local ok, name, icon, setID = pcall(api.GetEquipmentSetInfo, id)
                    if ok and type(name) == "string" and name ~= "" and setID == id then
                        options[#options+1] = {setID=id, name=name, icon=icon, character=guid,
                            target={mode="set", setID=id, name=name, character=guid}}
                    end
                end
            end
            table.sort(options, function(a, b)
                if a.name:lower() == b.name:lower() then return a.setID < b.setID end
                return a.name:lower() < b.name:lower()
            end)
        end
    end
    optionsCache = {options=options, error=errorText}
    return options, errorText
end

local function itemLinkAtLocation(location)
    local data
    if type(EquipmentManager_GetLocationData) == "function" then
        data = call(EquipmentManager_GetLocationData, location)
    elseif type(EquipmentManager_UnpackLocation) == "function" then
        -- Older client helper: player, bank, bags, void storage, slot, bag.
        local ok, player, bank, bags, void, slot, bag = pcall(EquipmentManager_UnpackLocation, location)
        if ok and not void then data={isPlayer=player, isBank=bank, isBags=bags, slot=slot, bag=bag} end
    end
    if type(data) ~= "table" or type(data.slot) ~= "number" or
        not (data.isPlayer or data.isBank) then return nil end
    local itemLocation
    if data.isBags and type(data.bag) == "number" then
        if ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function" then
            local ok, value = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, data.bag, data.slot)
            if ok then itemLocation=value end
        end
        local link = itemLocation and call(C_Item and C_Item.GetItemLink, itemLocation)
        return link or call(C_Container and C_Container.GetContainerItemLink or GetContainerItemLink,
            data.bag, data.slot)
    end
    if ItemLocation and type(ItemLocation.CreateFromEquipmentSlot) == "function" then
        local ok, value = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, data.slot)
        if ok then itemLocation=value end
    end
    return (itemLocation and call(C_Item and C_Item.GetItemLink, itemLocation)) or
        call(GetInventoryItemLink, "player", data.slot)
end

local function setContext(self, target, signature, guid)
    local context = {mode="set", label="Set: " .. tostring(target.name or target.setID),
        signature=signature, links={}, slotErrors={}}
    if not guid or not target.character or target.character ~= guid then
        context.error = "The selected equipment set belongs to another character; choose a set on this character."
        return context
    end
    local options, errorText = self:GetEquipmentSetOptions()
    if errorText then context.error=errorText; return context end
    local chosen
    for _, option in ipairs(options) do
        if option.setID == target.setID then chosen=option; break end
    end
    if not chosen then
        context.error = "The selected equipment set no longer exists; choose another comparison target."
        return context
    end
    context.label = "Set: " .. chosen.name
    local api = equipmentAPI()
    local locations = call(api and api.GetItemLocations, target.setID)
    local ids = call(api and api.GetItemIDs, target.setID)
    local ignored = call(api and api.GetIgnoredSlots, target.setID)
    if type(locations) ~= "table" or type(ids) ~= "table" then
        context.error = "The selected equipment set's item data is loading."
        return context
    end
    for slot=0,19 do
        local location, id = locations[slot], ids[slot]
        if (type(ignored) == "table" and ignored[slot]) or location == 1 then
            context.slotErrors[slot] = "This slot is ignored by the selected equipment set."
        elseif location == 0 and not (type(id) == "number" and id > 0) then
            -- An explicitly empty slot is comparable to zero. Missing/ignored
            -- slots are never treated as empty and never use the equipped item.
        elseif type(location) ~= "number" or location < 2 then
            context.slotErrors[slot] = "The selected set item is unavailable."
        else
            local link = itemLinkAtLocation(location)
            local actualID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
            if actualID and (not id or id <= 0 or actualID == id) then
                context.links[slot] = link
            else
                context.slotErrors[slot] = "The selected set item's full link is unavailable; open its bag or bank."
            end
        end
    end
    return context
end

function FW:GetProfileComparisonContext(profile)
    local target = profile and profile.comparisonTarget
    if type(target) ~= "table" or target.mode ~= "set" then
        return {mode="equipped", label="Currently equipped", signature="equipped:" .. tostring(self.equipmentRevision or 0)}
    end
    local guid = playerGUID()
    local signature = table.concat({"set", tostring(target.setID), tostring(target.character),
        tostring(guid), tostring(baselineRevision)}, ":")
    if not contexts[signature] then contexts[signature] = setContext(self, target, signature, guid) end
    return contexts[signature]
end

function FW:GetUpgradeBaselineSignature(profile)
    return self:GetProfileComparisonContext(profile).signature
end
