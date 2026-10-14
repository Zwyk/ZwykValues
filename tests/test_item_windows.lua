-- Native bank/trade/vendor adapters plus the actual memoized upgrade decision.
-- Mock APIs verify live item identities and window recycling, not Blizzard UI.
local checks, timers, comparisons, reads = 0, {}, {}, {}
local function check(value, message)
    checks = checks + 1
    if not value then error(message or "assertion failed", 2) end
end
local function equal(actual, expected, message)
    check(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function pump()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
end
C_Timer = {After=function(delay, callback) equal(delay, 0); timers[#timers+1] = callback end}
local clock = 10
GetTime = function() return clock end
local function object(name, parent)
    local frame = {name=name, parent=parent, shown=true, id=1, scripts={}, hooks={}, textures={}, events={}, children={}}
    if parent then parent.children[#parent.children+1] = frame end
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    function frame:GetID() return self.id end
    function frame:SetID(id) self.id = id end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], callback)
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:Fire(event, ...)
        if self.scripts[event] then self.scripts[event](self, ...) end
        for _, callback in ipairs(self.hooks[event] or {}) do callback(self, ...) end
    end
    function frame:VisibilityEvent(event)
        self:Fire(event)
        for _, child in ipairs(self.children) do if child.shown then child:VisibilityEvent(event) end end
    end
    function frame:Show()
        local wasVisible = self:IsVisible()
        self.shown = true
        if not wasVisible and self:IsVisible() then self:VisibilityEvent("OnShow") end
    end
    function frame:Hide()
        local wasVisible = self:IsVisible()
        self.shown = false
        if wasVisible then self:VisibilityEvent("OnHide") end
    end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:CreateTexture(_, layer, _, sublayer)
        check(not self.forbidden and layer == "OVERLAY" and sublayer == 7)
        local texture = {shown=false}
        function texture:SetTexture(path) self.path = path end
        function texture:SetSize(width, height) self.width, self.height = width, height end
        function texture:SetPoint(...) self.anchor = {...} end
        function texture:Show() self.shown = true end
        function texture:Hide() self.shown = false end
        self.textures[#self.textures+1] = texture
        return texture
    end
    return frame
end
CreateFrame = function() return object() end
local hookCounts = {}
hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then callback, method, target = method, target, _G end
    hookCounts[target] = hookCounts[target] or {}
    hookCounts[target][method] = (hookCounts[target][method] or 0) + 1
    local original = assert(target[method])
    target[method] = function(...)
        local results = {original(...)}
        callback(...)
        return (unpack or table.unpack)(results)
    end
end
local function button(name, parent, id)
    local result = object(name, parent)
    result.id, result.icon = id or 1, {}
    result.scripts.OnClick = function() end
    return result
end
local function shown(frame) return frame.zvUpgradeArrow and frame.zvUpgradeArrow.shown == true end
local function read(kind, first, second)
    reads[#reads+1] = {kind, first, second}
end
local containers = {
    [-1]={[1]="item:101"}, [-3]={[1]="item:111"},
    [6]={[1]="item:100"}, [7]={[1]="item:103"}, [20]={[1]="item:112"},
}
C_Container = {GetContainerItemLink=function(bag, slot)
    read("container", bag, slot)
    return containers[bag] and containers[bag][slot]
end}
local inventory = {[22]="item:102"}
GetInventoryItemLink = function(unit, slot)
    equal(unit, "player"); read("inventory", slot); return inventory[slot]
end
NUM_CONTAINER_FRAMES, NUM_BAG_SLOTS, NUM_BANKBAGSLOTS = 1, 4, 7
NUM_BANKGENERIC_SLOTS, NUM_REAGENTBANKGENERIC_SLOTS = 3, 1
BANK_CONTAINER, REAGENTBANK_CONTAINER = -1, -3
Enum = {BagIndex={CharacterBankTab1=6, AccountBankTab1=20}}
BankFrame = object("BankFrame")
local panel = object("BankPanel", BankFrame)
BankFrame.BankPanel = panel
local function bankButton(tab, slot)
    local item = button(nil, panel)
    item.tab, item.slot, item.isInitialized = tab, slot, true
    function item:GetBankTabID() return self.tab end
    function item:GetContainerSlotID() return self.slot end
    function item:SetBankTabID(value) self.tab = value end
    function item:SetContainerSlotID(value) self.slot = value end
    function item:Refresh() end
    return item
end
local currentBank, emptyBank, uninitializedBank, accountBank = bankButton(6,1), bankButton(6,2), bankButton(6,3), bankButton(20,1)
uninitializedBank.isInitialized = false
panel.Items = {currentBank, emptyBank, uninitializedBank, accountBank}
function panel:EnumerateValidItems()
    local index = 0
    return function() index = index + 1; return self.Items[index] end
end
function panel:GenerateItemSlotsForSelectedTab() end
function panel:RefreshAllItemsForSelectedTab() end
local legacySlots = object("BankSlotsFrame", BankFrame); legacySlots.id = -1
BankFrameItem1 = button("BankFrameItem1", legacySlots, 1)
BankFrameItem2 = button("BankFrameItem2", BankFrame, 2)
function BankFrameItem2:GetInventorySlot() return 22 end
BankFrameItem3 = button("BankFrameItem3", BankFrame, 3); BankFrameItem3.isBag = true
function BankFrameItem3:GetInventorySlot() error("bank bag purchase controls are not gear") end
ReagentBankFrame = object("ReagentBankFrame", BankFrame); ReagentBankFrame.id = -3
ReagentBankFrameItem1 = button("ReagentBankFrameItem1", ReagentBankFrame, 1)
local bankBag = object("ContainerFrame1", BankFrame); bankBag.id = 7
local bankBagItem = button(nil, bankBag, 1)
bankBag.Items = {bankBagItem}
function bankBag:EnumerateValidItems() return ipairs(self.Items) end
function bankBag:UpdateItems() end
ContainerFrame1 = bankBag
BankFrameItemButton_Update, ReagentBankFrameItemButton_Update = function() end, function() end

MAX_TRADE_ITEMS = 7
TradeFrame = object("TradeFrame")
TradePlayerItem1ItemButton = button("TradePlayerItem1ItemButton", TradeFrame)
TradeRecipientItem1ItemButton = button("TradeRecipientItem1ItemButton", TradeFrame)
TradePlayerItem7ItemButton = button("TradePlayerItem7ItemButton", TradeFrame)
TradeRecipientItem7ItemButton = button("TradeRecipientItem7ItemButton", TradeFrame)
local playerTrade, targetTrade = {[1]="item:104", [7]="item:100"}, {[1]="item:105", [7]="item:107:8481"}
GetTradePlayerItemLink = function(slot) read("player trade", slot); return playerTrade[slot] end
GetTradeTargetItemLink = function(slot) read("target trade", slot); return targetTrade[slot] end
TradeFrame_UpdatePlayerItem, TradeFrame_UpdateTargetItem = function() end, function() end

MERCHANT_ITEMS_PER_PAGE, BUYBACK_ITEMS_PER_PAGE = 3, 3
MerchantFrame = object("MerchantFrame"); MerchantFrame.selectedTab = 1
MerchantItem1ItemButton = button("MerchantItem1ItemButton", MerchantFrame, 1)
MerchantItem2ItemButton = button("MerchantItem2ItemButton", MerchantFrame, 2)
MerchantItem3ItemButton = button("MerchantItem3ItemButton", MerchantFrame, 3)
MerchantBuyBackItemItemButton = button("MerchantBuyBackItemItemButton", MerchantFrame)
MerchantRepairItemButton = button("MerchantRepairItemButton", MerchantFrame)
local catalog, buybacks, catalogCount, buybackCount = {[1]="item:108",[2]="item:109",[17]="item:117",[18]="item:118"},
    {[1]="item:119",[2]="item:110"}, 18, 2
GetMerchantNumItems = function() return catalogCount end
GetMerchantItemLink = function(index) read("merchant", index); return catalog[index] end
GetNumBuybackItems = function() return buybackCount end
GetBuybackItemLink = function(index) read("buyback", index); return buybacks[index] end
MerchantFrame_UpdateMerchantInfo, MerchantFrame_UpdateBuybackInfo = function() end, function() end

local verdicts, loading = {}, {}
for _, id in ipairs({100,101,102,103,104,105,107,108,110,111,112,117,118,119,120,121,122}) do verdicts["item:" .. id] = true end
verdicts["item:107:8481"] = true
local FW = {equipmentRevision=0}
function FW:GetMainProfile()
    return self.DB and self.DB.profiles[self.DB.options.mainProfileID]
end
function FW:ItemKey(link) return link end
function FW:CompareItem(link)
    comparisons[#comparisons+1] = link
    if loading[link] then return nil end
    return {record={}, comparisons={{status=verdicts[link] and "upgrade" or "downgrade"}}}
end
assert(loadfile("Upgrades.lua"))("ZwykValues", FW)
assert(loadfile("Indicators.lua"))("ZwykValues", FW)
local nativeClicks = {currentBank.scripts.OnClick, TradePlayerItem1ItemButton.scripts.OnClick, MerchantItem1ItemButton.scripts.OnClick}
FW:InstallUpgradeIndicators(); pump()
equal(#reads, 0, "before saved options load, no item API is read")
equal(#comparisons, 0)
local eventFrame = FW.UpgradeIndicatorFrame
for _, event in ipairs({"BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "MERCHANT_UPDATE"}) do
    check(eventFrame.events[event], "missing native event " .. event)
end
FW.DB = {options={upgradeBags=true, upgradeRolls=false}, profiles={main={id="main",revision=1}}}
FW:RefreshUpgradeIndicators(); pump()
equal(#comparisons, 0, "without a main profile, native items are never compared")
check(not shown(currentBank) and not shown(TradePlayerItem1ItemButton) and not shown(MerchantItem1ItemButton))
FW.DB.options.mainProfileID = "main"
reads = {}
FW:RefreshUpgradeIndicators(); pump()
equal(#reads, 15, "one provider read per populated or empty native slot in a registry pass")
equal(#comparisons, 12, "duplicate links across windows share the actual upgrade memo")
for _, item in ipairs({currentBank,accountBank,BankFrameItem1,BankFrameItem2,ReagentBankFrameItem1,bankBagItem,
    TradePlayerItem1ItemButton,TradeRecipientItem1ItemButton,TradePlayerItem7ItemButton,TradeRecipientItem7ItemButton,
    MerchantItem1ItemButton,MerchantBuyBackItemItemButton}) do check(shown(item), "expected native upgrade arrow") end
check(not shown(emptyBank) and not shown(uninitializedBank) and not shown(BankFrameItem3) and not shown(MerchantItem2ItemButton))
equal(#MerchantRepairItemButton.textures, 0, "repair action control is never decorated as gear")
equal(currentBank.scripts.OnClick, nativeClicks[1]); equal(TradePlayerItem1ItemButton.scripts.OnClick, nativeClicks[2])
equal(MerchantItem1ItemButton.scripts.OnClick, nativeClicks[3])
equal(currentBank.zvUpgradeArrow.anchor[2], currentBank.icon)
equal(currentBank.zvUpgradeArrow.width, 16)
local before = #comparisons
FW:RefreshUpgradeIndicators(); FW:RefreshUpgradeIndicators()
eventFrame:Fire("OnEvent", "BANK_TABS_CHANGED")
eventFrame:Fire("OnEvent", "TRADE_UPDATE")
eventFrame:Fire("OnEvent", "MERCHANT_UPDATE")
equal(#timers, 1, "window events share one deferred registry refresh")
pump(); equal(#comparisons, before, "unchanged windows never recalculate cached decisions")

-- Pooled bank buttons clear old arrows while tab/slot identity settles.
currentBank:SetBankTabID(20); check(not shown(currentBank))
currentBank:SetContainerSlotID(2); check(not shown(currentBank))
containers[20][2] = "item:121"
currentBank:Refresh(); check(shown(currentBank))
equal(comparisons[#comparisons], "item:121")
equal(#currentBank.textures, 1, "pool recycling reuses its overlay")
currentBank:SetContainerSlotID(0); currentBank:Refresh(); check(not shown(currentBank))
currentBank:SetContainerSlotID(2); currentBank.isInitialized = false
currentBank:Refresh(); check(not shown(currentBank))
currentBank.isInitialized = true; currentBank:Refresh(); check(shown(currentBank))
local newBank = bankButton(6,1); panel.Items[#panel.Items+1] = newBank
panel:GenerateItemSlotsForSelectedTab(); check(shown(newBank), "new pool entries are discovered after native generation")
panel:Hide(); before = #comparisons
FW:RefreshUpgradeIndicators(); pump()
check(not shown(currentBank) and not shown(accountBank) and not shown(newBank))
equal(#comparisons, before, "hidden panel entries are never compared")
panel:Show(); check(shown(currentBank) and shown(accountBank))
BankFrame:Hide()
check(not shown(currentBank) and not shown(BankFrameItem1) and not shown(bankBagItem), "bank owner closes all its overlays immediately")
before = #reads
FW:RefreshUpgradeIndicators(); pump()
for index = before + 1, #reads do check(reads[index][1] ~= "container" and reads[index][1] ~= "inventory", "closed bank has no provider reads") end
BankFrame:Show(); check(shown(currentBank) and shown(BankFrameItem1))

-- Trade provider identity includes both participants and the enchantment slot.
targetTrade[7] = nil
TradeFrame_UpdateTargetItem(7); check(not shown(TradeRecipientItem7ItemButton), "empty enchantment target clears its old arrow")
targetTrade[7] = "item:122:0:0:0:0:0:-7:123"
verdicts[targetTrade[7]] = true
TradeFrame_UpdateTargetItem(7, true)
check(shown(TradeRecipientItem7ItemButton)); equal(comparisons[#comparisons], targetTrade[7], "full trade variant reaches scoring")
playerTrade[1] = "item:109"
TradeFrame_UpdatePlayerItem(1); check(not shown(TradePlayerItem1ItemButton))
TradeFrame:Hide(); check(not shown(TradeRecipientItem1ItemButton) and not shown(TradeRecipientItem7ItemButton))
TradeFrame:Show(); check(shown(TradeRecipientItem7ItemButton))

-- Merchant page IDs are absolute item indices, and buyback uses its own API.
MerchantItem1ItemButton:SetID(17); MerchantItem2ItemButton:SetID(18); MerchantItem3ItemButton:SetID(19)
MerchantFrame_UpdateMerchantInfo(true)
check(shown(MerchantItem1ItemButton) and shown(MerchantItem2ItemButton) and not shown(MerchantItem3ItemButton))
equal(comparisons[#comparisons-1], "item:117"); equal(comparisons[#comparisons], "item:118")
MerchantFrame.selectedTab = 2
MerchantItem1ItemButton:SetID(1); MerchantItem2ItemButton:SetID(2); MerchantItem3ItemButton:SetID(3)
reads = {}; MerchantFrame_UpdateBuybackInfo(true)
check(shown(MerchantItem1ItemButton) and shown(MerchantItem2ItemButton))
check(not shown(MerchantItem3ItemButton) and not shown(MerchantBuyBackItemItemButton))
equal(#reads, 2)
for _, call in ipairs(reads) do equal(call[1], "buyback", "buyback tab never reads merchant catalog entries") end
MerchantFrame.selectedTab = 1
buybacks[3], buybackCount = "item:120", 3
MerchantFrame_UpdateMerchantInfo()
check(shown(MerchantBuyBackItemItemButton)); equal(comparisons[#comparisons], "item:120", "latest-sold icon reads the newest buyback index")
buybackCount = 0
MerchantFrame_UpdateMerchantInfo(); check(not shown(MerchantBuyBackItemItemButton))
MerchantFrame.selectedTab = 2
MerchantFrame_UpdateBuybackInfo()
check(not shown(MerchantItem1ItemButton) and not shown(MerchantItem2ItemButton), "empty buyback list clears recycled catalog arrows")
MerchantFrame.selectedTab = 1
MerchantFrame_UpdateMerchantInfo()
MerchantFrame:Hide(); check(not shown(MerchantItem1ItemButton) and not shown(MerchantItem2ItemButton))

-- The shared item-icons toggle clears all locations immediately and does no work.
MerchantFrame:Show(); TradeFrame:Show(); BankFrame:Show(); pump()
FW.DB.options.upgradeBags = false
before = #comparisons; reads = {}
FW:RefreshUpgradeIndicators()
for _, item in ipairs({currentBank,accountBank,BankFrameItem1,bankBagItem,TradeRecipientItem1ItemButton,MerchantItem1ItemButton}) do check(not shown(item)) end
pump(); equal(#comparisons, before); equal(#reads, 0)
TradeFrame_UpdateTargetItem(1); MerchantFrame_UpdateMerchantInfo(); panel:RefreshAllItemsForSelectedTab()
equal(#comparisons, before); equal(#reads, 0, "disabled native update hooks do not read item links")

-- Loading data is retried once its shared temporary decision expires.
FW.DB.options.upgradeBags = true
playerTrade[1] = "item:120:0"
loading[playerTrade[1]], verdicts[playerTrade[1]] = true, true
FW:RefreshUpgradeIndicators(); pump(); check(not shown(TradePlayerItem1ItemButton))
before = #comparisons
eventFrame:Fire("OnEvent", "TRADE_PLAYER_ITEM_CHANGED", 1); pump()
equal(#comparisons, before, "pending item decisions are briefly reused")
loading[playerTrade[1]], clock = nil, clock + 1.1
FW:RefreshUpgradeIndicators(); pump(); check(shown(TradePlayerItem1ItemButton))
equal(#comparisons, before + 1)
FW.DB.options.mainProfileID = nil
FW:InvalidateUpgradeComparisons()
before = #comparisons
FW:RefreshUpgradeIndicators(); pump()
check(not shown(currentBank) and not shown(TradePlayerItem1ItemButton) and not shown(MerchantItem1ItemButton))
equal(#comparisons, before, "removing the main profile clears arrows without comparisons")
eventFrame:Fire("OnEvent", "ADDON_LOADED", "Blizzard_TradeUI"); pump()
equal(hookCounts[_G].TradeFrame_UpdatePlayerItem, 1, "late UI loads never duplicate native hooks")
equal(hookCounts[panel].GenerateItemSlotsForSelectedTab, 1)
equal(eventFrame.scripts.OnUpdate, nil, "normal item windows never start continuous polling")
print("Native item-window indicators: " .. checks .. " checks passed.")
