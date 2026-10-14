local _, FW = ...

function FW:InstallBlizzardOptions()
    if self.blizzardOptionsPanel then return self.blizzardOptionsPanel end
    local modern = Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function"
    if not modern and type(InterfaceOptions_AddCategory) ~= "function" then return end

    local panel = CreateFrame("Frame")
    panel.name = "ZwykValues"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ZwykValues")
    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", 16, -50)
    help:SetPoint("TOPRIGHT", -16, -50)
    help:SetJustifyH("LEFT")
    help:SetText("Configure profiles, stat weights and item value displays.")
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(180, 26)
    button:SetPoint("TOPLEFT", 16, -100)
    button:SetText("Open ZwykValues")
    button:SetScript("OnClick", function() self:ShowUI() end)

    if modern then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.blizzardOptionsCategory = category
    else
        InterfaceOptions_AddCategory(panel)
    end
    self.blizzardOptionsPanel = panel
    return panel
end
