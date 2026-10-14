local _, FW = ...

-- Native Forever AuctionHouseUI: TableBuilder owns the visible rows/cells;
-- ItemDisplay owns buy/sell/commodity header buttons. Providers read their
-- current entry, including its suffix, rather than a cached row index.
local hooks, scriptHooks = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local itemButtons, keyLinks = setmetatable({}, { __mode = "k" }), {}
local keyLinkCount = 0

local function usable(frame)
    if not frame then return false end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return false end
    end
    return true
end

local function visible(frame)
    if not usable(frame) then return false end
    local method = frame.IsVisible or frame.IsShown
    if type(method) ~= "function" then return false end
    local ok, shown = pcall(method, frame)
    return ok and shown == true
end

local function hide(button)
    if usable(button) and button.zvUpgradeArrow then button.zvUpgradeArrow:Hide() end
end

local function hookMethod(target, method, callback)
    if not usable(target) or type(target[method]) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    local methods = hooks[target]
    if not methods then methods = {}; hooks[target] = methods end
    if not methods[method] and pcall(hooksecurefunc, target, method, callback) then methods[method] = true end
end

local function hookScript(target, script, callback)
    if not usable(target) or type(target.HookScript) ~= "function" then return end
    local scripts = scriptHooks[target]
    if not scripts then scripts = {}; scriptHooks[target] = scripts end
    if not scripts[script] and pcall(target.HookScript, target, script, callback) then scripts[script] = true end
end

local function enabled()
    return FW.DB and FW.DB.options and FW.DB.options.upgradeBags == true
end

local function itemLink(link)
    if issecretvalue and issecretvalue(link) then return end
    if type(link) == "string" and link:find("item:", 1, true) then return link end
end

local function itemKeyLink(key)
    if type(key) ~= "table" then return end
    local id, level, suffix, pet = key.itemID, key.itemLevel or 0, key.itemSuffix or 0, key.battlePetSpeciesID or 0
    for _, value in ipairs({ id, level, suffix, pet }) do
        if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then return end
    end
    if not id or id < 1 or pet ~= 0 then return end
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local cacheKey = table.concat({id, level, suffix, playerLevel}, ":")
    if keyLinks[cacheKey] then return keyLinks[cacheKey] end
    if not C_TooltipInfo or type(C_TooltipInfo.GetItemKey) ~= "function" then return end
    -- This getter returns the same hyperlink used by TooltipUtil.GetDisplayedItem,
    -- preserving random suffixes and item levels without touching GameTooltip.
    local requiredLevel
    if C_AuctionHouse and type(C_AuctionHouse.GetItemKeyRequiredLevel) == "function" then
        local ok, value = pcall(C_AuctionHouse.GetItemKeyRequiredLevel, key)
        if ok then requiredLevel = value end
    end
    local ok, data = pcall(C_TooltipInfo.GetItemKey, id, level, suffix, requiredLevel)
    local link = ok and type(data) == "table" and itemLink(data.hyperlink)
    if link then
        if keyLinkCount >= (FW.CACHE_LIMIT or 2000) then keyLinks, keyLinkCount = {}, 0 end
        keyLinks[cacheKey], keyLinkCount = link, keyLinkCount + 1
    end
    return link
end

local function rowLink(row, cell)
    local data = row and row.rowData
    if type(data) ~= "table" or data.isVirtualEntry or (cell and cell.pendingItemID) then return end
    if cell and (cell.rowData ~= data or not visible(cell.Icon)) then return end
    return itemLink(data.itemLink) or itemKeyLink(data.itemKey)
end

local function displayLink(display)
    if display.pendingInfo or display.pendingItemKey then return end
    if display.itemKey then return itemKeyLink(display.itemKey) end
    if type(display.GetItemLink) == "function" then return itemLink(display:GetItemLink()) end
    return itemLink(display.itemLink)
end

local function register(button, provider, owner, anchor, deferPaint)
    if not usable(button) or type(FW.RegisterUpgradeItemButton) ~= "function" then return end
    itemButtons[button] = true
    FW:RegisterUpgradeItemButton(button, provider, {owner = owner, anchor = anchor, deferPaint = deferPaint})
end

local function changed(button)
    hide(button)
    FW:RefreshUpgradeIndicators()
end

