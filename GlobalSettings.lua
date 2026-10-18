local _, FW = ...

local optionGroups = {
    { title="Upgrade indicators", y=86, options={
        {key="upgradeBags", label="Item windows", upgrade=true,
            help="Show upgrade arrows in bags, loot, banks, trade, vendor and auction house windows."},
        {key="upgradeRolls", label="Loot rolls", upgrade=true,
            help="Show upgrade arrows in native loot-roll windows."},
        {key="upgradeChat", label="Chat item links", upgrade=true,
            help="Show upgrade arrows next to newly received chat item links. Existing messages keep their original display."},
    }},
    { title="Tooltips", y=208, options={
        {key="showComparisons", label="Show upgrade comparisons", default=true,
            help="Show the score change and percentage comparison for each visible profile, using its selected equipped gear or equipment set."},
        {key="showProfileIcon", label="Profile icon", default=true,
            help="Show the profile's chosen decorative icon beside its name in item tooltips."},
        {key="showClassIcon", label="Class icon", default=true,
            help="Show the profile's class, specialization or group icon beside its name in item tooltips."},
        {key="debugUnknownStats", label="Mark unrecognized stats",
            help="Add [ZV ?] beside unrecognized item stat lines. Partial-data warnings and the issue log are always available."},
    }},
}

local function text(parent, value, font, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, -y)
    label:SetText(value)
    return label
end

function FW:RefreshGlobalSettings()
    local frame = self.globalSettingsFrame
    if not frame or not self.DB then return end
    local options = self.DB.options or {}
    for _, group in ipairs(optionGroups) do
        for _, definition in ipairs(group.options) do
            local value = options[definition.key]
            if value == nil then value = definition.default == true end
            frame.controls[definition.key]:SetChecked(value == true)
        end
    end
end

function FW:ShowGlobalSettings(owner)
    self:Initialize()
    local frame = self.globalSettingsFrame
    if not frame then
        frame = CreateFrame("Frame", "ZwykValuesGlobalSettings", UIParent, "BackdropTemplate")
        self.globalSettingsFrame, self.GlobalSettingsFrame = frame, frame
        frame:SetSize(520, 410)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
            tileSize=32, edgeSize=32, insets={left=8, right=8, top=8, bottom=8}})
        text(frame, "ZwykValues - Global settings", "GameFontNormalLarge", 24, 20)
        local help = text(frame, "Applies to all profiles. Changes take effect immediately.", "GameFontHighlightSmall", 24, 48)
        help:SetWidth(470)
        help:SetJustifyH("LEFT")
        frame.controls = {}
        for _, group in ipairs(optionGroups) do
            text(frame, group.title, "GameFontNormal", 25, group.y)
            for index, definition in ipairs(group.options) do
                local option = definition
                local control = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
                control:SetSize(24, 24)
                control:SetPoint("TOPLEFT", 25, -(group.y + 20 + (index - 1) * 27))
                control.optionKey, control.default = option.key, option.default == true
                control.label = text(control, option.label, "GameFontHighlight", 29, 5)
                control:SetScript("OnClick", function(button)
                    local setter = option.upgrade and FW.SetUpgradeOption or FW.SetGlobalOption
                    local ok, errorMessage = setter(FW, option.key, button:GetChecked() and true or false)
                    frame.status:SetText(ok and "" or (errorMessage or "Could not update this setting."))
                    FW:RefreshGlobalSettings()
                end)
                control:SetScript("OnEnter", function(button)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                    GameTooltip:SetText(option.label, 1, .82, 0)
                    GameTooltip:AddLine(option.help, .9, .9, .9, true)
                    if option.upgrade then
                        GameTooltip:AddLine("Requires a profile enabled for upgrade arrows.", .75, .75, .75, true)
                    end
                    GameTooltip:Show()
                end)
                control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                frame.controls[option.key] = control
            end
        end
        frame.status = text(frame, "", "GameFontHighlightSmall", 25, 365)
        frame.status:SetTextColor(1, .35, .35)
        frame.status:SetWidth(355)
        frame.status:SetJustifyH("LEFT")
        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(90, 25)
        close:SetPoint("BOTTOMRIGHT", -24, 17)
        close:SetText("Close")
        close:SetScript("OnClick", function() frame:Hide() end)
        frame.close = close
        frame:SetScript("OnHide", function() if GameTooltip then GameTooltip:Hide() end end)
        if UISpecialFrames then table.insert(UISpecialFrames, "ZwykValuesGlobalSettings") end
    end
    frame.owner = owner
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", owner or UIParent, "CENTER")
    if owner and owner.GetFrameLevel then frame:SetFrameLevel(owner:GetFrameLevel() + 30) end
    if owner and owner.HookScript then
        frame.hookedOwners = frame.hookedOwners or setmetatable({}, {__mode="k"})
        if not frame.hookedOwners[owner] then
            owner:HookScript("OnHide", function(hiddenOwner)
                if frame.owner == hiddenOwner then frame:Hide() end
            end)
            frame.hookedOwners[owner] = true
        end
    end
    self:RefreshGlobalSettings()
    frame.status:SetText("")
    frame:Show()
    return frame
end
