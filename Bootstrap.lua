local addonName, FW = ...
_G.ZwykValues = FW
FW.version = "0.1.23"

function FW:Print(message)
    local text = "|cff80ccffZwykValues:|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) else print(text) end
end

local function countEntries(map)
    local count = 0
    for _ in pairs(map or {}) do count = count + 1 end
    return count
end

local function inspect(link)
    link = link or FW:GetHoveredItemLink() or (GetInventoryItemLink and GetInventoryItemLink("player", 16))
    if not link then FW:Print("Hover an item or type /zv inspect <item link>."); return end
    local record, err = FW:GetItem(link)
    if not record then FW:Print(tostring(err)); return end
    local raw = FW.GetRawItemStats and FW:GetRawItemStats(link) or {}
    local stored = FW.DB.itemIssues and FW.DB.itemIssues[record.key] or {}
    local data = {item=link, name=record.name, key=record.key, partial=record.partial,
        classID=record.classID, subclassID=record.subclassID,
        allowedClasses=record.allowedClasses, classRestrictionsKnown=record.classRestrictionsKnown,
        build=GetBuildInfo and ({GetBuildInfo()}) or {},
        locale=GetLocale and GetLocale() or "unknown", stats=record.stats,
        percentStats=record.percentStats, ratingStats=record.ratingStats,
        onUseStats=record.onUseStats, onUsePercentStats=record.onUsePercentStats,
        onUseRatingStats=record.onUseRatingStats, onUseEffects=record.onUseEffects,
        onUseUnsupported=record.onUseUnsupported,
        unresolvedStats=record.unresolvedStats, unrecognizedLines=record.unrecognizedLines,
        unknownAPIStats=record.unknownAPIStats, ignoredTooltipStats=record.ignoredTooltipStats,
        warnings=record.warnings, raw=raw,
        scoreIssues=stored.scoreIssues, profileScores=stored.profileScores}
    if FW.CopyItemDiagnostic then data=FW:CopyItemDiagnostic(data) end
    local json, encodeError = FW.JSON.Encode(data)
    if FW.ShowTextDialog then FW:ShowTextDialog("Item diagnostics", json or tostring(encodeError), false)
    elseif FW.ShowTransferDialog then FW:ShowTransferDialog("Item diagnostics", json or tostring(encodeError), false)
    else FW:Print(json or tostring(encodeError)) end
end

function FW:ExportItemIssues()
    local report = self:GetIssueReport()
    local json, err = self.JSON.Encode(report)
    if not json then self:Print("Could not export item issues: " .. tostring(err)); return end
    local title = "Item issues (" .. tostring(report.itemCount) .. ")"
    if self.ShowTextDialog then self:ShowTextDialog(title, json, false)
    elseif self.ShowTransferDialog then self:ShowTransferDialog(title, json, false)
    else self:Print(json) end
end

SLASH_ZWYKVALUES1 = "/zv"
SLASH_ZWYKVALUES2 = "/zwykvalues"
SlashCmdList.ZWYKVALUES = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "cache" then
        FW:Print(countEntries(FW.DB.cache.items) .. " cached item variants; " ..
            countEntries(FW.DB.cache.scores) .. " scored variants.")
    elseif command == "clearcache" then
        FW:InvalidateCache(); FW:Print("Item and score caches cleared.")
    elseif command == "inspect" then
        inspect(rest ~= "" and rest or nil)
    elseif command == "exportissues" then
        FW:ExportItemIssues()
    elseif command == "clearissues" then
        FW:ClearItemIssues(); FW:Print("Recorded item issues cleared.")
    elseif command == "help" then
        FW:Print("/zv opens profiles. /zv cache, /zv clearcache, /zv inspect [item link], /zv exportissues, /zv clearissues.")
    else FW:ToggleUI() end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
