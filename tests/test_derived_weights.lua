-- Run from the addon directory: luatex --luaonly tests/test_derived_weights.lua
local addonPath=(arg and arg[1]) or "."
local FW={}
assert(loadfile(addonPath .. "/Stats.lua"))("ZwykValues", FW)
assert(loadfile(addonPath .. "/DerivedWeights.lua"))("ZwykValues", FW)
local passed=0
local function check(value, message) assert(value, message or "assertion failed"); passed=passed+1 end
local function equal(actual, expected, message) check(actual==expected, (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected)) end
local function close(actual, expected, message) check(type(actual)=="number" and math.abs(actual-expected)<0.0000001, (message or "number") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected)) end
local function has(lines, fragment)
    for _, line in ipairs(lines) do if line:find(fragment,1,true) then passed=passed+1; return end end
    error("Missing explanation: " .. fragment)
end
local playerClass, playerLevel, stats, form="PALADIN",60,{20,100,100,100,100},0
UnitClass=function() return playerClass,playerClass end
UnitLevel=function() return playerLevel end
UnitStat=function(_, index) return stats[index],stats[index],0,0 end
GetShapeshiftFormID=function() return form end
local function reset(class, level)
    playerClass,playerLevel=class or "PALADIN",level or 60
    stats,form={20,100,100,100,100},0
    GetCritChanceFromStat,GetSpellCritChanceFromStat=nil,nil
    GetCritChanceFromAgility,GetSpellCritChanceFromIntellect=nil,nil
    GetAttackPowerForStat,GetRangedAttackPowerForStat,UnitHPPerStamina=nil,nil,nil
    GetActiveSpecGroup,C_SpecializationInfo,C_ClassTalents,C_Traits,IsPlayerSpell=nil,nil,nil,nil,nil
    issecretvalue=nil
end
local function calculate(key, weights, options)
    local result=FW:GetDerivedWeightOptions(key,weights,options)
    check(result.available, result.reason)
    return result
end

check(FW:IsDerivedWeightStat("strength"))
check(FW:IsDerivedWeightStat("spirit"))
check(FW:IsDerivedWeightStat("mp5"))
equal(FW:IsDerivedWeightStat("haste"),false)
equal(FW:GetDerivedWeightOptions("haste",{}).available,false)
reset()
close(calculate("strength",{attackPower=0.1,blockValue=0.1}).value,0.205)
has(calculate("strength",{attackPower=0.1}).lines,"2 Attack power")
has(calculate("strength",{attackPower=0.1}).lines,"Click once")
reset("HUNTER")
close(calculate("strength",{attackPower=0.1,blockValue=10,rangedAttackPower=10}).value,0.1,"Hunter Strength must not gain ranged AP or shield block")
reset("SHAMAN")
close(calculate("strength",{attackPower=0.1,blockValue=2}).value,0.3)
has(calculate("strength",{blockValue=2}).lines,"Vanilla fallback: 20 Strength")

reset("ROGUE",60)
close(calculate("agility",{attackPower=0.1,rangedAttackPower=0.2,armorBonus=0.05,crit=10,dodge=2}).value,0.883)
has(calculate("agility",{crit=10}).lines,"Vanilla fallback")
reset("PALADIN",20)
close(calculate("agility",{armorBonus=0.05,crit=10,dodge=2}).value,1.5748)
playerLevel=60
close(calculate("agility",{armorBonus=0.05,crit=10,dodge=2}).value,0.7072,"Different level uses exact table row")
reset("SHAMAN",24)
equal(FW:GetDerivedWeightOptions("agility",{crit=1}).available,false,"Reject upstream tenfold outlier")
close(calculate("agility",{armorBonus=0.5}).value,1,"Missing zero-weight rates do not block known contributions")
reset("PALADIN",61)
equal(FW:GetDerivedWeightOptions("agility",{crit=1}).available,false,"Do not extrapolate beyond Classic fallback tables")
reset("DRUID",60)
form=1
close(calculate("agility",{attackPower=1}).value,1,"Cat agility gives AP")
form=5
close(calculate("agility",{attackPower=1}).value,0,"Bear agility does not give AP")
GetShapeshiftFormID=nil
equal(FW:GetDerivedWeightOptions("agility",{attackPower=1}).available,false,"Druid form must be known for AP conversion")

