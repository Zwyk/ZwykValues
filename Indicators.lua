local _, FW = ...

-- Audited against Gethe/wow-ui-source's Forever UI (735496d): containers,
-- bank panels, trade and merchant windows expose their own live item slots.
-- Only those known owners are visited; no global frame-discovery walk is used.
local buttons, containers, hookTargets, owners, windows = {}, {}, {}, {}, {}
local arrowTexture = "Interface\\AddOns\\ZwykValues\\Textures\\ArrowUp"
local profileArrowTexture = "Interface\\AddOns\\ZwykValues\\Textures\\ArrowUpWhite"
local MAX_PROFILE_MARKERS = 3
local refreshPending = false
local betterBagsItems = setmetatable({}, { __mode = "k" })
local betterBagsEvents, betterBagsMessages
local betterBagsBankBags = {}
local lootScrolls, clearedLootSlots, lootClosed = {}, {}, false

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

local function enabled(option)
    return FW.DB and FW.DB.options and FW.DB.options[option] == true
end

local function hide(entry)
    if not entry then return end
    for _, texture in ipairs(entry.textures or {}) do texture:Hide() end
    if entry.overflow then entry.overflow:Hide() end
end

local function marker(button, entry, index)
    entry.textures = entry.textures or {}
    if entry.textures[index] then return entry.textures[index] end
    if type(button.CreateTexture) ~= "function" then return end
    local ok, texture = pcall(button.CreateTexture, button, nil, "OVERLAY", nil, 7)
    if not ok or not texture then return end
    entry.textures[index] = texture
    -- Keep the original first-marker handle for existing integrations.
    if index == 1 then entry.texture, button.zvUpgradeArrow = texture, texture end
    button.zvUpgradeArrows = entry.textures
    return texture
end

local function overflow(button, entry, count)
    if count <= 0 then
        if entry.overflow then entry.overflow:Hide() end
        return
    end
    if not entry.overflow and type(button.CreateFontString) == "function" then
        local ok, label = pcall(button.CreateFontString, button, nil, "OVERLAY", "GameFontNormalSmall")
        if ok and label then
            entry.overflow = label
            if type(label.SetTextColor) == "function" then label:SetTextColor(1, 1, 1) end
            if type(label.SetShadowOffset) == "function" then label:SetShadowOffset(1, -1) end
            button.zvUpgradeOverflow = label
        end
    end
    if entry.overflow then
        if type(entry.overflow.ClearAllPoints) == "function" then entry.overflow:ClearAllPoints() end
        entry.overflow:SetPoint("TOPRIGHT", entry.anchor or button, "TOPRIGHT", -1, -12)
        entry.overflow:SetText("+" .. count)
        entry.overflow:Show()
    end
end

