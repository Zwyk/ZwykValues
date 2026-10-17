local _, FW = ...

local arrow = "|TInterface\\AddOns\\ZwykValues\\Textures\\ArrowUp:12:12:0:0|t"
local profileArrow = "|TInterface\\AddOns\\ZwykValues\\Textures\\ArrowUpWhite:12:12:0:0:16:16:0:16:0:16:%d:%d:%d|t"
local memo, memoCount, memoSignature = {}, 0, nil
local function remember(key, value)
    if memoCount >= (FW.CACHE_LIMIT or 2000) then memo, memoCount = {}, 0 end
    if memo[key] == nil then memoCount = memoCount + 1 end
    memo[key] = value
end
local function temporaryFalse(key)
    if GetTime then remember(key, {value=false, expires=GetTime()+1}) end
    return false
end

local function safeString(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return type(value) == "string" and value or nil
end

function FW:InvalidateUpgradeComparisons()
    memo, memoCount, memoSignature = {}, 0, nil
end

local function upgradeProfiles(self)
    if self.GetUpgradeProfiles then return self:GetUpgradeProfiles() end
    local profile = self.GetMainProfile and self:GetMainProfile()
    return profile and {profile} or {}
end

local function isProfileUpgrade(self, link, itemKey, profile)
    local signature = tostring(self.equipmentRevision or 0)
    if signature ~= memoSignature then
        self:InvalidateUpgradeComparisons()
        memoSignature = signature
    end
    local target = profile.comparisonTarget or {}
    local baseline = table.concat({target.mode or "equipped", target.character or "", target.setID or ""}, ":")
    if self.GetUpgradeBaselineSignature then
        local ok, value = pcall(self.GetUpgradeBaselineSignature, self, profile)
        if ok and safeString(value) then baseline = value end
    end
    local key = table.concat({profile.id, profile.revision or 0, baseline, itemKey}, "\31")
    local cached = memo[key]
    if type(cached) == "boolean" then return cached end
    if cached and GetTime and cached.expires > GetTime() then return cached.value end
    local ok, result = pcall(self.CompareItem, self, link, profile)
    if not ok or not result or result.pending then return temporaryFalse(key) end
    if result.excluded then remember(key, false); return false end
    -- A partial subtotal is useful in a tooltip, but cannot establish whether
    -- an item is an upgrade. Do not persist temporary/loading decisions.
    if result.record and ((self.ItemHasIssues and self:ItemHasIssues(result.record, profile))
        or result.record.partial) then return temporaryFalse(key) end
    local upgrade, complete = false, true
    for _, comparison in ipairs(result.comparisons or {}) do
        if comparison.error or comparison.hasIssues then complete = false
        elseif comparison.status == "upgrade" then upgrade = true end
    end
    if complete or upgrade then
        remember(key, upgrade)
    else
        return temporaryFalse(key)
    end
    return upgrade
end

function FW:GetItemUpgradeProfiles(link)
    link = safeString(link)
    if not link or not link:find("item:", 1, true) then return {} end
    local profiles = upgradeProfiles(self)
    if #profiles == 0 then return {} end
    local key = self.ItemKey and self:ItemKey(link) or link
    if not key then return {} end
    local upgrades = {}
    for _, profile in ipairs(profiles) do
        if isProfileUpgrade(self, link, key, profile) then upgrades[#upgrades + 1] = profile end
    end
    return upgrades
end

function FW:IsMainProfileUpgrade(link)
    return #self:GetItemUpgradeProfiles(link) > 0
end

local function profileMarker(profile)
    local color = profile.color or {r=0.35, g=0.8, b=1}
    local function byte(value)
        if type(value) ~= "number" or value ~= value then return 255 end
        return math.floor(math.min(1, math.max(0, value)) * 255 + 0.5)
    end
    local marker = profileArrow:format(byte(color.r), byte(color.g), byte(color.b))
    if profile.icon then marker = "|T" .. profile.icon .. ":12:12:0:0|t" .. marker end
    return marker
end

function FW:DecorateUpgradeChatMessage(message)
    message = safeString(message)
    if not message or not self.DB or not self.DB.options.upgradeChat or #upgradeProfiles(self) == 0 then
        return message
    end
    -- Keep the original hyperlink (including enchant/suffix fields) and all
    -- surrounding color codes intact. The icon is outside the clickable text.
    return (message:gsub("()(|Hitem:[^|]+|h.-|h)()", function(_, link, after)
        if message:sub(after, after + #arrow) == " " .. arrow then return link end
        local profiles = self:GetItemUpgradeProfiles(link)
        if #profiles == 0 then return link end
        local markers = {}
        for _, profile in ipairs(profiles) do markers[#markers + 1] = profileMarker(profile) end
        local suffix = " " .. table.concat(markers, " ")
        if message:sub(after, after + #suffix - 1) ~= suffix then return link .. suffix end
        return link
    end))
end

local chatEvents = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_COMMUNITIES_CHANNEL", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
}
local registered = {}
local function filter(_, _, message, ...)
    -- Filtering changes local display only. Preserve every trailing argument,
    -- including nils, so sender identities/channel metadata are not altered.
    if safeString(message) then
        local ok, decorated = pcall(FW.DecorateUpgradeChatMessage, FW, message)
        if ok and decorated then return false, decorated, ... end
    end
    return false, message, ...
end

function FW:InstallUpgradeChatHooks()
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if not add then return end
    for _, event in ipairs(chatEvents) do
        if not registered[event] then
            local ok = pcall(add, event, filter)
            if ok then registered[event] = true end
        end
    end
end
