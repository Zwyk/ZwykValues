local _, FW = ...

-- External scales are parsed as data. Saved weights always use percentage
-- points (defense uses skill points); the editor's display unit is independent.
local function trim(value) return value:match("^%s*(.-)%s*$") end
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function decimal(source)
    if type(source) ~= "string" then return nil end
    source = trim(source)
    local mantissa, exponent = source:match("^([%+%-]?[%d%.]+)[eE]([%+%-]?%d+)$")
    if not mantissa then mantissa = source end
    mantissa = mantissa:gsub("^[%+%-]", "")
    if not mantissa:match("^%d+%.?%d*$") and not mantissa:match("^%.%d+$") then return nil end
    -- An unmatched exponent, hexadecimal literal, expression, NaN or infinity
    -- cannot reach tonumber. Overflow is rejected after conversion as well.
    if source:find("[eE]") and not exponent then return nil end
    local value = tonumber(source)
    if finite(value) then return value end
end

local function envelope(name, weights, displayUnit)
    return {format="ZwykValues", version=1, name=name, weights=weights,
        secondaryUnit="percent", secondaryDisplayUnit=displayUnit}
end

local function urlDecode(value)
    local index = 1
    while true do
        index = value:find("%", index, true)
        if not index then break end
        if not value:sub(index + 1, index + 2):match("^%x%x$") then return nil end
        index = index + 3
    end
    value = value:gsub("+", " "):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    if value:find("[%z\1-\31\127]") or not FW.JSON.Encode(value) then return nil end
    return value
end

local function duplicate(key)
    return "Duplicate external weight '" .. key .. "'. Remove the duplicate before importing."
end

local function unsupported(kind, key)
    return kind .. " stat '" .. key .. "' has a nonzero weight but ZwykValues cannot represent it. Remove that field or set it to 0 before importing."
end

local function addWeight(weights, seen, key, value, sourceKey)
    if seen[key] then return nil, duplicate(sourceKey) end
    seen[key], weights[key] = true, value
    return true
end

