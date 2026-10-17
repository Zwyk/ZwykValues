local _, FW = ...

-- The editor is created once, then refreshed in place. Unapplied weights stay in
-- the editor while cache updates or profile visibility changes refresh the UI.
local UI
local refreshItemFilters
local closeColorPicker
local closeIconPicker
local refreshComparisonTarget
local function closeProfileDialogs()
    if not UI then return end
    UI.comparisonSession, UI.calculationSession = nil, nil
    if UI.comparisonDialog then UI.comparisonDialog:Hide() end
    if UI.calculationDialog then UI.calculationDialog:Hide() end
end
local ROW_HEIGHT = 30
local unpack = unpack or table.unpack
local finite = function(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function setEnabled(control, enabled)
    if control.SetEnabled then
        control:SetEnabled(enabled)
    elseif enabled and control.Enable then
        control:Enable()
    elseif not enabled and control.Disable then
        control:Disable()
    end
end

local function backdrop(frame, color)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(color or { 0.055, 0.07, 0.095, 0.97 }))
    frame:SetBackdropBorderColor(0.25, 0.3, 0.38, 1)
end

local function panel(parent)
    local frame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    backdrop(frame, { 0.035, 0.045, 0.065, 0.85 })
    return frame
end

local function label(parent, text, size, color)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size then font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "") end
    font:SetText(text or "")
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    if color then font:SetTextColor(unpack(color)) end
    return font
end

local function button(parent, text, width, action)
    local frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    frame:SetSize(width or 90, 25)
    frame:SetText(text)
    if action then frame:SetScript("OnClick", action) end
    return frame
end

local function editBox(parent, width)
    local frame = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    frame:SetSize(width or 100, 24)
    frame:SetAutoFocus(false)
    frame:SetFontObject("GameFontHighlight")
    frame:SetTextInsets(4, 4, 0, 0)
    frame:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return frame
end

