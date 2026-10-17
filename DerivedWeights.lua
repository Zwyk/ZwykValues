local _, FW = ...

-- These helpers change profile weights only when the player clicks a gear.
-- They never add derived stats to item scores or run during bag/tooltip scans.
-- Data provenance: class/level Classic tables retained in RatingBuster's
-- Forever (Camelot) rules, and its Forever spirit/talent conversions:
-- https://github.com/raethkcj/RatingBuster/blob/905c14184527e0466c85b1d180bcd62d875fd4dd/libs/StatLogic/CamelotLogic.lua
-- Live client conversion APIs take priority. Tables are a labelled Classic
-- fallback, rather than an assumption that Forever shares every coefficient.

local critPerAgility = {
	["WARRIOR"] = {
		0.2500, 0.2381, 0.2381, 0.2273, 0.2174, 0.2083, 0.2083, 0.2000, 0.1923, 0.1923,
		0.1852, 0.1786, 0.1667, 0.1613, 0.1563, 0.1515, 0.1471, 0.1389, 0.1351, 0.1282,
		0.1282, 0.1250, 0.1190, 0.1163, 0.1111, 0.1087, 0.1064, 0.1020, 0.1000, 0.0962,
		0.0943, 0.0926, 0.0893, 0.0877, 0.0847, 0.0833, 0.0820, 0.0794, 0.0781, 0.0758,
		0.0735, 0.0725, 0.0704, 0.0694, 0.0676, 0.0667, 0.0649, 0.0633, 0.0625, 0.0610,
		0.0595, 0.0588, 0.0575, 0.0562, 0.0549, 0.0543, 0.0532, 0.0521, 0.0510, 0.0500,
	},
	["PALADIN"] = {
		0.2150, 0.2048, 0.2048, 0.1955, 0.1955, 0.1870, 0.1870, 0.1792, 0.1792, 0.1720,
		0.1720, 0.1654, 0.1536, 0.1536, 0.1433, 0.1433, 0.1387, 0.1303, 0.1303, 0.1229,
		0.1194, 0.1194, 0.1132, 0.1103, 0.1075, 0.1049, 0.1024, 0.1000, 0.0977, 0.0935,
		0.0915, 0.0915, 0.0878, 0.0860, 0.0827, 0.0811, 0.0811, 0.0782, 0.0768, 0.0741,
		0.0729, 0.0729, 0.0705, 0.0694, 0.0672, 0.0662, 0.0652, 0.0632, 0.0623, 0.0606,
		0.0597, 0.0589, 0.0573, 0.0566, 0.0551, 0.0544, 0.0538, 0.0524, 0.0518, 0.0506,
	},
	["HUNTER"] = {
		0.2174, 0.2083, 0.2000, 0.1852, 0.1786, 0.1724, 0.1667, 0.1613, 0.1515, 0.1471,
		0.1351, 0.1190, 0.1087, 0.1000, 0.0909, 0.0862, 0.0806, 0.0746, 0.0704, 0.0658,
		0.0633, 0.0595, 0.0568, 0.0538, 0.0515, 0.0495, 0.0472, 0.0455, 0.0435, 0.0417,
		0.0407, 0.0391, 0.0376, 0.0365, 0.0352, 0.0342, 0.0331, 0.0321, 0.0311, 0.0303,
		0.0296, 0.0287, 0.0279, 0.0272, 0.0265, 0.0259, 0.0253, 0.0245, 0.0239, 0.0234,
		0.0229, 0.0224, 0.0219, 0.0213, 0.0209, 0.0206, 0.0201, 0.0197, 0.0192, 0.0189,
	},
	["ROGUE"] = {
		0.4348, 0.4167, 0.4000, 0.3704, 0.3571, 0.3448, 0.3226, 0.3125, 0.3030, 0.2857,
		0.2564, 0.2326, 0.2083, 0.1923, 0.1724, 0.1613, 0.1515, 0.1408, 0.1316, 0.1235,
		0.1163, 0.1111, 0.1053, 0.1010, 0.0952, 0.0909, 0.0877, 0.0840, 0.0806, 0.0769,
		0.0746, 0.0719, 0.0694, 0.0671, 0.0645, 0.0625, 0.0610, 0.0592, 0.0575, 0.0556,
		0.0541, 0.0526, 0.0513, 0.0498, 0.0483, 0.0472, 0.0461, 0.0450, 0.0441, 0.0427,
		0.0418, 0.0410, 0.0400, 0.0392, 0.0383, 0.0375, 0.0368, 0.0360, 0.0353, 0.0345,
	},
	["PRIEST"] = {
		0.1000, 0.1000, 0.1000, 0.0952, 0.0952, 0.0952, 0.0952, 0.0909, 0.0909, 0.0909,
		0.0909, 0.0870, 0.0870, 0.0870, 0.0870, 0.0833, 0.0833, 0.0833, 0.0800, 0.0800,
		0.0800, 0.0800, 0.0769, 0.0769, 0.0769, 0.0741, 0.0741, 0.0741, 0.0714, 0.0714,
		0.0714, 0.0690, 0.0690, 0.0690, 0.0667, 0.0667, 0.0667, 0.0645, 0.0645, 0.0645,
		0.0625, 0.0625, 0.0606, 0.0606, 0.0606, 0.0588, 0.0588, 0.0571, 0.0571, 0.0571,
		0.0556, 0.0556, 0.0541, 0.0541, 0.0526, 0.0526, 0.0513, 0.0513, 0.0500, 0.0500,
	},
	["SHAMAN"] = {
		0.1650, 0.1650, 0.1571, 0.1571, 0.1500, 0.1500, 0.1500, 0.1435, 0.1435, 0.1375,
		0.1375, 0.1320, 0.1320, 0.1269, 0.1222, 0.1179, 0.1179, 0.1138, 0.1138, 0.1065,
		0.1065, 0.1031, 0.1031, 0.0100, 0.0971, 0.0943, 0.0943, 0.0917, 0.0917, 0.0868,
		0.0868, 0.0846, 0.0825, 0.0825, 0.0786, 0.0767, 0.0767, 0.0750, 0.0750, 0.0717,
		0.0702, 0.0702, 0.0688, 0.0673, 0.0660, 0.0647, 0.0635, 0.0623, 0.0623, 0.0600,
		0.0589, 0.0579, 0.0579, 0.0569, 0.0550, 0.0541, 0.0532, 0.0532, 0.0524, 0.0508,
	},
	["MAGE"] = {
		0.0900, 0.0900, 0.0900, 0.0857, 0.0857, 0.0857, 0.0857, 0.0857, 0.0857, 0.0818,
		0.0818, 0.0818, 0.0818, 0.0818, 0.0783, 0.0783, 0.0783, 0.0783, 0.0783, 0.0750,
		0.0750, 0.0750, 0.0750, 0.0720, 0.0720, 0.0720, 0.0720, 0.0720, 0.0692, 0.0692,
		0.0692, 0.0692, 0.0667, 0.0667, 0.0667, 0.0643, 0.0643, 0.0643, 0.0643, 0.0621,
		0.0621, 0.0621, 0.0621, 0.0600, 0.0600, 0.0600, 0.0581, 0.0581, 0.0581, 0.0563,
		0.0563, 0.0563, 0.0545, 0.0545, 0.0545, 0.0529, 0.0529, 0.0529, 0.0514, 0.0514,
	},
	["WARLOCK"] = {
		0.1500, 0.1500, 0.1429, 0.1429, 0.1429, 0.1364, 0.1364, 0.1364, 0.1304, 0.1304,
		0.1250, 0.1250, 0.1250, 0.1200, 0.1154, 0.1111, 0.1111, 0.1111, 0.1071, 0.1034,
		0.1000, 0.1000, 0.0968, 0.0968, 0.0909, 0.0909, 0.0909, 0.0882, 0.0882, 0.0833,
		0.0833, 0.0811, 0.0811, 0.0789, 0.0769, 0.0750, 0.0732, 0.0732, 0.0714, 0.0698,
		0.0682, 0.0682, 0.0667, 0.0667, 0.0638, 0.0625, 0.0625, 0.0612, 0.0600, 0.0588,
		0.0577, 0.0577, 0.0566, 0.0556, 0.0545, 0.0536, 0.0526, 0.0517, 0.0517, 0.0500,
	},
	["DRUID"] = {
		0.2050, 0.2050, 0.1952, 0.1952, 0.1864, 0.1864, 0.1783, 0.1783, 0.1708, 0.1577,
		0.1519, 0.1519, 0.1464, 0.1464, 0.1367, 0.1367, 0.1323, 0.1281, 0.1281, 0.1139,
		0.1139, 0.1108, 0.1079, 0.1079, 0.1025, 0.1025, 0.1000, 0.0976, 0.0976, 0.0891,
		0.0872, 0.0872, 0.0854, 0.0837, 0.0820, 0.0804, 0.0788, 0.0788, 0.0774, 0.0719,
		0.0707, 0.0707, 0.0695, 0.0683, 0.0661, 0.0651, 0.0651, 0.0641, 0.0631, 0.0594,
		0.0586, 0.0577, 0.0569, 0.0569, 0.0554, 0.0547, 0.0539, 0.0532, 0.0526, 0.0500,
	},
}