reset("MAGE",60)
close(calculate("intellect",{crit=10}).value,0.168)
playerLevel=1
close(calculate("intellect",{crit=10}).value,1.92)
has(calculate("intellect",{crit=10}).lines,"no Mana weight")
reset("WARRIOR",60)
close(calculate("intellect",{crit=10}).value,0,"Non-mana classes do not get an invented spell crit conversion")

reset()
close(calculate("stamina",{health=2}).value,20)
close(calculate("health",{stamina=2}).value,0.2)
stats[3]=19
UnitHPPerStamina=function() return 12 end
close(calculate("stamina",{health=2}).value,2,"First 20 Stamina always give one health")
stats[3]=20
close(calculate("stamina",{health=2}).value,24,"Native current class/form health multiplier wins after threshold")
stats[3]=19.5
close(calculate("stamina",{health=2}).value,13,"Next point crossing threshold is split correctly")
stats[3]=nil
equal(FW:GetDerivedWeightOptions("stamina",{health=2}).available,false,"Unknown stamina does not guess threshold side")

reset()
-- Native APIs may include offsets. The finite difference must remove them,
-- and Forever's stat crit API is a fraction, unlike profile percentage points.
GetCritChanceFromStat=function(index,value) equal(index,2); return 0.05+value*0.0004 end
GetSpellCritChanceFromStat=function(index,value) equal(index,4); return 0.08+value*0.0002 end
close(calculate("agility",{crit=10}).value,0.4)
close(calculate("intellect",{crit=10}).value,0.2)
has(calculate("agility",{crit=10}).lines,"Live client, PALADIN level 60")
GetAttackPowerForStat=function(index,value) return 100+value*(index==1 and 3 or 0) end
GetRangedAttackPowerForStat=function(index,value) return 40+value*(index==1 and 0.5 or 0) end
close(calculate("strength",{attackPower=0.2,rangedAttackPower=0.4,blockValue=0}).value,0.8,"Native AP derivatives include current class/form behavior and strip offsets")
close(calculate("agility",{attackPower=4,rangedAttackPower=5}).value,0,"Explicit zero native AP conversion must not fall back")
GetCritChanceFromStat=function() error("not readable in combat") end
close(calculate("agility",{crit=10}).value,0.506,"API failures use labelled current-level fallback")
GetCritChanceFromAgility=function() return 3 end
close(calculate("agility",{crit=10}).value,0.3,"Older dedicated stat-contribution API remains supported")
local secret={}
issecretvalue=function(value) return value==secret end
GetCritChanceFromAgility=function() return secret end
GetCritChanceFromStat=function() return secret end
close(calculate("agility",{crit=10}).value,0.506,"Secret conversion values never enter arithmetic")
equal(FW:GetDerivedWeightOptions("strength",{attackPower=secret}).available,false)
issecretvalue=nil

reset()
close(calculate("spirit",{mp5=10},{castingShare=0,whileCastingRegen=0}).value,6.25)
close(calculate("spirit",{mp5=10},{castingShare=1,whileCastingRegen=0}).value,0)
close(calculate("spirit",{mp5=10},{castingShare=1,whileCastingRegen=0.3}).value,1.875)
close(calculate("spirit",{mp5=-2},{castingShare=0}).value,-1.25,"Negative source weights are valid")
stats[5]=49
close(calculate("spirit",{mp5=1},{castingShare=0}).value,1.25)
stats[5]=50
close(calculate("spirit",{mp5=1},{castingShare=0}).value,0.625,"Point beyond 50 uses next-point rate")
stats[5]=49.5
close(calculate("spirit",{mp5=1},{castingShare=0}).value,0.9375,"Spirit point crossing 50 uses both slopes")
stats[5]=100
close(calculate("mp5",{spirit=1},{combatShare=0,castingShare=1,whileCastingRegen=0}).value,1.6)
close(calculate("mp5",{spirit=1},{combatShare=1,castingShare=1,whileCastingRegen=0.3}).value,1/0.1875)
close(calculate("mp5",{spirit=1},{combatShare=0.5,castingShare=1,whileCastingRegen=0}).value,3.2)
local unavailable=FW:GetDerivedWeightOptions("mp5",{spirit=1},{combatShare=1,castingShare=1,whileCastingRegen=0})
equal(unavailable.available,false,"Never divide by zero at no mana regeneration")
check(unavailable.params.combatShare and unavailable.params.castingShare and unavailable.params.whileCastingRegen)
has(unavailable.lines,"cannot be inferred")
check(calculate("spirit",{mp5=1}).params.combatShare==false)
has(calculate("spirit",{mp5=1},{whileCastingRegen=0.7}).lines,"Chosen value is shown above")
stats[5]=nil
equal(FW:GetDerivedWeightOptions("spirit",{mp5=1}).available,false)
reset("ROGUE")
equal(FW:GetDerivedWeightOptions("spirit",{mp5=1}).available,false,"Rogue has no mana conversion")
equal(FW:GetDerivedWeightOptions("mp5",{spirit=1}).available,false)