local function hint(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        if text then GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function status(text, kind)
    if not UI then return end
    UI.status:SetText(text or "")
    if kind == "error" then
        UI.status:SetTextColor(1, 0.36, 0.3)
    elseif kind == "success" then
        UI.status:SetTextColor(0.42, 0.9, 0.59)
    else
        UI.status:SetTextColor(0.64, 0.78, 0.96)
    end
end

local function profiles()
    return FW:GetProfiles(false) or {}
end

local function selectedProfile()
    if not UI or not UI.selectedID then return nil end
    for _, profile in ipairs(profiles()) do
        if profile.id == UI.selectedID then return profile end
    end
end

local function clearCalculationSources()
    if not UI then return end
    for _, field in ipairs(UI.calculationSources or {}) do
        field.sourceHighlight:Hide()
        field.sourceOutline:Hide()
        field.text:SetTextColor(unpack(field.sourceLabelColor))
        field.sourceLabelColor = nil
    end
    UI.calculationSources, UI.calculationSourceOwner, UI.calculationSourceProfile = nil, nil, nil
end

local function highlightCalculationSources(owner, result)
    clearCalculationSources()
    local profile = selectedProfile()
    if not profile then return end
    local keys = {}
    local contributions = type(result.contributions) == "table" and result.contributions or result.sources
    for _, contribution in ipairs(contributions or {}) do
        if type(contribution.key) == "string" then keys[contribution.key] = true end
    end
    UI.calculationSources = {}
    UI.calculationSourceOwner, UI.calculationSourceProfile = owner, profile
    for _, field in ipairs(UI.fields) do
        if keys[field.key] then
            if not field.sourceHighlight then
                field.sourceHighlight = field.frame:CreateTexture(nil, "BACKGROUND")
                field.sourceHighlight:SetAllPoints()
                field.sourceHighlight:SetColorTexture(0.15, 0.6, 1, 0.15)
                field.frame.zvCalculationSourceHighlight = field.sourceHighlight
                field.sourceOutline = CreateFrame("Frame", nil, field.box, BackdropTemplateMixin and "BackdropTemplate" or nil)
                field.sourceOutline:EnableMouse(false)
                field.sourceOutline:SetPoint("TOPLEFT", -2, 2)
                field.sourceOutline:SetPoint("BOTTOMRIGHT", 2, -2)
                field.sourceOutline:SetFrameLevel(field.box:GetFrameLevel() + 1)
                if field.sourceOutline.SetBackdrop then
                    field.sourceOutline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                    field.sourceOutline:SetBackdropBorderColor(0.45, 0.8, 1, 1)
                end
                field.box.zvCalculationSourceOutline = field.sourceOutline
            end
            field.sourceLabelColor = field.text.GetTextColor and { field.text:GetTextColor() } or { 0.85, 0.89, 0.94 }
            field.text:SetTextColor(0.55, 0.85, 1)
            field.sourceHighlight:Show()
            field.sourceOutline:Show()
            UI.calculationSources[#UI.calculationSources + 1] = field
        end
    end
end

local function hexColor(color)
    color = color or {}
    local function channel(value)
        return math.floor(math.max(0, math.min(1, tonumber(value) or 1)) * 255 + 0.5)
    end
    return string.format("#%02X%02X%02X", channel(color.r), channel(color.g), channel(color.b))
end

local function parseColor(text)
    local value = trim(text):gsub("^#", "")
    if not value:match("^%x%x%x%x%x%x$") then return nil end
    return {
        r = tonumber(value:sub(1, 2), 16) / 255,
        g = tonumber(value:sub(3, 4), 16) / 255,
        b = tonumber(value:sub(5, 6), 16) / 255,
    }
end

local function previewColor(color)
    if not UI then return end
    color = color or { r = 1, g = 1, b = 1 }
    UI.colorSwatch:SetColorTexture(color.r, color.g, color.b, 1)
end

local function updateUnitHelp()
    UI.unitHelp:SetText("Secondary weights always use 1% (1% = 1); defense uses skill points.")
    for _, field in ipairs(UI.fields) do
        if field.secondary then
            local unit = field.key == "defense" and "skill" or "%"
            local name = field.key == "defense" and "Defense" or field.label
            field.text:SetText(name .. " (" .. unit .. ")")
        end
    end
end

local function refreshEditor(force)
    local profile = selectedProfile()
    if UI.calculationSourceProfile and UI.calculationSourceProfile ~= profile then clearCalculationSources() end
    if UI.colorPickerSession and (not profile or UI.colorPickerSession.profile ~= profile) then
        closeColorPicker(true)
    end
    if UI.iconPickerSession and (not profile or UI.iconPickerSession.profile ~= profile) then
        closeIconPicker()
    end
    if (UI.comparisonSession and UI.comparisonSession.profile ~= profile) or
       (UI.calculationSession and UI.calculationSession.profile ~= profile) then closeProfileDialogs() end
    local enabled = profile ~= nil
    for _, control in ipairs(UI.profileControls) do
        setEnabled(control, enabled)
    end
    UI.copy:SetEnabled(enabled)
    UI.delete:SetEnabled(enabled)
    UI.export:SetEnabled(enabled)
    UI.exportWeights:SetEnabled(enabled)
    UI.loading = true
    if profile then
        if force or not UI.dirtyName then UI.name:SetText(profile.name or "") end
        if force or not UI.dirtyColor then UI.color:SetText(hexColor(profile.color)) end
        UI.active:SetChecked(profile.active and true or false)
        UI.upgradeProfile:SetChecked(profile.upgradeEnabled and true or false)
        previewColor(parseColor(UI.color:GetText()) or profile.color)
        UI.profileIcon:SetTexture(profile.icon)
        UI.profileIcon:SetShown(profile.icon ~= nil)
        UI.iconNone:SetShown(profile.icon == nil)
        updateUnitHelp(profile)
        for _, field in ipairs(UI.fields) do
            setEnabled(field.box, true)
            if field.calculate then setEnabled(field.calculate, true) end
            if force or not UI.dirtyWeights then
                field.box:SetText(tostring((profile.weights or {})[field.key] or 0))
            end
        end
        UI.editorTitle:SetText("Weights for " .. (profile.name or "profile"))
    else
        UI.name:SetText("")
        UI.color:SetText("#FFFFFF")
        UI.active:SetChecked(false)
        UI.upgradeProfile:SetChecked(false)
        previewColor()
        UI.profileIcon:Hide()
        UI.iconNone:Show()
        updateUnitHelp(nil)
        for _, field in ipairs(UI.fields) do
            field.box:SetText("0")
            setEnabled(field.box, false)
            if field.calculate then setEnabled(field.calculate, false) end
        end
        UI.editorTitle:SetText("Create a profile to set weights")
    end
    if force then
        UI.dirtyName, UI.dirtyColor, UI.dirtyWeights = false, false, false
        UI.draftCalculationOptions = nil
    end
    UI.weightState:SetText(UI.dirtyWeights and "Unsaved weights" or "Weights saved")
    UI.weightState:SetTextColor(UI.dirtyWeights and 1 or 0.6, UI.dirtyWeights and 0.78 or 0.72, UI.dirtyWeights and 0.35 or 0.64)
    UI.loading = false
    if refreshItemFilters then refreshItemFilters(profile) end
    if refreshComparisonTarget then refreshComparisonTarget(profile) end
end

local function commit(changes, clearDraft, success)
    local profile = selectedProfile()
    if not profile then return false end
    UI.committing = true
    local ok, err = FW:UpdateProfile(profile.id, changes)
    UI.committing = false
    if not ok then
        status(err or "Could not save this profile.", "error")
        FW:RefreshUI()
        return false
    end
    if clearDraft == "name" then UI.dirtyName = false end
    if clearDraft == "color" then UI.dirtyColor = false end
    if clearDraft == "weights" then UI.dirtyWeights, UI.draftCalculationOptions = false, nil end
    FW:RefreshUI()
    status(success or "Profile saved.", "success")
    return true
end

local function draftWeights(quiet)
    local weights = {}
    for _, field in ipairs(UI.fields) do
        local text = trim(field.box:GetText())
        local value = text == "" and 0 or tonumber(text)
        if not finite(value) then
            if not quiet then
                status("Enter a finite number for " .. field.label .. ".", "error")
                field.box:SetFocus()
                field.box:HighlightText()
            end
            return nil
        end
        weights[field.key] = value
    end
    return weights
end

local function applyWeights()
    if not selectedProfile() then return end
    local weights = draftWeights()
    if weights then
        commit({ weights = weights, calculationOptions = UI.draftCalculationOptions }, "weights", "Weights saved. Cached scores will use the updated weights.")
    end
end

local function comparisonContext(profile)
    if FW.GetProfileComparisonContext then return FW:GetProfileComparisonContext(profile) end
    local target = profile and profile.comparisonTarget
    if target and target.mode == "set" then
        return { label = "Set: " .. (target.name or "Unknown"), error = "Equipment Manager is unavailable." }
    end
    return { mode = "equipped", label = "Currently equipped" }
end

refreshComparisonTarget = function(profile)
    if not UI.comparison then return end
    local context = profile and comparisonContext(profile)
    UI.comparisonCaption:SetText(not profile and "Compare: No profile" or context.error and "Compare: Unavailable" or
        (context.mode == "equipped" and "Compare: Equipped" or context.label))
    UI.comparisonCaption:SetTextColor(context and context.error and 1 or 0.85, context and context.error and 0.48 or 0.89, context and context.error and 0.35 or 0.94)
end

local function showComparisonPicker()
    local profile = selectedProfile()
    if not profile then return end
    closeProfileDialogs()
    if not UI.comparisonDialog then
        local dialog = CreateFrame("Frame", "ZwykValuesComparisonPicker", UI.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        UI.comparisonDialog = dialog
        dialog:SetSize(430, 330)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetFrameLevel(UI.frame:GetFrameLevel() + 10)
        backdrop(dialog)
        dialog.title = label(dialog, "Compare this profile with", 14, { 1, 0.82, 0.35 })
        dialog.title:SetPoint("TOPLEFT", 18, -18)
        dialog.message = label(dialog, "", 11, { 0.78, 0.84, 0.92 })
        dialog.message:SetPoint("TOPLEFT", 18, -46)
        dialog.message:SetPoint("TOPRIGHT", -18, -46)
        dialog.message:SetHeight(42)
        dialog.message:SetJustifyV("TOP")
        dialog.scroll = CreateFrame("ScrollFrame", "ZwykValuesComparisonScroll", dialog, "UIPanelScrollFrameTemplate")
        dialog.scroll:SetPoint("TOPLEFT", 18, -97)
        dialog.scroll:SetPoint("BOTTOMRIGHT", -37, 52)
        dialog.content = CreateFrame("Frame", nil, dialog.scroll)
        dialog.content:SetWidth(370)
        dialog.scroll:SetScrollChild(dialog.content)
        dialog.rows = {}
        dialog.close = button(dialog, "Close", 85, closeProfileDialogs)
        dialog.close:SetPoint("BOTTOMRIGHT", -17, 15)
        dialog:SetScript("OnHide", function() UI.comparisonSession = nil end)
        if UISpecialFrames then table.insert(UISpecialFrames, "ZwykValuesComparisonPicker") end
    end
    local dialog = UI.comparisonDialog
    local session = { profile = profile }
    UI.comparisonSession = session
    local choices = { { name = "Currently equipped", target = { mode = "equipped" } } }
    local sets, err
    if FW.GetEquipmentSetOptions then sets, err = FW:GetEquipmentSetOptions() else err = "Equipment Manager is unavailable on this client." end
    for _, option in ipairs(sets or {}) do choices[#choices + 1] = option end
    local context = comparisonContext(profile)
    dialog.message:SetText(context.error and ((context.label or "Selected set") .. ": " .. context.error) or
        (err or "Choose equipped items or a saved equipment set. This changes comparisons for this profile."))
    dialog.title:SetText("Compare " .. (profile.name or "profile") .. " with")
    for index, choice in ipairs(choices) do
        local row = dialog.rows[index]
        if not row then
            row = button(dialog.content, "", 370)
            row:SetHeight(30)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 34)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(21, 21)
            row.icon:SetPoint("LEFT", 5, 0)
            row.caption = label(row, "", 11, { 0.85, 0.89, 0.94 })
            row.caption:SetPoint("LEFT", 31, 0)
            row.caption:SetPoint("RIGHT", -8, 0)
            row.caption:SetHeight(26)
            row.caption:SetWordWrap(false)
            dialog.rows[index] = row
        end
        local target = choice.target or { mode = "set", setID = choice.setID, name = choice.name, character = choice.character }
        local selected = target.mode == "equipped" and (not profile.comparisonTarget or profile.comparisonTarget.mode == "equipped") or
            target.mode == "set" and profile.comparisonTarget and profile.comparisonTarget.mode == "set" and target.setID == profile.comparisonTarget.setID and target.character == profile.comparisonTarget.character
        row.target = target
        row.caption:SetText((selected and "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t " or "") .. (choice.name or "Equipment set"))
        row.icon:SetTexture(choice.icon)
        row.icon:SetShown(choice.icon ~= nil)
        row:SetScript("OnClick", function()
            if UI.comparisonSession ~= session or selectedProfile() ~= profile then return end
            if commit({ comparisonTarget = target }, nil, "Comparison target saved.") then closeProfileDialogs() end
        end)
        hint(row, choice.name or "Currently equipped", target.mode == "equipped" and "Compare with items currently worn by this character." or
            "Compare with the saved item variants in this equipment set. Missing or inaccessible items leave the comparison unavailable.")
        row:Show()
    end
    for index = #choices + 1, #dialog.rows do dialog.rows[index]:Hide() end
    dialog.content:SetHeight(math.max(1, #choices * 34))
    dialog.scroll:SetVerticalScroll(0)
    dialog.scroll:UpdateScrollChildRect()
    dialog:Show()
end

local function calculationOptions(profile)
    local result = FW.GetDerivedWeightDefaults and FW:GetDerivedWeightDefaults(profile) or {}
    local options = {}
    for key, value in pairs(result) do if key ~= "talentRanks" then options[key] = value end end
    options.talentRanks = {}
    for key, value in pairs(result.talentRanks or {}) do options.talentRanks[key] = value end
    for key, value in pairs(UI.draftCalculationOptions or {}) do
        if key == "talentRanks" then
            if value == false then options.talentRanks = {}
            else
                for node, rank in pairs(value) do options.talentRanks[node] = rank ~= false and rank or nil end
            end
        else options[key] = value end
    end
    return options
end

local function weightCalculation(field, options, quiet)
    if not FW.GetDerivedWeightOptions then return { available = false, reason = "Weight calculations are unavailable." } end
    local weights = draftWeights(quiet)
    if not weights then return { available = false, reason = "Enter valid numbers in the weight fields first." } end
    return FW:GetDerivedWeightOptions(field.key, weights, options or calculationOptions(selectedProfile())) or
        { available = false, reason = "This weight could not be calculated." }
end

local function useCalculatedWeight(field, result, options, params, rankChanges, restoreCurrent)
    if not selectedProfile() or not result.available or not finite(result.value) then return end
    UI.loading = true
    field.box:SetText(string.format("%.8g", result.value))
    UI.loading = false
    if options then
        local draft = {}
        for key, value in pairs(UI.draftCalculationOptions or {}) do draft[key] = value end
        for _, key in ipairs({ "combatShare", "castingShare", "whileCastingRegen", "kings", "attackerLevelOffset" }) do
            if params and params[key] then draft[key] = options[key] end
        end
        if rankChanges and next(rankChanges) then
            local ranks = {}
            for key, value in pairs(type(draft.talentRanks) == "table" and draft.talentRanks or {}) do ranks[key] = value end
            for key, value in pairs(rankChanges) do ranks[key] = value end
            draft.talentRanks = ranks
        end
        if restoreCurrent then draft.useTalents = true end
        UI.draftCalculationOptions = draft
    end
    UI.dirtyWeights = true
    UI.weightState:SetText("Unsaved weights")
    UI.weightState:SetTextColor(1, 0.78, 0.35)
    status(field.label .. " weight calculated. Apply weights to update item scores.")
end

local calculationColors = {
    context = { 0.65, 0.78, 0.94 }, heading = { 0.78, 0.85, 1 },
    text = { 0.94, 0.94, 0.94 }, detail = { 0.72, 0.77, 0.84 },
    result = { 0.45, 0.92, 0.63 }, warning = { 1, 0.65, 0.4 },
}
local function calculationNumber(value)
    return finite(value) and string.format("%.5g", value) or "?"
end
local function hasCalculationParams(result)
    if result.talentControls and #result.talentControls > 0 then return true end
    for _, enabled in pairs(result.params or {}) do if enabled then return true end end
    return false
end

-- The engine supplies structured data; use the same sections in the hover
-- tooltip and the regeneration prompt instead of repeating its diagnostic log.
local function calculationSections(field, result, withFooter)
    local sections = {}
    local function line(text, color, right)
        if text and text ~= "" then sections[#sections + 1] = { text = text, color = calculationColors[color or "text"], right = right } end
    end
    local function space()
        if #sections > 0 and sections[#sections].text ~= " " then line(" ") end
    end
    local function heading(text) space() line(text, "heading") end
    local function unique(values, color)
        local seen = {}
        for _, value in ipairs(values or {}) do
            if type(value) == "string" and value ~= "" and not seen[value] then
                seen[value] = true
                line(value, value:lower():find("fallback", 1, true) and "warning" or color)
            end
        end
    end
    line(result.contextText, "context")
    local structured = result.formula or result.contributions or result.modifierLines
    if structured then
        if result.formula and result.formula ~= "" then heading("Formula") line(result.formula) end
        if result.contributions and #result.contributions > 0 then
            heading(result.contributionHeading or "From your weights")
            for _, contribution in ipairs(result.contributions) do
                local subtract = contribution.operation == "subtract"
                local rate = contribution.displayRate or (subtract and math.abs(contribution.rate) or contribution.rate)
                local value = contribution.displayValue or (subtract and math.abs(contribution.value) or contribution.value)
                line((subtract and "Less " or "") .. (contribution.label or contribution.key), "text", calculationNumber(rate) .. (contribution.unit or "") ..
                    " x " .. calculationNumber(contribution.weight) .. " = " .. calculationNumber(value))
            end
        end
    else
        local lines = {}
        for _, text in ipairs(result.lines or {}) do
            if type(text) == "string" and text ~= result.reason and not text:match("^Calculated weight:") and not text:match("^Click") then lines[#lines + 1] = text end
        end
        unique(lines, "text")
    end
    space()
    if result.available and finite(result.value) then
        line("Calculated weight", "result", calculationNumber(result.value))
    else
        line(result.reason or "Calculation unavailable.", "warning")
    end
    if result.modifierLines and #result.modifierLines > 0 then heading("Modifiers") unique(result.modifierLines, "detail") end
    if withFooter then
        space()
        line(result.params and result.params.attackerLevelOffset and "Click to choose attacker level. Apply weights saves changes." or
            (field.key == "spirit" or field.key == "mp5") and "Click to choose ratios. Apply weights saves changes." or
            (hasCalculationParams(result) and "Click to review bonuses. Apply weights saves changes." or
                (result.footer or "Click to fill this weight. Apply weights saves changes.")), "context")
    end
    return sections
end

local function calculationText(field, result)
    local lines = {}
    for _, section in ipairs(calculationSections(field, result, false)) do
        local color = section.color
        lines[#lines + 1] = string.format("|cff%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255)) ..
            section.text .. (section.right and (": " .. section.right) or "") .. "|r"
    end
    return lines
end

local function hideCalculationTooltip(owner)
    if not UI then return end
    if not owner or UI.calculationSourceOwner == owner then clearCalculationSources() end
    if not UI.calculationTooltipOwner or (owner and UI.calculationTooltipOwner ~= owner) then return end
    local tooltipOwner = UI.calculationTooltipOwner
    UI.calculationTooltipOwner = nil
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(tooltipOwner) then return end
    if GameTooltip.GetOwner and GameTooltip:GetOwner() ~= tooltipOwner then return end
    if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(0, false) end
    GameTooltip:Hide()
end

local function showCalculationPrompt(field)
    local profile = selectedProfile()
    if not profile then return end
    hideCalculationTooltip()
    closeProfileDialogs()
    if not UI.calculationDialog then
        local dialog = CreateFrame("Frame", "ZwykValuesWeightCalculation", UI.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        UI.calculationDialog = dialog
        dialog:SetSize(520, 460)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetFrameLevel(UI.frame:GetFrameLevel() + 10)
        backdrop(dialog)
        dialog.title = label(dialog, "Calculate weight", 14, { 1, 0.82, 0.35 })
        dialog.title:SetPoint("TOPLEFT", 18, -18)
        dialog.help = label(dialog, "", 11, { 0.78, 0.84, 0.92 })
        dialog.help:SetPoint("TOPLEFT", 18, -45)
        dialog.help:SetPoint("TOPRIGHT", -18, -45)
        dialog.help:SetHeight(42)
        dialog.help:SetJustifyV("TOP")
        dialog.sliders, dialog.toggles, dialog.talentRows = {}, {}, {}
        dialog.controlsScroll = CreateFrame("ScrollFrame", "ZwykValuesCalculationControls", dialog, "UIPanelScrollFrameTemplate")
        dialog.controlsScroll:SetPoint("TOPLEFT", 18, -97)
        dialog.controlsScroll:SetPoint("TOPRIGHT", -37, -97)
        dialog.controlsContent = CreateFrame("Frame", nil, dialog.controlsScroll)
        dialog.controlsContent:SetWidth(465)
        dialog.controlsContent:SetPoint("TOPLEFT")
        dialog.controlsScroll:SetScrollChild(dialog.controlsContent)
        dialog.talentHeading = label(dialog.controlsContent, "Talent ranks", 11, { 0.78, 0.85, 1 })
        dialog.currentTalents = button(dialog.controlsContent, "Use current talents", 145)
        hint(dialog.currentTalents, "Use current talents", "Restore automatic current ranks for the talents shown here. This also enables automatic talent bonuses for other stats that have no manual override. Other saved rank overrides are kept.")
        dialog.attackerSelector = CreateFrame("Frame", nil, dialog.controlsContent)
        dialog.attackerSelector:SetSize(465, 62)
        dialog.attackerSelector.title = label(dialog.attackerSelector, "Attacker level", 11, { 0.78, 0.85, 1 })
        dialog.attackerSelector.title:SetPoint("TOPLEFT")
        dialog.attackerSelector.choices = {}
        for index, offset in ipairs({ 0, 3 }) do
            local choice = CreateFrame("CheckButton", nil, dialog.attackerSelector, "UICheckButtonTemplate")
            choice:SetSize(24, 24)
            choice:SetPoint("TOPLEFT", (index - 1) * 232, -25)
            choice.caption = label(choice, "", 11, { 0.85, 0.89, 0.94 })
            choice.caption:SetPoint("LEFT", choice, "RIGHT", 3, 0)
            choice.caption:SetWidth(190)
            choice.caption:SetHeight(28)
            choice.offset = offset
            dialog.attackerSelector.choices[offset] = choice
        end
        dialog.detailsScroll = CreateFrame("ScrollFrame", "ZwykValuesCalculationDetails", dialog, "UIPanelScrollFrameTemplate")
        dialog.detailsScroll:SetPoint("TOPLEFT", 18, -280)
        dialog.detailsScroll:SetPoint("BOTTOMRIGHT", -37, 62)
        dialog.detailsContent = CreateFrame("Frame", nil, dialog.detailsScroll)
        dialog.detailsContent:SetWidth(465)
        dialog.details = label(dialog.detailsContent, "", 11, { 0.84, 0.88, 0.94 })
        dialog.details:SetPoint("TOPLEFT")
        dialog.details:SetWidth(465)
        dialog.details:SetJustifyV("TOP")
        dialog.detailsScroll:SetScrollChild(dialog.detailsContent)
        dialog.use = button(dialog, "Use calculated weight", 172)
        dialog.use:SetPoint("BOTTOMRIGHT", -18, 17)
        dialog.cancel = button(dialog, "Cancel", 85, closeProfileDialogs)
        dialog.cancel:SetPoint("RIGHT", dialog.use, "LEFT", -8, 0)
        dialog:SetScript("OnHide", function() UI.calculationSession = nil end)
        if UISpecialFrames then table.insert(UISpecialFrames, "ZwykValuesWeightCalculation") end
    end
    local dialog = UI.calculationDialog
    local session = { profile = profile, field = field, options = calculationOptions(profile), rankChanges = {} }
    local initialResult = weightCalculation(field, session.options, true)
    session.params = initialResult.params or {}
    session.talents = initialResult.talentControls or {}
    UI.calculationSession = session
    dialog.title:SetText("Calculate " .. field.label .. " weight")
    dialog.help:SetText((session.params.attackerLevelOffset and "Choose the attacker's level for armor mitigation." or
        session.params.castingShare and "Adjust regeneration ratios and stat bonuses." or "Choose the stat bonuses to include.") ..
        " Calculated weights stay unsaved until Apply weights.")
    local definitions = {
        { key = "combatShare", text = "Time in combat", help = "Out of combat uses full Spirit regeneration; time in combat uses the casting assumptions below." },
        { key = "castingShare", text = "Time while casting", help = "Share of time affected by the five-second mana regeneration rule. For MP5 this applies only to time in combat." },
        { key = "whileCastingRegen", text = "Spirit regeneration while casting", help = "Percentage of normal Spirit regeneration retained while casting, including talents. The initial value is read from your current talents when possible." },
    }
    local function refresh()
        if UI.calculationSession ~= session then return end
        session.result = weightCalculation(field, session.options, true)
        local result = session.result
        for key, control in pairs(dialog.toggles) do
            if result.paramLabels and result.paramLabels[key] then control.caption:SetText(result.paramLabels[key]) end
            if control.hintTitle then hint(control, control.hintTitle, result.paramHelp and result.paramHelp[key] or control.defaultHint) end
        end
        session.refreshingRanks = true
        local canRestore = session.options.useTalents == false
        for _, talent in ipairs(result.talentControls or {}) do
            local row = dialog.talentRows[talent.key]
            if row then
                row.caption:SetText(talent.name .. ": " .. (finite(talent.rank) and talent.rank or "?") .. "/" .. talent.maxRank)
                row.current:SetText("Current: " .. (finite(talent.currentRank) and (talent.currentRank .. "/" .. talent.maxRank) or "unavailable"))
                hint(row, talent.name, (talent.effectText and (talent.effectText .. "\n") or "") ..
                    "Current rank: " .. (finite(talent.currentRank) and (talent.currentRank .. "/" .. talent.maxRank) or "unavailable") ..
                    ". Choose a rank from 0 to " .. talent.maxRank .. ". Apply weights saves manual ranks; Use current talents restores automatic ranks.")
                row:SetValue(finite(talent.rank) and talent.rank or 0)
                if session.options.talentRanks[talent.key] ~= nil then canRestore = true end
            end
        end
        session.refreshingRanks = false
        setEnabled(dialog.currentTalents, canRestore)
        if session.params.attackerLevelOffset then
            local playerLevel = result.armorContext and result.armorContext.playerLevel or result.context and result.context.level
            for offset, choice in pairs(dialog.attackerSelector.choices) do
                choice:SetChecked(session.options.attackerLevelOffset == offset)
                choice.caption:SetText((offset == 0 and "Same level (+0)" or "Boss (+3)") ..
                    (finite(playerLevel) and (" - Level " .. (playerLevel + offset)) or ""))
            end
        end
        local lines = calculationText(field, result)
        dialog.details:SetText(table.concat(lines, "\n"))
        local lineCount = 0
        for _, line in ipairs(lines) do lineCount = lineCount + math.max(1, math.ceil(#line * 6.2 / 465)) end
        local height = dialog.details.GetStringHeight and dialog.details:GetStringHeight() or lineCount * 14
        height = math.max(14, height)
        dialog.details:SetHeight(height)
        dialog.detailsContent:SetHeight(height)
        dialog.detailsScroll:UpdateScrollChildRect()
        setEnabled(dialog.use, result.available and finite(result.value))
    end
    local nextY = 8
    for _, definition in ipairs({
        { key = "kings", text = "Include Blessing of Kings (+10%)", help = "Multiply the relevant primary stat by 1.10. The bonus is applied once, including inverse calculations." },
    }) do
        local control = dialog.toggles[definition.key]
        if not control then
            control = CreateFrame("CheckButton", nil, dialog.controlsContent, "UICheckButtonTemplate")
            control:SetSize(24, 24)
            control.caption = label(control, "", 11, { 0.85, 0.89, 0.94 })
            control.caption:SetPoint("LEFT", control, "RIGHT", 3, 0)
            control.caption:SetWidth(430)
            control.caption:SetHeight(32)
            dialog.toggles[definition.key] = control
        end
        control.optionKey = definition.key
        control.hintTitle, control.defaultHint = definition.text, definition.help
        control:SetShown(session.params[definition.key] and true or false)
        if session.params[definition.key] then
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", 3, -nextY)
            nextY = nextY + 40
            control.caption:SetText(initialResult.paramLabels and initialResult.paramLabels[definition.key] or definition.text)
            control:SetChecked(session.options[definition.key] and true or false)
            control:SetScript("OnClick", function(self)
                if UI.calculationSession ~= session then return end
                session.options[definition.key] = self:GetChecked() and true or false
                refresh()
            end)
            hint(control, definition.text, initialResult.paramHelp and initialResult.paramHelp[definition.key] or definition.help)
        end
    end
    for _, row in pairs(dialog.talentRows) do row:Hide() end
    local hasTalents = #session.talents > 0
    dialog.talentHeading:SetShown(hasTalents)
    dialog.currentTalents:SetShown(hasTalents)
    if hasTalents then
        dialog.talentHeading:ClearAllPoints()
        dialog.talentHeading:SetPoint("TOPLEFT", 0, -nextY)
        dialog.currentTalents:ClearAllPoints()
        dialog.currentTalents:SetPoint("TOPRIGHT", 0, -nextY + 5)
        nextY = nextY + 30
        dialog.currentTalents:SetScript("OnClick", function()
            if UI.calculationSession ~= session then return end
            session.options.useTalents, session.restoreCurrent = true, true
            for _, talent in ipairs(session.talents) do
                session.options.talentRanks[talent.key] = nil
                session.rankChanges[talent.key] = false
            end
            refresh()
        end)
        for _, talent in ipairs(session.talents) do
            local row = dialog.talentRows[talent.key]
            if not row then
                row = CreateFrame("Slider", nil, dialog.controlsContent, "OptionsSliderTemplate")
                row:SetSize(450, 17)
                row:SetValueStep(1)
                if row.SetObeyStepOnDrag then row:SetObeyStepOnDrag(true) end
                row.caption = label(row, "", 11, { 0.85, 0.89, 0.94 })
                row.caption:SetPoint("BOTTOMLEFT", 0, 7)
                row.caption:SetWidth(315)
                row.caption:SetHeight(18)
                row.caption:SetWordWrap(false)
                row.current = label(row, "", 10, { 0.65, 0.74, 0.85 })
                row.current:SetPoint("BOTTOMRIGHT", 0, 7)
                row.current:SetWidth(130)
                row.current:SetHeight(18)
                row.current:SetWordWrap(false)
                dialog.talentRows[talent.key] = row
            end
            row.talentKey = talent.key
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 7, -(nextY + 18))
            nextY = nextY + 66
            row:SetMinMaxValues(0, talent.maxRank)
            if row.Low then row.Low:SetText("0") end
            if row.High then row.High:SetText(tostring(talent.maxRank)) end
            row:SetScript("OnValueChanged", nil)
            row:SetValue(finite(talent.rank) and talent.rank or 0)
            local function chooseRank(_, value)
                if UI.calculationSession ~= session or session.refreshingRanks then return end
                value = math.max(0, math.min(talent.maxRank, math.floor(value + 0.5)))
                if session.options.talentRanks[talent.key] == value and session.rankChanges[talent.key] == value then return end
                session.options.talentRanks[talent.key], session.rankChanges[talent.key] = value, value
                refresh()
            end
            row:SetScript("OnValueChanged", chooseRank)
            row:SetScript("OnMouseUp", function(self) chooseRank(self, self:GetValue()) end)
            hint(row, talent.name, "Choose a rank from 0 to " .. talent.maxRank .. ". Changed ranks remain drafts until Apply weights. Use current talents restores automatic ranks.")
            row:Show()
        end
    end
    for index, definition in ipairs(definitions) do
        local slider = dialog.sliders[index]
        if not slider then
            slider = CreateFrame("Slider", nil, dialog.controlsContent, "OptionsSliderTemplate")
            slider:SetSize(450, 17)
            slider:SetMinMaxValues(0, 100)
            slider:SetValueStep(1)
            if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
            slider.caption = label(slider, "", 11, { 0.85, 0.89, 0.94 })
            slider.caption:SetPoint("BOTTOMLEFT", 0, 7)
            slider.caption:SetPoint("BOTTOMRIGHT", 0, 7)
            slider.caption:SetHeight(18)
            if slider.Low then slider.Low:SetText("0%") end
            if slider.High then slider.High:SetText("100%") end
            dialog.sliders[index] = slider
        end
        slider.optionKey = definition.key
        local shown = session.params[definition.key] and true or false
        slider:SetShown(shown)
        if shown then
            slider:ClearAllPoints()
            slider:SetPoint("TOPLEFT", 7, -(nextY + 13))
            nextY = nextY + 57
            local function caption(value) slider.caption:SetText(definition.text .. ": " .. math.floor(value + 0.5) .. "%") end
            slider:SetScript("OnValueChanged", nil)
            local percent = math.max(0, math.min(100, (tonumber(session.options[definition.key]) or 0) * 100))
            slider:SetValue(percent)
            caption(percent)
            slider:SetScript("OnValueChanged", function(_, value)
                if UI.calculationSession ~= session then return end
                session.options[definition.key] = math.max(0, math.min(1, value / 100))
                caption(value)
                refresh()
            end)
            hint(slider, definition.text, definition.help)
        end
    end
    dialog.attackerSelector:SetShown(session.params.attackerLevelOffset and true or false)
    if session.params.attackerLevelOffset then
        dialog.attackerSelector:ClearAllPoints()
        dialog.attackerSelector:SetPoint("TOPLEFT", 0, -nextY)
        nextY = nextY + 65
        for offset, choice in pairs(dialog.attackerSelector.choices) do
            choice:SetScript("OnClick", function()
                if UI.calculationSession ~= session then return end
                session.options.attackerLevelOffset = offset
                refresh()
            end)
            hint(choice, "Attacker level " .. (offset == 0 and "+0" or "+3"),
                offset == 0 and "Calculate armor mitigation against an attacker at your current level." or
                    "Calculate armor mitigation against an attacker three levels above your current level.")
        end
    end
    dialog.controlsContent:SetHeight(math.max(1, nextY))
    dialog.controlsScroll:SetHeight(math.min(260, math.max(1, nextY)))
    dialog.controlsScroll:SetVerticalScroll(0)
    dialog.controlsScroll:UpdateScrollChildRect()
    local detailsTop = 97 + math.min(260, math.max(1, nextY)) + 10
    dialog:SetHeight(math.max(400, detailsTop + 180))
    dialog.detailsScroll:ClearAllPoints()
    dialog.detailsScroll:SetPoint("TOPLEFT", 18, -detailsTop)
    dialog.detailsScroll:SetPoint("BOTTOMRIGHT", -37, 62)
    dialog.use:SetScript("OnClick", function()
        if UI.calculationSession ~= session or selectedProfile() ~= profile then return end
        refresh()
        if session.result.available and finite(session.result.value) then
            useCalculatedWeight(field, session.result, session.options, session.params, session.rankChanges, session.restoreCurrent)
            closeProfileDialogs()
        end
    end)
    refresh()
    dialog:Show()
end

local function installCalculationButton(field)
    if not FW.IsDerivedWeightStat or not FW:IsDerivedWeightStat(field.key) then return end
    local control = CreateFrame("Button", nil, field.frame)
    field.calculate = control
    control.isDerivedWeight, control.statKey = true, field.key
    control:SetSize(16, 16)
    control:SetPoint("RIGHT", field.box, "LEFT", -6, 0)
    control:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    control:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    control:SetScript("OnEnter", function(self)
        local result = weightCalculation(field, nil, true)
        highlightCalculationSources(self, result)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(result.title or ("Calculate " .. field.label .. " weight"), 1, 0.82, 0)
        for _, section in ipairs(calculationSections(field, result, true)) do
            local color = section.color
            if section.right and GameTooltip.AddDoubleLine then
                GameTooltip:AddDoubleLine(section.text, section.right, color[1], color[2], color[3], color[1], color[2], color[3])
            else
                GameTooltip:AddLine(section.text .. (section.right and (": " .. section.right) or ""), color[1], color[2], color[3], true)
            end
        end
        UI.calculationTooltipOwner = self
        -- Native FrameXML uses the second argument to reflow wrapped text to
        -- the requested minimum width. Reset it when this tooltip is released.
        if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(400, true) end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function(self) hideCalculationTooltip(self) end)
    control:SetScript("OnHide", function(self) hideCalculationTooltip(self) end)
    control:SetScript("OnClick", function()
        local result = weightCalculation(field, nil, false)
        if hasCalculationParams(result) then showCalculationPrompt(field) return end
        if result.available and finite(result.value) then useCalculatedWeight(field, result)
        else status(result.reason or "This weight could not be calculated.", "error") end
    end)
end

-- The game has one shared picker. Keep callbacks tied to the profile that
-- opened it, and ignore callbacks after it is replaced or that profile is gone.
local function ownsColorPicker(session)
    local picker = session.picker
    return picker[session.callbackKey] == session.swatch and picker.cancelFunc == session.cancel
end

closeColorPicker = function(cancel)
    local session = UI and UI.colorPickerSession
    if not session then return end
    local picker = session.picker
    local shown = ownsColorPicker(session) and picker.IsShown and picker:IsShown()
    if cancel and shown then session.cancel() end
    UI.colorPickerSession = nil
    session.closed = true
    if shown and picker.Hide then picker:Hide() end
end

local function showColorPicker()
    local profile = selectedProfile()
    if not profile then return end
    closeIconPicker()
    closeColorPicker(true)
    local picker = ColorPickerFrame
    if not picker then
        local loadAddon = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if loadAddon then pcall(loadAddon, "Blizzard_ColorPickerFrame") end
        picker = ColorPickerFrame
    end
    if not picker or not picker.GetColorRGB or not (picker.SetupColorPickerAndShow or (picker.SetColorRGB and picker.Show)) then
        status("The game's color picker is unavailable. Enter a HEX color and use Set color.", "error")
        return
    end
    local saved = profile.color or { r = 1, g = 1, b = 1 }
    local original = { r = saved.r, g = saved.g, b = saved.b }
    local session = {
        picker = picker, profile = profile, setup = true,
        draft = UI.color:GetText(), dirtyColor = UI.dirtyColor,
        callbackKey = picker.SetupColorPickerAndShow and "swatchFunc" or "func",
    }
    UI.colorPickerSession = session
    local function saveColor(color, restoreDraft)
        if not FW.DB or not FW.DB.profiles or FW.DB.profiles[profile.id] ~= profile then return end
        local wasCommitting = UI.committing
        UI.committing = true
        local ok, err = FW:UpdateProfile(profile.id, { color = color })
        UI.committing = wasCommitting
        if not ok then status(err or "Could not save the tooltip color.", "error") return end
        if UI.selectedID == profile.id then
            UI.loading = true
            UI.dirtyColor = restoreDraft and session.dirtyColor or false
            UI.color:SetText(restoreDraft and session.draft or hexColor(color))
            UI.loading = false
            previewColor(parseColor(UI.color:GetText()) or color)
        end
        FW:RefreshUI()
        status(restoreDraft and "Original tooltip color restored." or "Tooltip color saved.", "success")
    end
    session.swatch = function()
        if session.closed or session.setup or UI.colorPickerSession ~= session then return end
        if not ownsColorPicker(session) then return end
        local ok, r, g, b = pcall(picker.GetColorRGB, picker)
        if ok and finite(r) and finite(g) and finite(b) then saveColor({ r = r, g = g, b = b }, false) end
    end
    session.cancel = function()
        if session.closed or UI.colorPickerSession ~= session or not ownsColorPicker(session) then return end
        session.closed = true
        UI.colorPickerSession = nil
        saveColor(original, true)
    end
    if picker.SetFrameStrata then picker:SetFrameStrata("DIALOG") end
    if picker.SetFrameLevel then
        picker:SetFrameLevel(math.max(picker.GetFrameLevel and picker:GetFrameLevel() or 0, UI.frame:GetFrameLevel() + 30))
    end
    local ok
    if picker.SetupColorPickerAndShow then
        ok = pcall(picker.SetupColorPickerAndShow, picker, {
            r = original.r, g = original.g, b = original.b,
            hasOpacity = false, swatchFunc = session.swatch, cancelFunc = session.cancel,
        })
    else
        if picker.Hide then picker:Hide() end
        -- Older Classic clients use func; newer ones use swatchFunc.
        picker.func, picker.swatchFunc = session.swatch, session.swatch
        picker.cancelFunc, picker.opacityFunc, picker.hasOpacity = session.cancel, nil, false
        picker.previousValues = { r = original.r, g = original.g, b = original.b }
        ok = pcall(picker.SetColorRGB, picker, original.r, original.g, original.b)
        if ok then ok = pcall(picker.Show, picker) end
    end
    session.setup = false
    if not ok then
        closeColorPicker(false)
        status("Could not open the game's color picker. Enter a HEX color and use Set color.", "error")
    end
end

closeIconPicker = function()
    if not UI then return end
    UI.iconPickerSession = nil
    if UI.iconDialog then UI.iconDialog:Hide() end
end

local function saveIcon(session, icon)
    if UI.iconPickerSession ~= session or selectedProfile() ~= session.profile
        or not FW.DB or not FW.DB.profiles or FW.DB.profiles[session.profile.id] ~= session.profile then return end
    if commit({ icon = icon or false }, nil, icon and "Profile icon saved." or "Profile icon removed.") then closeIconPicker() end
end

local function refreshIconPage()
    local dialog, session = UI.iconDialog, UI.iconPickerSession
    if not dialog or not session then return end
    local matches = session.matches
    local pages = math.max(1, math.ceil(#matches / 48))
    session.page = math.max(1, math.min(pages, session.page))
    dialog.page:SetText(session.page .. " / " .. pages)
    dialog.previous:SetEnabled(session.page > 1)
    dialog.next:SetEnabled(session.page < pages)
    dialog.count:SetText(#matches .. (#matches == 1 and " icon" or " icons"))
    for _, control in ipairs(dialog.categories) do
        setEnabled(control, control.categoryKey ~= session.category)
    end
    for index, cell in ipairs(dialog.cells) do
        local entry = matches[(session.page - 1) * 48 + index]
        local icon = entry and entry.icon
        cell.entry = entry
        cell.iconValue = icon
        cell.texture:SetTexture(icon)
        cell.selected:SetShown(icon ~= nil and icon == session.profile.icon)
        cell:SetShown(icon ~= nil)
        cell:SetScript("OnClick", function() if icon then saveIcon(session, icon) end end)
    end
end

local function filterIcons()
    local session = UI.iconPickerSession
    if not session then return end
    local query = UI.iconDialog.search:GetText()
    session.matches = FW:FilterProfileIconCatalog(session.catalog, query, session.category)
    session.page = 1
    refreshIconPage()
end

local function createIconPicker()
    local dialog = panel(UI.frame)
    UI.iconDialog = dialog
    dialog:SetSize(560, 444)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(UI.frame:GetFrameLevel() + 20)
    dialog:EnableMouse(true)
    backdrop(dialog, { 0.055, 0.065, 0.09, 1 })
    dialog.title = label(dialog, "Profile icon", 15, { 1, 0.82, 0 })
    dialog.title:SetPoint("TOPLEFT", 16, -16)
    dialog.title:SetWidth(480)
    dialog.title:SetWordWrap(false)
    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", closeIconPicker)
    label(dialog, "Search", 11):SetPoint("TOPLEFT", 17, -53)
    dialog.search = editBox(dialog, 442)
    dialog.search:SetPoint("TOPLEFT", 92, -45)
    dialog.search:SetScript("OnTextChanged", filterIcons)
    dialog.search:SetScript("OnEscapePressed", closeIconPicker)
    hint(dialog.search, "Search icons", "Match part of a spell or item name, class, category, texture name or ID. Multiple words narrow the results.")
    dialog.categories = {}
    dialog.count = label(dialog, "", 11, { 0.65, 0.74, 0.85 })
    dialog.count:SetPoint("BOTTOM", 0, 46)
    dialog.count:SetJustifyH("CENTER")
    dialog.cells = {}
    for index = 1, 48 do
        local cell = CreateFrame("Button", nil, dialog)
        cell:SetSize(38, 38)
        cell:SetPoint("TOPLEFT", 107 + ((index - 1) % 8) * 44, -122 - math.floor((index - 1) / 8) * 44)
        cell.texture = cell:CreateTexture(nil, "ARTWORK")
        cell.texture:SetAllPoints()
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        cell.selected = cell:CreateTexture(nil, "OVERLAY")
        cell.selected:SetAllPoints()
        cell.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        cell.isProfileIconChoice = true
        cell:SetScript("OnEnter", function(self)
            local entry = self.entry
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.label or "Profile icon", 1, 0.82, 0)
            for _, category in ipairs(UI.iconPickerSession and UI.iconPickerSession.categories or {}) do
                if category.key == entry.category then GameTooltip:AddLine(category.label, 0.75, 0.8, 0.9) break end
            end
            for _, detail in ipairs(entry.details or {}) do GameTooltip:AddLine(detail, 0.9, 0.9, 0.9, true) end
            GameTooltip:AddLine("Icon: " .. tostring(entry.icon), 0.65, 0.7, 0.8, true)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dialog.cells[index] = cell
    end
    dialog.none = button(dialog, "None", 65)
    dialog.none:SetPoint("BOTTOMLEFT", 17, 14)
    dialog.previous = button(dialog, "<", 40, function()
        if UI.iconPickerSession then UI.iconPickerSession.page = UI.iconPickerSession.page - 1 refreshIconPage() end
    end)
    dialog.previous:SetPoint("BOTTOMLEFT", 180, 14)
    dialog.page = label(dialog, "", 11)
    dialog.page:SetPoint("LEFT", dialog.previous, "RIGHT", 6, 0)
    dialog.page:SetWidth(76)
    dialog.page:SetJustifyH("CENTER")
    dialog.next = button(dialog, ">", 40, function()
        if UI.iconPickerSession then UI.iconPickerSession.page = UI.iconPickerSession.page + 1 refreshIconPage() end
    end)
    dialog.next:SetPoint("LEFT", dialog.page, "RIGHT", 6, 0)
    dialog.done = button(dialog, "Done", 65, closeIconPicker)
    dialog.done:SetPoint("BOTTOMRIGHT", -17, 14)
    dialog:EnableMouseWheel(true)
    dialog:SetScript("OnMouseWheel", function(_, delta)
        if UI.iconPickerSession then
            UI.iconPickerSession.page = UI.iconPickerSession.page + (delta > 0 and -1 or 1)
            refreshIconPage()
        end
    end)
    dialog:SetScript("OnHide", function() UI.iconPickerSession = nil dialog.search:ClearFocus() end)
    dialog:Hide()
end

local function showIconPicker()
    local profile = selectedProfile()
    if not profile then return end
    closeColorPicker(true)
    if UI.dialog then UI.dialog:Hide() end
    if UI.filterDialog then UI.filterDialog:Hide() end
    if not UI.iconDialog then createIconPicker() end
    local catalog, categories = FW:GetProfileIconCatalog()
    local session = { profile = profile, catalog = catalog, categories = categories, category = "all", matches = catalog, page = 1 }
    UI.iconPickerSession = session
    UI.iconDialog.title:SetText("Icon for " .. (profile.name or "profile"))
    local choices = { { key = "all", label = "All" } }
    for _, category in ipairs(categories) do choices[#choices + 1] = category end
    for index, category in ipairs(choices) do
        local control = UI.iconDialog.categories[index]
        if not control then
            control = button(UI.iconDialog, "", 100)
            control:SetPoint("TOPLEFT", 17 + (index - 1) * 106, -80)
            UI.iconDialog.categories[index] = control
        end
        control.categoryKey = category.key
        control:SetText(category.label)
        control:SetScript("OnClick", function()
            if UI.iconPickerSession ~= session then return end
            session.category = category.key
            filterIcons()
        end)
    end
    UI.iconDialog.search:SetText("")
    UI.iconDialog.none:SetScript("OnClick", function() saveIcon(session, nil) end)
    refreshIconPage()
    UI.iconDialog:Show()
    if #catalog == 0 then status("The game's icon catalog is unavailable.", "error") end
end

local function selectProfile(id, reveal)
    closeColorPicker(true)
    closeIconPicker()
    hideCalculationTooltip()
    closeProfileDialogs()
    UI.selectedID = id
    UI.revealSelected = reveal
    refreshEditor(true)
    FW:RefreshUI()
    status("", nil)
end

local function uniqueName(base)
    local names = {}
    for _, profile in ipairs(profiles()) do names[profile.name] = true end
    if not names[base] then return base end
    local index = 2
    while names[base .. " " .. index] do index = index + 1 end
    return base .. " " .. index
end

local function newProfile()
    UI.committing = true
    local profile, err = FW:CreateProfile(uniqueName("New profile"), {})
    UI.committing = false
    if not profile then status(err or "Could not create a profile.", "error") return end
    selectProfile(profile.id, true)
    UI.name:SetFocus()
    UI.name:HighlightText()
    status("Name this profile, enter weights, then apply them.")
end

local function copyProfile()
    local profile = selectedProfile()
    if not profile then return end
    UI.committing = true
    local copy, err = FW:CopyProfile(profile.id)
    UI.committing = false
    if not copy then status(err or "Could not copy the profile.", "error") return end
    selectProfile(copy.id, true)
    status("Profile copied.", "success")
end

local function deleteProfile(id)
    UI.committing = true
    local ok, err = FW:DeleteProfile(id)
    UI.committing = false
    if not ok then status(err or "Could not delete the profile.", "error") return end
    local remaining = profiles()
    selectProfile(remaining[1] and remaining[1].id, true)
    status("Profile deleted.", "success")
end

local function confirmDelete()
    local profile = selectedProfile()
    if not profile then return end
    if not StaticPopupDialogs or not StaticPopup_Show then
        status("The game's confirmation dialog is unavailable.", "error")
        return
    end
    StaticPopupDialogs.ZWYKVALUES_DELETE_PROFILE = StaticPopupDialogs.ZWYKVALUES_DELETE_PROFILE or {
        text = 'Delete weight profile "%s"?',
        button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            if data and data.profileID then deleteProfile(data.profileID) end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("ZWYKVALUES_DELETE_PROFILE", profile.name, nil, { profileID = profile.id })
end

local function createJSONDialog()
    local dialog = panel(UI.frame)
    UI.dialog = dialog
    dialog:SetSize(740, 470)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(UI.frame:GetFrameLevel() + 20)
    dialog:EnableMouse(true)
    backdrop(dialog, { 0.055, 0.065, 0.09, 1 })
    dialog.title = label(dialog, "", 17, { 1, 0.82, 0 })
    dialog.title:SetPoint("TOPLEFT", 18, -17)
    dialog.help = label(dialog, "", 11, { 0.79, 0.84, 0.91 })
    dialog.help:SetPoint("TOPLEFT", 18, -47)
    dialog.help:SetPoint("TOPRIGHT", -18, -47)
    dialog.help:SetHeight(30)
    dialog.help:SetJustifyV("TOP")
    dialog.nameLabel = label(dialog, "Profile name:", 11)
    dialog.nameLabel:SetPoint("TOPLEFT", 18, -86)
    dialog.name = editBox(dialog, 260)
    dialog.name:SetPoint("TOPLEFT", 112, -79)
    local inset = panel(dialog)
    inset:SetPoint("TOPLEFT", 16, -112)
    inset:SetPoint("BOTTOMRIGHT", -16, 66)
    dialog.scroll = CreateFrame("ScrollFrame", "ZwykValuesJSONScroll", inset, "UIPanelScrollFrameTemplate")
    dialog.scroll:SetPoint("TOPLEFT", 8, -8)
    dialog.scroll:SetPoint("BOTTOMRIGHT", -29, 8)
    dialog.text = CreateFrame("EditBox", nil, dialog.scroll)
    dialog.text:SetMultiLine(true)
    dialog.text:SetAutoFocus(false)
    dialog.text:SetMaxLetters(131072)
    dialog.text:SetFontObject("ChatFontNormal")
    dialog.text:SetTextInsets(3, 3, 3, 3)
    dialog.text:SetWidth(665)
    dialog.text:SetHeight(270)
    dialog.scroll:SetScrollChild(dialog.text)
    dialog.text:SetScript("OnEscapePressed", function(self) self:ClearFocus() dialog:Hide() end)
    dialog.text:SetScript("OnTextChanged", function(self)
        local lineHeight = 14
        if self.GetFont then
            local _, height = self:GetFont()
            lineHeight = (height or 12) + 2
        end
        local count = self.GetNumLines and self:GetNumLines() or 20
        self:SetHeight(math.max(dialog.scroll:GetHeight(), count * lineHeight + 16))
        dialog.scroll:UpdateScrollChildRect()
    end)
    dialog.text:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local scroll = dialog.scroll:GetVerticalScroll()
        local position = -y
        if position < scroll then
            dialog.scroll:SetVerticalScroll(math.max(0, position))
        elseif position + height > scroll + dialog.scroll:GetHeight() then
            dialog.scroll:SetVerticalScroll(position + height - dialog.scroll:GetHeight())
        end
    end)
    dialog.message = label(dialog, "", 11, { 1, 0.42, 0.34 })
    dialog.message:SetPoint("BOTTOMLEFT", 18, 42)
    dialog.message:SetWidth(680)
    dialog.message:SetHeight(17)
    dialog.close = button(dialog, "Close", 90, function() dialog:Hide() end)
    dialog.close:SetPoint("BOTTOMRIGHT", -18, 12)
    dialog.import = button(dialog, "Import profile", 120, function()
        UI.committing = true
        local profile, err, warnings = FW:ImportProfile(dialog.text:GetText(), trim(dialog.name:GetText()))
        UI.committing = false
        if not profile then
            dialog.message:SetText(err or "Could not import this JSON.")
            return
        end
        dialog:Hide()
        selectProfile(profile.id, true)
        local message = "Imported " .. profile.name .. "."
        if type(warnings) == "table" and #warnings > 0 then
            message = message .. " " .. table.concat(warnings, " ")
        elseif type(warnings) == "string" and warnings ~= "" then
            message = message .. " " .. warnings
        end
        status(message, "success")
    end)
    dialog.import:SetPoint("RIGHT", dialog.close, "LEFT", -8, 0)
    dialog.selectAll = button(dialog, "Select all", 90, function()
        dialog.text:SetFocus()
        dialog.text:HighlightText()
    end)
    dialog.selectAll:SetPoint("BOTTOMLEFT", 18, 12)
    dialog:SetScript("OnHide", function()
        dialog.text:ClearFocus()
        dialog.name:ClearFocus()
    end)
    dialog:Hide()
end

local function showJSON(mode)
    closeIconPicker()
    if UI.filterDialog then UI.filterDialog:Hide() end
    if not UI.dialog then createJSONDialog() end
    local dialog = UI.dialog
    dialog.text:SetMaxLetters(131072)
    dialog.mode = mode
    dialog.message:SetText("")
    if mode == "import" then
        dialog.title:SetText("Import a weight profile")
        dialog.help:SetText("Paste a Sixty Upgrades weights object, a ZwykValues profile, or a legacy ZwykPoints/ForeverWeights profile. Secondary weights always use percentage points; defense uses skill points.")
        dialog.nameLabel:Show()
        dialog.name:Show()
        dialog.name:SetText(uniqueName("Imported profile"))
        dialog.import:Show()
        dialog.text:SetText("")
    else
        local profile = selectedProfile()
        if not profile then return end
        local text, err = FW:ExportProfile(profile.id, mode == "weights")
        if not text then status(err or "Could not export this profile.", "error") return end
        dialog.title:SetText(mode == "weights" and "Export weights only" or "Export a weight profile")
        dialog.help:SetText(mode == "weights"
            and "Sixty Upgrades compatible keys. The weights-only JSON does not include this profile's name, color, icon, visibility, unit or item filters. Press Ctrl+C to copy."
            or "Includes all weights, name, color, icon, stat units and item filters. Press Ctrl+C to copy this profile, then import it on another character or account.")
        dialog.nameLabel:Hide()
        dialog.name:Hide()
        dialog.import:Hide()
        dialog.text:SetText(text)
    end
    dialog:Show()
    dialog.scroll:SetVerticalScroll(0)
    dialog.text:SetFocus()
    if mode ~= "import" then dialog.text:HighlightText() end
end

local function itemTypeLabel(group, definition)
    local classID = group.classID or (group.key == "weapons" and 2 or group.key == "armor" and 4)
    local subClassID = tonumber(definition.key)
    local getter = C_Item and C_Item.GetItemSubClassInfo or GetItemSubClassInfo
    if getter and classID and subClassID then
        local ok, localized = pcall(getter, classID, subClassID)
        if ok and type(localized) == "string" and localized ~= "" then return localized end
    end
    return definition.label or tostring(definition.key)
end

refreshItemFilters = function(profile)
    if not UI or not UI.filterDialog then return end
    local dialog = UI.filterDialog
    local enabled = profile ~= nil
    local filters = profile and profile.itemFilters or {}
    dialog.title:SetText(profile and ("Item filters for " .. profile.name) or "Choose a profile to set item filters")
    setEnabled(dialog.otherClasses, enabled)
    dialog.otherClasses:SetChecked(enabled and filters.includeOtherClasses ~= false)
    for _, control in ipairs(dialog.types) do
        local included = type(filters[control.filterGroup]) ~= "table" or filters[control.filterGroup][control.filterKey] ~= false
        setEnabled(control, enabled)
        control:SetChecked(enabled and included)
    end
end

local function showItemFilters()
    if not selectedProfile() then return end
    closeIconPicker()
    if UI.dialog then UI.dialog:Hide() end
    if not UI.filterDialog then
        local dialog = panel(UI.frame)
        UI.filterDialog = dialog
        dialog:SetSize(560, 500)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:SetFrameLevel(UI.frame:GetFrameLevel() + 20)
        dialog:EnableMouse(true)
        backdrop(dialog, { 0.055, 0.065, 0.09, 1 })
        dialog.title = label(dialog, "", 17, { 1, 0.82, 0 })
        dialog.title:SetPoint("TOPLEFT", 18, -17)
        dialog.title:SetPoint("TOPRIGHT", -18, -17)
        dialog.title:SetHeight(23)
        dialog.title:SetWordWrap(false)
        dialog.help = label(dialog, "Choose the item types this profile evaluates. Changes save immediately; your unsaved weights stay in the editor.", 11, { 0.79, 0.84, 0.91 })
        dialog.help:SetPoint("TOPLEFT", 18, -49)
        dialog.help:SetPoint("TOPRIGHT", -18, -49)
        dialog.help:SetHeight(31)
        dialog.help:SetJustifyV("TOP")
        dialog.otherClasses = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
        dialog.otherClasses:SetSize(25, 25)
        dialog.otherClasses:SetPoint("TOPLEFT", 13, -90)
        label(dialog.otherClasses, "Include items restricted to other classes", 11, { 0.88, 0.91, 0.96 }):SetPoint("LEFT", dialog.otherClasses, "RIGHT", 1, 0)
        dialog.otherClasses:SetScript("OnClick", function(self)
            commit({ itemFilters = { includeOtherClasses = self:GetChecked() and true or false } }, nil, "Class restriction filter saved.")
        end)
        hint(dialog.otherClasses, "Items restricted to other classes", "Include items whose Classes restriction excludes your current class. Uncheck to exclude them for this profile. The weapon and armor type filters still apply.")
        local inset = panel(dialog)
        inset:SetPoint("TOPLEFT", 16, -130)
        inset:SetPoint("BOTTOMRIGHT", -16, 52)
        dialog.scroll = CreateFrame("ScrollFrame", "ZwykValuesItemFiltersScroll", inset, "UIPanelScrollFrameTemplate")
        dialog.scroll:SetPoint("TOPLEFT", 8, -8)
        dialog.scroll:SetPoint("BOTTOMRIGHT", -29, 8)
        dialog.content = CreateFrame("Frame", nil, dialog.scroll)
        dialog.content:SetWidth(491)
        dialog.scroll:SetScrollChild(dialog.content)
        dialog.types = {}
        local y, columnWidth = 2, 245
        for _, group in ipairs(FW.ItemFilterGroups or {}) do
            local heading = label(dialog.content, group.label, 12, { 1, 0.82, 0.35 })
            heading:SetPoint("TOPLEFT", 4, -y)
            heading:SetWidth(480)
            heading:SetHeight(20)
            y = y + 25
            for index, definition in ipairs(group.types or {}) do
                local groupKey, typeKey = group.key, tostring(definition.key)
                local text = itemTypeLabel(group, definition)
                local control = CreateFrame("CheckButton", nil, dialog.content, "UICheckButtonTemplate")
                control:SetSize(23, 23)
                control:SetPoint("TOPLEFT", ((index - 1) % 2) * columnWidth, -(y + math.floor((index - 1) / 2) * 27))
                control.filterGroup, control.filterKey = groupKey, typeKey
                local name = label(control, text, 11, { 0.88, 0.91, 0.96 })
                name:SetPoint("LEFT", control, "RIGHT", 2, 0)
                name:SetWidth(columnWidth - 28)
                name:SetHeight(23)
                name:SetWordWrap(false)
                control:SetScript("OnClick", function(self)
                    commit({ itemFilters = { [groupKey] = { [typeKey] = self:GetChecked() and true or false } } }, nil, text .. " filter saved.")
                end)
                hint(control, text, "Include this item type in scores and upgrade comparisons for the selected profile. Uncheck to exclude it. Changes save immediately.")
                dialog.types[#dialog.types + 1] = control
            end
            y = y + math.ceil(#(group.types or {}) / 2) * 27 + 13
        end
        dialog.content:SetHeight(math.max(y, dialog.scroll:GetHeight()))
        local done = button(dialog, "Done", 90, function() dialog:Hide() end)
        done:SetPoint("BOTTOMRIGHT", -18, 13)
    end
    refreshItemFilters(selectedProfile())
    UI.filterDialog.scroll:SetVerticalScroll(0)
    UI.filterDialog:Show()
end

local statHints = {
    hit = "The unified hit stat. Weight per 1 percentage point (1% = 1).",
    meleeCrit = "Critical strike chance for physical attacks, including ranged attacks. Weight per 1 percentage point (1% = 1).",
    spellCrit = "Critical strike chance for spells. Weight per 1 percentage point (1% = 1).",
    haste = "Weight per 1 percentage point (1% = 1).",
    expertise = "Weight per 1 percentage point of reduced dodge/parry chance (1% = 1).",
    dodge = "Weight per 1 percentage point of dodge chance (1% = 1).",
    parry = "Weight per 1 percentage point of parry chance (1% = 1).",
    block = "Weight per 1 percentage point of block chance (1% = 1).",
    defense = "Weight per 1 defense skill point.",
    dps = "Melee weapon damage per second. It is scored separately from damage and weapon speed weights.",
    rangedDps = "Ranged weapon damage per second.",
    lowDamage = "The weapon's minimum damage. Combining multiple damage weights intentionally adds each contribution.",
    highDamage = "The weapon's maximum damage. Combining multiple damage weights intentionally adds each contribution.",
    weaponDamage = "Average weapon damage, (minimum + maximum) / 2. Combining this with DPS weights adds both contributions.",
    speed = "Melee weapon speed in seconds. Negative weights can favor faster weapons.",
    rangedSpeed = "Ranged weapon speed in seconds.",
    armor = "The item's base armor. Bonus armor is tracked separately.",
    armorBonus = "Extra armor beyond base armor.",
    blockValue = "Base shield block value. Bonus block value is tracked separately.",
    blockValueBonus = "Additional block value from item stats.",
    feralAttackPower = "Attack power that applies specifically in feral forms; it has its own weight.",
}

local function buildWeightFields()
    UI.fields, UI.fieldGroups = {}, {}
    local groups = {}
    for _, definition in ipairs(FW.StatDefinitions or {}) do
        local groupName = definition.group or "Stats"
        if type(groupName) ~= "string" then groupName = tostring(groupName) end
        local group = groups[groupName]
        if not group then
            group = { name = groupName, fields = {} }
            group.heading = label(UI.weightContent, groupName, 12, { 0.95, 0.79, 0.42 })
            groups[groupName] = group
            UI.fieldGroups[#UI.fieldGroups + 1] = group
        end
        local field = { key = definition.key, label = definition.label or definition.key, secondary = definition.secondary }
        field.frame = CreateFrame("Frame", nil, UI.weightContent)
        field.frame:SetHeight(ROW_HEIGHT)
        field.text = label(field.frame, field.label, 11, { 0.85, 0.89, 0.94 })
        field.text:SetPoint("LEFT", 0, 0)
        field.text:SetHeight(26)
        field.text:SetWordWrap(false)
        field.box = editBox(field.frame, 86)
        field.box:SetPoint("RIGHT", -4, 0)
        field.box:SetJustifyH("RIGHT")
        field.box:SetMaxLetters(30)
        field.box:SetScript("OnTextChanged", function(_, userInput)
            if UI.loading or not userInput then return end
            UI.dirtyWeights = true
            UI.weightState:SetText("Unsaved weights")
            UI.weightState:SetTextColor(1, 0.78, 0.35)
            status("Unsaved weights. Apply weights to update item scores.")
        end)
        field.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() applyWeights() end)
        hint(field.box, field.label, (statHints[field.key] or "Weight per 1 unit of this stat. Zero ignores it. Negative and decimal weights are allowed.") .. "\nImport/export key: " .. field.key)
        installCalculationButton(field)
        UI.fields[#UI.fields + 1] = field
        group.fields[#group.fields + 1] = field
    end
    for index, field in ipairs(UI.fields) do
        field.box:SetScript("OnTabPressed", function(self)
            local nextIndex = IsShiftKeyDown() and index - 1 or index + 1
            if nextIndex < 1 then nextIndex = #UI.fields end
            if nextIndex > #UI.fields then nextIndex = 1 end
            self:ClearFocus()
            local nextField = UI.fields[nextIndex]
            if nextField then
                nextField.box:SetFocus()
                nextField.box:HighlightText()
                local _, _, _, _, y = nextField.frame:GetPoint()
                local scroll = UI.weightsScroll:GetVerticalScroll()
                local position = -(y or 0)
                if position < scroll or position + ROW_HEIGHT > scroll + UI.weightsScroll:GetHeight() then
                    UI.weightsScroll:SetVerticalScroll(math.max(0, math.min(position, UI.weightsScroll:GetVerticalScrollRange())))
                end
            end
        end)
    end
end

local function layoutWeights()
    if not UI or not UI.weightContent then return end
    local width = math.max(200, UI.weightsScroll:GetWidth())
    UI.weightContent:SetWidth(width)
    local columns = width >= 470 and 2 or 1
    local gap = 20
    local columnWidth = (width - gap * (columns - 1) - 8) / columns
    local y = 2
    for _, group in ipairs(UI.fieldGroups) do
        group.heading:ClearAllPoints()
        group.heading:SetPoint("TOPLEFT", 3, -y)
        group.heading:SetWidth(width - 8)
        group.heading:SetHeight(20)
        y = y + 24
        for index, field in ipairs(group.fields) do
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            field.frame:ClearAllPoints()
            field.frame:SetPoint("TOPLEFT", column * (columnWidth + gap) + 4, -(y + row * ROW_HEIGHT))
            field.frame:SetWidth(columnWidth)
            field.text:SetWidth(math.max(50, columnWidth - (field.calculate and 121 or 100)))
        end
        y = y + math.ceil(#group.fields / columns) * ROW_HEIGHT + 9
    end
    UI.weightContent:SetHeight(math.max(y + 8, UI.weightsScroll:GetHeight()))
    UI.weightsScroll:UpdateScrollChildRect()
end

local function createProfileRow(index)
    local row = CreateFrame("Button", nil, UI.profileContent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.17, 0.25, 0.37, 0.9)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.active = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.active:SetSize(25, 25)
    row.active:SetPoint("LEFT", 0, 0)
    row.active:SetScript("OnClick", function(self)
        if not row.profileID then return end
        UI.committing = true
        local ok, err = FW:UpdateProfile(row.profileID, { active = self:GetChecked() and true or false })
        UI.committing = false
        FW:RefreshUI()
        if not ok then status(err or "Could not update profile visibility.", "error") end
    end)
    hint(row.active, "Show this profile", "Active profiles appear in item tooltips and item comparisons.")
    row.name = label(row, "", 12)
    row.name:SetPoint("LEFT", 29, 0)
    row.name:SetPoint("RIGHT", -5, 0)
    row.name:SetHeight(26)
    row.name:SetWordWrap(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 29, 0)
    row:SetScript("OnClick", function() selectProfile(row.profileID, false) end)
    row:SetScript("OnEnter", function(self)
        if row.profileName then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.profileName, 1, 1, 1)
            GameTooltip:AddLine(row.isActive and "Active in tooltips" or "Inactive in tooltips", 0.7, 0.8, 0.9)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.rows[index] = row
    return row
end

local function createUI()
    UI = { rows = {}, fields = {}, profileControls = {} }
    local frame = CreateFrame("Frame", "ZwykValuesFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    UI.frame = frame
    FW.UI = frame
    frame:SetSize(930, 720)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(850, 600, 1400, 1100)
    elseif frame.SetMinResize then frame:SetMinResize(850, 600) end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    backdrop(frame)
    label(frame, "ZwykValues", 21, { 1, 0.82, 0.35 }):SetPoint("TOPLEFT", 21, -19)
    label(frame, "Item scores from your own stat weights", 12, { 0.69, 0.77, 0.87 }):SetPoint("TOPLEFT", 22, -46)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(18, 18)
    resize:SetPoint("BOTTOMRIGHT", -3, 3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, mouseButton) if mouseButton == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end)
    resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ZwykValuesFrame") end

    UI.left = panel(frame)
    UI.left:SetPoint("TOPLEFT", 18, -71)
    UI.left:SetPoint("BOTTOMLEFT", 18, 90)
    UI.left:SetWidth(220)
    label(UI.left, "Profiles", 13, { 1, 0.82, 0.35 }):SetPoint("TOPLEFT", 12, -13)
    UI.profileScroll = CreateFrame("ScrollFrame", "ZwykValuesProfilesScroll", UI.left, "UIPanelScrollFrameTemplate")
    UI.profileScroll:SetPoint("TOPLEFT", 9, -38)
    UI.profileScroll:SetPoint("BOTTOMRIGHT", -30, 215)
    UI.profileContent = CreateFrame("Frame", nil, UI.profileScroll)
    UI.profileContent:SetSize(179, 1)
    UI.profileScroll:SetScrollChild(UI.profileContent)
    UI.new = button(UI.left, "New", 61, newProfile)
    UI.new:SetPoint("BOTTOMLEFT", 10, 12)
    UI.copy = button(UI.left, "Copy", 61, copyProfile)
    UI.copy:SetPoint("LEFT", UI.new, "RIGHT", 7, 0)
    UI.delete = button(UI.left, "Delete", 61, confirmDelete)
    UI.delete:SetPoint("LEFT", UI.copy, "RIGHT", 7, 0)

    UI.upgrades = panel(UI.left)
    UI.upgrades:SetPoint("BOTTOMLEFT", 8, 46)
    UI.upgrades:SetPoint("BOTTOMRIGHT", -8, 46)
    UI.upgrades:SetHeight(160)
    UI.upgradeTitle = label(UI.upgrades, "Upgrade arrows (0)", 12, { 1, 0.82, 0.35 })
    UI.upgradeTitle:SetPoint("TOPLEFT", 9, -10)
    UI.upgradeTitle:SetPoint("TOPRIGHT", -9, -10)
    UI.upgradeTitle:SetHeight(18)
    UI.upgradeProfile = CreateFrame("CheckButton", nil, UI.upgrades, "UICheckButtonTemplate")
    UI.upgradeProfile:SetSize(24, 24)
    UI.upgradeProfile:SetPoint("TOPLEFT", 5, -28)
    label(UI.upgradeProfile, "Use this profile", 10, { 0.88, 0.91, 0.96 }):SetPoint("LEFT", UI.upgradeProfile, "RIGHT", 0, 0)
    UI.upgradeProfile:SetScript("OnClick", function(self)
        local profile = selectedProfile()
        if not profile then return end
        UI.committing = true
        local ok, err = FW:SetProfileUpgradeEnabled(profile.id, self:GetChecked() and true or false)
        UI.committing = false
        FW:RefreshUI()
        if not ok then
            status(err or "Could not change upgrade profile visibility.", "error")
        else
            status(self:GetChecked() and (profile.name .. " is enabled for upgrade arrows.") or (profile.name .. " is disabled for upgrade arrows."), "success")
        end
    end)
    hint(UI.upgradeProfile, "Use this profile for upgrade arrows", "Enable any number of profiles. Each can identify upgrades against equipped gear or its chosen equipment set, using the profile's color. This works even when the profile is inactive in tooltips.")
    UI.comparison = button(UI.upgrades, "", 184, showComparisonPicker)
    UI.comparison:SetHeight(22)
    UI.comparison:SetPoint("TOPLEFT", 9, -55)
    UI.comparisonCaption = label(UI.comparison, "Compare: Equipped", 10, { 0.85, 0.89, 0.94 })
    UI.comparisonCaption:SetPoint("LEFT", 8, 0)
    UI.comparisonCaption:SetPoint("RIGHT", -8, 0)
    UI.comparisonCaption:SetHeight(19)
    UI.comparisonCaption:SetWordWrap(false)
    UI.comparison:SetScript("OnEnter", function(self)
        local profile = selectedProfile()
        local context = comparisonContext(profile)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(context.label or "Comparison target", 1, 0.82, 0)
        GameTooltip:AddLine(context.error or "Click to choose currently equipped gear or a Blizzard Equipment Manager set for this profile.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    UI.comparison:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function upgradeOption(text, y, key, explanation)
        local control = CreateFrame("CheckButton", nil, UI.upgrades, "UICheckButtonTemplate")
        control:SetSize(22, 22)
        control:SetPoint("TOPLEFT", 6, -y)
        label(control, text, 10, { 0.76, 0.82, 0.9 }):SetPoint("LEFT", control, "RIGHT", 1, 0)
        control.optionKey, control.default = key, false
        control:SetScript("OnClick", function(self)
            local ok, err = FW:SetUpgradeOption(key, self:GetChecked() and true or false)
            FW:RefreshUI()
            if not ok then status(err or "Could not update upgrade arrows.", "error") end
        end)
        hint(control, text .. " upgrade arrows", explanation .. " Requires at least one profile enabled for arrows. Each location can be enabled independently; changes apply immediately.")
        return control
    end
    UI.upgradeBags = upgradeOption("Item windows", 79, "upgradeBags", "Show an upgrade arrow on item icons in bags, loot, banks, trade and vendor windows, and the auction house.")
    UI.upgradeRolls = upgradeOption("Loot rolls", 103, "upgradeRolls", "Show an upgrade arrow on the item icon in native loot-roll windows.")
    UI.upgradeChat = upgradeOption("Chat item links", 127, "upgradeChat", "Show an arrow next to item links in newly received chat messages once item data is loaded. Existing messages keep their original display.")

    UI.right = panel(frame)
    UI.right:SetPoint("TOPLEFT", 250, -71)
    UI.right:SetPoint("BOTTOMRIGHT", -18, 90)
    label(UI.right, "Profile name", 11, { 0.76, 0.82, 0.9 }):SetPoint("TOPLEFT", 15, -12)
    UI.name = editBox(UI.right, 315)
    UI.name:SetPoint("TOPLEFT", 17, -30)
    UI.name:SetPoint("TOPRIGHT", -122, -30)
    UI.name:SetMaxLetters(80)
    UI.name:SetScript("OnTextChanged", function(_, userInput)
        if not UI.loading and userInput then UI.dirtyName = true end
    end)
    local function rename()
        commit({ name = trim(UI.name:GetText()) }, "name", "Profile renamed.")
    end
    UI.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() rename() end)
    UI.rename = button(UI.right, "Rename", 90, rename)
    UI.rename:SetPoint("TOPRIGHT", -15, -29)
    UI.active = CreateFrame("CheckButton", nil, UI.right, "UICheckButtonTemplate")
    UI.active:SetSize(27, 27)
    UI.active:SetPoint("TOPLEFT", 9, -61)
    label(UI.active, "Active in tooltips", 11, { 0.88, 0.91, 0.96 }):SetPoint("LEFT", UI.active, "RIGHT", 1, 0)
    UI.active:SetScript("OnClick", function(self)
        commit({ active = self:GetChecked() and true or false }, nil, "Tooltip visibility updated.")
    end)
    hint(UI.active, "Active profile", "Each active profile adds a score and comparison to item tooltips, in its chosen color.")
    label(UI.right, "Color", 11, { 0.76, 0.82, 0.9 }):SetPoint("TOPLEFT", 198, -69)
    UI.color = editBox(UI.right, 85)
    UI.color:SetPoint("TOPLEFT", 245, -61)
    UI.color:SetMaxLetters(7)
    UI.color:SetScript("OnTextChanged", function(self, userInput)
        if not UI.loading and userInput then
            UI.dirtyColor = true
            local color = parseColor(self:GetText())
            if color then previewColor(color) end
        end
    end)
    local function setColor()
        local color = parseColor(UI.color:GetText())
        if not color then status("Enter a color as #RRGGBB, such as #66CCFF.", "error") return end
        commit({ color = color }, "color", "Tooltip color saved.")
    end
    UI.color:SetScript("OnEnterPressed", function(self) self:ClearFocus() setColor() end)
    UI.colorButton = button(UI.right, "Set color", 85, setColor)
    UI.colorButton:SetPoint("LEFT", UI.color, "RIGHT", 12, 0)
    UI.colorPicker = CreateFrame("Button", nil, UI.right)
    UI.colorPicker:SetSize(19, 19)
    UI.colorPicker:SetPoint("LEFT", UI.colorButton, "RIGHT", 10, 0)
    UI.colorPicker:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    UI.colorPicker:SetScript("OnClick", showColorPicker)
    UI.colorPicker.isColorSwatch = true
    UI.colorSwatch = UI.colorPicker:CreateTexture(nil, "ARTWORK")
    UI.colorSwatch:SetAllPoints()
    hint(UI.colorPicker, "Choose tooltip color", "Click to open the game's color picker. Changes save immediately; Cancel restores the previous color. Your unsaved weights and profile name are kept.")
    hint(UI.color, "Tooltip color", "Enter a six-digit hexadecimal color, for example #66CCFF. Click Set color to save it, or click the colored square to open the color picker.")
    label(UI.right, "Icon", 11, { 0.76, 0.82, 0.9 }):SetPoint("LEFT", UI.colorPicker, "RIGHT", 13, 0)
    UI.icon = CreateFrame("Button", nil, UI.right)
    UI.icon:SetSize(24, 24)
    UI.icon:SetPoint("LEFT", UI.colorPicker, "RIGHT", 45, 0)
    UI.icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    UI.icon:SetScript("OnClick", showIconPicker)
    UI.icon.isProfileIcon = true
    UI.profileIcon = UI.icon:CreateTexture(nil, "ARTWORK")
    UI.profileIcon:SetAllPoints()
    UI.iconNone = label(UI.icon, "—", 17, { 0.65, 0.74, 0.85 })
    UI.iconNone:SetPoint("CENTER")
    hint(UI.icon, "Choose profile icon", "Choose an optional game icon. Select None to remove it. Changes save immediately and keep unsaved name, color and weights.")

    UI.itemFilters = button(UI.right, "Item filters", 100, showItemFilters)
    UI.itemFilters:SetPoint("TOPRIGHT", -15, -98)
    hint(UI.itemFilters, "Item filters for this profile", "Choose weapon types, armor types, and whether to include items restricted to other classes. These settings are separate for each profile and save immediately.")
    UI.unitHelp = label(UI.right, "", 10, { 0.65, 0.74, 0.85 })
    UI.unitHelp:SetPoint("TOPLEFT", 15, -103)
    UI.unitHelp:SetPoint("TOPRIGHT", -130, -103)
    UI.unitHelp:SetHeight(26)
    UI.unitHelp:SetJustifyV("TOP")
    UI.editorTitle = label(UI.right, "Weights", 12, { 1, 0.82, 0.35 })
    UI.editorTitle:SetPoint("TOPLEFT", 15, -139)
    UI.editorTitle:SetPoint("TOPRIGHT", -15, -139)
    UI.editorTitle:SetHeight(20)
    UI.weightsScroll = CreateFrame("ScrollFrame", "ZwykValuesStatsScroll", UI.right, "UIPanelScrollFrameTemplate")
    UI.weightsScroll:SetPoint("TOPLEFT", 12, -167)
    UI.weightsScroll:SetPoint("BOTTOMRIGHT", -33, 51)
    UI.weightContent = CreateFrame("Frame", nil, UI.weightsScroll)
    UI.weightContent:SetSize(610, 1)
    UI.weightsScroll:SetScrollChild(UI.weightContent)
    UI.weightState = label(UI.right, "Weights saved", 11, { 0.6, 0.72, 0.64 })
    UI.weightState:SetPoint("BOTTOMLEFT", 15, 22)
    UI.apply = button(UI.right, "Apply weights", 120, applyWeights)
    UI.apply:SetPoint("BOTTOMRIGHT", -15, 14)
    UI.import = button(UI.right, "Import", 70, function() showJSON("import") end)
    UI.import:SetPoint("RIGHT", UI.apply, "LEFT", -8, 0)
    UI.export = button(UI.right, "Export", 70, function() showJSON("profile") end)
    UI.export:SetPoint("RIGHT", UI.import, "LEFT", -6, 0)
    UI.exportWeights = button(UI.right, "Weights JSON", 104, function() showJSON("weights") end)
    UI.exportWeights:SetPoint("RIGHT", UI.export, "LEFT", -6, 0)
    hint(UI.export, "Export profile", "Exports the saved profile with its name, color, icon, units and item filters. Apply edited weights before exporting.")
    hint(UI.exportWeights, "Export weights", "Exports the saved weights using Sixty Upgrades keys. Name, color, icon, unit and item filter metadata are omitted.")
    UI.profileControls = { UI.name, UI.rename, UI.active, UI.upgradeProfile, UI.comparison, UI.color, UI.colorButton, UI.colorPicker, UI.icon, UI.itemFilters, UI.apply }
    buildWeightFields()

    local note = label(frame, "Fixed weights ignore caps, procs, sets and rotations.", 10, { 0.66, 0.71, 0.79 })
    note:SetPoint("BOTTOMLEFT", 21, 73)
    note:SetWidth(305)
    local function option(text, x, key, default)
        local control = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        control:SetSize(24, 24)
        control:SetPoint("BOTTOMLEFT", x, 65)
        label(control, text, 10, { 0.76, 0.82, 0.9 }):SetPoint("LEFT", control, "RIGHT", 0, 0)
        control:SetScript("OnClick", function(self)
            FW.DB.options = FW.DB.options or {}
            FW.DB.options[key] = self:GetChecked() and true or false
            if FW.RefreshTooltips then FW:RefreshTooltips() end
        end)
        control.optionKey, control.default = key, default
        return control
    end
    UI.debugUnknown = option("Mark unrecognized stats", 340, "debugUnknownStats", false)
    UI.comparisons = option("Show upgrade comparisons", 590, "showComparisons", true)
    hint(UI.debugUnknown, "Unrecognized stat diagnostics", "Adds [ZV ?] next to unrecognized stat lines. Partial-data warnings and the issue log are available even when this option is off.")
    hint(UI.comparisons, "Item comparisons", "Show the flat score change and percentage upgrade or downgrade for every active tooltip profile, using its selected equipped gear or equipment set.")
    UI.status = label(frame, "", 11)
    UI.status:SetPoint("BOTTOMLEFT", 21, 44)
    UI.status:SetPoint("BOTTOMRIGHT", -21, 44)
    UI.status:SetHeight(27)
    UI.status:SetJustifyV("TOP")
    UI.cache = label(frame, "", 11, { 0.67, 0.75, 0.84 })
    UI.cache:SetPoint("BOTTOMLEFT", 21, 20)
    UI.clearCache = button(frame, "Clear cache", 105, function()
        FW:InvalidateCache()
        FW:RefreshUI()
        status("Item cache cleared. Scores will be rebuilt as items are inspected.", "success")
    end)
    UI.clearCache:SetPoint("BOTTOMRIGHT", -29, 13)
    hint(UI.clearCache, "Clear local item cache", "Discards cached item stats and scores. Profiles and their weights are kept.")
    UI.exportIssues = button(frame, "Export issues", 110, function() FW:ExportItemIssues() end)
    UI.exportIssues:SetPoint("RIGHT", UI.clearCache, "LEFT", -8, 0)
    hint(UI.exportIssues, "Export item diagnostics", "Copies JSON for every encountered item variant with parsing or stat-unit issues, including raw stats, tooltip lines and known scores. The log is saved between sessions. /zv clearissues resets it.")
    frame:SetScript("OnSizeChanged", function()
        UI.profileContent:SetWidth(math.max(100, UI.profileScroll:GetWidth()))
        layoutWeights()
    end)
    frame:SetScript("OnHide", function()
        closeColorPicker(true)
        closeIconPicker()
        hideCalculationTooltip()
        closeProfileDialogs()
        if UI.dialog then UI.dialog:Hide() end
        if UI.filterDialog then UI.filterDialog:Hide() end
        UI.name:ClearFocus()
        UI.color:ClearFocus()
        for _, field in ipairs(UI.fields) do field.box:ClearFocus() end
    end)
    frame:SetScript("OnShow", function() FW:RefreshUI() layoutWeights() end)
    local existing = profiles()
    UI.selectedID = existing[1] and existing[1].id
    refreshEditor(true)
    layoutWeights()
    frame:Hide()
end

function FW:RefreshUI()
    if not UI or UI.committing then return end
    local all = profiles()
    if not selectedProfile() then
        UI.selectedID = all[1] and all[1].id
        refreshEditor(true)
    else
        refreshEditor(false)
    end
    local currentScroll = UI.profileScroll:GetVerticalScroll()
    local selectedIndex
    for index, profile in ipairs(all) do
        local row = UI.rows[index] or createProfileRow(index)
        row.profileID, row.profileName, row.isActive = profile.id, profile.name, profile.active
        row.name:SetText(profile.name)
        row.icon:SetTexture(profile.icon)
        row.icon:SetShown(profile.icon ~= nil)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", profile.icon and 53 or 29, 0)
        row.name:SetPoint("RIGHT", -5, 0)
        local color = profile.color or { r = 1, g = 1, b = 1 }
        row.name:SetTextColor(color.r, color.g, color.b)
        row.active:SetChecked(profile.active and true or false)
        row.highlight:SetShown(profile.id == UI.selectedID)
        if profile.id == UI.selectedID then selectedIndex = index end
        row:Show()
    end
    for index = #all + 1, #UI.rows do UI.rows[index]:Hide() end
    UI.profileContent:SetWidth(math.max(100, UI.profileScroll:GetWidth()))
    UI.profileContent:SetHeight(math.max(1, #all * ROW_HEIGHT, UI.profileScroll:GetHeight()))
    UI.profileScroll:UpdateScrollChildRect()
    local maxScroll = math.max(0, UI.profileContent:GetHeight() - UI.profileScroll:GetHeight())
    currentScroll = math.min(currentScroll, maxScroll)
    if UI.revealSelected and selectedIndex then
        local top = (selectedIndex - 1) * ROW_HEIGHT
        if top < currentScroll then currentScroll = top end
        if top + ROW_HEIGHT > currentScroll + UI.profileScroll:GetHeight() then
            currentScroll = math.min(maxScroll, top + ROW_HEIGHT - UI.profileScroll:GetHeight())
        end
    end
    UI.revealSelected = false
    UI.profileScroll:SetVerticalScroll(math.max(0, currentScroll))
    local count = 0
    if self.GetCacheCount then
        count = self:GetCacheCount() or 0
    elseif self.DB and self.DB.cache and self.DB.cache.items then
        for _ in pairs(self.DB.cache.items) do count = count + 1 end
    end
    UI.cache:SetText(string.format("Cached items: %d  |  Profiles: %d", count, #all))
    local upgradeProfiles = self.GetUpgradeProfiles and self:GetUpgradeProfiles() or {}
    UI.upgradeTitle:SetText("Upgrade arrows (" .. #upgradeProfiles .. ")")
    local options = self.DB and self.DB.options or {}
    for _, control in ipairs({ UI.debugUnknown, UI.comparisons, UI.upgradeBags, UI.upgradeRolls, UI.upgradeChat }) do
        local value = options[control.optionKey]
        if value == nil then value = control.default end
        control:SetChecked(value and true or false)
    end
end

function FW:ToggleUI()
    if not UI then createUI() end
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end

function FW:ShowUI()
    if not UI then createUI() end
    UI.frame:Show()
    if UI.frame.Raise then UI.frame:Raise() end
end

function FW:InstallCharacterSheetButton()
    if self.characterSheetButton then return self.characterSheetButton end
    local slot = _G.CharacterTrinket1Slot
    if not slot then return end
    -- The slot supplies the character-tab visibility and position, including
    -- when Blizzard creates the character UI after this addon has loaded.
    local launcher = button(slot, "ZV", 42, function() self:ToggleUI() end)
    launcher:SetHeight(20)
    launcher:SetPoint("TOPRIGHT", slot, "BOTTOMRIGHT", 0, -6)
    hint(launcher, "ZwykValues", "Open item value profiles.")
    self.characterSheetButton = launcher
    return launcher
end

function FW:ShowTextDialog(title, text, importMode)
    if not UI then createUI() end
    closeIconPicker()
    if UI.filterDialog then UI.filterDialog:Hide() end
    UI.frame:Show()
    if importMode then
        showJSON("import")
        if title then UI.dialog.title:SetText(title) end
        if text then UI.dialog.text:SetText(text) end
        return
    end
    if not UI.dialog then createJSONDialog() end
    local dialog = UI.dialog
    dialog.mode = "text"
    dialog.title:SetText(title or "ZwykValues")
    dialog.help:SetText("Select all, then press Ctrl+C to copy this text.")
    dialog.nameLabel:Hide()
    dialog.name:Hide()
    dialog.import:Hide()
    dialog.message:SetText("")
    -- Diagnostics can contain every encountered issue item. Do not silently
    -- truncate a large export at the profile editor's input limit.
    dialog.text:SetMaxLetters(0)
    dialog.text:SetText(text or "")
    dialog:Show()
    dialog.scroll:SetVerticalScroll(0)
    dialog.text:SetFocus()
    dialog.text:HighlightText()
end