local spellCritPerIntellect = {
	["WARRIOR"] = {},
	["PALADIN"] = {
		0.0750, 0.0714, 0.0714, 0.0682, 0.0682, 0.0652, 0.0625, 0.0625, 0.0600, 0.0600,
		0.0577, 0.0556, 0.0536, 0.0517, 0.0484, 0.0484, 0.0469, 0.0441, 0.0441, 0.0417,
		0.0405, 0.0395, 0.0385, 0.0375, 0.0357, 0.0349, 0.0349, 0.0333, 0.0326, 0.0313,
		0.0306, 0.0300, 0.0294, 0.0288, 0.0278, 0.0273, 0.0268, 0.0259, 0.0254, 0.0246,
		0.0242, 0.0238, 0.0231, 0.0231, 0.0224, 0.0221, 0.0214, 0.0208, 0.0205, 0.0200,
		0.0197, 0.0195, 0.019, 0.0188, 0.0183, 0.0181, 0.0179, 0.0172, 0.0170, 0.0167,
	},
	["HUNTER"] = {
		0.0700, 0.0667, 0.0667, 0.0636, 0.0636, 0.0609, 0.0609, 0.0583, 0.0583, 0.0560,
		0.0560, 0.0538, 0.0500, 0.0500, 0.0467, 0.0467, 0.0452, 0.0424, 0.0424, 0.0400,
		0.0389, 0.0389, 0.0368, 0.0359, 0.0350, 0.0341, 0.0333, 0.0326, 0.0318, 0.0304,
		0.0298, 0.0298, 0.0286, 0.0280, 0.0269, 0.0264, 0.0264, 0.0255, 0.0250, 0.0241,
		0.0237, 0.0237, 0.0230, 0.0226, 0.0219, 0.0215, 0.0212, 0.0206, 0.0203, 0.0197,
		0.0194, 0.0192, 0.0187, 0.0184, 0.0179, 0.0177, 0.0175, 0.0171, 0.0169, 0.0165,
	},
	["ROGUE"] = {},
	["PRIEST"] = {
		0.1909, 0.1826, 0.1750, 0.1680, 0.1556, 0.1500, 0.1448, 0.1400, 0.1355, 0.1273,
		0.1167, 0.1050, 0.0977, 0.0875, 0.0808, 0.0764, 0.0700, 0.0667, 0.0627, 0.0583,
		0.0560, 0.0525, 0.0506, 0.0477, 0.0457, 0.0438, 0.0420, 0.0404, 0.0389, 0.0372,
		0.0359, 0.0347, 0.0336, 0.0323, 0.0313, 0.0304, 0.0294, 0.0286, 0.0278, 0.0269,
		0.0263, 0.0255, 0.0249, 0.0241, 0.0235, 0.0230, 0.0223, 0.0219, 0.0213, 0.0208,
		0.0204, 0.0199, 0.0195, 0.0191, 0.0186, 0.0183, 0.0179, 0.0176, 0.0171, 0.0168,
	},
	["SHAMAN"] = {
		0.1286, 0.1227, 0.1174, 0.1174, 0.1125, 0.1080, 0.1038, 0.1000, 0.0964, 0.0964,
		0.0900, 0.0844, 0.0771, 0.0730, 0.0675, 0.0643, 0.0614, 0.0574, 0.0551, 0.0519,
		0.0500, 0.0482, 0.0458, 0.0443, 0.0422, 0.0409, 0.0397, 0.0380, 0.0370, 0.0355,
		0.0342, 0.0333, 0.0321, 0.0314, 0.0303, 0.0293, 0.0287, 0.0278, 0.0273, 0.0262,
		0.0257, 0.0252, 0.0245, 0.0239, 0.0233, 0.0227, 0.0223, 0.0218, 0.0213, 0.0208,
		0.0203, 0.0200, 0.0194, 0.0191, 0.0186, 0.0184, 0.0180, 0.0175, 0.0173, 0.0169,
	},
	["MAGE"] = {
		0.1920, 0.1846, 0.1778, 0.1655, 0.1600, 0.1548, 0.1500, 0.1455, 0.1371, 0.1333,
		0.1231, 0.1091, 0.1021, 0.0857, 0.0787, 0.0750, 0.0706, 0.0667, 0.0632, 0.0593,
		0.0571, 0.0539, 0.0522, 0.0495, 0.0475, 0.0457, 0.0436, 0.0397, 0.0381, 0.0366,
		0.0358, 0.0345, 0.0336, 0.0327, 0.0316, 0.0308, 0.0298, 0.0291, 0.0282, 0.0276,
		0.0270, 0.0253, 0.0247, 0.0241, 0.0235, 0.0231, 0.0225, 0.0220, 0.0215, 0.0211,
		0.0207, 0.0203, 0.0199, 0.0194, 0.0190, 0.0181, 0.0177, 0.0175, 0.0171, 0.0168,
	},
	["WARLOCK"] = {
		0.1500, 0.1435, 0.1375, 0.1320, 0.1269, 0.1222, 0.1179, 0.1138, 0.1100, 0.1065,
		0.0971, 0.0892, 0.0825, 0.0767, 0.0717, 0.0688, 0.0635, 0.0600, 0.0569, 0.0541,
		0.0516, 0.0493, 0.0471, 0.0446, 0.0429, 0.0418, 0.0398, 0.0384, 0.0367, 0.0355,
		0.0347, 0.0333, 0.0324, 0.0311, 0.0303, 0.0295, 0.0284, 0.0277, 0.0268, 0.0262,
		0.0256, 0.0248, 0.0243, 0.0236, 0.0229, 0.0224, 0.0220, 0.0214, 0.0209, 0.0204,
		0.0200, 0.0195, 0.0191, 0.0186, 0.0182, 0.0179, 0.0176, 0.0172, 0.0168, 0.0165,
	},
	["DRUID"] = {
		0.1455, 0.1391, 0.1333, 0.1280, 0.1231, 0.1185, 0.1143, 0.1143, 0.1103, 0.1000,
		0.0941, 0.0865, 0.0821, 0.0762, 0.0696, 0.0667, 0.0627, 0.0604, 0.0571, 0.0525,
		0.0508, 0.0485, 0.0471, 0.0444, 0.0427, 0.0416, 0.0400, 0.0390, 0.0372, 0.0352,
		0.0344, 0.0330, 0.0323, 0.0314, 0.0302, 0.0296, 0.0288, 0.0281, 0.0274, 0.0260,
		0.0256, 0.0248, 0.0244, 0.0237, 0.0232, 0.0227, 0.0222, 0.0218, 0.0212, 0.0205,
		0.0201, 0.0196, 0.0194, 0.0189, 0.0185, 0.0182, 0.0179, 0.0176, 0.0172, 0.0167,
	},
}

