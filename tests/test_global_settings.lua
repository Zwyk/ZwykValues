-- Exercise the actual global-option setters with a small native-widget model.
local addonPath = (arg and arg[1]) or "."
local count, widgets, methods = 0, {}, {}
local function check(value, message) assert(value, message); count = count + 1 end
local function equal(actual, expected, message)
    check(actual == expected, (message or "Unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function widget(kind, name, parent)
    local result = setmetatable({kind=kind, name=name, parent=parent, scripts={}, shown=true}, {__index=methods})
    widgets[#widgets+1] = result
    if name then _G[name] = result end
    return result
end
function CreateFrame(kind, name, parent) return widget(kind, name, parent) end
function methods:CreateFontString() return widget("FontString", nil, self) end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetText(value) self.text = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local old = self.scripts[event]
    self.scripts[event] = function(frame) if old then old(frame) end callback(frame) end
end
function methods:Fire(event) if self.scripts[event] then self.scripts[event](self) end end
function methods:Show() self.shown = true; self:Fire("OnShow") end
function methods:Hide() if self.shown then self.shown = false; self:Fire("OnHide") end end
function methods:GetFrameLevel() return 7 end
for _, key in ipairs({"SetPoint", "ClearAllPoints", "SetFrameStrata", "EnableMouse", "SetClampedToScreen", "SetBackdrop", "SetWidth", "SetJustifyH", "SetTextColor", "SetFrameLevel"}) do
    methods[key] = function() end
end
UIParent, UISpecialFrames = widget("Frame", "UIParent"), {}
local tooltip = {hidden=0, shown=0, lines={}}
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:SetText(value) self.title, self.lines = value, {} end
function tooltip:AddLine(value) self.lines[#self.lines+1] = value end
function tooltip:Show() self.shown = self.shown + 1 end
function tooltip:Hide() self.hidden = self.hidden + 1 end
GameTooltip = tooltip
local FW = {}
for _, file in ipairs({"JSON.lua", "Stats.lua", "ProfileClasses.lua", "Core.lua", "GlobalSettings.lua"}) do
    assert(loadfile(addonPath .. "/" .. file))("ZwykValues", FW)
end
equal(FW.globalSettingsFrame, nil, "Module loading leaves the popup lazy")
local uiRefreshes, tooltipRefreshes, indicatorRefreshes = 0, 0, 0
function FW:RefreshUI() uiRefreshes = uiRefreshes + 1 end
function FW:RefreshTooltips() tooltipRefreshes = tooltipRefreshes + 1 end
function FW:RefreshUpgradeIndicators() indicatorRefreshes = indicatorRefreshes + 1 end
FW:Initialize()
local profile = FW:GetProfiles()[1]
local revision, weights = profile.revision, profile.weights
local cache = FW.DB.cache
local owner = widget("Frame", "SettingsOwner")
local frame = FW:ShowGlobalSettings(owner)
equal(frame, FW.GlobalSettingsFrame, "The launcher exposes the shared popup")
check(frame.shown and frame.owner == owner, "Opening records its editor owner")
equal(frame.width, 520, "The popup has readable compact sizing")
equal(UISpecialFrames[1], "ZwykValuesGlobalSettings", "Escape can close the popup")
equal(#UISpecialFrames, 1, "Only one Escape registration is created")
local defaults = {upgradeBags=false, upgradeRolls=false, upgradeChat=false,
    debugUnknownStats=false, showComparisons=true, showProfileIcon=true, showClassIcon=true}
for key, default in pairs(defaults) do
    local control = frame.controls[key]
    check(control and control.optionKey == key, key .. " has an identifiable checkbox")
    equal(control:GetChecked(), default, key .. " synchronizes its initial value")
    for _, value in ipairs({not default, default}) do
        local before = tooltipRefreshes
        control:SetChecked(value)
        control:Fire("OnClick")
        equal(FW.DB.options[key], value, key .. " is persisted through the real Core setter")
        equal(tooltipRefreshes, before + 1, key .. " refreshes tooltips once")
        equal(indicatorRefreshes, tooltipRefreshes, "The same notification refreshes indicators")
        equal(uiRefreshes, tooltipRefreshes, "The same notification refreshes the editor")
        equal(frame.controls[key]:GetChecked(), value, key .. " remains synchronized after notification")
        equal(profile.revision, revision, "Global presentation changes preserve score revisions")
        equal(profile.weights, weights, "Global presentation changes preserve the exact weights")
        equal(FW.DB.cache, cache, "Global presentation changes preserve the stat and score cache")
    end
    control:Fire("OnEnter")
    equal(tooltip.owner, control, "Help is anchored to the hovered setting")
    equal(tooltip.title, control.label.text, "Help identifies the setting")
    check(#tooltip.lines >= 1, "Help explains the setting")
    local hidden = tooltip.hidden
    control:Fire("OnLeave")
    equal(tooltip.hidden, hidden + 1, "Help clears on leaving the setting")
    equal(control.scripts.OnUpdate, nil, "The popup does no per-frame work")
end
equal(frame.scripts.OnUpdate, nil, "The window does no per-frame work")
local before = tooltipRefreshes
frame.controls.showClassIcon:Fire("OnClick")
equal(tooltipRefreshes, before, "Saving the same setting is a no-op")
-- Reopening reuses widgets and refreshes values changed outside the popup.
local created = #widgets
frame.close:Fire("OnClick")
check(not frame.shown, "Close hides the popup")
FW.DB.options.showClassIcon, FW.DB.options.upgradeBags = false, true
equal(FW:ShowGlobalSettings(owner), frame, "Reopening reuses the popup")
equal(#widgets, created, "Reopening creates no extra controls")
equal(#UISpecialFrames, 1, "Reopening creates no extra Escape registrations")
equal(frame.controls.showClassIcon:GetChecked(), false, "Reopening rereads tooltip choices")
equal(frame.controls.upgradeBags:GetChecked(), true, "Reopening rereads indicator choices")
owner:Hide()
check(not frame.shown, "Hiding the owning editor closes the popup")
local otherOwner = widget("Frame", "OtherSettingsOwner")
FW:ShowGlobalSettings(otherOwner)
owner:Show(); owner:Hide()
check(frame.shown, "A previous owner cannot close a popup opened by another editor")
otherOwner:Hide()
check(not frame.shown, "The new owner closes its popup")
FW:ShowGlobalSettings()
owner:Show(); owner:Hide()
check(frame.shown and frame.owner == nil, "Standalone opening clears the previous owner")
-- Setter failures restore the checkbox and show the useful validation error.
local setGlobal = FW.SetGlobalOption
FW.SetGlobalOption = function() return nil, "Setting is unavailable." end
frame.controls.showClassIcon:SetChecked(true)
frame.controls.showClassIcon:Fire("OnClick")
equal(frame.controls.showClassIcon:GetChecked(), false, "Rejected changes restore the saved checkbox")
equal(frame.status.text, "Setting is unavailable.", "Rejected changes explain the error")
equal(FW.DB.options.showClassIcon, false, "Rejected changes preserve the option")
FW.SetGlobalOption = setGlobal
frame.controls.showClassIcon:SetChecked(true)
frame.controls.showClassIcon:Fire("OnClick")
equal(frame.status.text, "", "A successful change clears previous errors")
print("Passed " .. count .. " global settings assertions")