local function channel(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    return math.max(0, math.min(1, value))
end

local function paint(button, entry)
    if not enabled(entry.option) or not visible(button) or
        (entry.owner and not visible(entry.owner)) then hide(entry); return end
    local ok, link = pcall(entry.provider, button)
    if not ok or (issecretvalue and issecretvalue(link)) or type(link) ~= "string" or not link:find("item:", 1, true) then
        hide(entry); return
    end
    local profiles, legacy
    if type(FW.GetItemUpgradeProfiles) == "function" then
        ok, profiles = pcall(FW.GetItemUpgradeProfiles, FW, link)
        if not ok or type(profiles) ~= "table" or #profiles == 0 then hide(entry); return end
    else
        -- Third-party adapters written for the original boolean API still
        -- receive their usual green marker; production uses one profile list.
        if type(FW.IsMainProfileUpgrade) ~= "function" then hide(entry); return end
        ok, legacy = pcall(FW.IsMainProfileUpgrade, FW, link)
        if not ok or not legacy then hide(entry); return end
        profiles = {false}
    end
    local count = math.min(#profiles, MAX_PROFILE_MARKERS)
    for index = 1, count do
        local texture = marker(button, entry, index)
        if not texture then hide(entry); return end
        local profile = profiles[index]
        local color = type(profile) == "table" and profile.color or {}
        texture:SetTexture(legacy and arrowTexture or profileArrowTexture)
        if type(texture.SetVertexColor) == "function" then
            texture:SetVertexColor(legacy and 1 or channel(color.r), legacy and 1 or channel(color.g),
                legacy and 1 or channel(color.b), 1)
        end
        local size = count == 1 and 16 or 12
        texture:SetSize(size, size)
        if type(texture.ClearAllPoints) == "function" then texture:ClearAllPoints() end
        texture:SetPoint("TOPLEFT", entry.anchor or button, "TOPLEFT", (index - 1) * 10, 0)
        texture:Show()
    end
    for index = count + 1, #(entry.textures or {}) do entry.textures[index]:Hide() end
    overflow(button, entry, #profiles - count)
end

local function hookMethod(target, method, callback)
    if not usable(target) or type(target[method]) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    local methods = hookTargets[target]
    if not methods then methods = {}; hookTargets[target] = methods end
    if methods[method] then return end
    local ok = pcall(hooksecurefunc, target, method, callback)
    if ok then methods[method] = true end
end

local function register(button, provider, option, owner, anchor, deferPaint)
    if not usable(button) or type(provider) ~= "function" then return end
    local entry = buttons[button]
    if not entry then
        entry = {}; buttons[button] = entry
        if type(button.HookScript) == "function" then
            pcall(button.HookScript, button, "OnHide", function() hide(entry) end)
            pcall(button.HookScript, button, "OnShow", function() paint(button, entry) end)
        end
        -- Clear old decoration at the moment a recycled button changes its
        -- slot. The native Initialize hook repaints after bag AND slot settle.
        hookMethod(button, "SetID", function()
            hide(entry)
            FW:RefreshUpgradeIndicators()
        end)
        hookMethod(button, "Initialize", function() paint(button, entry) end)
        hookMethod(button, "SetBagID", function() hide(entry) end)
    end
    entry.provider, entry.option, entry.owner, entry.anchor = provider, option, owner, anchor
    if usable(owner) and not owners[owner] and type(owner.HookScript) == "function" then
        owners[owner] = true
        pcall(owner.HookScript, owner, "OnHide", function()
            for _, owned in pairs(buttons) do if owned.owner == owner then hide(owned) end end
        end)
    end
    if not deferPaint then paint(button, entry) end
    return entry
end

local function validIndex(value, minimum)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == math.floor(value) and value >= (minimum or 1)
end

local function containerLink(bag, slot)
    if not validIndex(bag, -3) or not validIndex(slot) then return end
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        return C_Container.GetContainerItemLink(bag, slot)
    elseif type(GetContainerItemLink) == "function" then
        return GetContainerItemLink(bag, slot)
    end
end

local function isNativeBag(bag)
    if not validIndex(bag, -3) then return false end
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_TOTAL_BAG_FRAMES or NUM_BAG_SLOTS or 4
    if bag >= 0 and bag <= lastBag + (NUM_BANKBAGSLOTS or NUM_BANK_BAG_SLOTS or 7) then return true end
    if bag == (BANK_CONTAINER or -1) or bag == (REAGENTBANK_CONTAINER or -3) then return true end
    -- Current bank tabs have client-defined container IDs, including account
    -- storage. Compare explicit BagIndex constants rather than guessing ranges.
    for name, id in pairs(Enum and Enum.BagIndex or {}) do
        if type(name) == "string" and name:lower():find("bank", 1, true) and bag == id then return true end
    end
    return false
end

local function bagLink(button)
    local bag
    if type(button.GetBagID) == "function" then bag = button:GetBagID() end
    if bag == nil and type(button.GetParent) == "function" then
        local parent = button:GetParent()
        if usable(parent) and type(parent.GetID) == "function" then bag = parent:GetID() end
    end
    local slot = type(button.GetID) == "function" and button:GetID()
    if isNativeBag(bag) then return containerLink(bag, slot) end
end

local function scanContainer(container, deferPaint)
    if not usable(container) or not enabled("upgradeBags") or not visible(container) then return end
    local function visit(button)
        if usable(button) then
            register(button, bagLink, "upgradeBags", container, button.icon or button.Icon, deferPaint)
        end
    end
    if type(container.EnumerateValidItems) == "function" then
        -- Native Forever's iterator yields index, button (not pool keys).
        for _, button in container:EnumerateValidItems() do visit(button) end
    elseif type(container.Items) == "table" then
        for _, button in ipairs(container.Items) do visit(button) end
    else
        local name = type(container.GetName) == "function" and container:GetName()
        if type(name) == "string" and type(container.size) == "number" then
            for index = 1, container.size do visit(_G[name .. "Item" .. index]) end
        end
    end
end

local function hookContainer(container)
    if not usable(container) or containers[container] then return end
    containers[container] = true
    if type(container.HookScript) == "function" then
        pcall(container.HookScript, container, "OnShow", function() scanContainer(container) end)
        pcall(container.HookScript, container, "OnHide", function()
            for _, entry in pairs(buttons) do if entry.owner == container then hide(entry) end end
        end)
    end
    hookMethod(container, "UpdateItems", function() scanContainer(container) end)
    hookMethod(container, "UpdateItemSlots", function() scanContainer(container) end)
end

local function visitNativeContainers(callback)
    local seen = {}
    local function visit(frame)
        if frame and not seen[frame] then seen[frame] = true; callback(frame) end
    end
    visit(ContainerFrameCombinedBags)
    local owner = ContainerFrameContainer or UIParent
    if owner and type(owner.ContainerFrames) == "table" then
        for _, container in ipairs(owner.ContainerFrames) do visit(container) end
    end
    for index = 1, NUM_CONTAINER_FRAMES or 13 do visit(_G["ContainerFrame" .. index]) end
end

local function registerRollFrame(frame, deferPaint)
    if not usable(frame) then return end
    local name = type(frame.GetName) == "function" and frame:GetName()
    local icon = frame.IconFrame or (type(name) == "string" and _G[name .. "IconFrame"])
    if not usable(icon) then return end
    local entry = buttons[icon]
    entry = register(icon, function()
        local rollID = frame.rollID
        if rollID == nil or (entry and entry.cancelledRollID == rollID) or type(GetLootRollItemLink) ~= "function" then return end
        return GetLootRollItemLink(rollID)
    end, "upgradeRolls", frame, icon.Icon or icon.icon, deferPaint)
    if entry and not entry.ownerHideHook then
        entry.ownerHideHook = true
        if type(frame.HookScript) == "function" then
            pcall(frame.HookScript, frame, "OnHide", function() hide(entry) end)
            pcall(frame.HookScript, frame, "OnShow", function() paint(icon, entry) end)
        end
    end
end

local function visitRollFrames(callback)
    local seen = {}
    local function visit(frame)
        if usable(frame) and not seen[frame] then seen[frame] = true; callback(frame) end
    end
    for index = 1, NUM_GROUP_LOOT_FRAMES or 4 do visit(_G["GroupLootFrame" .. index]) end
    -- Current Forever also uses unnamed gamepad cards with the same IconFrame
    -- and rollID contract. SetupItemDisplay catches newly initialized cards;
    -- this explicit owner catches cards already visible when hooks install.
    local scrollBox = GamepadGroupLootRollFrame and GamepadGroupLootRollFrame.ScrollBox
    if usable(scrollBox) and type(scrollBox.EnumerateFrames) == "function" then
        for _, frame in scrollBox:EnumerateFrames() do visit(frame) end
    end
end

local globalHooks = {}
local function hookGlobal(name, callback)
    if globalHooks[name] or type(_G[name]) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    if pcall(hooksecurefunc, name, callback) then globalHooks[name] = true end
end

local function watchWindow(frame, refresh)
    if not usable(frame) or windows[frame] then return end
    windows[frame] = true
    if type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", refresh)
    end
end

local function clearLootIndicators(slot)
    for _, entry in pairs(buttons) do
        if entry.lootSlotProvider then
            local ok, current = pcall(entry.lootSlotProvider)
            if slot == nil or entry.lootSlot == slot or (ok and current == slot) then hide(entry) end
        end
    end
end

local function registerLootButton(button, slotProvider, anchor, row, deferPaint)
    if not usable(button) then return end
    local entry = buttons[button]
    entry = register(button, function()
        if lootClosed or (entry and entry.lootReleased) then return end
        local slot = slotProvider()
        if entry then entry.lootSlot = slot end
        if not validIndex(slot) or clearedLootSlots[slot] or type(GetLootSlotType) ~= "function" or
            type(GetLootSlotLink) ~= "function" then return end
        local itemType = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or LOOT_SLOT_ITEM or 1
        if GetLootSlotType(slot) ~= itemType then return end
        return GetLootSlotLink(slot)
    end, "upgradeBags", LootFrame, anchor, deferPaint)
    if not entry then return end
    entry.lootSlotProvider, entry.lootRow = slotProvider, row
    local ok, slot = pcall(slotProvider)
    if ok then entry.lootSlot = slot end
    return entry
end

local function registerLootRow(row, deferPaint)
    if not usable(row) or type(row.GetSlotIndex) ~= "function" then return end
    local button = row.Item
    local entry = registerLootButton(button, function() return row:GetSlotIndex() end,
        button and (button.icon or button.Icon), row, deferPaint)
    if not entry then return end
    -- LOOT_SLOT_CHANGED reinitializes an existing row directly, without a
    -- ScrollBox acquisition. Native Init finishes the icon before this hook.
    hookMethod(row, "Init", function()
        entry.lootReleased = false
        paint(button, entry)
    end)
end

local function legacyLootSlot(button, index)
    if type(button.IsEnabled) == "function" and not button:IsEnabled() then return end
    local frame = LootFrame
    if not usable(frame) or not validIndex(frame.page) then return end
    local count = frame.numLootItems
    if type(frame.AutoLootTable) == "table" then count = #frame.AutoLootTable end
    if not validIndex(count, 0) then return end
    local perPage = LOOTFRAME_NUMBUTTONS or 4
    if count > perPage then perPage = perPage - 1 end
    if index > perPage then return end
    local slot = perPage * (frame.page - 1) + index
    if slot > count or button.slot ~= slot then return end
    local autoLoot = frame.AutoLootTable and frame.AutoLootTable[slot]
    if autoLoot and autoLoot.hide then return end
    return slot
end

local function registerLegacyLootButton(index, deferPaint)
    if not validIndex(index) or index > (LOOTFRAME_NUMBUTTONS or 4) then return end
    local button = _G["LootButton" .. index]
    registerLootButton(button, function() return legacyLootSlot(button, index) end,
        button and (button.icon or button.Icon or _G["LootButton" .. index .. "IconTexture"]), nil, deferPaint)
end

local function scanLoot(deferPaint)
    local frame = LootFrame
    if not usable(frame) then return end
    watchWindow(frame, function() scanLoot() end)
    hookMethod(frame, "Open", function()
        lootClosed, clearedLootSlots = false, {}
        scanLoot()
    end)
    hookMethod(frame, "Close", function()
        lootClosed = true
        clearLootIndicators()
    end)
    local scrollBox = frame.ScrollBox
    if usable(scrollBox) and type(ScrollUtil) == "table" then
        local subscriptions = lootScrolls[scrollBox]
        if not subscriptions then subscriptions = {}; lootScrolls[scrollBox] = subscriptions end
        if not subscriptions.initialized and type(ScrollUtil.AddInitializedFrameCallback) == "function" then
            subscriptions.initialized = pcall(ScrollUtil.AddInitializedFrameCallback, scrollBox, function(_, row)
                -- Reused rows already repaint in Init; first-seen rows need
                -- discovery here even when scrolling creates no loot event.
                local known = row and buttons[row.Item]
                if known then known.lootReleased = false end
                registerLootRow(row, known ~= nil)
            end, FW, false)
        end
        if not subscriptions.released and type(ScrollUtil.AddReleasedFrameCallback) == "function" then
            subscriptions.released = pcall(ScrollUtil.AddReleasedFrameCallback, scrollBox, function(_, row)
                local entry = row and buttons[row.Item]
                if entry then entry.lootReleased = true; hide(entry) end
            end, FW)
        end
    end
    if not enabled("upgradeBags") or not visible(frame) then return end
    if usable(scrollBox) and type(scrollBox.ForEachFrame) == "function" then
        scrollBox:ForEachFrame(function(row) registerLootRow(row, deferPaint) end)
    else
        for index = 1, LOOTFRAME_NUMBUTTONS or 4 do registerLegacyLootButton(index, deferPaint) end
    end
end

local function bankPanelLink(button)
    if button.isInitialized == false or type(button.GetBankTabID) ~= "function" or
        type(button.GetContainerSlotID) ~= "function" then return end
    return containerLink(button:GetBankTabID(), button:GetContainerSlotID())
end

local function registerBankPanelButton(button, panel, deferPaint)
    if not usable(button) then return end
    local entry = register(button, bankPanelLink, "upgradeBags", BankFrame or panel, button.icon or button.Icon, deferPaint)
    if not entry then return end
    hookMethod(button, "SetBankTabID", function() hide(entry) end)
    hookMethod(button, "SetContainerSlotID", function() hide(entry) end)
    hookMethod(button, "Refresh", function() paint(button, entry) end)
end

local function legacyBankLink(button)
    if button.isBag then return end
    local parent = type(button.GetParent) == "function" and button:GetParent()
    local bag = usable(parent) and type(parent.GetID) == "function" and parent:GetID()
    local slot = type(button.GetID) == "function" and button:GetID()
    if bag == (BANK_CONTAINER or -1) or bag == (REAGENTBANK_CONTAINER or -3) then
        return containerLink(bag, slot)
    end
    if type(button.GetInventorySlot) == "function" and type(GetInventoryItemLink) == "function" then
        local inventorySlot = button:GetInventorySlot()
        if validIndex(inventorySlot) then return GetInventoryItemLink("player", inventorySlot) end
    end
end

local function scanBank(deferPaint)
    local frame = BankFrame
    if not usable(frame) then return end
    watchWindow(frame, function() scanBank() end)
    local panel = frame.BankPanel or BankPanel
    if usable(panel) then
        watchWindow(panel, function() scanBank() end)
        hookMethod(panel, "GenerateItemSlotsForSelectedTab", function() scanBank() end)
        hookMethod(panel, "RefreshAllItemsForSelectedTab", function() scanBank() end)
    end
    if not enabled("upgradeBags") or not visible(frame) then return end
    if usable(panel) and visible(panel) and type(panel.EnumerateValidItems) == "function" then
        -- BankPanel's pool iterator yields button directly (unlike bags).
        -- Existing buttons repaint in their native Refresh/OnShow hooks;
        -- discovery only paints new buttons outside a shared refresh pass.
        for button in panel:EnumerateValidItems() do
            registerBankPanelButton(button, panel, deferPaint or buttons[button] ~= nil)
        end
    end
    for index = 1, NUM_BANKGENERIC_SLOTS or 28 do
        local button = _G["BankFrameItem" .. index] or (BankSlotsFrame and BankSlotsFrame["Item" .. index])
        register(button, legacyBankLink, "upgradeBags", frame, button and (button.icon or button.Icon),
            deferPaint or buttons[button] ~= nil)
    end
    local reagent = ReagentBankFrame
    if usable(reagent) then
        watchWindow(reagent, function() scanBank() end)
        for index = 1, NUM_REAGENTBANKGENERIC_SLOTS or 98 do
            local button = _G["ReagentBankFrameItem" .. index] or (reagent.ItemSlots and reagent.ItemSlots[index])
            register(button, legacyBankLink, "upgradeBags", reagent, button and (button.icon or button.Icon),
                deferPaint or buttons[button] ~= nil)
        end
    end
end

local function registerTradeItem(id, target, deferPaint)
    if not validIndex(id) or id > (MAX_TRADE_ITEMS or 7) then return end
    local button = _G[(target and "TradeRecipientItem" or "TradePlayerItem") .. id .. "ItemButton"]
    register(button, function()
        local provider = target and GetTradeTargetItemLink or GetTradePlayerItemLink
        if type(provider) == "function" then return provider(id) end
    end, "upgradeBags", TradeFrame, button and (button.icon or button.Icon), deferPaint)
end

local function scanTrade(deferPaint)
    if not usable(TradeFrame) then return end
    watchWindow(TradeFrame, function() scanTrade() end)
    if not enabled("upgradeBags") or not visible(TradeFrame) then return end
    for index = 1, MAX_TRADE_ITEMS or 7 do
        registerTradeItem(index, false, deferPaint)
        registerTradeItem(index, true, deferPaint)
    end
end

local function merchantLink(button)
    if not usable(MerchantFrame) then return end
    local index = type(button.GetID) == "function" and button:GetID()
    if not validIndex(index) then return end
    if MerchantFrame.selectedTab == 1 then
        if type(GetMerchantNumItems) == "function" and index > GetMerchantNumItems() then return end
        if type(GetMerchantItemLink) == "function" then return GetMerchantItemLink(index) end
    elseif MerchantFrame.selectedTab == 2 then
        if type(GetNumBuybackItems) == "function" and index > GetNumBuybackItems() then return end
        if type(GetBuybackItemLink) == "function" then return GetBuybackItemLink(index) end
    end
end

local function latestBuybackLink()
    if not usable(MerchantFrame) or MerchantFrame.selectedTab ~= 1 or
        type(GetNumBuybackItems) ~= "function" or type(GetBuybackItemLink) ~= "function" then return end
    local index = GetNumBuybackItems()
    if validIndex(index) then return GetBuybackItemLink(index) end
end

local function scanMerchant(deferPaint)
    if not usable(MerchantFrame) then return end
    watchWindow(MerchantFrame, function() scanMerchant() end)
    if not enabled("upgradeBags") or not visible(MerchantFrame) then return end
    for index = 1, math.max(MERCHANT_ITEMS_PER_PAGE or 10, BUYBACK_ITEMS_PER_PAGE or 12) do
        local button = _G["MerchantItem" .. index .. "ItemButton"]
        register(button, merchantLink, "upgradeBags", MerchantFrame, button and (button.icon or button.Icon), deferPaint)
    end
    local button = MerchantBuyBackItemItemButton
    register(button, latestBuybackLink, "upgradeBags", MerchantFrame, button and (button.icon or button.Icon), deferPaint)
    -- MerchantRepairItemButton is an action control, not an item icon. Gear
    -- keeps its ordinary bag arrows while that repair mode is active.
end

local function installItemWindowHooks()
    scanBank(true); scanTrade(true); scanMerchant(true); scanLoot(true)
    hookGlobal("BankFrameItemButton_Update", function(button)
        if button and not button.isBag then
            register(button, legacyBankLink, "upgradeBags", BankFrame, button.icon or button.Icon)
        end
    end)
    hookGlobal("ReagentBankFrameItemButton_Update", function(button)
        register(button, legacyBankLink, "upgradeBags", ReagentBankFrame, button and (button.icon or button.Icon))
    end)
    hookGlobal("TradeFrame_UpdatePlayerItem", function(id) registerTradeItem(id, false) end)
    hookGlobal("TradeFrame_UpdateTargetItem", function(id) registerTradeItem(id, true) end)
    hookGlobal("MerchantFrame_UpdateMerchantInfo", function() scanMerchant() end)
    hookGlobal("MerchantFrame_UpdateBuybackInfo", function() scanMerchant() end)
    -- The legacy native updater has already assigned button.slot, including
    -- its page offset, and updated the enabled/visible state at this point.
    hookGlobal("LootFrame_UpdateButton", function(index) registerLegacyLootButton(index) end)
    hookGlobal("LootFrame_Update", function() scanLoot(true) end)
end

local function installNativeHooks()
    visitNativeContainers(hookContainer)
    hookGlobal("ContainerFrame_Update", function(frame) hookContainer(frame); scanContainer(frame) end)
    hookGlobal("ContainerFrame_GenerateFrame", function(frame) hookContainer(frame); scanContainer(frame) end)
    hookGlobal("GroupLootFrame_SetupItemDisplay", function(frame) registerRollFrame(frame) end)
    hookGlobal("GroupLootFrame_OnShow", function(frame) registerRollFrame(frame) end)
    hookGlobal("GroupLootContainer_OpenNewFrame", function() FW:RefreshUpgradeIndicators() end)
    visitRollFrames(function(frame) registerRollFrame(frame, true) end)
    installItemWindowHooks()
end

local function betterBagsLink(item)
    if type(item) ~= "table" or item.staticData or item.isFreeSlot or
        type(item.GetItemData) ~= "function" then return end
    local ok, data = pcall(item.GetItemData, item)
    if not ok or type(data) ~= "table" or data.isItemEmpty or data.isFreeSlot or data.isItemGap then return end
    local bag, slot = data.bagid, data.slotid
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_TOTAL_BAG_FRAMES or NUM_BAG_SLOTS or 4
    if (issecretvalue and (issecretvalue(bag) or issecretvalue(slot))) or
        type(bag) ~= "number" or bag ~= math.floor(bag) or
        (not betterBagsBankBags[bag] and (bag < 0 or bag > lastBag)) or
        type(slot) ~= "number" or slot < 1 or slot ~= math.floor(slot) then return end
    local link = data.itemInfo and data.itemInfo.itemLink
    if (issecretvalue and issecretvalue(link)) or type(link) ~= "string" or not link:find("item:", 1, true) then return end
    return link
end

local function updateBetterBagsItem(_, item, decoration, deferPaint)
    local record = betterBagsItems[item]
    if not betterBagsLink(item) or not usable(decoration) then
        if record then record.cleared = true; hide(buttons[record.button]) end
        return
    end
    if not record then record = {}; betterBagsItems[item] = record end
    if record.button and record.button ~= decoration then hide(buttons[record.button]) end
    record.button, record.cleared = decoration, false
    register(decoration, function(button)
        if record.cleared or record.button ~= button then return end
        return betterBagsLink(item)
    end, "upgradeBags", item.frame, decoration.IconTexture or decoration.icon or decoration.Icon, deferPaint)
end

local function clearBetterBagsItem(_, item, decoration)
    -- Clearing is sent before BetterBags resets its live data.
    local record = betterBagsItems[item]
    if record then record.cleared = true; hide(buttons[record.button]) end
    if buttons[decoration] then hide(buttons[decoration]) end
end

local function refreshBetterBags(deferPaint)
    if not LibStub then return end
    local ok, ace = pcall(function() return LibStub("AceAddon-3.0", true) end)
    if not ok or not ace or type(ace.GetAddon) ~= "function" then return end
    local loaded, addon = pcall(ace.GetAddon, ace, "BetterBags", true)
    if not loaded or not addon or type(addon.GetModule) ~= "function" then return end
    local function module(name)
        local found, value = pcall(addon.GetModule, addon, name, true)
        if found then return value end
    end
    local events, items, themes, context = module("Events"), module("ItemFrame"), module("Themes"), module("Context")
    -- Modules exist before OnInitialize; RegisterMessage needs initialized maps.
    if not events or type(events._messageMap) ~= "table" or type(events.RegisterMessage) ~= "function" or
        not items or type(items.buttonsBySlotkey) ~= "table" or not themes or
        type(themes.GetItemButton) ~= "function" or not context or type(context.New) ~= "function" then return end
    local constants = module("Constants")
    betterBagsBankBags = {}
    for _, name in ipairs({ "BANK_BAGS", "ACCOUNT_BANK_BAGS" }) do
        for _, bag in pairs(constants and constants[name] or {}) do
            if type(bag) == "number" and bag == math.floor(bag) then betterBagsBankBags[bag] = true end
        end
    end
    if betterBagsEvents ~= events then betterBagsEvents, betterBagsMessages = events, {} end
    local function subscribe(message, callback)
        if not betterBagsMessages[message] and pcall(events.RegisterMessage, events, message, callback) then
            betterBagsMessages[message] = true
        end
    end
    subscribe("item/Updated", function(ctx, item, decoration)
        updateBetterBagsItem(ctx, item, decoration)
        -- Updated precedes the item's Show, including list-row icons.
        FW:RefreshUpgradeIndicators()
    end)
    subscribe("item/Clearing", clearBetterBagsItem)
    if not enabled("upgradeBags") then return end
    local created, ctx = pcall(context.New, context, "ZwykValuesUpgradeIndicators")
    if not created or not ctx then return end
    local seen = {}
    local function visit(item)
        if type(item) ~= "table" or seen[item] then return end
        seen[item] = true
        if betterBagsLink(item) and visible(item.frame) then
            local themed, decoration = pcall(themes.GetItemButton, themes, ctx, item)
            if themed then updateBetterBagsItem(ctx, item, decoration, deferPaint) end
        end
    end
    for _, item in pairs(items.buttonsBySlotkey) do visit(item) end
    for item in pairs(items.activeItems or {}) do visit(item) end
end

function FW:RegisterUpgradeItemButton(button, linkProvider, options)
    -- Addon windows can supply a live provider, owner and icon anchor. Full
    -- discovery passes defer painting until the shared registry paints once.
    options = type(options) == "table" and options or {}
    return register(button, linkProvider, "upgradeBags", options.owner, options.anchor, options.deferPaint) ~= nil
end

function FW:RefreshBagUpgradeIndicators()
    -- Discovery updates live providers first; paint each registered button
    -- once below. Native update/show hooks keep their immediate decoration.
    refreshBetterBags(true)
    if enabled("upgradeBags") then
        visitNativeContainers(function(frame) hookContainer(frame); scanContainer(frame, true) end)
        scanBank(true); scanTrade(true); scanMerchant(true); scanLoot(true)
        if type(self.RefreshAuctionUpgradeIndicators) == "function" then self:RefreshAuctionUpgradeIndicators(true) end
    end
    for button, entry in pairs(buttons) do
        if entry.option == "upgradeBags" then paint(button, entry) end
    end
end

function FW:RefreshRollUpgradeIndicators()
    if enabled("upgradeRolls") then
        visitRollFrames(function(frame) registerRollFrame(frame, true) end)
    end
    for button, entry in pairs(buttons) do
        if entry.option == "upgradeRolls" then paint(button, entry) end
    end
end

function FW:RefreshUpgradeIndicators()
    -- Disabled locations disappear immediately; scoring waits until the next
    -- tick so the equipment event's revision and native slot updates settle.
    for _, entry in pairs(buttons) do if not enabled(entry.option) then hide(entry) end end
    if refreshPending then return end
    refreshPending = true
    local function refresh()
        refreshPending = false
        FW:RefreshBagUpgradeIndicators()
        FW:RefreshRollUpgradeIndicators()
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, refresh)
    elseif self.UpgradeIndicatorFrame then
        self.UpgradeIndicatorFrame:SetScript("OnUpdate", function(frame)
            frame:SetScript("OnUpdate", nil)
            refresh()
        end)
    else
        refresh()
    end
end

function FW:InstallUpgradeIndicators()
    if self.UpgradeIndicatorFrame or type(CreateFrame) ~= "function" then return end
    local frame = CreateFrame("Frame")
    self.UpgradeIndicatorFrame = frame
    frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
        if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then installNativeHooks() end
        if event == "LOOT_OPENED" then
            lootClosed, clearedLootSlots = false, {}
        elseif event == "LOOT_SLOT_CLEARED" then
            if validIndex(arg1) then clearedLootSlots[arg1] = true; clearLootIndicators(arg1) end
        elseif event == "LOOT_SLOT_CHANGED" then
            if validIndex(arg1) then clearedLootSlots[arg1] = nil end
        elseif event == "LOOT_CLOSED" then
            lootClosed = true
            clearLootIndicators()
        end
        if event == "CANCEL_LOOT_ROLL" or event == "CANCEL_ALL_LOOT_ROLLS" then
            for _, entry in pairs(buttons) do
                if entry.option == "upgradeRolls" and entry.owner and
                    (event == "CANCEL_ALL_LOOT_ROLLS" or entry.owner.rollID == arg1) then
                    entry.cancelledRollID = entry.owner.rollID
                    hide(entry)
                end
            end
        elseif event == "START_LOOT_ROLL" then
            for _, entry in pairs(buttons) do
                if entry.option == "upgradeRolls" and entry.cancelledRollID == arg1 then entry.cancelledRollID = nil end
            end
        end
        FW:RefreshUpgradeIndicators()
    end)
    for _, event in ipairs({
        "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED",
        "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_OPEN", "BAG_CLOSED", "BAG_CONTAINER_UPDATE", "USE_COMBINED_BAGS_CHANGED",
        -- Bootstrap coordinates successful pending-item completions. Listening
        -- independently would redraw all bags for unsolicited cache events.
        "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
        "PLAYERREAGENTBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
        "TRADE_SHOW", "TRADE_CLOSED", "TRADE_UPDATE", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
        "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE",
        "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED",
    }) do pcall(frame.RegisterEvent, frame, event) end
    installNativeHooks()
    self:RefreshUpgradeIndicators()
end