-- The upstream Shaman level-24 entry is an isolated tenfold outlier.
-- Do not turn that apparent typo into a claimed conversion without live data.
critPerAgility.SHAMAN[24] = nil

local derived = { strength=true, agility=true, stamina=true, intellect=true,
    spirit=true, mp5=true, health=true, mana=true, attackPower=true, rangedAttackPower=true,
    dps=true, rangedDps=true, armor=true, feralAttackPower=true, defense=true }
local manaClasses = { PALADIN=true, HUNTER=true, PRIEST=true, SHAMAN=true,
    MAGE=true, WARLOCK=true, DRUID=true }
local strengthAP = { WARRIOR=2, PALADIN=2, HUNTER=1, ROGUE=1,
    PRIEST=1, SHAMAN=2, MAGE=1, WARLOCK=1, DRUID=2 }
local castingTalents = {
    PALADIN = { node=110871, name="Reverence", rates={0.10,0.20,0.30} },
    PRIEST = { node=105843, name="Meditation", rates={0.17,0.33,0.50} },
    MAGE = { node=105803, name="Arcane Meditation", rates={0.17,0.33,0.50} },
    DRUID = { node=104917, name="Reflection", rates={0.17,0.33,0.50} },
    HUNTER = { node=104963, name="Bestial Discipline", rates={0.25,0.50} },
}
local primaryTalents = {
    PALADIN={strength={{node=105328,name="Divine Strength",rates={.02,.04,.06,.08,.10}}},
        intellect={{node=105332,name="Divine Intellect",rates={.02,.04,.06,.08,.10}}},
        stamina={{node=105632,name="Sacred Duty",rates={.02,.04}}}},
    DRUID={spirit={{node=104911,name="Living Spirit",rates={.05,.10,.15}}},
        intellect={{node=104939,name="Heart of the Wild",rates={.02,.04,.06,.08,.10}}},
        strength={{node=104939,name="Heart of the Wild",rates={.02,.04,.06,.08,.10},form="cat"}},
        stamina={{node=104939,name="Heart of the Wild",rates={.04,.08,.12,.16,.20},form="bear"}}},
    HUNTER={agility={{node=110859,name="Lightning Reflexes",rates={.02,.04,.06,.08,.10}}}},
    MAGE={intellect={{node=105800,name="Arcane Mind",rates={.02,.04,.06,.08,.10}}}},
    PRIEST={intellect={{node=105837,name="Mental Strength",rates={.03,.06,.09,.12,.15}}}},
    SHAMAN={stamina={{node=104746,name="Toughness",rates={.02,.04,.06,.08,.10}}},
        intellect={{node=104756,name="Ancestral Knowledge",rates={.02,.04,.06,.08,.10}}}},
}
local unpack = unpack or table.unpack
local function pack(...) return { n=select("#", ...), ... } end
local function readable(value) return not issecretvalue or not issecretvalue(value) end
local function finite(value)
    return readable(value) and type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function call(fn, ...)
    if type(fn)~="function" then return end
    local values=pack(pcall(fn, ...))
    if values[1] then return unpack(values, 2, values.n) end
