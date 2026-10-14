-- Native add-on category registration and launch behavior, without building the editor.
-- Run from the addon directory: luatex --luaonly tests/test_settings.lua
local addonPath = (arg and arg[1]) or "."
local passed, widgets = 0, {}
local function check(value, message)
    assert(value, message or "assertion failed")
    passed = passed + 1
end
local function equal(actual, expected, message)
    check(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local methods = {}
local function widget(kind, parent)
    local frame = setmetatable({kind = kind, parent = parent, children = {}, scripts = {}, shown = true}, {__index = methods})
    widgets[#widgets + 1] = frame
    if parent then parent.children[#parent.children + 1] = frame end
    return frame
end
function CreateFrame(kind, _, parent) return widget(kind, parent) end
function methods:CreateFontString() return widget("FontString", self) end
function methods:SetPoint() end
function methods:SetJustifyH() end
function methods:SetText(value) self.text = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
local function addon()
    local FW = {showCalls = 0}
    function FW:ShowUI() self.showCalls = self.showCalls + 1; self.editorShown = true end
    function FW:ToggleUI() error("The Settings launch button must not toggle an open editor closed") end
    assert(loadfile(addonPath .. "/Settings.lua"))("ZwykValues", FW)
    return FW
end
local function launchButton(panel)
    for _, child in ipairs(panel.children) do if child.kind == "Button" then return child end end
    error("Missing configuration launch button")
end

Settings, InterfaceOptions_AddCategory = nil, nil
local FW = addon()
local before = #widgets
equal(FW:InstallBlizzardOptions(), nil, "registration waits when no native settings API is available")
equal(#widgets, before, "waiting for native settings creates no widgets")
equal(FW.showCalls, 0, "loading settings does not construct the profile editor")

local categories, canvases, legacyCalls = {}, {}, 0
InterfaceOptions_AddCategory = function() legacyCalls = legacyCalls + 1 end
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        canvases[#canvases + 1] = panel
        equal(name, "ZwykValues", "native category has the add-on name")
        return {name = name, panel = panel}
    end,
    RegisterAddOnCategory = function(category) categories[#categories + 1] = category end,
}
local panel = FW:InstallBlizzardOptions()
check(panel ~= nil, "late settings availability can register the category")
equal(#canvases, 1, "one settings canvas is created")
equal(#categories, 1, "one add-on category is registered")
equal(categories[1].panel, panel, "the add-on category uses its own canvas")
equal(FW.blizzardOptionsCategory, categories[1], "category identity is retained")
equal(legacyCalls, 0, "modern registration takes precedence over the legacy API")
equal(panel.name, "ZwykValues", "canvas identifies the add-on")
local button = launchButton(panel)
equal(button.text, "Open ZwykValues", "button describes the destination")
equal(button.width, 180, "launch button is compact")
equal(button.height, 26, "launch button matches native settings sizing")
equal(panel.scripts.OnUpdate, nil, "settings category does no per-frame work")
equal(button.scripts.OnUpdate, nil, "launch button does no per-frame work")
local created = #widgets
equal(FW:InstallBlizzardOptions(), panel, "repeated installation reuses the same category")
equal(#widgets, created, "repeated registration creates no new widgets")
equal(#categories, 1, "repeated registration adds no duplicate category")
equal(FW.showCalls, 0, "registration leaves the profile editor lazy")
button.scripts.OnClick(button)
equal(FW.showCalls, 1, "click opens configuration")
check(FW.editorShown, "configuration is shown")
button.scripts.OnClick(button)
equal(FW.showCalls, 2, "another click still requests configuration")
check(FW.editorShown, "clicking again preserves an already open editor")

-- Incomplete or absent modern APIs still permit legacy clients to register once.
for _, modern in ipairs({false, {RegisterCanvasLayoutCategory = function() error("Incomplete modern API must not be used") end}}) do
    Settings = modern or nil
    local registered = {}
    InterfaceOptions_AddCategory = function(frame) registered[#registered + 1] = frame end
    local legacy = addon()
    local legacyPanel = legacy:InstallBlizzardOptions()
    equal(registered[1], legacyPanel, "legacy category receives the settings canvas")
    equal(legacy.blizzardOptionsCategory, nil, "legacy registration needs no modern category")
    equal(legacy:InstallBlizzardOptions(), legacyPanel, "legacy registration is idempotent")
    equal(#registered, 1, "legacy category is registered once")
    launchButton(legacyPanel).scripts.OnClick()
    check(legacy.editorShown, "legacy options can open the profile editor")
end
print("Passed " .. passed .. " settings assertions")