pcall(eventFrame.RegisterEvent, eventFrame, "ITEM_DATA_LOAD_RESULT")
local setEvents = {
    EQUIPMENT_SETS_CHANGED=true, EQUIPMENT_SWAP_FINISHED=true, BAG_UPDATE_DELAYED=true,
    BANKFRAME_OPENED=true, BANKFRAME_CLOSED=true, PLAYERBANKSLOTS_CHANGED=true,
    PLAYERBANKBAGSLOTS_CHANGED=true, PLAYER_ENTERING_WORLD=true,
}
for event in pairs(setEvents) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
local function invalidateSets()
    if FW.InvalidateEquipmentSetBaselines then FW:InvalidateEquipmentSetBaselines() end
end
local function hasSetProfiles(activeOnly)
    if not FW.GetProfiles then return false end
    for _, profile in ipairs(FW:GetProfiles(activeOnly)) do
        if profile.comparisonTarget and profile.comparisonTarget.mode == "set" then return true end
    end
    return false
end
eventFrame:SetScript("OnEvent", function(_, event, arg1, success)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            FW:Initialize()
            FW:InstallTooltipHooks()
            if FW.InstallUpgradeChatHooks then FW:InstallUpgradeChatHooks() end
            if FW.InstallUpgradeIndicators then FW:InstallUpgradeIndicators() end
        elseif FW.DB and FW.HookTooltip then
            for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2"}) do
                FW.HookTooltip(_G[name])
            end
            if FW.InstallUpgradeChatHooks then FW:InstallUpgradeChatHooks() end
        end
        if FW.DB and FW.InstallCharacterSheetButton then FW:InstallCharacterSheetButton() end
        if FW.DB and FW.InstallBlizzardOptions then FW:InstallBlizzardOptions() end
        if FW.DB and FW.InstallAuctionUpgradeIndicators then FW:InstallAuctionUpgradeIndicators() end
        if FW.DB then invalidateSets() end
    elseif not FW.DB then return
    elseif setEvents[event] then
        invalidateSets()
        if hasSetProfiles() and FW.RefreshUpgradeIndicators then FW:RefreshUpgradeIndicators() end
        if hasSetProfiles(true) then FW:RefreshTooltips() end
        if event == "EQUIPMENT_SETS_CHANGED" and FW.RefreshUI then FW:RefreshUI() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
        FW.equipmentRevision = (FW.equipmentRevision or 0) + 1
        invalidateSets()
        if FW.InvalidateRecentItemReads then FW:InvalidateRecentItemReads() end
        if FW.InvalidateUpgradeComparisons then FW:InvalidateUpgradeComparisons() end
        FW:RefreshTooltips()
    elseif event == "PLAYER_LEVEL_UP" then
        invalidateSets()
        FW:InvalidateCache()
    else
        -- Cached native queries can emit these events too. Only an awaited
        -- completion can change our data; otherwise this feeds bag redraws.
        local changed = FW.OnItemDataLoaded and FW:OnItemDataLoaded(arg1, success)
        if not changed then return end
        invalidateSets()
        if FW.InvalidateUpgradeComparisons then FW:InvalidateUpgradeComparisons() end
        if FW.RefreshUpgradeIndicators then FW:RefreshUpgradeIndicators() end
        -- Only refresh a hovered loading item. Do not redraw on each unrelated
        -- item load; scanner APIs may themselves trigger data events.
        local hovered = FW:GetHoveredItemLink()
        local id = hovered and tonumber(hovered:match("item:(%d+)"))
        local relevant = id and id == arg1
        if hovered and not relevant and GetInventoryItemLink then
            for slot = INVSLOT_AMMO or 0, 19 do
                local equipped = GetInventoryItemLink("player", slot)
                if equipped and tonumber(equipped:match("item:(%d+)")) == arg1 then
                    relevant = true; break
                end
            end
        end
        if hovered and not relevant then
            -- A set location can be unresolved until this awaited load finishes.
            -- Only meaningful requested loads reach this branch, never general
            -- native cache notifications that caused the previous hover loop.
            relevant = hasSetProfiles(true)
        end
        if relevant then FW:RefreshTooltips() end
    end
end)