local function parseSixtyUpgrades(source)
    local url = source:match("^%[[^%]]*%]%((.*)%)$") or source:match("^<(.*)>$") or source
    url = url:gsub("\\&", "&"):gsub("&amp;", "&")
    local scheme, host, path, query = url:match("^(https?)://([^/%?#]+)([^%?#]*)%?([^#]*)$")
    if not scheme or (host:lower() ~= "sixtyupgrades.com" and host:lower() ~= "www.sixtyupgrades.com")
        or path ~= "/forever/ep/import" then
        return nil, "Paste the complete Sixty Upgrades Forever EP import URL (https://sixtyupgrades.com/forever/ep/import?...)."
    end
    local weights, seen, fields, warnings, name = {}, {}, {}, {}, "Imported 60U weights"
    local aliases = {crit="crit"}
    for key in pairs(FW.StatByKey) do aliases[key:lower()] = key end
    local count = 0
    for field in (query .. "&"):gmatch("(.-)&") do
        if field == "" then return nil, "The Sixty Upgrades URL contains an empty query field." end
        local rawKey, rawValue = field:match("^([^=]+)=(.*)$")
        if not rawKey then return nil, "Every Sixty Upgrades query field must use name=value." end
        local key, value = urlDecode(rawKey), urlDecode(rawValue)
        if not key or not value then return nil, "The Sixty Upgrades URL has invalid percent encoding or control characters." end
        local normalized = key:lower()
        if fields[normalized] then return nil, duplicate(key) end
        fields[normalized] = true
        if normalized == "name" then
            name = trim(value)
            if name == "" then return nil, "The imported profile name is empty." end
        else
            local number = decimal(value)
            if not number then return nil, "Sixty Upgrades weight '" .. key .. "' must be a finite decimal number." end
            local target = aliases[normalized]
            if not target then
                if number ~= 0 then return nil, unsupported("Sixty Upgrades", key) end
                warnings[#warnings + 1] = "Ignored unsupported zero-weight Sixty Upgrades stat '" .. key .. "'."
            else
                local ok, failure = addWeight(weights, seen, target, number, key)
                if not ok then return nil, failure end
                count = count + 1
            end
        end
    end
    if count == 0 then return nil, "The Sixty Upgrades URL contains no supported stat weights." end
    if weights.crit ~= nil and (weights.meleeCrit ~= nil or weights.spellCrit ~= nil) then
        return nil, "Combined crit cannot be mixed with separate meleeCrit/spellCrit weights in the same URL."
    end
    warnings[#warnings + 1] = "Sixty Upgrades EP values use percentage points. WoWSims exports can combine melee/ranged attack power and omit unsupported simulator stats; those distinctions cannot be recovered from the URL."
    return envelope(name, weights, "percent"), nil, warnings
end

local pawnStats = {
    strength="strength", agility="agility", stamina="stamina", intellect="intellect", spirit="spirit",
    health="health", mana="mana", hp5="hp5", mp5="mp5", spelldamage="spellDamage", healing="healing",
    spellhealing="healing", spellpenetration="spellPen", spellpen="spellPen",
    arcanespelldamage="arcaneDamage", firespelldamage="fireDamage", frostspelldamage="frostDamage",
    holyspelldamage="holyDamage", naturespelldamage="natureDamage", shadowspelldamage="shadowDamage",
    ap="attackPower", feralap="feralAttackPower", rap="rangedAttackPower",
    meleedps="dps", rangeddps="rangedDps", meleespeed="speed", rangedspeed="rangedSpeed",
    mindamage="lowDamage", maxdamage="highDamage", weapondamage="weaponDamage",
    armor="armor", armor2="armorBonus", blockvalue="blockValue",
    arcaneresist="arcaneResist", fireresist="fireResist", frostresist="frostResist",
    natureresist="natureResist", shadowresist="shadowResist",
}
local pawnRatings = {
    hitrating="hit", hasterating="haste", expertiserating="expertise",
    defenserating="defense", dodgerating="dodge", parryrating="parry", blockrating="block",
    meleecritrating="meleeCrit", spellcritrating="spellCrit",
}

local function readQuoted(source, start)
    if source:sub(start, start) ~= '"' then return nil, "Expected a quoted Pawn scale name." end
    local pieces, index = {}, start + 1
    while index <= #source do
        local char = source:sub(index, index)
        if char == '"' then return table.concat(pieces), index + 1 end
        if char == "\\" then
            index = index + 1
            char = source:sub(index, index)
            if char ~= '"' and char ~= "\\" then return nil, "Unsupported escape in the Pawn scale name." end
        end
        if char:find("[%z\1-\31\127]") then return nil, "Pawn names cannot contain control characters." end
        pieces[#pieces + 1], index = char, index + 1
    end
    return nil, "The Pawn scale name is missing its closing quote."
end

local function metadataText(value)
    if value:sub(1, 1) == '"' then
        local text, nextIndex = readQuoted(value, 1)
        if not text or nextIndex ~= #value + 1 then return nil end
        return text
    end
    if value:match("^[%w_ %-]+$") then return value end
end

local function parsePawn(source, options)
    local body = source:match("^%(%s*[Pp][Aa][Ww][Nn]%s*:%s*(.-)%s*%)$")
    if not body then return nil, "Paste a complete Pawn scale string, including '( Pawn: ... )'." end
    local version, start = body:match("^v(%d+)%s*:%s*()")
    if version ~= "1" and version ~= "2" then return nil, "Unsupported Pawn scale version (expected v1 or v2)." end
    local name, nextIndex = readQuoted(body, start)
    if not name then return nil, nextIndex end
    name = trim(name)
    if name == "" then return nil, "The imported Pawn scale name is empty." end
    local tail = body:sub(nextIndex):match("^%s*:%s*(.-)%s*$")
    if not tail or tail == "" then return nil, "The Pawn scale has no stat fields after its name." end
    if options ~= nil and type(options) ~= "table" then return nil, "Pawn import options must be a table." end
    local critMode = options and options.pawnCritMode
    if critMode ~= nil and critMode ~= "shared" and critMode ~= "separate" then
        return nil, "Pawn crit mode must be 'shared' or 'separate'."
    end
    local unit = options and options.pawnUnit
    if unit == nil then unit = "rating" end
    if unit ~= "rating" and unit ~= "percent" then
        return nil, "Pawn source unit must be 'rating' or 'percent'."
    end
    local fields, seen, values, warnings, color = {}, {}, {}, {}, nil
    for field in (tail .. ","):gmatch("(.-),") do
        field = trim(field)
        local key, value = field:match("^([%a][%w]*)%s*=%s*(.-)%s*$")
        if not key or value == "" then return nil, "Each Pawn field must use Stat=number, separated by commas." end
        local normalized = key:lower()
        if seen[normalized] then return nil, duplicate(key) end
        seen[normalized] = true
        fields[#fields + 1] = {key=key, normalized=normalized, value=value}
        values[normalized] = value
    end
    if not critMode then
        critMode = values.spellcritrating ~= nil and "separate" or "shared"
        if values.critrating ~= nil then
            warnings[#warnings + 1] = critMode == "shared"
                and "Pawn CritRating was interpreted as shared crit for WoWSims Forever. Use separate Pawn crit mode for a Classic Pawn melee-only scale."
                or "Pawn CritRating was interpreted as melee crit because SpellCritRating is also present."
        end
    end
    if critMode == "shared" and values.critrating ~= nil
        and (values.spellcritrating ~= nil or values.meleecritrating ~= nil) then
        return nil, "Shared Pawn CritRating cannot be mixed with separate crit fields. Choose separate Pawn crit mode or remove the overlapping fields."
    end
    local weights, assigned, count = {}, {}, 0
    for _, field in ipairs(fields) do
        local key, normalized, value = field.key, field.normalized, field.value
        if normalized == "class" or normalized == "spec" or normalized == "classid" or normalized == "specid" then
            if normalized == "classid" or normalized == "specid" then
                local number = decimal(value)
                if not number or number < 0 or number ~= math.floor(number) then return nil, "Pawn " .. key .. " must be a nonnegative whole number." end
            elseif not metadataText(value) then
                return nil, "Invalid Pawn metadata '" .. key .. "'."
            end
            warnings[#warnings + 1] = "Pawn " .. key .. " metadata is informational; review the imported profile's item filters."
        elseif normalized == "color" then
            local hex = metadataText(value)
            if not hex or (not hex:match("^%x%x%x%x%x%x$") and not hex:match("^%x%x%x%x%x%x%x%x$")) then
                return nil, "Pawn Color must contain six RGB or eight ARGB hexadecimal digits."
            end
            hex = hex:sub(-6)
            color = {r=tonumber(hex:sub(1, 2), 16) / 255, g=tonumber(hex:sub(3, 4), 16) / 255,
                b=tonumber(hex:sub(5, 6), 16) / 255}
        else
            if value == "X" or value == "x" then
                return nil, "Pawn item exclusion '" .. key .. "=X' cannot be represented as a weight. Remove that field and configure the profile's item filters after importing."
            end
            local number = decimal(value)
            if not number then return nil, "Pawn weight '" .. key .. "' must be a finite decimal number." end
            local target, rating = pawnStats[normalized], pawnRatings[normalized]
            if normalized == "critrating" then rating = critMode == "shared" and "crit" or "meleeCrit" end
            if rating then
                target = rating
                if unit == "rating" then
                    local factor = FW.GetRatingPerPercent and FW:GetRatingPerPercent(rating)
                    if not finite(factor) or factor <= 0 then return nil, "No Forever rating conversion is available for Pawn stat '" .. key .. "'." end
                    number = number * factor
                    if not finite(number) then return nil, "Pawn weight '" .. key .. "' overflows after conversion." end
                end
            end
            if not target then
                if number ~= 0 then return nil, unsupported("Pawn", key) end
                warnings[#warnings + 1] = "Ignored unsupported zero-weight Pawn stat '" .. key .. "'."
            else
                local ok, failure = addWeight(weights, assigned, target, number, key)
                if not ok then return nil, failure end
                count = count + 1
            end
        end
    end
    if count == 0 then return nil, "The Pawn scale contains no supported stat weights." end
    warnings[#warnings + 1] = unit == "rating"
        and "Pawn rating weights were converted to Forever percentage points; defense uses skill points. WoWSims exports may combine melee/ranged attack power or omit simulator-only stats."
        or "Pawn secondary weights were interpreted as percentage points (Classic Pawn); defense uses skill points. Choose rating units for WoWSims Forever exports."
    local profile = envelope(name, weights, unit)
    profile.color = color
    return profile, nil, warnings
end

function FW:ParseExternalWeights(source, options)
    if type(source) ~= "string" then return nil end
    local text = trim(source)
    -- Leave JSON (including names or strings containing 'Pawn') to the strict
    -- existing JSON importer. A single pasted scale/link is required.
    if text:sub(1, 1) == "{" or text:sub(1, 1) == "[" and not text:match("^%[[^%]]*%]%(") then return nil end
    local isPawn = text:match("^%(%s*[Pp][Aa][Ww][Nn]%s*:") or text:match("^[Pp][Aa][Ww][Nn]%s*:")
    local isSixty = text:lower():find("sixtyupgrades.com", 1, true)
    if not isPawn and not isSixty then return nil end
    if #text > 1048576 then return nil, "External scale is too large (maximum 1 MiB)." end
    if not FW.JSON.Encode(text) then return nil, "External scale text must use valid UTF-8." end
    if isPawn then return parsePawn(text, options) end
    return parseSixtyUpgrades(text)
end
