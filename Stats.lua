local _, FW = ...

-- Explicit stat keys; legacy combined crit is normalized when weights are imported.
-- Secondary weights always mean one percentage point (defense uses one skill
-- point). The editor can display equivalent per-rating weights; scoring and
-- calculator inputs remain in these canonical units.
FW.StatDefinitions = {
    { key = "strength", label = "Strength", group = "Attributes" },
    { key = "agility", label = "Agility", group = "Attributes" },
    { key = "stamina", label = "Stamina", group = "Attributes" },
    { key = "intellect", label = "Intellect", group = "Attributes" },
    { key = "spirit", label = "Spirit", group = "Attributes" },
    { key = "health", label = "Health", group = "Resources" },
    { key = "mana", label = "Mana", group = "Resources" },
    { key = "hp5", label = "Health per 5 seconds", group = "Resources" },
    { key = "spellDamage", label = "Spell damage", group = "Spell" },
    { key = "healing", label = "Healing", group = "Spell" },
    { key = "spellPen", label = "Spell penetration", group = "Spell" },
    { key = "mp5", label = "Mana per 5 seconds", group = "Resources" },
    { key = "arcaneDamage", label = "Arcane damage", group = "Spell" },
    { key = "fireDamage", label = "Fire damage", group = "Spell" },
    { key = "natureDamage", label = "Nature damage", group = "Spell" },
    { key = "frostDamage", label = "Frost damage", group = "Spell" },
    { key = "shadowDamage", label = "Shadow damage", group = "Spell" },
    { key = "holyDamage", label = "Holy damage", group = "Spell" },
    { key = "attackPower", label = "Attack power", group = "Attack" },
    { key = "feralAttackPower", label = "Feral attack power", group = "Attack" },
    { key = "dps", label = "Melee weapon DPS", group = "Weapon" },
    { key = "lowDamage", label = "Weapon minimum damage", group = "Weapon" },
    { key = "highDamage", label = "Weapon maximum damage", group = "Weapon" },
    { key = "weaponDamage", label = "Flat added weapon damage", group = "Weapon" },
    { key = "speed", label = "Melee weapon speed", group = "Weapon" },
    { key = "hit", label = "Hit", group = "Secondary", secondary = true },
    { key = "meleeCrit", label = "Melee critical strike", group = "Secondary", secondary = true },
    { key = "spellCrit", label = "Spell critical strike", group = "Secondary", secondary = true },
    { key = "haste", label = "Haste", group = "Secondary", secondary = true },
    { key = "expertise", label = "Expertise", group = "Secondary", secondary = true },
    { key = "rangedDps", label = "Ranged weapon DPS", group = "Weapon" },
    { key = "rangedSpeed", label = "Ranged weapon speed", group = "Weapon" },
    { key = "rangedAttackPower", label = "Ranged attack power", group = "Attack" },
    { key = "armor", label = "Base armor", group = "Defense" },
    { key = "armorBonus", label = "Bonus armor", group = "Defense" },
    { key = "defense", label = "Defense", group = "Secondary", secondary = true },
    { key = "dodge", label = "Dodge", group = "Secondary", secondary = true },
    { key = "parry", label = "Parry", group = "Secondary", secondary = true },
    { key = "block", label = "Block chance", group = "Secondary", secondary = true },
    { key = "blockValue", label = "Block value", group = "Defense" },
    { key = "blockValueBonus", label = "Bonus block value", group = "Defense" },
    { key = "arcaneResist", label = "Arcane resistance", group = "Resistance" },
    { key = "fireResist", label = "Fire resistance", group = "Resistance" },
    { key = "natureResist", label = "Nature resistance", group = "Resistance" },
    { key = "frostResist", label = "Frost resistance", group = "Resistance" },
    { key = "shadowResist", label = "Shadow resistance", group = "Resistance" },
}

FW.StatByKey = {}
for _, definition in ipairs(FW.StatDefinitions) do
    FW.StatByKey[definition.key] = definition
end

-- WoWSims Forever's level-60 export units. These constants intentionally match
-- ui/sim/constants/mechanics.ts, rather than TBC/retail level scaling. They
-- convert WEIGHTS for display/import only, never the player's primary stats.
local ratingPerPercent = {
    crit = 14, meleeCrit = 14, spellCrit = 14,
    hit = 10, haste = 10, expertise = 10,
    dodge = 12, parry = 15, block = 5, defense = 1,
}

function FW:GetRatingPerPercent(key)
    return ratingPerPercent[key]
end

function FW:WeightToDisplay(key, value, unit)
    local rate = ratingPerPercent[key]
    return unit == "rating" and rate and value / rate or value
end

function FW:WeightFromDisplay(key, value, unit)
    local rate = ratingPerPercent[key]
    return unit == "rating" and rate and value * rate or value
end

-- Keep the explicit scoring channels, even though the editor presents their
-- sum. The remainder avoids increasing generic crit through rounding twice.
function FW:DistributeCritWeight(total, meleeShare)
    local melee = total * meleeShare
    return melee, total - melee
end

function FW:GetCritDistribution(weights, fallbackShare)
    local melee, spell = (weights and weights.meleeCrit) or 0, (weights and weights.spellCrit) or 0
    local total = melee + spell
    local share = fallbackShare or 0.5
    if total ~= 0 then
        local inferred = melee / total
        if inferred >= 0 and inferred <= 1 then return total, inferred, true end
    elseif melee == 0 and spell == 0 then
        return total, share, true
    end
    -- Opposite-sign legacy weights cannot be represented by a 0..100% split.
    -- Callers preserve that exact pair until the user edits the total or split.
    return total, share, false
end
