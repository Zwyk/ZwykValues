-- Fixed game-data-derived coefficients from wowsims/forever commit
-- bd2f6ae0a9ef8b5741666c650ebc7149316366a7, base_stats_auto_gen.go.
-- Numbers here are percentage points, not ratings or fractions.
local FW, checks = {}, 0
for _, file in ipairs({"Stats.lua", "DerivedWeights.lua"}) do assert(loadfile(file))("ZwykValues", FW) end
local function check(value, message) checks=checks+1; assert(value, message or "check failed") end
local function close(actual, expected, message)
    check(type(actual)=="number" and math.abs(actual-expected)<1e-10,
        (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local class, level, spirit = "PALADIN", 60, 10
UnitClass=function() return class, class end
UnitLevel=function() return level end
UnitStat=function(_, index) local amount=index==5 and spirit or 100; return amount, amount, 0, 0 end
GetShapeshiftFormID=function() return 0 end
C_ClassTalents={GetActiveConfigID=function() return 1 end}
C_Traits={GetNodeInfo=function() return {activeRank=0} end}
local opts={useTalents=false,kings=false,combatShare=1,castingShare=0}
local function calculate(key, weights, options)
    local result=FW:GetDerivedWeightOptions(key, weights, options or opts)
    check(result.available, result.reason)
    return result
end
local function source(result, key)
    for _, row in ipairs(result.sources) do if row.key==key then return row end end
end
local expected={
    WARRIOR={.05,0,.05,2}, PALADIN={.0506,.0167,.0506,2},
    HUNTER={.0189,.0165,.0378,1}, ROGUE={.0345,0,.069,1},
    PRIEST={.05,.0168,.05,1}, SHAMAN={.0508,.0169,.0508,2},
    MAGE={.0514,.0168,.0514,1}, WARLOCK={.05,.0165,.05,1}, DRUID={.05,.0167,.05,2},
}
check(FW.ForeverConversionReference.level==60)
check(FW.ForeverConversionReference.revision=="bd2f6ae0a9ef8b5741666c650ebc7149316366a7")
for token, values in pairs(expected) do
    class=token
    local agility=calculate("agility",{meleeCrit=1,dodge=1,armorBonus=1})
    close(source(agility,"meleeCrit").rate,values[1],token .. " crit / Agility")
    close(source(agility,"dodge").rate,values[3],token .. " dodge / Agility")
    close(source(agility,"armorBonus").rate,2,token .. " armor / Agility")
    close(agility.value,values[1]+values[3]+2)
    check(source(agility,"meleeCrit").provenance:find("WoWSims Forever level 60",1,true))
    local intellect=calculate("intellect",{spellCrit=1})
    close(intellect.value,values[2],token .. " crit / Intellect")
    close(calculate("strength",{attackPower=1}).value,values[4],token .. " AP / Strength")
    close(calculate("stamina",{health=1}).value,10,token .. " health / Stamina")
    if values[2]>0 then
        close(calculate("intellect",{mana=1}).value,15)
        close(calculate("spirit",{mp5=1}).value,.625,token .. " low Spirit has no mana breakpoint at60")
        close(calculate("mp5",{spirit=.625}).value,1,token .. " reverse mana coefficient")
    else check(not FW:GetDerivedWeightOptions("mp5",{},opts).available) end
end
class="PALADIN"
close(calculate("agility",{meleeCrit=14}).value,.0506*14,"ratings must not be applied to the per-percent source rate")
close(calculate("intellect",{spellCrit=1}).value,.0167)
-- Native client differences override the pinned snapshot, including an offset
-- that must be removed by taking the additional stat point's contribution.
GetCritChanceFromStat=function(_, value) return .1+value*.000123 end
local live=calculate("agility",{meleeCrit=1})
close(live.value,.0123)
check(source(live,"meleeCrit").provenance:find("Live client",1,true))
GetCritChanceFromStat=nil
level=59
local lower=calculate("agility",{meleeCrit=1})
close(lower.value,.0518)
check(source(lower,"meleeCrit").provenance:find("Vanilla fallback",1,true))
check(not source(lower,"meleeCrit").provenance:find("WoWSims",1,true))
level=61
check(not FW:GetDerivedWeightOptions("agility",{meleeCrit=1},opts).available,"do not extrapolate level60 data")
level=60
class="HUNTER"
local hunter=calculate("agility",{attackPower=1,rangedAttackPower=1})
close(source(hunter,"attackPower").rate,1)
close(source(hunter,"rangedAttackPower").rate,2)
class="PALADIN"
UnitArmor=function() return 1000,1000,0,0 end
C_PaperDollInfo=nil
check(not FW:GetDerivedWeightOptions("armor",{dodge=1},opts).available,
    "the sim's legacy armor curve must not replace the client's verified API")
print("Forever conversion audit: " .. checks .. " checks passed.")