end
local function ratio(value, fallback)
    if finite(value) then return math.max(0, math.min(1, value)) end
    return fallback
end
local function number(value) return string.format("%.6g", value) end
local function effectiveStat(index)
    local base, effective=call(UnitStat, "player", index)
    if finite(effective) then return effective end
    if finite(base) then return base end
end
local function context(options)
    local className, class=call(UnitClass, "player")
    local level=call(UnitLevel, "player")
    local actualClass, actualLevel=class, level
    if readable(options.class) and type(options.class)=="string" then class=options.class end
    if finite(options.level) then level=options.level end
    if not readable(class) or type(class)~="string" then class=nil end
    if not finite(level) or level<1 or level~=math.floor(level) then level=nil end
    local names=LOCALIZED_CLASS_NAMES_MALE
    local localized=type(names)=="table" and class and names[class]
    if readable(localized) and type(localized)=="string" then className=localized
    elseif not readable(actualClass) or class~=actualClass or not readable(className) or type(className)~="string" or className==class then
        className=class and (class:sub(1,1) .. class:sub(2):lower()) or nil
    end
    return { class=class, className=className, level=level, live=readable(actualClass) and finite(actualLevel)
        and class==actualClass and level==actualLevel }
end
local function traitRank(node)
    local specialization=call(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup)
    if not finite(specialization) then specialization=call(GetActiveSpecGroup) end
    if not finite(specialization) then specialization=1 end
    local config=call(C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup, specialization)
    if not finite(config) then config=call(C_ClassTalents and C_ClassTalents.GetActiveConfigID) end
    if not finite(config) then return end
    local info=call(C_Traits and C_Traits.GetNodeInfo, config, node)
    if readable(info) and type(info)=="table" and finite(info.activeRank) then
        return math.max(0, math.floor(info.activeRank))
    end
end

function FW:GetDerivedWeightDefaults(profile)
    local defaults={ combatShare=1, castingShare=0.8, whileCastingRegen=0, kings=false, useTalents=true,
        regenSource="Casting-regeneration talent data is unavailable; adjust if needed." }
    local current=context({})
    local talent=current.class and castingTalents[current.class]
    local rank=talent and traitRank(talent.node)
    if rank then
        defaults.whileCastingRegen=talent.rates[rank] or 0
        if rank==0 or talent.rates[rank] then
            defaults.regenSource=talent.name .. " rank " .. rank .. " (current talents)."
        else defaults.regenSource=talent.name .. " rank " .. rank .. " has no verified conversion; adjust if needed." end
    end
    local saved=type(profile)=="table" and profile.calculationOptions
    if type(saved)=="table" then
        for _, key in ipairs({"combatShare","castingShare","whileCastingRegen"}) do
            if finite(saved[key]) then defaults[key]=ratio(saved[key], defaults[key]) end
        end
        for _, key in ipairs({"kings","useTalents"}) do
            if readable(saved[key]) and type(saved[key])=="boolean" then defaults[key]=saved[key] end
        end
        if finite(saved.whileCastingRegen) then defaults.regenSource="Saved casting-regeneration setting." end
    end
    return defaults
end

