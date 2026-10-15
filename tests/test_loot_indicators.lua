-- Current Forever ScrollBox loot rows, legacy paged slots, and native roll
-- cards use live item links and the actual memoized main-profile decision.
local checks, timers, reads, comparisons, decisions = 0, {}, {}, {}, {}
local function check(value, message)
    checks = checks + 1
    assert(value, message or "loot indicator check failed")
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
    local frame = {name=name, parent=parent, shown=true, children={}, scripts={}, hooks={}, events={}, textures={}}
    if parent then parent.children[#parent.children+1] = frame end
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], callback)
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
        local visible = self:IsVisible(); self.shown = true
        if not visible and self:IsVisible() then self:VisibilityEvent("OnShow") end
    end
    function frame:Hide()
        local visible = self:IsVisible(); self.shown = false
        if visible then self:VisibilityEvent("OnHide") end
    end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:CreateTexture(_, layer, _, sublayer)
        equal(layer, "OVERLAY"); equal(sublayer, 7)
        local texture = {shown=false}
        function texture:SetTexture(path) self.path = path end
        function texture:SetSize(w, h) self.w, self.h = w, h end
        function texture:SetPoint(...) self.anchor = {...} end
        function texture:Show() self.shown = true end
        function texture:Hide() self.shown = false end
        self.textures[#self.textures+1] = texture
        return texture
    end
    return frame
end
local created = 0
CreateFrame = function() created = created + 1; return object() end
local hookCounts = {}
hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then callback, method, target = method, target, _G end
    hookCounts[target] = hookCounts[target] or {}
    hookCounts[target][method] = (hookCounts[target][method] or 0) + 1
    local original = assert(target[method])
    target[method] = function(...)
        local results = {original(...)}; callback(...)
        return (unpack or table.unpack)(results)
    end
end
local FW = {DB={options={upgradeBags=false,upgradeRolls=false}}, equipmentRevision=1}
local main, results = {id="main",revision=1}, {}
function FW:GetMainProfile() return main end
function FW:ItemKey(link) return link end
function FW:CompareItem(link)
    comparisons[link] = (comparisons[link] or 0) + 1
    return results[link]
end
local function result(link, status, issue)
    results[link] = {record={partial=issue=="partial"}, pending=issue=="pending",
        excluded=issue=="excluded", comparisons={{status=status or "upgrade"}}}
end
for _, link in ipairs({"item:101:exact", "item:102:exact", "item:103:pending", "item:104:partial", "item:105:excluded"}) do
    result(link)
end
result("item:103:pending", nil, "pending")
result("item:104:partial", nil, "partial")
result("item:105:excluded", nil, "excluded")
assert(loadfile("Upgrades.lua"))("ZwykValues", FW)
local realDecision = FW.IsMainProfileUpgrade
function FW:IsMainProfileUpgrade(link)
    decisions[link] = (decisions[link] or 0) + 1
    return realDecision(self, link)
end
local function shown(button) return button.zvUpgradeArrow and button.zvUpgradeArrow.shown == true end
local links, types = {[1]="item:101:exact",[2]="item:102:exact",[3]="item:101:exact"}, {[1]=1,[2]=2,[3]=3}
Enum = {LootSlotType={Item=1,Money=2,Currency=3}}
GetLootSlotType = function(slot) return types[slot] end
GetLootSlotLink = function(slot) reads[#reads+1] = slot; return links[slot] end
LootFrame = object("LootFrame")
function LootFrame:Open() self:Show() end
function LootFrame:Close() end -- native close may animate while its owner remains visible
local modern = LootFrame
local scrollBox = object(nil, modern); modern.ScrollBox = scrollBox
scrollBox.rows, scrollBox.callbacks = {}, {}
function scrollBox:ForEachFrame(callback) for _, row in ipairs(self.rows) do callback(row, row.data) end end
ScrollUtil = {}
function ScrollUtil.AddInitializedFrameCallback(box, callback, owner, iterateExisting)
    equal(iterateExisting, false); equal(box, scrollBox)
    box.callbacks.initialized = {callback,owner}
end
function ScrollUtil.AddReleasedFrameCallback(box, callback, owner)
    equal(box, scrollBox); box.callbacks.released = {callback,owner}
end
local nativeClick = function() end
local function lootRow(slot)
    local row = object(nil, modern)
    row.data = {slotIndex=slot}; row.Item = object(nil, row); row.Item.icon = {}
    row.Item.scripts.OnClick = nativeClick
    function row:GetSlotIndex() return self.data.slotIndex end
    function row:Init() self.nativeSlot = self:GetSlotIndex() end
    return row
end
local item, money, currency = lootRow(1), lootRow(2), lootRow(3)
scrollBox.rows = {item,money,currency}
local function initialize(row, slot)
    row.data = {slotIndex=slot}; row:Init(); row:Show()
    local callback = scrollBox.callbacks.initialized
    callback[1](callback[2], row, row.data)
end
local function release(row)
    local callback = scrollBox.callbacks.released
    callback[1](callback[2], row, row.data)
    for i, known in ipairs(scrollBox.rows) do if known == row then table.remove(scrollBox.rows,i); break end end
    row:Hide(); row.data = nil
end

-- A gamepad roll card can already be visible before the addon installs hooks.
GamepadGroupLootRollFrame = object("GamepadGroupLootRollFrame")
GamepadGroupLootRollFrame.ScrollBox = object(nil, GamepadGroupLootRollFrame)
local cards = {}
function GamepadGroupLootRollFrame.ScrollBox:EnumerateFrames() return ipairs(cards) end
local function rollCard(id)
    local card = object(nil, GamepadGroupLootRollFrame); card.rollID = id
    card.IconFrame = object(nil, card); card.IconFrame.Icon = {}
    return card
end
local oldCard = rollCard(10); cards[1] = oldCard
local rolls = {[10]="item:101:exact",[11]="item:102:exact",[12]="item:103:pending"}
GetLootRollItemLink = function(id) return rolls[id] end
GroupLootFrame_SetupItemDisplay = function() end
GroupLootFrame_OnShow = function() end

assert(loadfile("Indicators.lua"))("ZwykValues", FW)
FW:InstallUpgradeIndicators(); pump()
local event = FW.UpgradeIndicatorFrame
check(event.events.LOOT_READY and event.events.LOOT_OPENED and event.events.LOOT_CLOSED)
check(event.events.LOOT_SLOT_CLEARED and event.events.LOOT_SLOT_CHANGED)
equal(created,1,"indicators create only their event frame, not another item scanner")
equal(next(decisions),nil,"disabled locations perform no upgrade work")
FW.DB.options.upgradeBags = true
FW:RefreshUpgradeIndicators(); pump()
check(shown(item.Item)); check(not shown(money.Item) and not shown(currency.Item))
equal(#reads,1,"coin and currency rows never request an item link")
equal(decisions["item:101:exact"],1,"full discovery paints each item once")
equal(comparisons["item:101:exact"],1)
equal(item.Item.zvUpgradeArrow.anchor[2],item.Item.icon)
equal(item.Item.scripts.OnClick,nativeClick); equal(item.Item.scripts.OnUpdate,nil)
local before = comparisons["item:101:exact"]
FW:RefreshUpgradeIndicators(); pump()
equal(comparisons["item:101:exact"],before,"unchanged loot reuses the shared comparison memo")

-- Clear/autoloot animation can keep a live link and row visible temporarily.
event:Fire("OnEvent","LOOT_SLOT_CLEARED",1)
check(not shown(item.Item),"cleared loot loses its arrow immediately")
FW:RefreshUpgradeIndicators(); pump(); check(not shown(item.Item),"stale native links cannot restore cleared arrows")
event:Fire("OnEvent","LOOT_SLOT_CHANGED",1); item:Init(); pump(); check(shown(item.Item))
modern:Close(); check(modern:IsVisible() and not shown(item.Item))
FW:RefreshUpgradeIndicators(); pump(); check(not shown(item.Item),"closing animations cannot restore loot arrows")
modern:Open(); pump(); check(shown(item.Item))
event:Fire("OnEvent","LOOT_CLOSED"); check(not shown(item.Item))
event:Fire("OnEvent","LOOT_OPENED",true); pump(); check(shown(item.Item),"autoloot opening resets the cleared-slot session")

-- Pooled rows clear on release, rebind only after Init, and need no loot event when scrolling.
release(item); check(not shown(item.Item))
item:Show(); FW:RefreshUpgradeIndicators(); pump(); check(not shown(item.Item),"released rows reject stale identities")
types[4], links[4] = 1, "item:102:exact"
scrollBox.rows[#scrollBox.rows+1] = item
initialize(item,4); check(shown(item.Item)); equal(item.nativeSlot,4)
equal(#item.Item.textures,1,"pooled icons reuse the same overlay")
links[4] = nil; item:Init(); check(not shown(item.Item),"missing links immediately hide recycled loot")
links[4] = "item:103:pending"; item:Init(); check(not shown(item.Item))
result("item:103:pending"); FW:InvalidateUpgradeComparisons()
FW:RefreshUpgradeIndicators(); pump(); check(shown(item.Item),"coordinated item data completion restores pending loot")
links[4] = "item:104:partial"; item:Init(); check(not shown(item.Item))
links[4] = "item:105:excluded"; item:Init(); check(not shown(item.Item))
links[4] = "item:101:exact"; types[4] = 3; item:Init(); check(not shown(item.Item),"item-shaped currency links stay excluded")
types[4] = 1; item:Init(); check(shown(item.Item))
local savedMain = main; main = nil
FW:RefreshUpgradeIndicators(); pump(); check(not shown(item.Item))
main = savedMain; main.revision = main.revision + 1
FW:RefreshUpgradeIndicators(); pump(); check(shown(item.Item))
modern:Hide(); check(not shown(item.Item))
local readCount = #reads
FW:RefreshUpgradeIndicators(); pump(); equal(#reads,readCount,"hidden loot does not read item links")
modern:Show(); check(shown(item.Item))
event:Fire("OnEvent","ADDON_LOADED","Blizzard_UIPanels_Game"); pump()
equal(hookCounts[item].Init,1,"native Init hooks are idempotent")
equal(#item.Item.textures,1)

-- The existing roll option also covers unnamed, preexisting and newly initialized gamepad cards.
FW.DB.options.upgradeRolls = true
FW:RefreshUpgradeIndicators(); pump(); check(shown(oldCard.IconFrame))
equal(oldCard.IconFrame.zvUpgradeArrow.anchor[2],oldCard.IconFrame.Icon)
local dynamic = rollCard(11)
GroupLootFrame_SetupItemDisplay(dynamic,true); check(shown(dynamic.IconFrame))
dynamic.rollID = 12; GroupLootFrame_SetupItemDisplay(dynamic); check(shown(dynamic.IconFrame))
rolls[12] = nil; GroupLootFrame_SetupItemDisplay(dynamic); check(not shown(dynamic.IconFrame))
rolls[12] = "item:101:exact"; FW:RefreshUpgradeIndicators(); pump(); check(shown(dynamic.IconFrame))
event:Fire("OnEvent","CANCEL_LOOT_ROLL",12); check(not shown(dynamic.IconFrame))
pump(); check(not shown(dynamic.IconFrame))
dynamic.rollID = 11; GroupLootFrame_SetupItemDisplay(dynamic); check(shown(dynamic.IconFrame),"new roll binding is independent of the canceled ID")
event:Fire("OnEvent","CANCEL_ALL_LOOT_ROLLS"); pump()
check(not shown(oldCard.IconFrame) and not shown(dynamic.IconFrame))
event:Fire("OnEvent","START_LOOT_ROLL",11); pump(); check(shown(dynamic.IconFrame))
GamepadGroupLootRollFrame:Hide(); check(not shown(dynamic.IconFrame))
GamepadGroupLootRollFrame:Show(); check(shown(dynamic.IconFrame))
rolls[13] = "item:106:rollpending"; result(rolls[13],nil,"pending")
dynamic.rollID = 13; GroupLootFrame_SetupItemDisplay(dynamic)
check(not shown(dynamic.IconFrame),"pending roll data cannot establish an upgrade")
result(rolls[13],nil,"partial"); FW:InvalidateUpgradeComparisons()
FW:RefreshUpgradeIndicators(); pump(); check(not shown(dynamic.IconFrame))
result(rolls[13]); FW:InvalidateUpgradeComparisons()
FW:RefreshUpgradeIndicators(); pump(); check(shown(dynamic.IconFrame),"coordinated completion restores the same roll binding")
local rollDecisions = decisions[rolls[13]]
FW:RefreshUpgradeIndicators(); pump()
equal(decisions[rolls[13]],rollDecisions+1,"full discovery paints each registered roll once")
FW.DB.options.upgradeRolls = false
FW:RefreshUpgradeIndicators(); check(not shown(dynamic.IconFrame)); pump()
check(shown(item.Item),"loot follows Item windows independently of the Rolls toggle")

-- Older native windows paginate LootButtonN; its displayed slot must match the offset.
modern:Hide()
local legacy = object("LootFrame"); LootFrame = legacy
legacy.page, legacy.numLootItems = 2, 6
LOOTFRAME_NUMBUTTONS = 4
for i=1,4 do
    local button = object("LootButton"..i,legacy); button.id = i
    function button:IsEnabled() return self.enabled ~= false end
    _G["LootButton"..i], _G["LootButton"..i.."IconTexture"] = button, {}
end
function LootFrame_UpdateButton(index)
    local perPage = legacy.numLootItems > LOOTFRAME_NUMBUTTONS and LOOTFRAME_NUMBUTTONS-1 or LOOTFRAME_NUMBUTTONS
    local button, slot = _G["LootButton"..index], perPage*(legacy.page-1)+index
    button.slot, button.enabled = slot, true
    if index <= perPage and slot <= legacy.numLootItems then button:Show() else button:Hide() end
end
function LootFrame_Update() for i=1,4 do LootFrame_UpdateButton(i) end end
types[4],types[5],types[6] = 1,2,3
links[4],links[5],links[6] = "item:102:exact","item:101:exact","item:101:exact"
event:Fire("OnEvent","ADDON_LOADED","Blizzard_UIPanels_Game"); pump()
local offsetReads = #reads
LootFrame_Update(); check(shown(LootButton1))
check(not shown(LootButton2) and not shown(LootButton3) and not shown(LootButton4))
equal(reads[offsetReads+1],4,"second-page button1 uses slot4, not its button ID")
legacy.page = 1
FW:RefreshUpgradeIndicators(); pump(); check(not shown(LootButton1),"page changes cannot use the old displayed slot")
LootFrame_Update(); check(shown(LootButton1))
LootButton1.enabled = false; FW:RefreshUpgradeIndicators(); pump(); check(not shown(LootButton1))
LootButton1.enabled = true; LootFrame_UpdateButton(1); check(shown(LootButton1))
legacy.AutoLootTable = {{hide=true},{},{},{},{},{}}
LootFrame_UpdateButton(1); check(not shown(LootButton1),"autoloot-hidden legacy entries stay clear")
legacy.AutoLootTable[1].hide = nil
LootFrame_UpdateButton(1); check(shown(LootButton1))
event:Fire("OnEvent","LOOT_SLOT_CLEARED",1); check(not shown(LootButton1)); pump()
legacy.AutoLootTable = nil
event:Fire("OnEvent","LOOT_OPENED",false); pump(); check(shown(LootButton1))
FW.DB.options.upgradeBags = false
FW:RefreshUpgradeIndicators(); check(not shown(LootButton1))
readCount = #reads; pump(); LootFrame_Update()
equal(#reads,readCount,"disabled loot does no item-link or comparison work")
check(not event.scripts.OnUpdate and not LootButton1.scripts.OnUpdate,"loot integration adds no polling")
equal(created,1)
print("Loot and pooled-roll indicators: " .. checks .. " checks passed.")
