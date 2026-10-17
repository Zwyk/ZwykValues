-- Smoke actual editor callbacks with a small WoW widget model.
-- Run from the addon directory: luatex --luaonly tests/test_ui.lua
local addonPath = (arg and arg[1]) or "."
local widgets, methods = {}, {}
local passed = 0
local function check(value, message)
    assert(value, message or "assertion failed")
    passed = passed + 1
end
local function equal(actual, expected, message)
    check(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function widget(kind, name, parent)
    local result = setmetatable({ kind = kind, name = name, parent = parent, children = {}, points = {}, scripts = {}, shown = true, enabled = true, text = "", fontSize = 12, scroll = 0 }, { __index = methods })
    widgets[#widgets + 1] = result
    if parent then parent.children[#parent.children + 1] = result end
    if name then _G[name] = result end
    return result
end
function CreateFrame(kind, name, parent) return widget(kind, name, parent or UIParent) end
function methods:CreateFontString(name) return widget("FontString", name, self) end
function methods:CreateTexture(name) return widget("Texture", name, self) end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then relative, relativePoint, x, y = self.parent, point, 0, 0
    elseif type(relativePoint) == "number" then x, y, relativePoint = relativePoint, x, point end
    self.points[#self.points + 1] = { point, relative, relativePoint or point, x or 0, y or 0 }
end
function methods:GetPoint(index) return table.unpack(self.points[index or 1]) end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(target)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", target or self.parent, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", target or self.parent, "BOTTOMRIGHT", 0, 0)
end
local fractions = {
    TOPLEFT = {0, 0}, TOP = {.5, 0}, TOPRIGHT = {1, 0}, LEFT = {0, .5}, CENTER = {.5, .5}, RIGHT = {1, .5},
    BOTTOMLEFT = {0, 1}, BOTTOM = {.5, 1}, BOTTOMRIGHT = {1, 1},
}
function methods:Rect()
    if self == UIParent then return 0, 0, self.width, self.height end
    local width = self.width or math.max(1, #self.text * self.fontSize * .56)
    local height = self.height or self.fontSize
    local axis = { {}, {} }
    for _, point in ipairs(self.points) do
        local relative = point[2] or self.parent
        local left, top, rw, rh = relative:Rect()
        local own, anchor = fractions[point[1]], fractions[point[3]]
        axis[1][#axis[1] + 1] = { own[1], left + anchor[1] * rw + point[4] }
        axis[2][#axis[2] + 1] = { own[2], top + anchor[2] * rh - point[5] }
    end
    local dimensions = { width, height }
    local positions = {}
    for index = 1, 2 do
        for a = 1, #axis[index] do
            for b = a + 1, #axis[index] do
                local first, second = axis[index][a], axis[index][b]
                if first[1] ~= second[1] then dimensions[index] = (second[2] - first[2]) / (second[1] - first[1]) end
            end
        end
        local first = axis[index][1]
        positions[index] = first and first[2] - first[1] * dimensions[index] or 0
    end
    return positions[1], positions[2], dimensions[1], dimensions[2]
end
function methods:GetWidth() local _, _, width = self:Rect() return width end
function methods:GetHeight() local _, _, _, height = self:Rect() return height end
function methods:SetScript(event, script) self.scripts[event] = script end
function methods:GetScript(event) return self.scripts[event] end
function methods:Fire(event, ...) if self.scripts[event] then return self.scripts[event](self, ...) end end
function methods:SetText(text)
    self.text = tostring(text)
    if self.kind == "EditBox" then self:Fire("OnTextChanged", false) end
end
function methods:GetText() return self.text end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetFont() return "font", self.fontSize end
function methods:SetTextColor(...) self.color = {...} end
function methods:GetTextColor() return table.unpack(self.color or {1, 1, 1, 1}) end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
function methods:HighlightText() self.highlighted = true end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:Show() if not self.shown then self.shown = true self:Fire("OnShow") end end
function methods:Hide() if self.shown then self.shown = false self:Fire("OnHide") end end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetFrameLevel() return self.level or 1 end
function methods:Raise() self.raised = (self.raised or 0) + 1 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetMinMaxValues(low, high) self.minValue, self.maxValue = low, high end
function methods:SetValueStep(value) self.valueStep = value end
function methods:SetObeyStepOnDrag(value) self.obeyStep = value end
function methods:SetValue(value) self.value = value self:Fire("OnValueChanged", value) end
function methods:GetValue() return self.value end
function methods:GetVerticalScroll() return self.scroll end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScrollRange() return math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) end
function methods:GetNumLines() local _, lines = self.text:gsub("\n", "") return lines + 1 end
for _, name in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetJustifyH", "SetJustifyV", "SetFontObject", "SetTextInsets", "SetAutoFocus", "SetMaxLetters", "SetMultiLine", "SetWordWrap", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "SetResizable", "SetResizeBounds", "EnableMouse", "EnableMouseWheel", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "StartSizing", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "UpdateScrollChildRect", "RegisterEvent" }) do
    methods[name] = function() end
end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:SetFrameStrata(value) self.strata=value end
local catalogCalls = 0
issecretvalue = function(value) return value == "SecretTexture" end
GetLooseMacroIcons = function(values)
    catalogCalls = catalogCalls + 1
    values[#values + 1] = "Spell_Holy_HolyBolt"
    values[#values + 1] = 135920
    values[#values + 1] = "135920"
    values[#values + 1] = "SecretTexture"
    values[#values + 1] = -1
    values[#values + 1] = 1.5
    values[#values + 1] = math.huge
    values[#values + 1] = 4294967296
end
GetMacroIcons = function(values)
    catalogCalls = catalogCalls + 1
    for index = 1, 100 do values[#values + 1] = 200000 + index end
    values[#values + 1] = "../Invalid"
end
GetLooseMacroItemIcons = function(values)
    catalogCalls = catalogCalls + 1
    -- Some clients replace their output table instead of appending.
    for key in pairs(values) do values[key] = nil end
    values[#values + 1] = "INV_Chest_Plate01"
    values[#values + 1] = "interface\\icons\\inv_chest_plate01"
end
GetMacroItemIcons = function(values)
    catalogCalls = catalogCalls + 1
    values[#values + 1] = 133001
end
UIParent = widget("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
UISpecialFrames, SlashCmdList, StaticPopupDialogs = {}, {}, {}
BackdropTemplateMixin = {}
IsShiftKeyDown = function() return false end
GetItemSubClassInfo = function(classID, subClassID)
    if classID == 2 and subClassID == 0 then return "Localized one-handed axes" end
end
local popup
StaticPopup_Show = function(kind, _, _, data) popup = { kind = kind, data = data } end

local FW = {}
for _, file in ipairs({ "JSON.lua", "Stats.lua", "Core.lua", "IconCatalog.lua", "DerivedWeights.lua", "UI.lua" }) do assert(loadfile(addonPath .. "/" .. file))("ZwykValues", FW) end
local tooltipRefreshes, upgradeRefreshes = 0, 0
function FW:RefreshTooltips() tooltipRefreshes = tooltipRefreshes + 1 end
function FW:RefreshUpgradeIndicators() upgradeRefreshes = upgradeRefreshes + 1 end
function FW:InstallTooltipHooks() end
assert(loadfile(addonPath .. "/Bootstrap.lua"))("ZwykValues", FW)
equal(FW.UI, nil, "loading modules creates no editor")
local beforeCharacterButton = #widgets
equal(FW:InstallCharacterSheetButton(), nil, "character launcher waits for the native trinket slot")
equal(#widgets, beforeCharacterButton, "missing character UI creates no launcher or retry frame")
FW:Initialize()
equal(FW.UI, nil, "initializing profiles preserves lazy editor construction")
SlashCmdList.ZWYKVALUES("")
check(FW.UI and FW.UI:IsShown(), "/zv opens the editor")
local created = #widgets
SlashCmdList.ZWYKVALUES("")
check(not FW.UI:IsShown(), "/zv closes the editor")
SlashCmdList.ZWYKVALUES("")
equal(#widgets, created, "reopening editor reuses widgets")
equal(catalogCalls, 0, "opening the profile editor does not enumerate game icons")
FW.UI:Hide()
FW:ShowUI()
check(FW.UI:IsShown(), "ShowUI opens the profile editor")
equal(FW.UI.raised, 1, "ShowUI raises the editor above other windows")
FW:ShowUI()
check(FW.UI:IsShown(), "ShowUI keeps an already open editor visible")
equal(FW.UI.raised, 2, "ShowUI raises an already open editor")
equal(#widgets, created, "ShowUI reuses existing editor widgets")

local function find(predicate)
    for _, control in ipairs(widgets) do if predicate(control) then return control end end
    error("Missing UI control")
end
local function byText(text, kind)
    return find(function(control) return control.text == text and (not kind or control.kind == kind) end)
end
local function click(text) byText(text, "Button"):Fire("OnClick") end
local function userText(control, text) control:SetText(text) control:Fire("OnTextChanged", true) end
local function weightBox(text)
    local label = byText(text, "FontString")
    for _, child in ipairs(label.parent.children) do if child.kind == "EditBox" then return child end end
    error("Missing weight editor: " .. text)
end
local function filterControl(group, key)
    return find(function(control) return control.filterGroup == group and control.filterKey == key end)
end
local character = widget("Frame", "CharacterFrame", UIParent)
local paperDoll = widget("Frame", "PaperDollFrame", character)
local lastTrinket = widget("Button", "CharacterTrinket1Slot", paperDoll)
lastTrinket:SetSize(40, 40)
lastTrinket:SetPoint("TOPRIGHT", paperDoll, "TOPRIGHT", -20, -450)
local nativeTrinketClick = function() end
lastTrinket:SetScript("OnClick", nativeTrinketClick)
local launcher = FW:InstallCharacterSheetButton()
equal(launcher.parent, lastTrinket, "launcher inherits equipment-tab visibility")
equal(launcher:GetText(), "ZV", "character launcher keeps a small label")
equal(launcher:GetWidth(), 42, "character launcher fits below the trinket column")
equal(launcher:GetHeight(), 20, "character launcher has a compact height")
local anchor, relative, relativeAnchor, x, y = launcher:GetPoint()
equal(anchor, "TOPRIGHT", "launcher aligns its right edge with the trinket")
equal(relative, lastTrinket, "launcher is anchored to the last trinket")
equal(relativeAnchor, "BOTTOMRIGHT", "launcher appears below the last trinket")
equal(x, 0, "launcher has no horizontal offset")
equal(y, -6, "launcher has a small gap under the trinket")
equal(lastTrinket:GetScript("OnClick"), nativeTrinketClick, "launcher preserves native slot actions")
equal(launcher:GetScript("OnUpdate"), nil, "character launcher performs no per-frame work")
local withLauncher = #widgets
equal(FW:InstallCharacterSheetButton(), launcher, "repeated installation reuses the character launcher")
equal(#widgets, withLauncher, "repeated installation creates no extra widgets")
check(launcher:IsVisible(), "launcher is visible on the equipment tab")
paperDoll:Hide()
check(not launcher:IsVisible(), "launcher disappears on other character-sheet tabs")
paperDoll:Show()
character:Hide()
check(not launcher:IsVisible(), "closing the character sheet hides its launcher")
character:Show()
FW.UI:Hide()
launcher:Fire("OnClick")
check(FW.UI:IsShown(), "character launcher opens the profile editor")
launcher:Fire("OnClick")
check(not FW.UI:IsShown(), "character launcher can close the profile editor")
launcher:Fire("OnClick")
equal(#widgets, withLauncher, "character launcher reuses the existing editor")
local tooltipTitle, tooltipHelp
GameTooltip = {
    SetOwner = function(_, owner) equal(owner, launcher, "launcher owns its explanatory tooltip") end,
    SetText = function(_, title) tooltipTitle = title end,
    AddLine = function(_, text) tooltipHelp = text end,
    Show = function() end,
    Hide = function() end,
}
launcher:Fire("OnEnter")
equal(tooltipTitle, "ZwykValues", "launcher tooltip identifies the addon")
equal(tooltipHelp, "Open item value profiles.", "launcher tooltip explains its action")
launcher:Fire("OnLeave")

local strength, hit = weightBox("Strength"), weightBox("Hit (%)")
local profile = FW:GetProfiles()[1]
userText(strength, "2.5")
userText(hit, "-3")
local critical = byText("Spell critical strike (%)", "FontString")
do
    local meleeCritBox, spellCritBox = weightBox("Melee critical strike (%)"), weightBox("Spell critical strike (%)")
    userText(meleeCritBox, "2")
    userText(spellCritBox, "7")
    check(meleeCritBox ~= spellCritBox, "melee and spell critical strike have separate inputs")
end
local defense = byText("Defense (skill)", "FontString")
for _, text in ipairs({ "Haste (%)", "Expertise (%)", "Dodge (%)", "Parry (%)", "Block chance (%)" }) do
    check(byText(text, "FontString"), "percent weight label specifies its unit: " .. text)
end
for _, control in ipairs(widgets) do
    check(control:GetText() ~= "Rating" and control:GetText() ~= "Percent / skill", "editor has no secondary-unit mode choices")
end
local unitHelp = find(function(control) return control.kind == "FontString" and control:GetText():match("^Secondary weights always") end)
check(unitHelp:GetText():find("1% = 1", 1, true), "editor explains that secondary weights always use percentage points")
profile.secondaryUnit = "rating" -- Simulate a malformed legacy in-memory profile.
FW:RefreshUI()
equal(critical:GetText(), "Spell critical strike (%)", "crit label always uses percentage points")
equal(byText("Melee critical strike (%)", "FontString"):GetText(), "Melee critical strike (%)", "melee critical strike label uses percentage points")
equal(defense:GetText(), "Defense (skill)", "defense label always uses defense skill")
equal(hit.parent.children[1]:GetText(), "Hit (%)", "hit label always uses percentage points")
profile.secondaryUnit = "percent"
equal(strength:GetText(), "2.5", "refresh preserves unsaved primary weights")
equal(hit:GetText(), "-3", "refresh preserves unsaved secondary weights")
equal(profile.weights.hit, 0, "refresh does not apply draft weights")
equal(profile.weights.strength, 0, "weights remain drafts before applying")
equal(profile.weights.meleeCrit, 0, "melee crit stays a draft before Apply")
equal(profile.weights.spellCrit, 0, "spell crit stays a draft before Apply")
click("Item filters")
local filterScroll = ZwykValuesItemFiltersScroll
local filterDialog = filterScroll.parent.parent
check(filterDialog:IsShown(), "Item filters opens the filter dialog")
local filterCount = 0
for _, group in ipairs(FW.ItemFilterGroups) do
    for _, definition in ipairs(group.types) do
        filterCount = filterCount + 1
        check(filterControl(group.key, definition.key):GetChecked(), "new profiles include " .. group.key .. ":" .. definition.key)
    end
end
check(filterCount >= 22, "filter dialog offers weapon and armor subtype choices")
check(byText("Localized one-handed axes", "FontString"), "subtype labels use client localization when available")
check(byText("Plate", "FontString"), "subtype labels retain the definition fallback when the client has none")
local otherClasses = byText("Include items restricted to other classes", "FontString").parent
check(otherClasses:GetChecked(), "other-class items are included by default")
local weaponFilter, armorFilter = filterControl("weapons", "0"), filterControl("armor", "4")
local beforeFilters = upgradeRefreshes
weaponFilter:SetChecked(false)
weaponFilter:Fire("OnClick")
armorFilter:SetChecked(false)
armorFilter:Fire("OnClick")
otherClasses:SetChecked(false)
otherClasses:Fire("OnClick")
equal(profile.itemFilters.weapons["0"], false, "weapon filter is saved immediately")
equal(profile.itemFilters.armor["4"], false, "armor filter is saved immediately")
equal(profile.itemFilters.includeOtherClasses, false, "other-class restriction filter is saved immediately")
equal(profile.itemFilters.weapons["1"], true, "partial filter updates retain other weapon types")
equal(profile.itemFilters.armor["1"], true, "partial filter updates retain other armor types")
equal(upgradeRefreshes, beforeFilters + 3, "each filter edit refreshes indicators")
equal(strength:GetText(), "2.5", "filter edits preserve unsaved strength weights")
equal(hit:GetText(), "-3", "filter edits preserve every unsaved weight")
equal(profile.weights.strength, 0, "filter edits do not apply unsaved weights")
click("Done")
check(not filterDialog:IsShown(), "Done closes item filters")
local filterWidgets = #widgets
click("Item filters")
equal(#widgets, filterWidgets, "reopening filters reuses its widgets")
check(not weaponFilter:GetChecked() and not armorFilter:GetChecked() and not otherClasses:GetChecked(), "saved exclusions survive reopening filters")
click("Done")
FW:InvalidateCache()
equal(strength:GetText(), "2.5", "cache refresh preserves unsaved weights")
equal(hit:GetText(), "-3", "cache refresh preserves every unsaved weight")
click("Apply weights")
equal(profile.weights.strength, 2.5, "apply commits decimal weights")
equal(profile.weights.hit, -3, "apply commits negative weights")
equal(profile.weights.meleeCrit, 2, "Apply saves the melee critical-strike weight independently")
equal(profile.weights.spellCrit, 7, "Apply saves the spell critical-strike weight independently")
equal(profile.weights.crit, nil, "the editor saves canonical crit channels without the old combined key")
userText(strength, "invalid")
click("Apply weights")
equal(profile.weights.strength, 2.5, "invalid weight input leaves saved profile intact")
check(strength.focused, "validation focuses the invalid input")
userText(strength, "4")
click("Apply weights")

local name = find(function(control) return control.kind == "EditBox" and control.parent == strength.parent.parent.parent.parent and control:GetText() == "My profile" end)
local color = find(function(control) return control.kind == "EditBox" and control:GetText():match("^#%x%x%x%x%x%x$") end)
userText(name, "Draft name")
userText(color, "#12345Z")
FW:RefreshUI()
equal(name:GetText(), "Draft name", "cache updates preserve unsaved name")
equal(color:GetText(), "#12345Z", "cache updates preserve unsaved color")
local oldRed = profile.color.r
click("Set color")
equal(profile.color.r, oldRed, "invalid HEX does not change profile color")
userText(color, "#123456")
click("Set color")
equal(profile.color.r, 0x12 / 255, "valid HEX saves red")
equal(profile.color.g, 0x34 / 255, "valid HEX saves green")
equal(profile.color.b, 0x56 / 255, "valid HEX saves blue")
click("Rename")
equal(profile.name, "Draft name", "rename commits name")

local swatch = find(function(control) return control.isColorSwatch end)
local modernPicker = widget("Frame", nil, UIParent)
modernPicker:Hide()
function modernPicker:GetColorRGB() return table.unpack(self.rgb) end
function modernPicker:SetupColorPickerAndShow(info)
    self.info = info
    self.swatchFunc, self.cancelFunc = info.swatchFunc, info.cancelFunc
    self.rgb = { info.r, info.g, info.b }
    -- The native picker fires OnColorSelect while setting its initial RGB.
    self.swatchFunc()
    self:Show()
end
ColorPickerFrame = modernPicker
local pickerRevision = profile.revision
userText(name, "Picker draft name")
userText(strength, "7.25")
userText(color, "#ABCDEF")
swatch:Fire("OnClick")
check(modernPicker:IsShown(), "clicking the color square opens the native picker")
equal(modernPicker.strata, "DIALOG", "native picker is raised above the main editor")
check(modernPicker:GetFrameLevel() > FW.UI:GetFrameLevel(), "native picker has a higher frame level")
equal(modernPicker.info.hasOpacity, false, "profile colors do not expose an opacity slider")
equal(modernPicker.info.r, 0x12 / 255, "picker starts from the saved profile color")
equal(color:GetText(), "#ABCDEF", "opening a picker preserves unsaved HEX text")
equal(profile.color.r, 0x12 / 255, "native setup callback does not save or replace a draft")
modernPicker.rgb = { .25, .5, .75 }
modernPicker.info.swatchFunc()
equal(profile.color.r, .25, "modern picker saves selected colors immediately")
equal(profile.color.g, .5, "modern picker saves the selected green channel")
equal(profile.color.b, .75, "modern picker saves the selected blue channel")
equal(color:GetText(), "#4080BF", "picker selection updates HEX text")
equal(swatch.children[1].color[1], 0x40 / 255, "picker selection updates the color square to its displayed HEX")
equal(name:GetText(), "Picker draft name", "picker saves preserve the draft profile name")
equal(strength:GetText(), "7.25", "picker saves preserve unsaved stat weights")
equal(profile.name, "Draft name", "picker does not save draft names")
equal(profile.weights.strength, 4, "picker does not save draft weights")
equal(profile.revision, pickerRevision, "color changes do not invalidate stat-score revisions")
-- Classic Cancel hides the frame before calling cancelFunc.
modernPicker:Hide()
modernPicker.info.cancelFunc({ r = 0, g = 0, b = 0 })
equal(profile.color.r, 0x12 / 255, "Cancel restores original saved red despite supplied callback values")
equal(profile.color.g, 0x34 / 255, "Cancel restores original saved green")
equal(profile.color.b, 0x56 / 255, "Cancel restores original saved blue")
equal(color:GetText(), "#ABCDEF", "Cancel restores pre-picker HEX draft")
FW:RefreshUI()
equal(color:GetText(), "#ABCDEF", "Cancel preserves HEX draft state on later refresh")
equal(name:GetText(), "Picker draft name", "Cancel preserves the name draft")
equal(strength:GetText(), "7.25", "Cancel preserves the weight draft")
equal(profile.revision, pickerRevision, "Cancel leaves score revisions unchanged")
swatch:Fire("OnClick")
modernPicker.rgb = { .1, .2, .3 }
modernPicker.info.swatchFunc()
modernPicker:Hide() -- Accept: subsequent picker open must keep the accepted RGB.
swatch:Fire("OnClick")
equal(modernPicker.info.r, .1, "reopening after acceptance keeps the saved picker color")
local staleSelection = modernPicker.info
modernPicker.rgb = { .6, .7, .8 }
modernPicker.info.swatchFunc()
local other = assert(FW:CreateProfile("Picker other profile", {}))
local otherColor = other.color.r
find(function(control) return control.kind == "Button" and control.profileID == other.id end):Fire("OnClick")
check(not modernPicker:IsShown(), "switching profiles closes the previous profile's picker")
equal(profile.color.r, .1, "switching profiles cancels the pending picker edit")
modernPicker.rgb = { .9, .9, .9 }
staleSelection.swatchFunc()
staleSelection.cancelFunc()
equal(other.color.r, otherColor, "stale picker callbacks cannot recolor the newly selected profile")
equal(profile.color.r, .1, "stale picker callbacks cannot change the original profile")
find(function(control) return control.kind == "Button" and control.profileID == profile.id end):Fire("OnClick")
FW:DeleteProfile(other.id)
local deleted = assert(FW:CreateProfile("Picker deletion profile", {}))
find(function(control) return control.kind == "Button" and control.profileID == deleted.id end):Fire("OnClick")
swatch:Fire("OnClick")
local deletedSession = modernPicker.info
FW:DeleteProfile(deleted.id)
check(not modernPicker:IsShown(), "deleting a profile closes its picker")
deletedSession.swatchFunc()
deletedSession.cancelFunc()
equal(FW.DB.profiles[deleted.id], nil, "stale callbacks cannot recreate a deleted profile")
equal(profile.color.r, .1, "deletion callbacks cannot recolor the remaining profile")

ColorPickerFrame = nil
local loadedPicker
C_AddOns = { LoadAddOn = function(addon) loadedPicker = addon return false end }
local beforeUnavailable = profile.color.r
check(pcall(swatch.Fire, swatch, "OnClick"), "missing native picker is handled without Lua errors")
equal(loadedPicker, "Blizzard_ColorPickerFrame", "missing picker uses the correct native addon loader")
equal(profile.color.r, beforeUnavailable, "missing picker leaves saved colors intact")
C_AddOns.LoadAddOn = function(addon) loadedPicker = addon ColorPickerFrame = modernPicker return true end
swatch:Fire("OnClick")
check(modernPicker:IsShown(), "native picker can be loaded when its addon is unavailable initially")
modernPicker:Hide()
modernPicker.info.cancelFunc()
C_AddOns = nil

local legacyPicker = widget("ColorSelect", nil, UIParent)
legacyPicker:Hide()
function legacyPicker:GetColorRGB() return table.unpack(self.rgb) end
function legacyPicker:SetColorRGB(r, g, b)
    self.rgb = { r, g, b }
    if self.func then self.func() end
end
ColorPickerFrame = legacyPicker
userText(color, "#FEDCBA")
swatch:Fire("OnClick")
check(legacyPicker:IsShown(), "older picker API has a guarded compatibility path")
equal(color:GetText(), "#FEDCBA", "legacy initial RGB callback preserves HEX drafts")
equal(legacyPicker.hasOpacity, false, "legacy picker disables opacity")
legacyPicker:SetColorRGB(.2, .4, .6)
equal(profile.color.r, .2, "legacy picker saves changes")
equal(color:GetText(), "#336699", "legacy picker updates HEX")
legacyPicker:Hide()
legacyPicker.cancelFunc(legacyPicker.previousValues)
equal(profile.color.r, .1, "legacy Cancel restores the original saved color")
equal(color:GetText(), "#FEDCBA", "legacy Cancel restores the HEX draft")
equal(profile.revision, pickerRevision, "all picker paths leave stat-score revisions unchanged")

swatch:Fire("OnClick")
legacyPicker:SetColorRGB(.4, .5, .6)
local staleLegacySwatch, staleLegacyCancel = legacyPicker.func, legacyPicker.cancelFunc
-- An older addon replaces active func/cancelFunc, leaving unused swatchFunc.
legacyPicker.func, legacyPicker.cancelFunc = function() end, function() end
staleLegacyCancel()
equal(profile.color.r, .4, "foreign legacy picker ownership prevents stale cancellation")
FW.UI:Hide()
check(legacyPicker:IsShown(), "closing the editor does not hide another addon's legacy picker")
equal(profile.color.r, .4, "foreign picker replacement keeps the last saved profile color")
legacyPicker.rgb = { .8, .8, .8 }
staleLegacySwatch()
equal(profile.color.r, .4, "foreign legacy picker callbacks cannot save another color")
FW.UI:Show()

ColorPickerFrame = modernPicker
swatch:Fire("OnClick")
modernPicker.rgb = { .3, .6, .9 }
modernPicker.info.swatchFunc()
local staleModern = modernPicker.info
modernPicker.swatchFunc, modernPicker.cancelFunc = function() end, function() end
staleModern.cancelFunc()
equal(profile.color.r, .3, "foreign modern picker ownership prevents stale cancellation")
FW.UI:Hide()
check(modernPicker:IsShown(), "closing the editor does not hide another addon's modern picker")
modernPicker.rgb = { .8, .8, .8 }
staleModern.swatchFunc()
equal(profile.color.r, .3, "foreign modern picker callbacks cannot save another color")
FW.UI:Show()

local brokenPicker = widget("Frame", nil, UIParent)
brokenPicker:Hide()
brokenPicker.GetColorRGB = modernPicker.GetColorRGB
brokenPicker.SetupColorPickerAndShow = function() error("unsupported picker setup") end
ColorPickerFrame = brokenPicker
check(pcall(swatch.Fire, swatch, "OnClick"), "native picker setup errors are handled without a Lua error")
equal(profile.color.r, .3, "failed native picker setup preserves saved colors")
ColorPickerFrame = modernPicker

local iconControl = find(function(control) return control.isProfileIcon end)
equal(profile.icon, nil, "profile icons are optional by default")
check(not iconControl.children[1]:IsShown(), "a profile without an icon has no preview texture")
local profileRow = find(function(control) return control.kind == "Button" and control.profileID == profile.id end)
local _, _, _, noIconOffset = profileRow.name:GetPoint()
equal(noIconOffset, 29, "profiles without icons keep the original name alignment")
userText(name, "Icon draft name")
userText(color, "#AABBCC")
userText(strength, "9.5")
local iconRevision, savedName, savedWeight = profile.revision, profile.name, profile.weights.strength
local catalogAPIs = { GetLooseMacroIcons, GetMacroIcons, GetLooseMacroItemIcons, GetMacroItemIcons }
GetLooseMacroIcons, GetMacroIcons, GetLooseMacroItemIcons, GetMacroItemIcons = nil, nil, nil, nil
check(pcall(iconControl.Fire, iconControl, "OnClick"), "missing game icon APIs do not raise Lua errors")
local emptyCell = find(function(control) return control.isProfileIconChoice end)
check(not emptyCell:IsShown(), "unavailable game catalogs leave no invalid texture choices")
emptyCell.parent.done:Fire("OnClick")
GetLooseMacroIcons, GetMacroIcons, GetLooseMacroItemIcons, GetMacroItemIcons = table.unpack(catalogAPIs)
local spellCatalogCalls = 0
UnitClass = function() return "Paladin", "PALADIN" end
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() spellCatalogCalls = spellCatalogCalls + 1 return 2 end,
    GetSpellBookSkillLineInfo = function(index)
        if index == 1 then return { name = "General", itemIndexOffset = 0, numSpellBookItems = 0 } end
        return { name = "Holy", iconID = 135920, itemIndexOffset = 0, numSpellBookItems = 1 }
    end,
    GetSpellBookItemInfo = function() return { name = "Holy Light", subName = "Rank 1", iconID = 135920, spellID = 635 } end,
    GetSpellBookItemDescription = function() return "Heals a friendly target" end,
}
iconControl:Fire("OnClick")
local iconCell = find(function(control) return control.isProfileIconChoice end)
local iconDialog = iconCell.parent
check(iconDialog:IsShown(), "icon control opens a game icon picker")
equal(catalogCalls, 4, "opening the picker lazily enumerates spell and item icons")
equal(#iconDialog.cells, 48, "picker creates only one reusable page of icon buttons")
equal(iconCell.entry.category, "playerClass", "the player's class icons are shown first")
equal(#iconDialog.categories, 5, "picker offers All and four native icon categories")
check(not iconDialog.categories[1].enabled, "All is selected when opening the picker")
local allEntries = FW:GetProfileIconCatalog()
local firstCategory, lastCategory = {}, nil
for _, entry in ipairs(allEntries) do
    if lastCategory ~= entry.category then
        check(not firstCategory[entry.category], "icons in each category form one ordered group")
        firstCategory[entry.category], lastCategory = true, entry.category
    end
end
local selectedFirstIcon = iconCell.iconValue
equal(iconDialog.page:GetText(), "1 / 3", "catalog pages include game spell and item icons")
check(not iconDialog.previous.enabled and iconDialog.next.enabled, "first page enables only forward navigation")
iconCell:Fire("OnClick")
equal(profile.icon, selectedFirstIcon, "choosing a game icon saves it immediately")
check(not iconDialog:IsShown(), "choosing an icon closes its picker")
equal(iconControl.children[1].texture, profile.icon, "selected icon appears beside profile color")
check(iconControl.children[1]:IsShown(), "selected icon preview is visible")
equal(profileRow.icon.texture, profile.icon, "profile list displays its selected icon")
check(profileRow.icon:IsShown(), "profile list icon is visible")
local _, _, _, withIconOffset = profileRow.name:GetPoint()
equal(withIconOffset, 53, "profile names leave space for an optional icon")
equal(name:GetText(), "Icon draft name", "icon changes preserve unsaved profile names")
equal(color:GetText(), "#AABBCC", "icon changes preserve unsaved HEX colors")
equal(strength:GetText(), "9.5", "icon changes preserve unsaved weights")
equal(profile.name, savedName, "icon changes do not apply draft names")
equal(profile.weights.strength, savedWeight, "icon changes do not apply draft weights")
equal(profile.revision, iconRevision, "icon changes do not invalidate score revisions")
local iconWidgets = #widgets
iconControl:Fire("OnClick")
equal(#widgets, iconWidgets, "reopening the icon picker reuses all widgets")
equal(catalogCalls, 4, "reopening the picker reuses the native catalog")
local initialSpellCatalogCalls = spellCatalogCalls
check(iconCell.selected:IsShown(), "picker marks the saved icon")
iconDialog.next:Fire("OnClick")
equal(iconDialog.page:GetText(), "2 / 3", "next page changes the visible icon range")
equal(iconCell.iconValue, allEntries[49].icon, "next page reuses icon cells with the next textures")
iconDialog:Fire("OnMouseWheel", -1)
equal(iconDialog.page:GetText(), "3 / 3", "mouse wheel can browse pages")
check(not iconDialog.next.enabled, "last page disables forward navigation")
local lastPageCount = #allEntries - 96
equal(iconDialog.cells[lastPageCount].iconValue, allEntries[#allEntries].icon, "last page includes the final native item icon")
check(not iconDialog.cells[lastPageCount + 1]:IsShown(), "last page hides cells beyond the catalog")
iconDialog:Fire("OnMouseWheel", -1)
equal(iconDialog.page:GetText(), "3 / 3", "wheel navigation stays within available pages")
userText(iconDialog.search, "inv_chest")
equal(iconCell.iconValue, "Interface\\Icons\\INV_Chest_Plate01", "name search finds native item icons")
check(not iconDialog.cells[2]:IsShown(), "case-insensitive duplicate paths are displayed once")
userText(iconDialog.search, "liGh")
equal(iconCell.iconValue, 135920, "partial localized spell names find numeric texture icons")
userText(iconDialog.search, "friendly target")
equal(iconCell.iconValue, 135920, "search finds words from native spell descriptions")
userText(iconDialog.search, "rank 1")
equal(iconCell.iconValue, 135920, "search includes spell rank metadata")
userText(iconDialog.search, "635")
equal(iconCell.iconValue, 135920, "search includes spell IDs as well as texture IDs")
local iconTooltipOwner, iconTooltipTitle, iconTooltipLines = nil, nil, {}
GameTooltip.SetOwner = function(_, owner) iconTooltipOwner = owner end
GameTooltip.SetText = function(_, text) iconTooltipTitle = text end
GameTooltip.AddLine = function(_, text) iconTooltipLines[#iconTooltipLines + 1] = text end
iconCell:Fire("OnEnter")
equal(iconTooltipOwner, iconCell, "the hovered icon owns its tooltip")
check(iconTooltipTitle:find("Holy Light", 1, true) ~= nil, "icon tooltips identify native spell names")
check(#iconTooltipLines >= 2, "icon tooltips include category and source details")
userText(iconDialog.search, "")
iconDialog.categories[4]:Fire("OnClick")
check(not iconDialog.categories[4].enabled and iconDialog.categories[1].enabled, "selecting Items updates the category selection")
equal(iconCell.entry.category, "items", "the Items category shows only item catalog entries")
userText(iconDialog.search, "light")
check(not iconCell:IsShown(), "search respects the chosen category")
iconDialog.categories[2]:Fire("OnClick")
equal(iconCell.iconValue, 135920, "switching categories retains the text query")
iconDialog.categories[1]:Fire("OnClick")
equal(catalogCalls, 4, "typing and changing categories never rebuilds the native catalog")
equal(spellCatalogCalls, initialSpellCatalogCalls, "typing and category changes never rescan the spellbook")
userText(iconDialog.search, "200099")
equal(iconCell.iconValue, 200099, "texture file IDs can be searched")
userText(iconDialog.search, "not an icon")
check(not iconCell:IsShown(), "a search with no matches hides icon cells")
userText(iconDialog.search, "135920")
iconCell:Fire("OnClick")
equal(profile.icon, 135920, "picker saves native numeric texture IDs")
iconControl:Fire("OnClick")
userText(iconDialog.search, "inv_chest")
iconCell:Fire("OnClick")
equal(profile.icon, "Interface\\Icons\\INV_Chest_Plate01", "item category textures can be saved as profile icons")
iconControl:Fire("OnClick")
equal(iconCell.entry.category, "playerClass", "reopening starts with the player's class even when an item icon is saved")
check(not iconDialog.categories[1].enabled, "reopening resets category browsing to All")
iconDialog.none:Fire("OnClick")
equal(profile.icon, nil, "None removes the saved profile icon")
check(not profileRow.icon:IsShown(), "clearing an icon hides it in the profile list")
local _, _, _, restoredOffset = profileRow.name:GetPoint()
equal(restoredOffset, 29, "clearing an icon restores the original name alignment")
equal(profile.revision, iconRevision, "removing an icon leaves score revisions unchanged")
iconControl:Fire("OnClick")
local staleIconClick, staleNoneClick = iconCell:GetScript("OnClick"), iconDialog.none:GetScript("OnClick")
local iconOther = assert(FW:CreateProfile("Icon other profile", {}))
find(function(control) return control.kind == "Button" and control.profileID == iconOther.id end):Fire("OnClick")
check(not iconDialog:IsShown(), "switching profiles closes the previous icon picker")
iconControl:Fire("OnClick")
staleIconClick()
staleNoneClick()
equal(iconOther.icon, nil, "stale icon callbacks cannot modify another profile")
iconDialog.done:Fire("OnClick")
find(function(control) return control.kind == "Button" and control.profileID == profile.id end):Fire("OnClick")
FW:DeleteProfile(iconOther.id)
local iconDeleted = assert(FW:CreateProfile("Icon deletion profile", {}))
find(function(control) return control.kind == "Button" and control.profileID == iconDeleted.id end):Fire("OnClick")
iconControl:Fire("OnClick")
local deletedIconClick = iconCell:GetScript("OnClick")
FW:DeleteProfile(iconDeleted.id)
check(not iconDialog:IsShown(), "deleting a profile closes its icon picker")
deletedIconClick()
equal(FW.DB.profiles[iconDeleted.id], nil, "stale icon callbacks cannot recreate deleted profiles")
iconControl:Fire("OnClick")
FW.UI:Hide()
check(not iconDialog:IsShown(), "closing the editor closes its icon picker")
FW:ShowUI()
equal(catalogCalls, 4, "profile and editor refreshes do not reload the icon catalog")

-- Weight calculators read the current draft and require the normal Apply action.
UnitLevel = function() return 29 end
UnitStat = function() return 100, 100, 0, 0 end
local talentRank, strengthTalentRank, intellectTalentRank = 3, 0, 0
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = { GetNodeInfo = function(_, node)
    return { activeRank = node == 110871 and talentRank or node == 105328 and strengthTalentRank or node == 105332 and intellectTalentRank or 0 }
end }
local function gear(key)
    return find(function(control) return control.isDerivedWeight and control.statKey == key end)
end
local calculationProfile = assert(FW:CreateProfile("Calculated profile", {}))
find(function(control) return control.kind == "Button" and control.profileID == calculationProfile.id end):Fire("OnClick")
userText(weightBox("Attack power"), "3")
userText(weightBox("Block value"), "4")
local calculatorLines, calculatorDoubleLines, calculatorWidths = {}, {}, {}
local calculationTooltipOwner, calculationTooltipHides
GameTooltip.SetOwner = function(_, owner) calculationTooltipOwner = owner end
GameTooltip.GetOwner = function() return calculationTooltipOwner end
GameTooltip.IsOwned = function(_, owner) return calculationTooltipOwner == owner end
GameTooltip.Hide = function() calculationTooltipHides = (calculationTooltipHides or 0) + 1 end
GameTooltip.SetText = function(_, title) tooltipTitle = title calculatorLines, calculatorDoubleLines = {}, {} end
GameTooltip.AddLine = function(_, line) calculatorLines[#calculatorLines + 1] = line end
GameTooltip.AddDoubleLine = function(_, left, right, ...)
    calculatorLines[#calculatorLines + 1] = left .. ": " .. right
    calculatorDoubleLines[#calculatorDoubleLines + 1] = { left = left, right = right, colors = { ... } }
end
GameTooltip.SetMinimumWidth = function(_, width, reflow) calculatorWidths[#calculatorWidths + 1] = { width, reflow } end
local function sourceHighlighted(text)
    local box = weightBox(text)
    local row, outline = box.parent.zvCalculationSourceHighlight, box.zvCalculationSourceOutline
    return row and row:IsShown() and outline and outline:IsShown() or false
end
local attackBox = weightBox("Attack power")
local attackLabel = attackBox.parent.children[1]
local originalAttackColor = { attackLabel:GetTextColor() }
attackLabel:SetTextColor(0.2, 0.3, 0.4, 0.7)
local draftAttack, draftFocus, draftScroll = attackBox:GetText(), attackBox.focused, ZwykValuesStatsScroll:GetVerticalScroll()
local actualCalculation, hoverCalculations = FW.GetDerivedWeightOptions, 0
FW.GetDerivedWeightOptions = function(self, ...)
    hoverCalculations = hoverCalculations + 1
    return actualCalculation(self, ...)
end
gear("strength"):Fire("OnEnter")
FW.GetDerivedWeightOptions = actualCalculation
equal(hoverCalculations, 1, "highlighting reuses the existing hover calculation")
check(sourceHighlighted("Attack power") and sourceHighlighted("Block value"), "Strength hover highlights its source rows and numeric fields")
check(not sourceHighlighted("Intellect") and not sourceHighlighted("Strength"), "Strength hover leaves unrelated and target fields unchanged")
equal(attackBox:GetText(), draftAttack, "hover highlighting preserves draft text")
equal(attackBox.focused, draftFocus, "hover highlighting does not move keyboard focus")
equal(ZwykValuesStatsScroll:GetVerticalScroll(), draftScroll, "hover highlighting does not scroll the editor")
equal(tooltipTitle, "Calculate Strength", "gear tooltip identifies the target attribute")
check(table.concat(calculatorLines, "\n"):lower():find("paladin", 1, true), "gear tooltip includes player class")
check(table.concat(calculatorLines, "\n"):find("29", 1, true), "gear tooltip includes player level")
check(table.concat(calculatorLines, "\n"):find("Attack power", 1, true), "gear tooltip names the input weights")
equal(calculatorWidths[#calculatorWidths][1], 400, "calculation tooltip uses a spacious fixed minimum width")
equal(calculatorWidths[#calculatorWidths][2], true, "calculation tooltip reflows wrapped text to its width")
local calculatedCount, footerCount = 0, 0
for _, line in ipairs(calculatorLines) do
    if line:find("Calculated weight", 1, true) then calculatedCount = calculatedCount + 1 end
    if line:find("Click", 1, true) then footerCount = footerCount + 1 end
end
equal(calculatedCount, 1, "calculation tooltip shows its result once")
equal(footerCount, 1, "calculation tooltip gives one short action footer")
check(#calculatorDoubleLines >= 2, "calculation tooltip aligns input formulas and the result in separate columns")
check(table.concat(calculatorLines, "\n"):find("From your weights", 1, true), "calculation tooltip separates source weights from prose")
check(table.concat(calculatorLines, "\n"):find("Formula", 1, true), "calculation tooltip gives the formula its own section")
check(not table.concat(calculatorLines, "\n"):find("Data source", 1, true), "calculation tooltip omits data sources")
check(not table.concat(calculatorLines, "\n"):find("Assumptions", 1, true), "calculation tooltip omits general assumptions")
check(table.concat(calculatorLines, "\n"):find("Modifiers", 1, true), "calculation tooltip groups relevant modifiers")
local resultColumn
for _, columns in ipairs(calculatorDoubleLines) do if columns.left == "Calculated weight" then resultColumn = columns end end
check(resultColumn and resultColumn.colors[2] > resultColumn.colors[1], "calculation tooltip highlights the final result in green")
gear("strength"):Fire("OnLeave")
check(not sourceHighlighted("Attack power") and not sourceHighlighted("Block value"), "leaving the cog clears source highlights")
equal(attackLabel.color[1], 0.2, "source highlight restores the original label color")
equal(attackLabel.color[4], 0.7, "source highlight preserves the original label alpha")
attackLabel:SetTextColor(table.unpack(originalAttackColor))
equal(calculatorWidths[#calculatorWidths][1], 0, "leaving a calculation gear restores the shared tooltip width")
equal(calculatorWidths[#calculatorWidths][2], false, "width cleanup releases forced wrapping")
userText(attackBox, "0")
gear("strength"):Fire("OnEnter")
check(sourceHighlighted("Attack power"), "zero-weight source inputs are still highlighted")
do
    local meleeCritBox, spellCritBox = weightBox("Melee critical strike (%)"), weightBox("Spell critical strike (%)")
    local function contribution(label)
        for _, columns in ipairs(calculatorDoubleLines) do if columns.left == label then return columns.right end end
    end
    userText(meleeCritBox, "2")
    userText(spellCritBox, "7")
    gear("agility"):Fire("OnEnter")
    check(sourceHighlighted("Melee critical strike (%)") and not sourceHighlighted("Spell critical strike (%)"), "Agility highlights only the melee critical-strike input")
    check(contribution("Melee critical strike") and contribution("Melee critical strike"):find("x 2", 1, true), "Agility calculation uses the melee critical-strike draft weight")
    equal(contribution("Spell critical strike"), nil, "Agility does not calculate with the spell critical-strike weight")
    gear("intellect"):Fire("OnEnter")
    check(sourceHighlighted("Spell critical strike (%)") and not sourceHighlighted("Melee critical strike (%)"), "Intellect highlights only the spell critical-strike input")
    check(contribution("Spell critical strike") and contribution("Spell critical strike"):find("x 7", 1, true), "Intellect calculation uses the spell critical-strike draft weight")
    equal(contribution("Melee critical strike"), nil, "Intellect does not calculate with the melee critical-strike weight")
    userText(meleeCritBox, "0")
    userText(spellCritBox, "0")
end
gear("mana"):Fire("OnEnter")
check(sourceHighlighted("Intellect") and sourceHighlighted("Spell critical strike (%)"), "Mana hover highlights each modeled inverse input")
check(not sourceHighlighted("Melee critical strike (%)"), "Mana inverse calculation leaves melee critical strike unhighlighted")
check(not sourceHighlighted("Attack power") and not sourceHighlighted("Block value"), "switching cogs replaces earlier highlights")
local actualUnitClass = UnitClass
UnitClass = function() return "Rogue", "ROGUE" end
gear("strength"):Fire("OnEnter")
check(sourceHighlighted("Attack power") and not sourceHighlighted("Block value"), "highlighted dependencies follow the current player class")
UnitClass = actualUnitClass
gear("strength"):Fire("OnLeave")
local oldUnitArmor, oldPaperDoll = UnitArmor, C_PaperDollInfo
UnitArmor = function() return 1000, 1000 end
C_PaperDollInfo = { GetArmorEffectiveness = function() return 0.75 end }
gear("armor"):Fire("OnEnter")
check(sourceHighlighted("Dodge (%)"), "an explicitly listed zero-rate input remains highlighted at the Armor cap")
gear("armor"):Fire("OnLeave")
UnitArmor, C_PaperDollInfo = oldUnitArmor, oldPaperDoll
userText(attackBox, "3")
gear("strength"):Fire("OnEnter")
find(function(control) return control.kind == "Button" and control.profileID == profile.id end):Fire("OnClick")
check(not sourceHighlighted("Attack power"), "changing profiles clears source highlights")
find(function(control) return control.kind == "Button" and control.profileID == calculationProfile.id end):Fire("OnClick")
userText(attackBox, "3")
userText(weightBox("Block value"), "4")
gear("strength"):Fire("OnEnter")
local stolenWidths, stolenHides = #calculatorWidths, calculationTooltipHides
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
gear("strength"):Fire("OnHide")
check(not sourceHighlighted("Attack power"), "source highlights clear even when another addon owns the tooltip")
equal(#calculatorWidths, stolenWidths, "gear cleanup leaves another tooltip owner's layout alone")
equal(calculationTooltipHides, stolenHides, "gear cleanup never hides another owner's tooltip")
gear("strength"):Fire("OnClick")
local calculationDialog = ZwykValuesWeightCalculation
check(calculationDialog and calculationDialog:IsShown(), "primary attribute gear opens the bonus prompt")
check(calculationDialog.toggles.kings:IsShown() and not calculationDialog.toggles.kings:GetChecked(), "primary bonus prompt offers optional Kings disabled by default")
equal(calculationDialog.toggles.useTalents, nil, "rank sliders replace the talent checkbox")
local strengthRanks = calculationDialog.talentRows["105328"]
equal(strengthRanks:GetValue(), 0, "rank slider defaults to the current talent rank")
equal(strengthRanks.minValue, 0, "talent slider includes rank zero")
equal(strengthRanks.maxValue, 5, "Divine Strength slider includes every valid rank")
check(not calculationDialog.sliders[1]:IsShown() and not calculationDialog.sliders[2]:IsShown(), "primary bonus prompt omits regeneration ratios")
calculationDialog.use:Fire("OnClick")
check(math.abs(tonumber(strength:GetText()) - 6.2) < 0.000001, "gear calculates from unsaved source weights")
equal(calculationProfile.weights.strength, 0, "gear leaves saved weights unchanged")
FW:RefreshUI()
check(math.abs(tonumber(strength:GetText()) - 6.2) < 0.000001, "refresh preserves the calculated draft")
click("Apply weights")
equal(calculationProfile.calculationOptions.talentRanks, nil, "using current ranks never saves detected ranks as overrides")
strengthTalentRank = 3
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 3, "reopening reads the changed current talent rank")
check(strengthRanks.caption:GetText():find("Divine Strength: 3/5", 1, true), "rank caption identifies the selected talent and rank")
calculationDialog.toggles.kings:SetChecked(true)
calculationDialog.toggles.kings:Fire("OnClick")
calculationDialog.use:Fire("OnClick")
check(math.abs(tonumber(strength:GetText()) - 7.2292) < 0.000001, "primary bonus prompt applies Kings and current talents once")
equal(calculationProfile.calculationOptions.kings, false, "accepted stat bonuses remain draft settings")
equal(calculationProfile.calculationOptions.talentRanks, nil, "accepting current talents does not latch their ranks")
strengthTalentRank = 4
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 4, "accepted automatic ranks continue following current talents")
check(calculationDialog.toggles.kings:GetChecked(), "reopening the bonus prompt retains the draft Kings setting")
calculationDialog.toggles.kings:SetChecked(false)
calculationDialog.toggles.kings:Fire("OnClick")
strengthRanks:SetValue(0)
calculationDialog.use:Fire("OnClick")
check(math.abs(tonumber(strength:GetText()) - 6.2) < 0.000001, "rank zero restores the base conversion")
strengthTalentRank = 5
gear("strength"):Fire("OnClick")
check(not calculationDialog.toggles.kings:GetChecked() and strengthRanks:GetValue() == 0, "manual rank zero survives draft refreshes")
check(strengthRanks.current:GetText():find("5/5", 1, true), "manual rank slider also shows the current default")
strengthRanks:SetValue(2)
calculationDialog.cancel:Fire("OnClick")
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 0, "Cancel discards an unaccepted rank change")
calculationDialog.currentTalents:Fire("OnClick")
equal(strengthRanks:GetValue(), 5, "Use current talents restores the live rank")
calculationDialog.use:Fire("OnClick")
strengthTalentRank = 1
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 1, "restored current ranks remain automatic")
strengthRanks:SetValue(0)
calculationDialog.use:Fire("OnClick")
gear("strength"):Fire("OnClick")
calculationDialog.cancel:Fire("OnClick")
gear("dps"):Fire("OnClick")
equal(tonumber(weightBox("Melee weapon DPS"):GetText()), 42, "melee DPS gear uses the draft attack power weight")
userText(weightBox("Intellect"), "45")
local actualTraitInfo = C_Traits.GetNodeInfo
C_Traits.GetNodeInfo = function(config, node) if node ~= 105332 then return actualTraitInfo(config, node) end end
gear("mana"):Fire("OnClick")
check(calculationDialog:IsShown() and calculationDialog.toggles.kings:IsShown(), "Mana inverse calculation opens the stat bonus prompt")
local intellectRanks = calculationDialog.talentRows["105332"]
check(intellectRanks:IsShown() and intellectRanks.current:GetText():find("unavailable", 1, true), "Mana rank slider allows an unreadable current rank")
check(not calculationDialog.use.enabled, "unreadable current talent rank initially leaves the calculation unavailable")
intellectRanks:SetValue(2)
check(calculationDialog.use.enabled, "choosing a manual rank restores an unavailable calculation")
intellectRanks:SetValue(0)
intellectRanks:Fire("OnMouseUp")
calculationDialog.use:Fire("OnClick")
equal(tonumber(weightBox("Mana"):GetText()), 3, "Mana gear fills the inverse Intellect conversion")
C_Traits.GetNodeInfo = actualTraitInfo
userText(weightBox("Intellect"), "0")
userText(weightBox("Spell critical strike (%)"), "10")
gear("mana"):Fire("OnEnter")
check(table.concat(calculatorLines, "\n"):find("Intellect breakdown", 1, true), "Mana explains its inputs in Intellect units")
local critDeduction, intellectInput
for _, columns in ipairs(calculatorDoubleLines) do
    if columns.left == "Less Spell critical strike" then critDeduction = columns.right end
    if columns.left == "Intellect" then intellectInput = columns.right end
end
check(critDeduction and not critDeduction:match("^-"), "Mana presents Crit as a deduction with a positive rate")
check(intellectInput and intellectInput:match("^1 x 0"), "Mana displays the original Intellect weight before converting units")
gear("mana"):Fire("OnClick")
check(not calculationDialog.use.enabled, "inconsistent Intellect and Crit weights cannot fill a negative inferred Mana weight")
check(calculationDialog.details:GetText():find("exceed the Intellect weight", 1, true), "Mana explains why an inconsistent weight cannot be inferred")
check(not calculationDialog.details:GetText():find("Data source", 1, true) and not calculationDialog.details:GetText():find("Assumptions", 1, true), "calculation prompts omit sources and general assumptions too")
calculationDialog.cancel:Fire("OnClick")
userText(weightBox("Intellect"), "45")
userText(weightBox("Spell critical strike (%)"), "0")
local spirit, mp5 = weightBox("Spirit"), weightBox("Mana per 5 seconds")
userText(mp5, "4")
gear("spirit"):Fire("OnClick")
check(calculationDialog:IsShown(), "Spirit gear opens a regeneration prompt")
check(not calculationDialog.sliders[1]:IsShown(), "Spirit prompt omits combat share")
equal(calculationDialog.sliders[2]:GetValue(), 80, "Spirit prompt starts with a visible casting assumption")
equal(calculationDialog.sliders[3]:GetValue(), 30, "Spirit prompt defaults from current Reverence talent rank")
calculationDialog.cancel:Fire("OnClick")
talentRank = 1
gear("spirit"):Fire("OnClick")
equal(calculationDialog.sliders[3]:GetValue(), 10, "opening an unsaved prompt reads current talents again")
calculationDialog.cancel:Fire("OnClick")
talentRank = 3
gear("spirit"):Fire("OnClick")
calculationDialog.sliders[2]:SetValue(100)
calculationDialog.sliders[3]:SetValue(30)
check(calculationDialog.use.enabled, "valid regeneration ratios allow using the result")
calculationDialog.use:Fire("OnClick")
check(not calculationDialog:IsShown(), "using the calculated weight closes its prompt")
check(math.abs(tonumber(spirit:GetText()) - 0.75) < 0.000001, "Spirit draft includes the selected casting regeneration ratio")
equal(calculationProfile.calculationOptions.castingShare, nil, "regeneration assumptions stay unsaved until Apply")
equal(calculationProfile.weights.spirit, 0, "Spirit calculation is a draft")
gear("spirit"):Fire("OnClick")
equal(calculationDialog.sliders[2]:GetValue(), 100, "reopening keeps the draft casting assumption")
equal(calculationDialog.sliders[3]:GetValue(), 30, "reopening keeps the draft regeneration assumption")
calculationDialog.sliders[3]:SetValue(55)
calculationDialog.cancel:Fire("OnClick")
gear("mp5"):Fire("OnClick")
check(calculationDialog.sliders[1]:IsShown(), "MP5 prompt includes combat share")
equal(calculationDialog.sliders[3]:GetValue(), 30, "Cancel discards unaccepted ratio edits")
calculationDialog.sliders[1]:SetValue(100)
calculationDialog.sliders[2]:SetValue(100)
calculationDialog.sliders[3]:SetValue(0)
check(not calculationDialog.use.enabled, "zero Spirit regeneration disables inverse MP5 calculation")
check(calculationDialog.details:GetText():find("Spirit gives no mana", 1, true), "unavailable inverse result explains the zero denominator")
calculationDialog.sliders[1]:SetValue(0)
check(calculationDialog.use.enabled, "changing combat ratio can restore the MP5 calculation")
calculationDialog.use:Fire("OnClick")
check(math.abs(tonumber(mp5:GetText()) - 1.2) < 0.000001, "MP5 draft uses the explicit out-of-combat ratio")
click("Apply weights")
check(math.abs(calculationProfile.weights.strength - 6.2) < 0.000001, "Apply saves calculated attribute weights")
check(math.abs(calculationProfile.weights.spirit - 0.75) < 0.000001, "Apply saves calculated regeneration weights")
equal(calculationProfile.calculationOptions.combatShare, 0, "Apply saves chosen combat ratio")
equal(calculationProfile.calculationOptions.castingShare, 1, "Apply saves chosen casting ratio")
equal(calculationProfile.calculationOptions.whileCastingRegen, 0, "Apply saves chosen retained regeneration")
equal(calculationProfile.calculationOptions.kings, false, "Apply preserves an explicitly disabled Kings bonus")
equal(calculationProfile.calculationOptions.talentRanks["105328"], 0, "Apply saves manually selected Strength rank zero")
equal(calculationProfile.calculationOptions.talentRanks["105332"], 0, "Apply saves manually selected Intellect rank zero")
local savedRankMap = calculationProfile.calculationOptions.talentRanks
gear("strength"):Fire("OnClick")
strengthRanks:SetValue(4)
calculationDialog.cancel:Fire("OnClick")
equal(calculationProfile.calculationOptions.talentRanks, savedRankMap, "Cancel preserves the saved rank-map object")
equal(savedRankMap["105328"], 0, "Cancel cannot mutate a saved manual rank")
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 0, "a cancelled slider edit does not mutate an earlier accepted draft")
calculationDialog.currentTalents:Fire("OnClick")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(calculationProfile.calculationOptions.talentRanks["105328"], nil, "restoring current talents removes the shown manual override")
equal(calculationProfile.calculationOptions.talentRanks["105332"], 0, "restoring current talents preserves other stat overrides")
assert(FW:UpdateProfile(calculationProfile.id, { calculationOptions = { useTalents = false } }))
gear("strength"):Fire("OnClick")
equal(strengthRanks:GetValue(), 0, "legacy disabled talent settings display rank zero")
check(calculationDialog.currentTalents.enabled, "legacy disabled settings offer an explicit return to current talents")
strengthRanks:SetValue(3)
check(calculationDialog.use.enabled, "manual ranks work while legacy automatic talents are disabled")
calculationDialog.cancel:Fire("OnClick")
gear("strength"):Fire("OnClick")
calculationDialog.currentTalents:Fire("OnClick")
equal(strengthRanks:GetValue(), strengthTalentRank, "Use current talents explicitly restores automatic legacy settings")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(calculationProfile.calculationOptions.useTalents, true, "Apply saves the explicit return to automatic talents")
equal(calculationProfile.calculationOptions.talentRanks["105328"], nil, "restoring automatic mode never saves the detected rank")

-- Conversion talents use the same rank controls and expose their extra inputs.
local conversionClass, conversionTraits, conversionBuild = UnitClass, C_Traits.GetNodeInfo, GetBuildInfo
local championRank, carefulAimRank = 2, 3
UnitClass = function() return "Paladin", "PALADIN" end
GetBuildInfo = function() return "1.60.1", "70425", "Oct 17 2026", 16001 end
C_Traits.GetNodeInfo = function(config, node)
    if node == 110882 then return { activeRank = championRank } end
    if node == 105332 then return { activeRank = 2 } end
    if node == 105008 then return { activeRank = carefulAimRank } end
    return conversionTraits(config, node)
end
local conversionProfile = assert(FW:CreateProfile("Conversion controls", { mana = 1, spellDamage = 2, healing = 100, intellect = 100 }))
find(function(control) return control.kind == "Button" and control.profileID == conversionProfile.id end):Fire("OnClick")
gear("intellect"):Fire("OnEnter")
check(sourceHighlighted("Spell damage") and not sourceHighlighted("Healing"), "Paladin Intellect highlights Champion spell damage without healing")
gear("intellect"):Fire("OnClick")
local champion = calculationDialog.talentRows["110882"]
check(champion and champion:IsShown() and intellectRanks:IsShown(), "Intellect prompt shows primary and conversion talents together")
equal(champion.maxValue, 3, "Champion of the Light slider uses its three-rank cap")
equal(champion:GetValue(), 2, "conversion slider defaults to the current Champion rank")
check(#champion.caption:GetText() * champion.caption.fontSize * 0.56 <= champion.caption:GetWidth(), "long conversion talent names fit their selected-rank caption")
check(not champion.caption:GetText():find("->", 1, true), "conversion effects do not crowd the rank caption")
champion:Fire("OnEnter")
check(table.concat(calculatorLines, "\n"):lower():find("spell damage", 1, true), "conversion talent hover explains the human-readable effect")
calculationDialog.toggles.kings:SetChecked(true)
calculationDialog.toggles.kings:Fire("OnClick")
local combinedModifiers = calculationDialog.details:GetText()
check(combinedModifiers:find("Divine Intellect", 1, true) and combinedModifiers:find("Champion of the Light", 1, true) and combinedModifiers:find("Kings", 1, true), "modifier preview includes stat and conversion talents with Kings")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(conversionProfile.calculationOptions.talentRanks, nil, "using current conversion ranks never pins detected ranks")
championRank = 1
gear("intellect"):Fire("OnClick")
equal(champion:GetValue(), 1, "automatic conversion ranks follow current talent changes")
local beforeConversionPreview = calculationDialog.details:GetText()
champion:SetValue(3)
check(calculationDialog.details:GetText() ~= beforeConversionPreview, "manual conversion ranks update the calculation preview")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(conversionProfile.calculationOptions.talentRanks["110882"], 3, "Apply saves an explicit conversion-rank override")
gear("intellect"):Fire("OnClick")
champion:SetValue(0)
calculationDialog.cancel:Fire("OnClick")
equal(conversionProfile.calculationOptions.talentRanks["110882"], 3, "Cancel preserves a saved conversion-rank override")
gear("mana"):Fire("OnEnter")
check(sourceHighlighted("Spell damage") and not sourceHighlighted("Healing"), "inverse Mana highlights the same Paladin conversion input")
local spellDeduction = false
for _, columns in ipairs(calculatorDoubleLines) do if columns.left == "Less Spell damage" then spellDeduction = true end end
check(spellDeduction, "inverse Mana presents the conversion's spell-damage share as a deduction")
gear("intellect"):Fire("OnClick")
calculationDialog.currentTalents:Fire("OnClick")
equal(champion:GetValue(), championRank, "Use current talents restores the live conversion rank")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(conversionProfile.calculationOptions.talentRanks, nil, "restoring current conversion talents clears manual overrides")
UnitClass = function() return "Hunter", "HUNTER" end
userText(weightBox("Attack power"), "4")
userText(weightBox("Ranged attack power"), "5")
gear("intellect"):Fire("OnEnter")
check(sourceHighlighted("Attack power") and sourceHighlighted("Ranged attack power"), "Hunter Intellect highlights both Careful Aim attack-power inputs")
check(not sourceHighlighted("Spell damage"), "changing classes replaces conversion source highlights")
gear("intellect"):Fire("OnClick")
local carefulAim = calculationDialog.talentRows["105008"]
check(carefulAim and carefulAim:IsShown() and not champion:IsShown(), "Hunter prompt replaces Paladin conversion controls")
equal(carefulAim.maxValue, 5, "Careful Aim slider uses its verified rank cap")
equal(carefulAim:GetValue(), 3, "Careful Aim defaults to the current rank")
carefulAim:SetValue(0)
calculationDialog.cancel:Fire("OnClick")
gear("intellect"):Fire("OnClick")
equal(carefulAim:GetValue(), 3, "cancelled Hunter ranks remain automatic")
calculationDialog.use:Fire("OnClick")
click("Apply weights")
equal(conversionProfile.calculationOptions.talentRanks, nil, "Hunter automatic ranks are not saved as manual overrides")
UnitClass, C_Traits.GetNodeInfo, GetBuildInfo = conversionClass, conversionTraits, conversionBuild
FW:DeleteProfile(conversionProfile.id)
find(function(control) return control.kind == "Button" and control.profileID == calculationProfile.id end):Fire("OnClick")

-- Armor compares mitigation at an explicitly selected attacker level.
local effectivePlayerLevel, armorLevels = 31, {}
UnitEffectiveLevel = function() return effectivePlayerLevel end
UnitArmor = function() return 1000, 1000, 1000, 0, 0 end
C_PaperDollInfo = { GetArmorEffectiveness = function(armor, level)
    armorLevels[#armorLevels + 1] = level
    return armor / (armor + level * 100)
end }
userText(weightBox("Dodge (%)"), "10")
local armorBox = weightBox("Base armor")
gear("armor"):Fire("OnEnter")
check(table.concat(calculatorLines, "\n"):find("Click to choose attacker level", 1, true), "Armor tooltip explains its attacker-level prompt")
gear("armor"):Fire("OnLeave")
gear("armor"):Fire("OnClick")
local attackerSelector = calculationDialog.attackerSelector
check(calculationDialog:IsShown() and attackerSelector:IsShown(), "Armor gear opens the attacker-level selector")
check(attackerSelector.choices[3]:GetChecked() and not attackerSelector.choices[0]:GetChecked(), "Armor attacker level defaults to +3")
equal(armorLevels[#armorLevels], 34, "default Armor preview uses effective player level plus three")
check(attackerSelector.choices[0].caption:GetText():find("Level 31", 1, true), "same-level option displays effective player level")
check(attackerSelector.choices[3].caption:GetText():find("Level 34", 1, true), "boss option displays effective player level plus three")
for _, control in pairs(calculationDialog.toggles) do check(not control:IsShown(), "Armor prompt hides stat-bonus checkboxes") end
for _, slider in ipairs(calculationDialog.sliders) do check(not slider:IsShown(), "Armor prompt hides regeneration sliders") end
local bossPreview = calculationDialog.details:GetText()
attackerSelector.choices[0]:SetChecked(true)
attackerSelector.choices[0]:Fire("OnClick")
check(attackerSelector.choices[0]:GetChecked() and not attackerSelector.choices[3]:GetChecked(), "attacker-level choices are mutually exclusive")
equal(armorLevels[#armorLevels], 31, "selecting +0 recalculates with the same-level attacker")
check(calculationDialog.details:GetText() ~= bossPreview, "selecting attacker level updates the visible preview")
calculationDialog.cancel:Fire("OnClick")
equal(calculationProfile.calculationOptions.attackerLevelOffset, nil, "Cancel does not save an attacker-level choice")
equal(tonumber(armorBox:GetText()), 0, "Cancel does not fill the Armor weight")
gear("armor"):Fire("OnClick")
check(attackerSelector.choices[3]:GetChecked(), "Cancel discards the unaccepted attacker-level choice")
attackerSelector.choices[0]:SetChecked(true)
attackerSelector.choices[0]:Fire("OnClick")
calculationDialog.use:Fire("OnClick")
check(tonumber(armorBox:GetText()) > 0, "Use fills the calculated Armor draft")
equal(calculationProfile.weights.armor, 0, "Use leaves saved Armor weights unchanged")
equal(calculationProfile.calculationOptions.attackerLevelOffset, nil, "Use keeps the attacker-level setting as a draft")
effectivePlayerLevel = 32
gear("armor"):Fire("OnClick")
check(attackerSelector.choices[0]:GetChecked(), "reopening keeps an accepted draft attacker-level choice")
equal(armorLevels[#armorLevels], 32, "reopening refreshes the actual player level")
check(attackerSelector.choices[3].caption:GetText():find("Level 35", 1, true), "attacker-level labels refresh after a level change")
calculationDialog.cancel:Fire("OnClick")
click("Apply weights")
equal(calculationProfile.calculationOptions.attackerLevelOffset, 0, "Apply saves an explicitly chosen +0 attacker offset")
check(calculationProfile.weights.armor > 0, "Apply saves the calculated Armor weight")
gear("armor"):Fire("OnClick")
check(attackerSelector.choices[0]:GetChecked(), "saved +0 selection survives reopening")
attackerSelector.choices[3]:SetChecked(true)
attackerSelector.choices[3]:Fire("OnClick")
calculationDialog.cancel:Fire("OnClick")
equal(calculationProfile.calculationOptions.attackerLevelOffset, 0, "Cancel preserves an existing saved attacker offset")
gear("spirit"):Fire("OnClick")
check(not attackerSelector:IsShown(), "reusing the calculation prompt for Spirit hides attacker-level choices")
equal(calculationDialog.sliders[3]:GetValue(), 0, "saved user regeneration overrides talent defaults")
local staleCalculation = calculationDialog.use:GetScript("OnClick")
gear("strength"):Fire("OnEnter")
FW.UI:Hide()
check(not sourceHighlighted("Attack power"), "closing the editor clears source highlights")
check(not calculationDialog:IsShown(), "closing the editor closes the calculation prompt")
FW:ShowUI()

-- The comparison selector preserves draft weights and never replaces an invalid set.
local setAvailable, setLookups = true, 0
local chosenSet = { mode = "set", setID = 7, name = "Spell gear", character = "Player-UI-Test" }
function FW:GetEquipmentSetOptions()
    setLookups = setLookups + 1
    return setAvailable and { { setID = 7, name = chosenSet.name, character = chosenSet.character, icon = 135920, target = chosenSet } } or {},
        not setAvailable and "The selected equipment set was deleted." or nil
end
function FW:GetProfileComparisonContext(candidate)
    local target = candidate and candidate.comparisonTarget
    if not target or target.mode == "equipped" then return { mode = "equipped", label = "Currently equipped" } end
    return { mode = "set", label = "Set: " .. target.name, error = not setAvailable and "The selected equipment set was deleted." or nil }
end
local comparisonButton = byText("Compare: Equipped", "FontString").parent
comparisonButton:Fire("OnClick")
local comparisonDialog = ZwykValuesComparisonPicker
check(comparisonDialog:IsShown(), "comparison button opens the equipment target selector")
equal(setLookups, 1, "opening the selector requests current set choices once")
equal(#comparisonDialog.rows, 2, "selector offers equipped gear and native sets")
userText(strength, "8.75")
comparisonDialog.rows[2]:Fire("OnClick")
equal(calculationProfile.comparisonTarget.setID, 7, "choosing a set saves its native set ID")
equal(calculationProfile.comparisonTarget.character, chosenSet.character, "choosing a set saves its character identity")
equal(strength:GetText(), "8.75", "choosing a comparison target preserves unsaved weights")
equal(comparisonButton.children[1]:GetText(), "Set: Spell gear", "comparison button identifies the selected set")
check(not comparisonDialog:IsShown(), "choosing a target closes the selector")
setAvailable = false
FW:RefreshUI()
equal(comparisonButton.children[1]:GetText(), "Compare: Unavailable", "deleted set is visibly unavailable")
equal(calculationProfile.comparisonTarget.setID, 7, "unavailable set is kept as the selected target")
comparisonButton:Fire("OnClick")
check(comparisonDialog.message:GetText():find("deleted", 1, true), "selector explains why the chosen set is unavailable")
check(not comparisonDialog.rows[2]:IsShown(), "deleted set is absent from current choices")
comparisonDialog.rows[1]:Fire("OnClick")
equal(calculationProfile.comparisonTarget.mode, "equipped", "equipped gear is restored only through an explicit choice")
setAvailable = true
comparisonButton:Fire("OnClick")
local staleComparison = comparisonDialog.rows[2]:GetScript("OnClick")
FW:DeleteProfile(calculationProfile.id)
check(not comparisonDialog:IsShown(), "deleting the selected profile closes its target selector")
staleComparison()
staleCalculation()
equal(profile.weights.strength, 4, "stale calculation callbacks do not change another profile")
equal(profile.comparisonTarget.mode, "equipped", "stale target callbacks do not change another profile")

local debug = find(function(control) return control.optionKey == "debugUnknownStats" end)
check(not debug:GetChecked(), "unknown-stat debug option starts disabled")
debug:SetChecked(true)
local beforeRefresh = tooltipRefreshes
debug:Fire("OnClick")
equal(FW.DB.options.debugUnknownStats, true, "debug checkbox persists the requested option")
equal(tooltipRefreshes, beforeRefresh + 1, "debug toggle refreshes item tooltips")
debug:SetChecked(false)
debug:Fire("OnClick")
equal(FW.DB.options.debugUnknownStats, false, "debug checkbox can disable warnings")

local main = byText("Use this profile", "FontString").parent
local mainName = byText("Upgrade arrows (0)", "FontString")
equal(#FW:GetUpgradeProfiles(), 0, "arrows start with no selected profiles")
check(not main:GetChecked(), "selected profile is not enabled for arrows by default")
local arrowControls = {}
equal(byText("Item windows", "FontString").parent.optionKey, "upgradeBags", "item-window arrows retain the existing bag-arrow preference")
for _, key in ipairs({ "upgradeBags", "upgradeRolls", "upgradeChat" }) do
    local control = find(function(candidate) return candidate.optionKey == key end)
    arrowControls[#arrowControls + 1] = control
    check(not control:GetChecked(), key .. " starts disabled")
    control:SetChecked(true)
    local before = upgradeRefreshes
    control:Fire("OnClick")
    equal(FW.DB.options[key], true, key .. " can be enabled independently")
    equal(upgradeRefreshes, before + 1, key .. " immediately refreshes upgrade indicators")
    equal(#FW:GetUpgradeProfiles(), 0, "location toggles do not implicitly choose upgrade profiles")
end
main:SetChecked(true)
local beforeMainRefresh = upgradeRefreshes
main:Fire("OnClick")
equal(FW:GetUpgradeProfiles()[1], profile, "selected profile can drive upgrade arrows")
equal(mainName:GetText(), "Upgrade arrows (1)", "enabled count appears in upgrade panel")
equal(upgradeRefreshes, beforeMainRefresh + 1, "main selection immediately refreshes arrows")
local active = byText("Active in tooltips", "FontString").parent
active:SetChecked(false)
active:Fire("OnClick")
check(not profile.active, "tooltip visibility can be disabled on the main profile")
equal(FW:GetUpgradeProfiles()[1], profile, "arrow profile remains chosen while inactive in tooltips")
check(main:GetChecked(), "main checkbox stays checked after tooltip visibility changes")

click("Copy")
equal(#FW:GetProfiles(), 2, "copy creates another profile")
local copied = FW:GetProfiles()[2]
equal(copied.weights.strength, 4, "copy retains saved weights")
click("Item filters")
check(not weaponFilter:GetChecked() and not armorFilter:GetChecked() and not otherClasses:GetChecked(), "copied profile keeps original item filters")
weaponFilter:SetChecked(true)
weaponFilter:Fire("OnClick")
equal(copied.itemFilters.weapons["0"], true, "filter edit targets the selected copied profile")
equal(profile.itemFilters.weapons["0"], false, "copied profile filters are independent")
find(function(control) return control.kind == "Button" and control.profileID == profile.id end):Fire("OnClick")
check(not weaponFilter:GetChecked(), "open filter dialog follows a profile selection change")
check(byText("Item filters for " .. profile.name, "FontString"), "filter dialog identifies selected profile")
find(function(control) return control.kind == "Button" and control.profileID == copied.id end):Fire("OnClick")
check(weaponFilter:GetChecked(), "switching back restores the copied profile filter")
click("Done")
check(not main:GetChecked(), "copying a main profile does not designate the copy main")
equal(FW:GetUpgradeProfiles()[1], profile, "copy leaves original arrow activation intact")
main:SetChecked(true)
main:Fire("OnClick")
equal(#FW:GetUpgradeProfiles(), 2, "enabling a second arrow profile retains the first")
equal(FW:GetUpgradeProfiles()[2], copied, "second selected profile drives arrows too")
equal(mainName:GetText(), "Upgrade arrows (2)", "enabled count includes both profiles")
main:SetChecked(false)
main:Fire("OnClick")
equal(#FW:GetUpgradeProfiles(), 1, "checkbox clears only the selected arrow profile")
equal(FW:GetUpgradeProfiles()[1], profile, "clearing a second profile retains the first")
equal(mainName:GetText(), "Upgrade arrows (1)", "enabled count follows independent activation")
for index, key in ipairs({ "upgradeBags", "upgradeRolls", "upgradeChat" }) do
    equal(FW.DB.options[key], true, "clearing main preserves " .. key .. " preference")
    arrowControls[index]:SetChecked(false)
    arrowControls[index]:Fire("OnClick")
    equal(FW.DB.options[key], false, key .. " can be independently disabled")
end
click("Export")
local dialogText = ZwykValuesJSONScroll.scrollChild
local exported = assert(FW.JSON.Decode(dialogText:GetText()))
equal(exported.name, copied.name, "export is the selected full profile")
equal(exported.weights.strength, 4, "export carries weights")
equal(exported.weights.meleeCrit, 2, "profile export retains the independent melee crit weight")
equal(exported.weights.spellCrit, 7, "profile export retains the independent spell crit weight")
equal(exported.weights.crit, nil, "profile export omits the legacy combined crit key")
equal(exported.color.b, copied.color.b, "export carries color")
equal(exported.secondaryUnit, copied.secondaryUnit, "export carries stat units")
equal(exported.itemFilters.weapons["0"], true, "profile export carries its item filters")
equal(exported.itemFilters.armor["4"], false, "profile export retains subtype exclusions")
equal(dialogText.maxLetters, 131072, "profile input retains its limit")
click("Close")
click("Export issues")
local issues = assert(FW.JSON.Decode(dialogText:GetText()))
equal(issues.format, "ZwykValuesIssues", "issue export button copies the aggregate diagnostics")
equal(issues.itemCount, 0, "issue export works before any issues are recorded")
equal(dialogText.maxLetters, 0, "aggregate diagnostics must not be silently truncated")
local largeDiagnostics = string.rep("x", 140000)
FW:ShowTextDialog("Large diagnostics", largeDiagnostics, false)
equal(dialogText:GetText(), largeDiagnostics, "full diagnostics remain available to copy")
click("Close")
click("Weights JSON")
equal(dialogText.maxLetters, 131072, "reopening profile export restores its input limit")
local bare = assert(FW.JSON.Decode(dialogText:GetText()))
equal(bare.strength, 4, "weights-only export uses Sixty Upgrades keys")
equal(bare.name, nil, "weights-only export omits profile metadata")
click("Close")
click("Import")
userText(dialogText, '{"strength":9,"expertise":1.75}')
click("Import profile")
equal(#FW:GetProfiles(), 3, "JSON dialog imports a profile")
local imported = FW:GetProfiles()[3]
equal(imported.weights.strength, 9, "import applies weights")
equal(imported.weights.expertise, 1.75, "import supports Forever expertise")
click("New")
equal(#FW:GetProfiles(), 4, "New creates a blank profile")
equal(FW:GetProfiles()[4].weights.strength, 0, "new profile is deliberately unweighted")
click("Delete")
equal(#FW:GetProfiles(), 4, "deleting requires the native confirmation")
check(popup and popup.kind == "ZWYKVALUES_DELETE_PROFILE")
StaticPopupDialogs[popup.kind].OnAccept(nil, popup.data)
equal(#FW:GetProfiles(), 3, "accepting the confirmation deletes that profile")

-- Approximate geometry checks catch clipping/overlap at default and minimum
-- sizes. Font metrics and native templates still require an in-game review.
local function within(control, outer, message)
    local x, y, width, height = control:Rect()
    local left, top, ow, oh = outer:Rect()
    check(x >= left - .1 and y >= top - .1 and x + width <= left + ow + .1 and y + height <= top + oh + .1, message)
end
local function separate(first, second, message)
    local x, y, width, height = first:Rect()
    local ax, ay, aw, ah = second:Rect()
    check(x + width <= ax or ax + aw <= x or y + height <= ay or ay + ah <= y, message)
end
local geometryUnitClass = UnitClass
UnitClass = function() return "Druid", "DRUID" end
gear("mp5"):Fire("OnClick")
check(calculationDialog.sliders[1]:IsShown() and calculationDialog.toggles.kings:IsShown(), "minimum-size checks include the full regeneration and Kings prompt")
check(calculationDialog.talentRows["104911"]:IsShown(), "minimum-size checks include a relevant primary talent slider")
equal(calculationDialog.talentRows["104911"].maxValue, 3, "talent controls use the appropriate maximum rank")
check(calculationDialog.controlsScroll:GetVerticalScrollRange() > 0, "long talent and regeneration controls remain accessible by scrolling")
check(calculationDialog:GetHeight() <= 560, "long calculation prompts stay within a minimum-height editor")
for _, dimensions in ipairs({ {930, 720}, {850, 600} }) do
    FW.UI:SetSize(table.unpack(dimensions))
    FW.UI:Fire("OnSizeChanged")
    within(byText("Mark unrecognized stats", "FontString"), FW.UI, "debug label fits minimum width")
    within(byText("Show upgrade comparisons", "FontString"), FW.UI, "comparison label fits minimum width")
    separate(byText("Mark unrecognized stats", "FontString"), find(function(control) return control.optionKey == "showComparisons" end), "footer options do not overlap")
    separate(byText("Fixed weights ignore caps, procs, sets and rotations.", "FontString"), debug, "footer note leaves space for options")
    separate(byText("Weights saved", "FontString"), byText("Weights JSON", "Button"), "weight state does not overlap action buttons")
    within(byText("Apply weights", "Button"), FW.UI, "apply button fits editor")
    within(byText("Clear cache", "Button"), FW.UI, "cache button fits footer")
    check(ZwykValuesStatsScroll:GetHeight() >= 190, "resized editor keeps useful visible weight area")
    for _, control in ipairs({ critical, byText("Melee critical strike (%)", "FontString"), defense }) do
        check(#control:GetText() * control.fontSize * .56 <= control:GetWidth(), "secondary units fit beside their weights at minimum width")
        local box
        for _, child in ipairs(control.parent.children) do if child.kind == "EditBox" then box = child end end
        separate(control, box, "secondary weight labels leave room for the numeric field")
    end
    check(math.ceil(#unitHelp:GetText() * unitHelp.fontSize * .56 / unitHelp:GetWidth()) * unitHelp.fontSize <= unitHelp:GetHeight(), "unit explanation fits its available height")
    within(byText("Item filters", "Button"), FW.UI, "filter button fits minimum editor width")
    within(swatch, FW.UI, "clickable color square fits minimum editor width")
    within(iconControl, FW.UI, "optional icon control fits minimum editor width")
    separate(iconControl, swatch, "icon picker does not overlap the color square")
    within(iconDialog, FW.UI, "icon dialog fits minimum editor size")
    within(comparisonDialog, FW.UI, "comparison target selector fits minimum editor size")
    within(comparisonDialog.message, comparisonDialog, "comparison status fits its selector")
    within(comparisonDialog.scroll, comparisonDialog, "comparison choices fit their selector")
    within(calculationDialog, FW.UI, "regeneration prompt fits minimum editor size")
    within(calculationDialog.help, calculationDialog, "calculation help fits its prompt")
    within(calculationDialog.controlsScroll, calculationDialog, "calculation control viewport fits its prompt")
    separate(calculationDialog.controlsScroll, calculationDialog.detailsScroll, "scrolled controls cannot overlap calculation details")
    within(calculationDialog.detailsScroll, calculationDialog, "long conversion formulas stay in a scrollable area")
    within(calculationDialog.use, calculationDialog, "calculated-weight action fits its prompt")
    within(attackerSelector, calculationDialog, "attacker-level selector fits the calculation prompt")
    within(attackerSelector.title, attackerSelector, "attacker-level heading fits the selector")
    for _, choice in pairs(attackerSelector.choices) do
        within(choice, attackerSelector, "attacker-level choice fits its selector")
        within(choice.caption, attackerSelector, "attacker-level caption fits its selector")
    end
    separate(attackerSelector.choices[0].caption, attackerSelector.choices[3], "attacker-level choices do not overlap")
    separate(calculationDialog.detailsScroll, calculationDialog.use, "conversion details leave room for calculation action")
    for _, slider in ipairs(calculationDialog.sliders) do
        within(slider, calculationDialog.controlsContent, "regeneration slider fits the scrollable controls")
        within(slider.caption, calculationDialog.controlsContent, "regeneration ratio label fits the scrollable controls")
    end
    for _, row in pairs(calculationDialog.talentRows) do
        if row:IsShown() then
            within(row, calculationDialog.controlsContent, "talent slider fits the scrollable controls")
            within(row.caption, calculationDialog.controlsContent, "talent rank caption fits the scrollable controls")
            within(row.current, calculationDialog.controlsContent, "current-rank label fits the scrollable controls")
            separate(row.caption, row.current, "selected and current talent ranks do not overlap")
        end
    end
    within(calculationDialog.currentTalents, calculationDialog.controlsContent, "automatic-rank restore button fits the controls")
    for _, control in pairs(calculationDialog.toggles) do
        if control:IsShown() then
            within(control, calculationDialog, "bonus checkbox fits its calculation prompt")
            within(control.caption, calculationDialog, "bonus checkbox caption fits its prompt")
            separate(control.caption, calculationDialog.detailsScroll, "bonus checkbox leaves room for calculation details")
            for _, slider in ipairs(calculationDialog.sliders) do
                if slider:IsShown() then separate(control.caption, slider.caption, "bonus checkboxes leave room for regeneration labels") end
            end
        end
    end
    for _, key in ipairs({ "strength", "agility", "stamina", "intellect", "spirit", "mp5", "mana", "dps", "rangedDps", "armor", "defense" }) do
        local control = gear(key)
        within(control, control.parent, "calculation gear fits the attribute row")
        local fieldLabel = control.parent.children[1]
        separate(control, fieldLabel, "calculation gear leaves room for the attribute label")
        local box
        for _, child in ipairs(control.parent.children) do if child.kind == "EditBox" then box = child end end
        local anchor, relative, relativeAnchor, offset = control:GetPoint()
        equal(anchor, "RIGHT", "calculation gear anchors by its right edge")
        equal(relative, box, "calculation gear is next to the numeric value")
        equal(relativeAnchor, "LEFT", "calculation gear appears just before the numeric value")
        equal(offset, -6, "calculation gear keeps a small gap before the numeric value")
        local labelAnchor, _, _, labelOffset = fieldLabel:GetPoint()
        equal(labelAnchor, "LEFT", "stat labels retain their left alignment")
        equal(labelOffset, 0, "stat labels have no gear indentation")
        separate(control, box, "calculation gear leaves the numeric value unobstructed")
        check(control:GetScript("OnUpdate") == nil, "calculation gear performs no per-frame work")
    end
    within(iconDialog.search, iconDialog, "icon search fits the picker")
    within(iconDialog.count, iconDialog, "match count fits the picker")
    for index, control in ipairs(iconDialog.categories) do
        within(control, iconDialog, "category buttons fit the picker")
        separate(control, iconDialog.search, "categories leave room for the search field")
        separate(control, iconDialog.cells[1], "categories leave room for the icon grid")
        if index > 1 then separate(control, iconDialog.categories[index - 1], "category buttons do not overlap") end
    end
    separate(iconDialog.previous, iconDialog.none, "icon pagination leaves space for None")
    separate(iconDialog.next, iconDialog.done, "icon pagination leaves space for Done")
    for _, cell in ipairs(iconDialog.cells) do within(cell, iconDialog, "icon cells fit the picker") end
    separate(swatch, byText("Set color", "Button"), "color picker square does not overlap HEX save button")
    separate(byText("Item filters", "Button"), unitHelp, "filter button leaves room for the secondary-unit explanation")
    within(filterDialog, FW.UI, "filter dialog fits minimum editor size")
    within(otherClasses, filterDialog, "class-restriction checkbox fits filter dialog")
    within(byText("Include items restricted to other classes", "FontString"), filterDialog, "class-restriction label fits filter dialog")
    separate(otherClasses, filterScroll, "class restriction does not overlap subtype choices")
    check(filterScroll:GetHeight() >= 290, "filter dialog keeps a useful visible subtype list")
    check(filterScroll:GetVerticalScrollRange() > 0, "long subtype choices are available through scrolling")
    for _, group in ipairs(FW.ItemFilterGroups) do
        for _, definition in ipairs(group.types) do
            local control = filterControl(group.key, definition.key)
            within(control, filterScroll.scrollChild, "subtype checkbox fits scroll content")
            for _, child in ipairs(control.children) do within(child, filterScroll.scrollChild, "subtype label fits scroll content") end
        end
    end
    local upgradePanel = main.parent
    within(upgradePanel, FW.UI, "upgrade panel fits minimum editor size")
    within(mainName, upgradePanel, "main name fits upgrade panel")
    within(byText("Use this profile", "FontString"), upgradePanel, "profile checkbox label fits compact panel")
    within(comparisonButton, upgradePanel, "comparison target button fits the compact upgrade panel")
    separate(main, comparisonButton, "upgrade activation leaves room for target selection")
    separate(ZwykValuesProfilesScroll, upgradePanel, "profile list leaves room for upgrade settings")
    separate(upgradePanel, byText("New", "Button"), "upgrade settings leave room for profile buttons")
    check(ZwykValuesProfilesScroll:GetHeight() >= 170, "compact settings retain useful profile list height")
    for _, control in ipairs(arrowControls) do
        within(control, upgradePanel, "arrow location checkbox fits panel")
        for _, child in ipairs(control.children) do within(child, upgradePanel, "arrow location label fits panel") end
        separate(main, control, "main choice does not overlap arrow locations")
        separate(comparisonButton, control, "target selector does not overlap arrow location controls")
    end
    separate(arrowControls[1], arrowControls[2], "bag and roll arrow toggles do not overlap")
    separate(arrowControls[2], arrowControls[3], "roll and chat arrow toggles do not overlap")
end
UnitClass = geometryUnitClass
calculationDialog.cancel:Fire("OnClick")
click("Item filters")
gear("strength"):Fire("OnEnter")
local remaining = FW:GetProfiles()
for _, existing in ipairs(remaining) do FW:DeleteProfile(existing.id) end
check(not sourceHighlighted("Attack power"), "removing every profile clears disabled source fields")
check(not byText("Item filters", "Button").enabled, "filter button is disabled without a profile")
check(not swatch.enabled, "color picker square is disabled without a profile")
check(not iconControl.enabled, "icon picker is disabled without a profile")
check(not comparisonButton.enabled, "comparison selector is disabled without a profile")
check(not gear("strength").enabled and not gear("spirit").enabled, "calculation gears are disabled without a profile")
check(not otherClasses.enabled and not weaponFilter.enabled and not armorFilter.enabled, "open filters disable their controls when the profile is deleted")
local restored = assert(FW:CreateProfile("Restored profile", {}))
check(byText("Item filters", "Button").enabled, "creating a profile re-enables filters")
check(swatch.enabled, "creating a profile re-enables the color picker")
check(iconControl.enabled, "creating a profile re-enables the icon picker")
check(otherClasses.enabled and weaponFilter.enabled and armorFilter.enabled, "new profile enables existing dialog controls")
check(otherClasses:GetChecked() and weaponFilter:GetChecked() and armorFilter:GetChecked(), "new profile restores default inclusion")
click("Done")
click("Item filters")
ColorPickerFrame = modernPicker
local restoredColor = restored.color.r
swatch:Fire("OnClick")
modernPicker.rgb = { .9, .8, .7 }
modernPicker.info.swatchFunc()
FW.UI:Hide()
check(not filterDialog:IsShown(), "closing the editor hides its filter dialog")
check(not modernPicker:IsShown(), "closing the editor hides its own color picker")
equal(restored.color.r, restoredColor, "closing the editor cancels the current picker edit")
print("UI: " .. passed .. " checks passed (widget smoke and approximate geometry).")