local function primaryMultiplier(ctx, key, options, defaults)
    local primary=({health="stamina",mana="intellect",mp5="spirit"})[key] or key
    if primary~="strength" and primary~="agility" and primary~="stamina" and primary~="intellect" and primary~="spirit" then
        return 1, nil
    end
    local kings=defaults.kings
    if readable(options.kings) and type(options.kings)=="boolean" then kings=options.kings end
    -- Unlike 'x and false or default', this preserves an explicit false.
    local useTalents=defaults.useTalents
    if readable(options.useTalents) and type(options.useTalents)=="boolean" then useTalents=options.useTalents end
    local multiplier=kings and 1.1 or 1
    local data={primary=primary,kings=kings,useTalents=useTalents,bonuses={},summaries={},supported=false}
    local models=primaryTalents[ctx.class] and primaryTalents[ctx.class][primary]
    local form=ctx.live and call(GetShapeshiftFormID)
    for _, model in ipairs(models or {}) do
        if model.form and not finite(form) then
            data.supported=true
            data.summaries[#data.summaries+1]=model.name .. ": current form unavailable"
            if useTalents then data.unavailable="Current form is unavailable for " .. model.name .. ". Uncheck talent bonuses to use base conversions." end
        end
        local applies=not model.form or (finite(form) and ((model.form=="cat" and form==1) or (model.form=="bear" and (form==5 or form==8))))
        if applies then
            data.supported=true
            local rank=ctx.live and traitRank(model.node)
            local rate=rank and (rank==0 and 0 or model.rates[rank])
            if finite(rate) then
                data.summaries[#data.summaries+1]=model.name .. " " .. rank .. "/" .. #model.rates .. " (+" .. number(rate*100) .. "%)"
                if useTalents then multiplier=multiplier*(1+rate); data.bonuses[#data.bonuses+1]={name=model.name,rate=rate,rank=rank} end
            else
                data.summaries[#data.summaries+1]=model.name .. ": current rank unavailable"
                if useTalents then data.unavailable="Current rank is unavailable for " .. model.name .. ". Uncheck talent bonuses to use base conversions." end
            end
        end
    end
    data.multiplier=multiplier
    return multiplier,data
end

function FW:IsDerivedWeightStat(key) return derived[key]==true end

-- The new Forever APIs accept a stat value. Taking a one-point difference
-- avoids folding a base crit chance or a flat AP bonus into a marginal rate.
local function marginal(fn, statIndex, ctx, scale, increment)
    if not ctx.live then return end
    local stat=effectiveStat(statIndex)
    if not finite(stat) or stat<0 then return end
    local before, after=call(fn, statIndex, stat), call(fn, statIndex, stat+(increment or 1))
    if finite(before) and finite(after) then
        local result=(after-before)*(scale or 1)
        if finite(result) and result>=0 then return result end
    end
end
local function critRate(statIndex, ctx, increment)
    increment=increment or 1
    local fn=statIndex==2 and GetCritChanceFromStat or GetSpellCritChanceFromStat
    local rate=marginal(fn, statIndex, ctx, 100, increment)
    if rate then return rate, "Live client, " .. ctx.class .. " level " .. ctx.level end
    -- Older clients expose only the crit contribution of the current stat.
    -- A total-stat ratio is safe only for the APIs named 'FromAgility/Intellect',
    -- not GetCritChance/GetSpellCritChance, which also include base crit.
    if ctx.live then
        local stat=effectiveStat(statIndex)
        local old=statIndex==2 and GetCritChanceFromAgility or GetSpellCritChanceFromIntellect
        local total=call(old, "player")
        if finite(stat) and stat>0 and finite(total) and total>=0 then
            return total/stat*increment, "Live client stat contribution, " .. ctx.class .. " level " .. ctx.level
        end
    end
    local tableForClass=(statIndex==2 and critPerAgility or spellCritPerIntellect)[ctx.class]
    rate=tableForClass and tableForClass[ctx.level]
    if finite(rate) then return rate*increment, "Vanilla fallback, " .. ctx.class .. " level " .. ctx.level .. " (RatingBuster)" end
end
local function attackRate(statIndex, ranged, ctx, increment)
    increment=increment or 1
    local rate=marginal(ranged and GetRangedAttackPowerForStat or GetAttackPowerForStat, statIndex, ctx, nil, increment)
    if rate then return rate, "Live client" end
    if statIndex==1 then return ranged and 0 or strengthAP[ctx.class]*increment, "Forever base conversion (RatingBuster)" end
    if statIndex==2 then
        if ranged then return (ctx.class=="HUNTER" and 2 or ((ctx.class=="WARRIOR" or ctx.class=="ROGUE") and 1 or 0))*increment, "Forever base conversion (RatingBuster)" end
        if ctx.class=="DRUID" and ctx.live then
            local form=call(GetShapeshiftFormID)
            if not finite(form) then return nil, "Druid form was unavailable." end
            return form==1 and increment or 0, "Vanilla fallback, current druid form"
        end
        return (ctx.class=="HUNTER" or ctx.class=="ROGUE") and increment or 0, "Forever base conversion (RatingBuster)"
    end
    return 0, "Base conversion; talent stat conversions are not included"
end
local function healthRate(ctx, increment)
    increment=increment or 1
    local stamina=ctx.live and effectiveStat(3)
    if not finite(stamina) then return end
    local rate=ctx.live and call(UnitHPPerStamina, "player")
    local native=finite(rate) and rate>0
    if not native then rate=10 end
    local below=math.max(0, math.min(increment, 20-stamina))
    return below+(increment-below)*rate, (native and "Live client" or "Vanilla fallback") .. ", first 20 Stamina give one Health each."
end

local function manaRate(ctx, increment)
    increment=increment or 1
    local intellect=ctx.live and effectiveStat(4)
    if not finite(intellect) then return end
    -- Forever's native character sheet still uses these two constants, with
    -- one Mana per Intellect for the first 20 points. A +1 difference also
    -- handles fractional attributes crossing that breakpoint.
    local breakpoint=finite(INTELLECT_BREAK) and INTELLECT_BREAK>0 and INTELLECT_BREAK or 20
    local perIntellect=finite(MANA_PER_INTELLECT) and MANA_PER_INTELLECT>0 and MANA_PER_INTELLECT or 15
    local below=math.max(0, math.min(increment, breakpoint-intellect))
    return below+(increment-below)*perIntellect, "Forever client constants: first " .. number(breakpoint) .. " Intellect give one Mana each, then " .. number(perIntellect) .. "."
end

local function attackPowerPerDPS()
    if finite(ATTACK_POWER_MAGIC_NUMBER) and ATTACK_POWER_MAGIC_NUMBER>0 then
        return ATTACK_POWER_MAGIC_NUMBER, "Forever client constants: AP to autoattack DPS."
    end
    return 14, "Forever client constants: 14 AP = 1 autoattack DPS."
end

local function armorRate(ctx, options)
    if not ctx.live then return nil, nil, "Armor conversion requires the current character." end
    local _, armor=call(UnitArmor, "player")
    if not finite(armor) or armor<0 then return nil, nil, "Current effective Armor is unavailable." end
    local level=options.attackerLevel
    if not readable(level) then return nil, nil, "Attacker level is unavailable." end
    if level==nil then
        level=call(UnitEffectiveLevel, "player")
        if not finite(level) or level<1 then level=ctx.level end
    end
    if not finite(level) or level<1 or level~=math.floor(level) then return nil, nil, "Attacker level must be a positive whole number." end
    local fn=C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness
    if type(fn)~="function" then return nil, nil, "The Forever Armor mitigation API is unavailable." end
    local before, after=call(fn, armor, level), call(fn, armor+1, level)
    if not finite(before) or not finite(after) or before<0 or after<before or after>1 then
        return nil, nil, "The Forever Armor mitigation API did not return a readable conversion."
    end
    return (after-before)*100, "Live Forever Armor mitigation API", nil,
        { armor=armor, attackerLevel=level, reduction=before*100 }
end

local function sourceLabel(source)
    if not source then return end
    if source:find("Forever Armor",1,true) then return "Live Forever Armor API" end
    if source:find("Live client",1,true) then return "Live game API" end
    if source:find("Forever client constants",1,true) then return "Forever client constants" end
    if source:find("Vanilla",1,true) then return "Vanilla fallback" end
    if source:find("RatingBuster",1,true) then return "Forever: RatingBuster" end
    if source:find("effective MP5",1,true) then return "Regeneration equivalence" end
    if source:find("feral AP",1,true) then return "Classic feral AP conversion" end
    return "Base class conversion"
end

function FW:GetDerivedWeightOptions(key, weights, options)
    options=type(options)=="table" and options or {}
    weights=type(weights)=="table" and weights or {}
    local ctx=context(options)
    local definition=FW.StatByKey and FW.StatByKey[key]
    local label=definition and definition.label or key
    local result={ key=key, available=false, value=0, lines={}, sources={}, params={}, context=ctx,
        title="Calculate " .. tostring(label), contextText=ctx.className and ctx.level and (ctx.className .. " · level " .. ctx.level) or "",
        formula="", assumptions={}, provenance={}, footer="Click to fill the draft. Apply saves changes." }
    result.contributions=result.sources
    local defaults=self:GetDerivedWeightDefaults()
    local increment, modifiers=primaryMultiplier(ctx, key, options, defaults)
    result.modifiers=modifiers
    result.paramLabels={}
    result.paramHelp={}
    if modifiers then
        result.params.kings=true
        result.params.useTalents=modifiers.supported
        result.paramLabels.kings="Blessing of Kings (+10% primary stats)"
        result.paramLabels.useTalents="Apply talent stat bonuses"
        result.talentSummary=table.concat(modifiers.summaries, "; ")
        result.paramHelp.useTalents=result.talentSummary~="" and result.talentSummary or "No verified talent bonus for this stat."
        result.options={kings=modifiers.kings,useTalents=modifiers.useTalents}
    end
    if not derived[key] then result.reason="No reliable direct conversion is available for this attribute."; return result end
    if not ctx.class or not strengthAP[ctx.class] or not ctx.level then
        result.reason="Player class and level are not available yet."; return result
    end
    local failed, seenSources=false, {}
    local function line(value) result.lines[#result.lines+1]=value end
    local function assume(value) result.assumptions[#result.assumptions+1]=value; line(value) end
    local function fail(message) failed=true; result.reason=result.reason or message; line(message) end
    local function weight(stat)
        local value=weights[stat]
        if value==nil then return 0 end
        if not finite(value) then fail("The source weight for " .. stat .. " is not a finite number."); return 0 end
        return value
    end
    local function add(stat, rate, source, suffix)
        local sourceWeight=weight(stat)
        local definition=FW.StatByKey and FW.StatByKey[stat]
        local label=definition and definition.label or stat
        if not finite(rate) then
            if sourceWeight~=0 then fail("The " .. label .. " conversion for this class and level is unavailable.") end
            return
        end
        if rate==0 then return end
        local value=sourceWeight*rate
        if not finite(value) then fail("The calculated weight is outside the supported numeric range."); return end
        result.value=result.value+value
        result.sources[#result.sources+1]={ key=stat, label=label, weight=sourceWeight, rate=rate, value=value, unit=suffix, provenance=source }
        line(number(rate) .. (suffix or "") .. " " .. label .. " × weight " .. number(sourceWeight) .. " = " .. number(value))
        if source then
            line(source)
            local readableSource=sourceLabel(source)
            if not seenSources[readableSource] then
                result.provenance[#result.provenance+1]=readableSource
                seenSources[readableSource]=true
            end
        end
    end
    local function addAttack(statIndex)
        local ap, source=attackRate(statIndex, false, ctx, increment)
        add("attackPower", ap, source)
        local ranged, rangedSource=attackRate(statIndex, true, ctx, increment)
        add("rangedAttackPower", ranged, rangedSource)
    end
    local function addIntellectOther(scale)
        local ap, source=attackRate(4, false, ctx, increment)
        add("attackPower", ap and ap*scale, source)
        local ranged, rangedSource=attackRate(4, true, ctx, increment)
        add("rangedAttackPower", ranged and ranged*scale, rangedSource)
        local crit, critSource=critRate(4, ctx, increment)
        add("crit", crit and crit*scale, critSource, "%")
    end
    line(ctx.class .. " · level " .. ctx.level .. "; weight per 1 " .. (FW.StatByKey and FW.StatByKey[key] and FW.StatByKey[key].label or key))
    if modifiers then
        assume("1 item " .. modifiers.primary .. " adds " .. number(increment) .. " effective " .. modifiers.primary .. ".")
        if modifiers.kings then assume("Kings: +10%; primary-stat bonuses multiply once with talent bonuses.") end
        if modifiers.supported then
            assume((modifiers.useTalents and "Current talents: " or "Talent stat bonuses excluded: ") .. result.talentSummary)
            if modifiers.useTalents and not modifiers.unavailable then
                result.provenance[#result.provenance+1]="Current talent ranks"
                seenSources["Current talent ranks"]=true
            end
        end
        if modifiers.unavailable then fail(modifiers.unavailable) end
    end
    if key=="strength" then
        addAttack(1)
        if ctx.class=="WARRIOR" or ctx.class=="PALADIN" or ctx.class=="SHAMAN" then
            add("blockValue", 0.05*increment, ctx.class=="SHAMAN" and "Vanilla fallback: 20 Strength = 1 shield block value."
                or "Forever base conversion (RatingBuster)")
        end
    elseif key=="agility" then
        addAttack(2)
        add("armorBonus", 2*increment, "Vanilla fallback: armor gained from agility is bonus armor.")
        local rate, source=critRate(2, ctx, increment)
        add("crit", rate, source, "%")
        -- Dodge is a separate conversion: never divide total dodge (which
        -- includes base chance and defense) by agility.
        local fallback=critPerAgility[ctx.class] and critPerAgility[ctx.class][ctx.level]
        add("dodge", fallback and fallback*((ctx.class=="HUNTER" or ctx.class=="ROGUE") and 2 or 1)*increment,
            "Vanilla fallback dodge table, class and level", "%")
    elseif key=="stamina" then
        local rate, source=healthRate(ctx, increment)
        add("health", rate, source)
        assume("First 20 Stamina give 1 Health each; later points use the current Health conversion.")
    elseif key=="health" then
        local rate, source=healthRate(ctx, increment)
        add("stamina", rate and 1/rate, source)
        assume("Uses the next Stamina point at your current Stamina; the first 20 have a different rate.")
    elseif key=="intellect" then
        if manaClasses[ctx.class] then
            local mana, manaSource=manaRate(ctx, increment)
            add("mana", mana, manaSource)
            addIntellectOther(1)
            assume("Mana conversion uses the next Intellect point; temporary maximum-Mana modifiers are not included.")
            assume("First 20 Intellect give 1 Mana each; later points use the client Mana-per-Intellect constant.")
        else addAttack(4) end
    elseif key=="mana" then
        if not manaClasses[ctx.class] then fail("This class does not use mana.")
        else
            local mana, manaSource=manaRate(ctx, increment)
            if not finite(mana) or mana<=0 then fail("Current Intellect is unavailable; Mana per Intellect cannot be checked.")
            else
                add("intellect", 1/mana, manaSource)
                addIntellectOther(-1/mana)
                result.formula="Mana = (Intellect - its other modeled contributions) / " .. number(mana)
                assume("Subtracts Intellect's crit and native AP contributions before converting the remaining weight to Mana.")
                assume("Temporary maximum-Mana modifiers are not included.")
                assume("Uses the next Intellect point, including the first-20 breakpoint.")
                if result.value<0 then assume("Other Intellect contributions exceed its weight; inferred Mana weight is negative.") end
            end
        end
    elseif key=="spirit" or key=="mp5" then
        local combat=ratio(options.combatShare, defaults.combatShare)
        local casting=ratio(options.castingShare, defaults.castingShare)
        local regen=ratio(options.whileCastingRegen, defaults.whileCastingRegen)
        result.params.castingShare,result.params.whileCastingRegen,result.params.combatShare=true,true,key=="mp5"
        result.options=result.options or {}
        result.options.combatShare,result.options.castingShare,result.options.whileCastingRegen=combat,casting,regen
        if not manaClasses[ctx.class] then fail("This class does not use mana.")
        else
            local spirit=ctx.live and effectiveStat(5)
            if not finite(spirit) then fail("Current Spirit is unavailable; the regeneration breakpoint cannot be checked.")
            else
                -- Integrate the next point across the 50-Spirit breakpoint.
                -- A fractional stat near the breakpoint must not get the
                -- entire point priced at the rate on either side.
                local below=math.max(0, math.min(increment, 50-spirit))
                local base=below*1.25+(increment-below)*0.625
                local castingMultiplier=(1-casting)+casting*regen
                local multiplier=key=="spirit" and castingMultiplier or ((1-combat)+combat*castingMultiplier)
                local effective=base*multiplier
                if not seenSources["Forever: RatingBuster"] then
                    result.provenance[#result.provenance+1]="Forever: RatingBuster"
                    seenSources["Forever: RatingBuster"]=true
                end
                result.contextText=result.contextText .. " · " .. number(spirit) .. " Spirit"
                line("Next 1 Spirit = " .. number(base) .. " MP5 before casting reductions (Forever / RatingBuster; breakpoint 50 Spirit).")
                line(number(casting*100) .. "% while casting; " .. number(regen*100) .. "% Spirit regeneration retained while casting.")
                line("Casting-regeneration default: " .. defaults.regenSource .. " Chosen value is shown above.")
                assume(number(casting*100) .. "% under the casting rule; " .. number(regen*100) .. "% Spirit regeneration retained.")
                assume("Before casting reductions, next 1 Spirit gives " .. number(base) .. " MP5 (breakpoint: 50 Spirit).")
                assume("Casting-regeneration default: " .. defaults.regenSource)
                if key=="mp5" then
                    line(number(combat*100) .. "% in combat; casting share applies during that combat time.")
                    assume(number(combat*100) .. "% in combat; casting share applies during combat.")
                    if effective<=0 then fail("Spirit gives no mana at these ratios; an MP5 weight cannot be inferred. Reduce casting/combat time or increase retained regeneration.")
                    else add("spirit", 1/effective, "MP5 = Spirit weight ÷ effective MP5 per Spirit.") end
                else add("mp5", effective, "Spirit = MP5 weight × effective MP5 per Spirit.") end
                assume("Mana regeneration only; health regeneration and other talent conversions are excluded.")
            end
        end
    elseif key=="attackPower" then
        local ap, source=attackPowerPerDPS()
        add("dps", 1/ap, source)
        assume("Autoattack approximation: " .. number(ap) .. " AP equals 1 DPS; special attacks are not modeled.")
    elseif key=="dps" then
        local ap, source=attackPowerPerDPS()
        add("attackPower", ap, source)
        assume("Autoattack approximation: 1 DPS equals " .. number(ap) .. " AP. Special attacks and feral weapon mechanics are not modeled.")
    elseif key=="rangedAttackPower" then
        if ctx.class=="WARRIOR" or ctx.class=="HUNTER" or ctx.class=="ROGUE" then
            local ap, source=attackPowerPerDPS()
            add("rangedDps", 1/ap, source)
            assume("Bow/gun autoattacks only: " .. number(ap) .. " ranged AP equals 1 ranged DPS. Wands are excluded.")
        else fail("This class cannot use an AP-scaled ranged weapon.") end
    elseif key=="rangedDps" then
        if ctx.class=="WARRIOR" or ctx.class=="HUNTER" or ctx.class=="ROGUE" then
            local ap, source=attackPowerPerDPS()
            add("rangedAttackPower", ap, source)
            assume("Bow/gun autoattacks only: 1 ranged DPS equals " .. number(ap) .. " ranged AP. Wands are excluded.")
        else fail("This class cannot use an AP-scaled ranged weapon.") end
    elseif key=="armor" then
        local rate, source, failure, armorContext=armorRate(ctx, options)
        if failure then fail(failure)
        else
            result.armorContext=armorContext
            result.contextText=result.contextText .. " · " .. number(armorContext.armor) .. " Armor · attacker level " .. armorContext.attackerLevel
            add("dodge", rate, source, "%")
            result.formula="Armor = Dodge x " .. number(rate) .. " percentage points of damage reduction"
            -- add() deliberately skips zero rates. At the cap retain the
            -- native provenance and an explicit zero contribution instead.
            if rate==0 then
                result.sources[#result.sources+1]={key="dodge",label="Dodge",rate=0,weight=weight("dodge"),value=0,unit="%",provenance=source}
                result.provenance[#result.provenance+1]="Live Forever Armor API"
                assume("The next Armor point adds no reduction at these values, including at the mitigation cap.")
            end
            assume("Treats 1 percentage point of physical damage reduction as worth 1 percentage point of Dodge.")
            assume("Assumes 1 base Armor adds 1 effective Armor; form/talent Armor multipliers are not included.")
            assume("Current Armor and the selected attacker level set the conversion; this does not equate spell avoidance.")
        end
    elseif key=="feralAttackPower" then
        if ctx.class=="DRUID" then add("attackPower", 1, "One feral AP acts as one AP in cat/bear form.")
        else fail("Feral attack power applies only to druids in cat/bear form.") end
    elseif key=="defense" then
        add("dodge", 0.04, "Vanilla fallback: one defense skill point.", "%")
        local parry=ctx.class=="WARRIOR" or ctx.class=="PALADIN" or ctx.class=="HUNTER" or ctx.class=="ROGUE"
        if ctx.live and type(IsPlayerSpell)=="function" then
            local known=call(IsPlayerSpell, 3127)
            if readable(known) then parry=known==true end
        end
        if parry then add("parry", 0.04, "Vanilla fallback: one defense skill point.", "%") end
        if ctx.class=="WARRIOR" or ctx.class=="PALADIN" or ctx.class=="SHAMAN" then
            add("block", 0.04, "Vanilla fallback: one defense skill point, when using a shield.", "%")
        end
        assume("Reduced enemy hit/crit chance has no matching profile weight and is not included.")
    end
    if not finite(result.value) then fail("The calculated weight is outside the supported numeric range.") end
    result.available=not failed
    if result.formula=="" then
        local terms={}
        for _, contribution in ipairs(result.contributions) do
            local prefix=#terms>0 and (contribution.rate<0 and " - " or " + ") or (contribution.rate<0 and "-" or "")
            terms[#terms+1]=prefix .. number(math.abs(contribution.rate)) .. " x " .. contribution.label
        end
        result.formula=tostring(label) .. " = " .. (#terms>0 and table.concat(terms) or "0")
    end
    if result.available then line("Calculated weight: " .. number(result.value)) end
    if key=="strength" or key=="agility" or key=="stamina" or key=="intellect" then
        assume("Other talent effects beyond supported stat bonuses and native conversions are not included.")
    end
    line("Click once to copy this value into the draft; Apply saves it. Recalculate after a level/form change.")
    return result
end


