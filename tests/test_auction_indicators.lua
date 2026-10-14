local FW = { DB = { options = { upgradeBags = false, upgradeRolls = false } }, CACHE_LIMIT = 2 }
local verdicts, scored, timers = {}, {}, {}
local mainProfile = true
function FW:IsMainProfileUpgrade(link)
    scored[#scored + 1] = link
    return mainProfile and verdicts[link] == true
end
local function pump()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
end
C_Timer = { After = function(delay, callback) assert(delay == 0); timers[#timers + 1] = callback end }

local function object(parent)
    local frame = { parent = parent, shown = true, scripts = {}, scriptHooks = {}, textures = {}, events = {} }
    function frame:IsForbidden() return self.forbidden == true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:HookScript(name, callback)
        self.scriptHooks[name] = self.scriptHooks[name] or {}
        table.insert(self.scriptHooks[name], callback)
    end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    function frame:Fire(name, ...)
        if self.scripts[name] then self.scripts[name](self, ...) end
        for _, callback in ipairs(self.scriptHooks[name] or {}) do callback(self, ...) end
    end
    function frame:Show() self.shown = true; self:Fire("OnShow") end
    function frame:Hide() self.shown = false; self:Fire("OnHide") end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:CreateTexture(_, layer, _, sublayer)
        assert(layer == "OVERLAY" and sublayer == 7)
        local texture = { shown = false }
        function texture:Show() self.shown = true end
        function texture:Hide() self.shown = false end
        function texture:SetTexture(value) self.path = value end
        function texture:SetSize(w, h) self.w, self.h = w, h end
        function texture:SetPoint(...) self.anchor = { ... } end
        self.textures[#self.textures + 1] = texture
        return texture
    end
    return frame
end
CreateFrame = function() return object() end
hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then callback, method, target = method, target, _G end
    local original = assert(target[method])
    target[method] = function(...)
        local result = { original(...) }
        callback(...)
        return (unpack or table.unpack)(result)
    end
end
local playerLevel, keyCalls = 30, 0
UnitLevel = function(unit) assert(unit == "player"); return playerLevel end
local keyData = {}
C_AuctionHouse = { GetItemKeyRequiredLevel = function() return 20 end }
C_TooltipInfo = { GetItemKey = function(id, level, suffix, requiredLevel)
    keyCalls = keyCalls + 1
    assert(requiredLevel == 20)
    local link = keyData[table.concat({ id, level, suffix, playerLevel }, ":")]
    return link and { hyperlink = link }
end }

assert(loadfile("Indicators.lua"))("ZwykValues", FW)
assert(loadfile("AuctionIndicators.lua"))("ZwykValues", FW)
FW:InstallUpgradeIndicators()
FW:InstallAuctionUpgradeIndicators(); pump()
local eventFrame = FW.AuctionUpgradeIndicatorFrame
assert(eventFrame.events.AUCTION_HOUSE_SHOW and eventFrame.events.AUCTION_HOUSE_CLOSED)
assert(not eventFrame.scripts.OnUpdate and not eventFrame.events.AUCTION_ITEM_LIST_UPDATE)
FW:InstallAuctionUpgradeIndicators(); pump()
assert(FW.AuctionUpgradeIndicatorFrame == eventFrame and #scored == 0)

local auction = object(); auction.shown = false
AuctionHouseFrame = auction
local function display(parent)
    local result = object(parent)
    result.ItemButton = object(result); result.ItemButton.icon = object(result.ItemButton)
    function result:GetItemLink() return self.itemLink end
    function result:SetItemKey(key) self.itemKey = key; self.pendingItemKey = nil end
    function result:SetItemInternal(link) self.itemLink = link; self.pendingInfo = nil end
    function result:SetItemLocation(link) self.itemKey = nil; self:SetItemInternal(link) end
    function result:Reset() self.itemKey, self.itemLink, self.pendingInfo, self.pendingItemKey = nil, nil, nil, nil end
    return result
end
local function list(parent)
    local result = object(parent)
    result.tableBuilder = { rows = {} }
    function result.tableBuilder:AddRow(row, data)
        row.rowData = data
        for _, cell in ipairs(row.cells) do cell.rowData = data; cell.Icon.shown = true end
        for _, known in ipairs(self.rows) do if known == row then return end end
        self.rows[#self.rows + 1] = row
    end
    function result.tableBuilder:RemoveRow(row)
        for i, known in ipairs(self.rows) do if known == row then table.remove(self.rows, i); break end end
        row.rowData = nil
    end
    function result:Init() end
    function result:RefreshScrollFrame() end
    function result:UpdateTableBuilderLayout() end
    return result
end
local function row(parent, data)
    local result = object(parent)
    local cell = object(result); cell.Icon = object(cell)
    function cell:TryUpdateDisplay() self.pendingItemID = nil end
    function cell:ClearDisplay() self.Icon.shown = false end
    result.cells, result.rowData = { cell }, data
    cell.rowData = data
    return result, cell
end
local browse = object(auction); browse.ItemList = list(browse)
auction.BrowseResultsFrame = browse
local firstKey = { itemID = 100, itemLevel = 35, itemSuffix = 17 }
local firstRow, firstCell = row(browse.ItemList, { itemKey = firstKey })
browse.ItemList.tableBuilder.rows = { firstRow }
local nativeClick = function() end
firstCell.scripts.OnClick = nativeClick

local buy = object(auction); buy.ItemDisplay = display(buy)
auction.ItemBuyFrame = buy
buy.ItemDisplay.itemKey = firstKey
-- The native header's generic base link must not replace the auction suffix.
buy.ItemDisplay.itemLink = "item:100:0:0:0:0:0:0"
local sell = object(auction); sell.ItemDisplay = display(sell); sell.shown = false
auction.ItemSellFrame = sell
local commodities = object(auction); commodities.BuyDisplay = object(commodities)
commodities.BuyDisplay.ItemDisplay = display(commodities.BuyDisplay); commodities.shown = false
auction.CommoditiesBuyFrame = commodities
local owned = object(auction); owned.AllAuctionsList = list(owned)
auction.AuctionsFrame = owned
local ownedRow, ownedCell = row(owned.AllAuctionsList, { itemLink = "item:101:exact" })
owned.AllAuctionsList.tableBuilder.rows = { ownedRow }
keyData["100:35:17:30"] = "item:100:suffix17"
verdicts["item:100:suffix17"], verdicts["item:101:exact"] = true, true

-- Late native loading installs no poll or click replacement; disabled/hidden UI does no scoring.
FW:InstallAuctionUpgradeIndicators(); pump()
assert(#scored == 0 and keyCalls == 0)
auction:Show(); pump()
assert(#scored == 0 and keyCalls == 0)
FW.DB.options.upgradeBags = true
FW:RefreshUpgradeIndicators(); pump()
assert(firstCell.zvUpgradeArrow.shown and buy.ItemDisplay.ItemButton.zvUpgradeArrow.shown and ownedCell.zvUpgradeArrow.shown)
assert(firstCell.zvUpgradeArrow.anchor[2] == firstCell.Icon)
assert(firstCell.scripts.OnClick == nativeClick and not firstCell.scripts.OnUpdate)
assert(keyCalls == 1, "same auction item key resolves once across list and header")
assert(#scored == 3, "shared refresh paints each visible item once")
local before = #scored
FW:RefreshUpgradeIndicators(); pump()
assert(#scored - before == 3 and keyCalls == 1)

-- Recycled rows immediately clear the previous upgrade and use the new full item link.
browse.ItemList.tableBuilder:AddRow(firstRow, { itemLink = "item:102:variant" })
assert(not firstCell.zvUpgradeArrow.shown and #timers == 1)
pump(); assert(not firstCell.zvUpgradeArrow.shown)
verdicts["item:102:variant"] = true
FW:RefreshUpgradeIndicators(); pump(); assert(firstCell.zvUpgradeArrow.shown)
browse.ItemList.tableBuilder:RemoveRow(firstRow)
assert(not firstCell.zvUpgradeArrow.shown)
FW:RefreshUpgradeIndicators(); pump(); assert(not firstCell.zvUpgradeArrow.shown)

-- Incomplete keys have no fallback to the wrong base variant and can resolve on native metadata updates.
local pendingKey = { itemID = 103, itemLevel = 40, itemSuffix = -18 }
browse.ItemList.tableBuilder:AddRow(firstRow, { itemKey = pendingKey }); pump()
assert(not firstCell.zvUpgradeArrow.shown)
keyData["103:40:-18:30"], verdicts["item:103:suffix-18"] = "item:103:suffix-18", true
firstCell.pendingItemID = 103
FW:RefreshUpgradeIndicators(); pump(); assert(not firstCell.zvUpgradeArrow.shown)
firstCell:TryUpdateDisplay(); pump(); assert(firstCell.zvUpgradeArrow.shown)
firstCell:ClearDisplay(); pump(); assert(not firstCell.zvUpgradeArrow.shown)
firstCell.Icon.shown = true
firstCell:TryUpdateDisplay(); pump(); assert(firstCell.zvUpgradeArrow.shown)
browse.ItemList.tableBuilder:AddRow(firstRow, { isVirtualEntry = true, itemLink = "item:101:exact" })
pump(); assert(not firstCell.zvUpgradeArrow.shown)

-- Header changes, sell slots and ammunition commodity headers share current data and item filters.
sell:Show(); sell.ItemDisplay:SetItemLocation("item:104:sell")
verdicts["item:104:sell"] = true
pump(); assert(sell.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
sell.ItemDisplay.pendingInfo = {}; sell.ItemDisplay:SetItemInternal(nil)
sell.ItemDisplay.pendingInfo = {}; pump(); assert(not sell.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
sell.ItemDisplay:Reset(); pump(); assert(not sell.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
commodities:Show()
commodities.BuyDisplay.ItemDisplay:SetItemLocation("item:105:ammo")
verdicts["item:105:ammo"] = true
pump(); assert(commodities.BuyDisplay.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
commodities.BuyDisplay.ItemDisplay:SetItemLocation("item:106:consumable")
pump(); assert(not commodities.BuyDisplay.ItemDisplay.ItemButton.zvUpgradeArrow.shown)

-- Missing main profile and pending item decisions hide every arrow through the shared verdict.
mainProfile = false
FW:RefreshUpgradeIndicators(); pump()
assert(not ownedCell.zvUpgradeArrow.shown and not buy.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
mainProfile = true
FW:RefreshUpgradeIndicators(); pump(); assert(ownedCell.zvUpgradeArrow.shown)
buy.ItemDisplay.pendingItemKey = { itemID = 999 }
FW:RefreshUpgradeIndicators(); pump(); assert(not buy.ItemDisplay.ItemButton.zvUpgradeArrow.shown)
buy.ItemDisplay.pendingItemKey = nil

-- Native late-created pooled rows are discovered by the builder hook; neither scrolling nor profile invalidation polls.
local lateRow, lateCell = row(browse.ItemList, {})
browse.ItemList.tableBuilder:AddRow(lateRow, { itemLink = "item:101:exact" })
pump(); assert(lateCell.zvUpgradeArrow.shown)
local textureCount = #lateCell.textures
FW:InstallAuctionUpgradeIndicators(); FW:InstallAuctionUpgradeIndicators(); pump()
assert(#lateCell.textures == textureCount and #lateCell.scriptHooks.OnHide == 1)
FW.DB.options.upgradeBags = false
before = #scored; local keyBefore = keyCalls
FW:RefreshUpgradeIndicators(); assert(not lateCell.zvUpgradeArrow.shown)
pump(); assert(#scored == before and keyCalls == keyBefore)

-- Cached key links are bounded, successful only, and include player level.
FW.DB.options.upgradeBags = true
keyData["100:35:17:31"], verdicts["item:100:level31"] = "item:100:level31", true
playerLevel = 31
FW:RefreshUpgradeIndicators(); pump()
assert(buy.ItemDisplay.ItemButton.zvUpgradeArrow.shown and scored[#scored])
local found = false
for i = before + 1, #scored do if scored[i] == "item:100:level31" then found = true end end
assert(found, "level changes resolve the auction key in the current player context")
-- Three successful key contexts overflow the two-entry test limit, evicting the
-- old context instead of retaining every item ever browsed for this session.
playerLevel = 30
keyBefore = keyCalls
FW:RefreshUpgradeIndicators(); pump()
assert(keyCalls > keyBefore, "the old successful context is evicted by the bounded key cache")
auction:Hide()
assert(not lateCell.zvUpgradeArrow.shown and not ownedCell.zvUpgradeArrow.shown)
before = #scored; keyBefore = keyCalls
FW:RefreshUpgradeIndicators(); pump()
assert(#scored == before and keyCalls == keyBefore)
eventFrame:Fire("OnEvent", "AUCTION_HOUSE_CLOSED")
assert(not eventFrame.scripts.OnUpdate)

print("auction upgrade indicators tests passed")