reset()
local selectedGroup,selectedNode
C_SpecializationInfo={GetActiveSpecGroup=function() return 2 end,
    GetCombatConfigIDForSpecGroup=function(group) selectedGroup=group; return 123 end}
C_Traits={GetNodeInfo=function(config,node) equal(config,123); selectedNode=node; return {activeRank=2} end}
local defaults=FW:GetDerivedWeightDefaults()
equal(selectedGroup,2,"Read currently active spec group rather than first spec")
equal(selectedNode,110871,"Read Forever Reverence node")
close(defaults.whileCastingRegen,0.2)
check(defaults.regenSource:find("Reverence rank 2",1,true))
defaults=FW:GetDerivedWeightDefaults({calculationOptions={combatShare=0.2,castingShare=0.4,whileCastingRegen=0.7}})
close(defaults.combatShare,0.2); close(defaults.castingShare,0.4); close(defaults.whileCastingRegen,0.7)
equal(defaults.regenSource,"Saved casting-regeneration setting.")
reset("PRIEST")
C_ClassTalents={GetActiveConfigID=function() return 456 end}
C_Traits={GetNodeInfo=function(config,node) equal(config,456);equal(node,105843);return {activeRank=3} end}
close(FW:GetDerivedWeightDefaults().whileCastingRegen,0.5,"Priest meditation rank mapping differs from Paladin")
reset("MAGE")
C_ClassTalents={GetActiveConfigID=function() return 456 end}
C_Traits={GetNodeInfo=function(_,node) equal(node,105803); return {activeRank=1} end}
close(FW:GetDerivedWeightDefaults().whileCastingRegen,0.17)
reset()
C_ClassTalents={GetActiveConfigID=function() return 456 end}
C_Traits={GetNodeInfo=function() error("not ready") end}
close(FW:GetDerivedWeightDefaults().whileCastingRegen,0,"Talent API failure yields editable zero default")

reset("WARRIOR")
close(calculate("attackPower",{dps=14}).value,1)
has(calculate("attackPower",{dps=14}).lines,"special attacks are not modeled")
close(calculate("rangedAttackPower",{rangedDps=28}).value,2)
reset("MAGE")
equal(FW:GetDerivedWeightOptions("rangedAttackPower",{rangedDps=28}).available,false,"Wands never gain ranged AP DPS")
reset("DRUID")
close(calculate("feralAttackPower",{attackPower=0.4}).value,0.4)
reset("PALADIN")
equal(FW:GetDerivedWeightOptions("feralAttackPower",{attackPower=0.4}).available,false)
close(calculate("defense",{dodge=2,parry=3,block=5}).value,0.4)
IsPlayerSpell=function() return false end
close(calculate("defense",{dodge=2,parry=3,block=5}).value,0.28,"Unlearned parry contributes nothing")
reset("DRUID")
close(calculate("defense",{dodge=2,parry=3,block=5}).value,0.08,"Druids cannot parry or block")

reset()
local draft={attackPower=0.2,crit=10,mp5=2}
calculate("strength",draft)
equal(draft.strength,nil,"Calculating never mutates draft source weights")
equal(draft.attackPower,0.2)
equal(FW:GetDerivedWeightOptions("strength",{attackPower=math.huge}).available,false)
equal(FW:GetDerivedWeightOptions("strength",{attackPower=0/0}).available,false)
equal(FW:GetDerivedWeightOptions("strength",{attackPower=1e308}).available,false,"Overflow is unavailable")
UnitLevel=function() return nil end
equal(FW:GetDerivedWeightOptions("strength",{}).available,false)
UnitLevel=function() return 60 end
UnitClass=function() return "Unknown","EVOKER" end
equal(FW:GetDerivedWeightOptions("strength",{}).available,false)
print("Derived weight tests passed: " .. passed)