local function registerRow(row, deferPaint)
    if not usable(row) or type(row.cells) ~= "table" then return end
    for _, cell in ipairs(row.cells) do
        if usable(cell) and cell.Icon and type(cell.TryUpdateDisplay) == "function" then
            register(cell, function() return rowLink(row, cell) end, AuctionHouseFrame, cell.Icon, deferPaint)
            hookMethod(cell, "TryUpdateDisplay", function() changed(cell) end)
            hookMethod(cell, "ClearDisplay", function() changed(cell) end)
        end
    end
end

local function discoverList(list, deferPaint)
    if not usable(list) then return end
    local builder = list.tableBuilder
    if usable(builder) then
        hookMethod(builder, "AddRow", function(_, row)
            -- Recycled cells must lose the old upgrade before the shared paint.
            for _, cell in ipairs(row.cells or {}) do hide(cell) end
            registerRow(row, true)
            FW:RefreshUpgradeIndicators()
        end)
        hookMethod(builder, "RemoveRow", function(_, row)
            for _, cell in ipairs(row.cells or {}) do hide(cell) end
        end)
        if enabled() and visible(list) and type(builder.rows) == "table" then
            for _, row in ipairs(builder.rows) do registerRow(row, deferPaint) end
        end
    end
    hookMethod(list, "Init", function() FW:RefreshUpgradeIndicators() end)
    hookMethod(list, "RefreshScrollFrame", function() FW:RefreshUpgradeIndicators() end)
    hookMethod(list, "UpdateTableBuilderLayout", function() FW:RefreshUpgradeIndicators() end)
    hookScript(list, "OnShow", function() FW:RefreshUpgradeIndicators() end)
end

local function discoverDisplay(display, deferPaint)
    if not usable(display) or not usable(display.ItemButton) then return end
    local button = display.ItemButton
    register(button, function() return displayLink(display) end, display,
        button.icon or button.Icon, deferPaint)
    for _, method in ipairs({ "SetItemKey", "SetItemInternal", "SetItemLocation", "Reset" }) do
        hookMethod(display, method, function() changed(button) end)
    end
    hookScript(display, "OnShow", function() FW:RefreshUpgradeIndicators() end)
end

function FW:RefreshAuctionUpgradeIndicators(deferPaint)
    local frame = AuctionHouseFrame
    if not usable(frame) then return end
    -- These are native, named ownership paths; never enumerate unrelated UI.
    for _, name in ipairs({ "BrowseResultsFrame", "ItemBuyFrame", "ItemSellFrame", "CommoditiesSellFrame" }) do
        local panel = frame[name]
        if usable(panel) then
            discoverDisplay(panel.ItemDisplay, deferPaint)
            discoverList(panel.ItemList, deferPaint)
        end
    end
    local commodities = frame.CommoditiesBuyFrame
    if usable(commodities) then
        discoverDisplay(commodities.BuyDisplay and commodities.BuyDisplay.ItemDisplay, deferPaint)
        discoverList(commodities.ItemList, deferPaint)
    end
    discoverList(frame.ItemSellList, deferPaint)
    discoverList(frame.CommoditiesSellList, deferPaint)
    local auctions = frame.AuctionsFrame
    if usable(auctions) then
        discoverDisplay(auctions.ItemDisplay, deferPaint)
        for _, name in ipairs({ "AllAuctionsList", "BidsList", "ItemList", "CommoditiesList" }) do
            discoverList(auctions[name], deferPaint)
        end
    end
    hookScript(frame, "OnShow", function() FW:RefreshUpgradeIndicators() end)
    hookScript(frame, "OnHide", function() for button in pairs(itemButtons) do hide(button) end end)
end

function FW:InstallAuctionUpgradeIndicators()
    if not self.AuctionUpgradeIndicatorFrame and type(CreateFrame) == "function" then
        local frame = CreateFrame("Frame")
        self.AuctionUpgradeIndicatorFrame = frame
        frame:SetScript("OnEvent", function(_, event)
            if event == "AUCTION_HOUSE_CLOSED" then
                for button in pairs(itemButtons) do hide(button) end
            else
                self:RefreshAuctionUpgradeIndicators(true)
                self:RefreshUpgradeIndicators()
            end
        end)
        for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    self:RefreshAuctionUpgradeIndicators(true)
    self:RefreshUpgradeIndicators()
end
