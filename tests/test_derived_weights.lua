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
    GetActiveSpecGroup,C_SpecializationInfo,IsPlayerSpell=nil,nil,nil
    C_ClassTalents={GetActiveConfigID=function() return 1 end}
    C_Traits={GetNodeInfo=function() return {activeRank=0} end}
    GetShapeshiftFormID=function() return form end
    UnitArmor=function() return 700,1000,800,200 end
    C_PaperDollInfo,UnitEffectiveLevel=nil,nil
    INTELLECT_BREAK,MANA_PER_INTELLECT,ATTACK_POWER_MAGIC_NUMBER,LOCALIZED_CLASS_NAMES_MALE=nil,nil,nil,nil
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
has(calculate("intellect",{crit=10}).assumptions,"First 20 Intellect")
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

-- Resource equivalence is reversible after removing Intellect's other
-- modeled effects. Mana is one resource point, not MP5 or an invented fight.
reset("PALADIN")
check(FW:IsDerivedWeightStat("mana")); check(FW:IsDerivedWeightStat("dps"))
check(FW:IsDerivedWeightStat("rangedDps")); check(FW:IsDerivedWeightStat("armor"))
local intResult=calculate("intellect",{mana=0.1,crit=10})
close(intResult.value,1.667)
close(calculate("mana",{intellect=intResult.value,crit=10}).value,0.1,"Intellect/Mana inverse removes spell crit")
equal(intResult.title,"Calculate Intellect")
check(intResult.contextText:find("Paladin",1,true))
check(intResult.formula:find("15 x Mana",1,true))
check(intResult.contributions==intResult.sources and #intResult.contributions>0)
check(#intResult.assumptions>0 and #intResult.provenance>0 and #intResult.footer>0)
for _, source in ipairs(intResult.provenance) do check(not source:find("level",1,true),"Sources do not repeat context") end
local negativeMana=FW:GetDerivedWeightOptions("mana",{intellect=0.01,crit=10})
equal(negativeMana.available,false,"Inconsistent nonnegative weights cannot auto-fill negative Mana")
check(negativeMana.value<0)
check(negativeMana.reason:find("exceeds the Intellect weight",1,true))
check(negativeMana.formula:find("other modeled contributions",1,true))
local intentionalNegative=calculate("mana",{intellect=-0.01,crit=10})
check(intentionalNegative.value<0,"Explicitly negative Intellect weights retain intentional negative inference")
reset("HUNTER")
GetAttackPowerForStat=function(index,value) return 10+(index==4 and value*0.5 or 0) end
GetRangedAttackPowerForStat=function(index,value) return 20+(index==4 and value*0.8 or 0) end
local hunterInt=calculate("intellect",{mana=0.2,attackPower=2,rangedAttackPower=3,crit=10}).value
close(calculate("mana",{intellect=hunterInt,attackPower=2,rangedAttackPower=3,crit=10}).value,0.2,"Mana inverse removes native melee and ranged AP as well as crit")
reset()
for _, entry in ipairs({{19,1},{19.5,8},{20,15},{100,15}}) do
    stats[4]=entry[1]
    close(calculate("intellect",{mana=2}).value,entry[2]*2,"First20 Intellect Mana threshold")
    close(calculate("mana",{intellect=entry[2]*2}).value,2,"Inverse uses same next-point threshold")
end
MANA_PER_INTELLECT=18
close(calculate("intellect",{mana=2}).value,36,"Native Mana constant takes priority")
stats[4]=nil
close(calculate("intellect",{crit=10,mana=0}).value,0.167,"Unknown Mana rate does not block zero-weight Mana")
equal(FW:GetDerivedWeightOptions("intellect",{mana=1}).available,false)
equal(FW:GetDerivedWeightOptions("mana",{intellect=1}).available,false)
reset("WARRIOR")
equal(FW:GetDerivedWeightOptions("mana",{intellect=1}).available,false,"Warrior has no Mana resource")

-- Reciprocal autoattack-DPS conversions use the same live client constant.
reset("HUNTER")
local meleeDPS=calculate("dps",{attackPower=0.2}).value
close(meleeDPS,2.8)
close(calculate("attackPower",{dps=meleeDPS}).value,0.2)
local rangedDPS=calculate("rangedDps",{rangedAttackPower=0.3}).value
close(rangedDPS,4.2)
close(calculate("rangedAttackPower",{rangedDps=rangedDPS}).value,0.3)
ATTACK_POWER_MAGIC_NUMBER=10
close(calculate("dps",{attackPower=0.2}).value,2)
close(calculate("attackPower",{dps=2}).value,0.2)
reset("MAGE")
equal(FW:GetDerivedWeightOptions("rangedDps",{rangedAttackPower=1}).available,false,"Wand DPS has no AP equivalence")

-- Armor uses the Forever API and absolute percentage points. This test API
-- yields 20% current DR, then +0.02pp for one Armor: no /(1-currentDR) factor.
reset("PALADIN")
local armorCalls={}
C_PaperDollInfo={GetArmorEffectiveness=function(armor,level)
    armorCalls[#armorCalls+1]={armor,level}; return armor*0.0002
end}
UnitEffectiveLevel=function() return 58 end
local armorResult=calculate("armor",{dodge=10})
close(armorResult.value,0.2,"One pp DR is priced as one pp Dodge")
equal(armorCalls[1][1],1000,"Use effective Armor, second UnitArmor return")
equal(armorCalls[2][1],1001)
equal(armorCalls[1][2],61,"Default attacker is three levels above player effective level")
equal(armorResult.armorContext.playerLevel,58)
equal(armorResult.armorContext.attackerLevel,61)
equal(armorResult.armorContext.attackerLevelOffset,3)
equal(armorResult.options.attackerLevelOffset,3)
check(armorResult.params.attackerLevelOffset,"Armor gear opens attacker-level prompt")
equal(FW:GetDerivedWeightDefaults().attackerLevelOffset,3)
equal(FW:GetDerivedWeightDefaults({calculationOptions={attackerLevelOffset=0}}).attackerLevelOffset,0,"Saved same-level choice stays zero")
equal(FW:GetDerivedWeightDefaults({calculationOptions={attackerLevelOffset=3}}).attackerLevelOffset,3)
equal(FW:GetDerivedWeightDefaults({calculationOptions={attackerLevelOffset=1}}).attackerLevelOffset,3,"Invalid stored offset is not used by defaults")
local sameLevelArmor=calculate("armor",{dodge=10},{attackerLevelOffset=0})
equal(armorCalls[#armorCalls][2],58,"Explicit +0 uses effective level exactly")
equal(sameLevelArmor.armorContext.attackerLevelOffset,0)
equal(sameLevelArmor.options.attackerLevelOffset,0)
check(sameLevelArmor.contextText:find("attacker level 58 (+0)",1,true))
calculate("armor",{dodge=10},{attackerLevelOffset=3})
equal(armorCalls[#armorCalls][2],61,"Explicit +3 matches default")
UnitEffectiveLevel=nil
playerLevel=62
local changedLevelArmor=calculate("armor",{dodge=10})
equal(changedLevelArmor.armorContext.playerLevel,62)
equal(changedLevelArmor.armorContext.attackerLevel,65,"Default follows current level instead of freezing attacker level")
calculate("armor",{dodge=10},{attackerLevelOffset=0})
equal(armorCalls[#armorCalls][2],62,"Same-level setting follows level changes")
playerLevel=60
UnitEffectiveLevel=function() return 58 end
for _, invalidOffset in ipairs({1,-3,3.5,"3",true,math.huge}) do
    equal(FW:GetDerivedWeightOptions("armor",{dodge=10},{attackerLevelOffset=invalidOffset}).available,false,"Only offset0 or3 is supported")
end
has(armorResult.assumptions,"1 percentage point of physical damage reduction")
has(armorResult.assumptions,"form/talent Armor multipliers are not included")
check(armorResult.contextText:find("1000 Armor",1,true))
close(calculate("armor",{dodge=-10},{attackerLevel=63}).value,-0.2,"Negative source weights stay valid")
equal(armorCalls[#armorCalls][2],63,"Explicit attacker level overrides default")
C_PaperDollInfo.GetArmorEffectiveness=function(armor) return math.min(0.75,armor*0.001) end
local capped=calculate("armor",{dodge=10})
close(capped.value,0)
has(capped.assumptions,"next Armor point adds no reduction")
equal(#capped.contributions,1,"Cap result explains the zero contribution")
C_PaperDollInfo.GetArmorEffectiveness=function() error("unavailable") end
equal(FW:GetDerivedWeightOptions("armor",{dodge=10}).available,false,"Native API errors do not use a Vanilla formula")
C_PaperDollInfo=nil
local missingArmorAPI=FW:GetDerivedWeightOptions("armor",{dodge=10},{attackerLevelOffset=0})
equal(missingArmorAPI.available,false,"Missing Forever API does not invent current Armor formula")
check(missingArmorAPI.params.attackerLevelOffset,"Failed preview still exposes level selector")
equal(missingArmorAPI.armorContext.playerLevel,58,"Failed API preserves effective player level for selector captions")
equal(missingArmorAPI.armorContext.attackerLevel,58)
equal(missingArmorAPI.options.attackerLevelOffset,0)
C_PaperDollInfo={GetArmorEffectiveness=function(armor) return armor==1000 and 0.4 or 0.3 end}
equal(FW:GetDerivedWeightOptions("armor",{dodge=10}).available,false,"Negative mitigation slope is rejected")
C_PaperDollInfo.GetArmorEffectiveness=function() return 20 end
equal(FW:GetDerivedWeightOptions("armor",{dodge=10}).available,false,"Do not confuse native fraction with already-percent data")
UnitArmor=function() return 1000 end
equal(FW:GetDerivedWeightOptions("armor",{dodge=10}).available,false,"No total-Armor/base-Armor ratio guesses")

-- Item-primary multipliers apply once, and current ranks are re-read rather
-- than saved in profile options. All reciprocal conversions use the same M.
reset("PALADIN")
local ranks={[105328]=3,[105332]=5,[105632]=2}
C_Traits.GetNodeInfo=function(_,node) return {activeRank=ranks[node] or 0} end
local bonuses={kings=true,useTalents=true}
local strengthBonus=calculate("strength",{attackPower=1},bonuses)
close(strengthBonus.value,2*1.1*1.06)
check(strengthBonus.params.kings and strengthBonus.params.talentRanks)
check(strengthBonus.talentSummary:find("Divine Strength 3/5 (+6%)",1,true))
close(calculate("strength",{attackPower=1},{kings=true,useTalents=false}).value,2.2,"Unchecking talents preserves optional Kings")
close(calculate("strength",{attackPower=1},{kings=false,useTalents=false}).value,2,"Explicit false values do not fall through to defaults")
ranks[105328]=5
close(calculate("strength",{attackPower=1},bonuses).value,2.42,"Live talent changes apply on next calculation")
GetAttackPowerForStat=function(index,value) return 100+value*(index==1 and 2 or 0) end
close(calculate("strength",{attackPower=1},bonuses).value,2.42,"Native AP increment M is not multiplied twice")
GetSpellCritChanceFromStat=function(_,value) return .05+value*.001 end
stats[4]=19.5
local intBonuses=calculate("intellect",{mana=1,crit=2},bonuses)
close(intBonuses.value,11.15+0.121*2,"1.21 effective Intellect crosses first20 exactly")
close(calculate("mana",{intellect=intBonuses.value,crit=2},bonuses).value,1,"Mana inverse accounts for Kings and Divine Intellect")
close(calculate("intellect",{mana=1},{kings=true,useTalents=false}).value,9.5,"Kings crossing first20 differs from scaling old +1 rate")
stats[3]=19.5
local staBonus=calculate("stamina",{health=2},{kings=true,useTalents=false}).value
close(staBonus,13)
close(calculate("health",{stamina=staBonus},{kings=true,useTalents=false}).value,2,"Health inverse includes identical Kings threshold interval")
stats[3]=19
close(calculate("stamina",{health=1},bonuses).value,1+0.144*10,"Sacred Duty multiplies with Kings once across threshold")
stats[5]=49.5
local spiritBonus=calculate("spirit",{mp5=2},{kings=true,castingShare=0}).value
close(spiritBonus,2,"Kings Spirit interval spans both sides of50")
close(calculate("mp5",{spirit=spiritBonus},{kings=true,combatShare=0,castingShare=0}).value,2,"MP5 inverse uses raw Spirit bonus interval")
local savedOptions=FW:GetDerivedWeightDefaults({calculationOptions={kings=true,useTalents=false}})
equal(savedOptions.kings,true); equal(savedOptions.useTalents,false)
C_Traits=nil
local unreadable=FW:GetDerivedWeightOptions("strength",{attackPower=1},{useTalents=true})
equal(unreadable.available,false,"Selected current-talent calculation requires a readable rank")
check(unreadable.params.talentRanks,"User can choose a rank when current talent reading is unavailable")
close(calculate("strength",{attackPower=1},{useTalents=false}).value,2,"Unchecking talents permits explicit base-only fallback")
reset("DRUID")
form=1
C_Traits.GetNodeInfo=function(_,node) return {activeRank=node==104939 and 5 or node==104911 and 3 or 0} end
close(calculate("strength",{attackPower=1},bonuses).value,2.42,"Druid Cat Heart of the Wild affects Strength")
form=5
close(calculate("strength",{attackPower=1},bonuses).value,2.2,"Heart of the Wild Strength is Cat-only")
close(calculate("stamina",{health=1},bonuses).value,13.2,"Bear Stamina uses20% Heart of the Wild")
stats[5]=100
close(calculate("spirit",{mp5=1},{kings=true,castingShare=0}).value,.625*1.1*1.15,"Living Spirit and Kings multiply once")
GetShapeshiftFormID=nil
equal(FW:GetDerivedWeightOptions("stamina",{health=1},bonuses).available,false,"Unknown Druid form cannot claim current talent conversion")
reset("HUNTER")
C_Traits.GetNodeInfo=function(_,node) return {activeRank=node==110859 and 5 or 0} end
close(calculate("agility",{rangedAttackPower=1},bonuses).value,2.42,"Hunter Lightning Reflexes is class-specific")
reset("MAGE")
C_Traits.GetNodeInfo=function(_,node) return {activeRank=node==105800 and 5 or 0} end
close(calculate("intellect",{mana=1},bonuses).value,18.15,"Mage Arcane Mind affects Intellect")
LOCALIZED_CLASS_NAMES_MALE={MAGE="Mage localised"}
check(calculate("intellect",{mana=1},bonuses).contextText:find("Mage localised",1,true))

-- Talent sliders start at live ranks. Only explicit manual values are stored;
-- a later specialization/rank change must refresh an unmodified default.
reset("PALADIN")
equal(FW.DerivedTalentDefinitions["105328"].maxRank,5)
equal(FW.DerivedTalentDefinitions["105332"].name,"Divine Intellect")
equal(FW.DerivedTalentDefinitions["105632"].maxRank,2)
equal(FW.DerivedTalentDefinitions["110871"],nil,"Casting-regeneration talents remain controlled by the existing percentage setting")
local currentRanks={[105328]=3,[105332]=5,[105632]=1}
C_Traits.GetNodeInfo=function(_,node) return {activeRank=currentRanks[node] or 0} end
local currentStrength=calculate("strength",{attackPower=1})
equal(#currentStrength.talentControls,1)
local control=currentStrength.talentControls[1]
equal(control.key,"105328"); equal(control.nodeID,105328); equal(control.maxRank,5)
equal(control.currentRank,3); equal(control.rank,3); equal(control.source,"current")
close(control.effect,.06)
equal(next(FW:GetDerivedWeightDefaults().talentRanks),nil,"Detected ranks are not silently saved as manual overrides")
currentRanks[105328]=5
equal(calculate("strength",{attackPower=1}).talentControls[1].rank,5,"Reopening uses the latest live rank")
local manualStrength=calculate("strength",{attackPower=1},{talentRanks={["105328"]=2}})
close(manualStrength.value,2.08)
equal(manualStrength.talentControls[1].currentRank,5)
equal(manualStrength.talentControls[1].rank,2)
equal(manualStrength.talentControls[1].source,"manual")
close(calculate("strength",{attackPower=1},{talentRanks={["105328"]=0}}).value,2,"Rank-zero override remains zero")
close(calculate("strength",{attackPower=1},{useTalents=false,talentRanks={["105328"]=4}}).value,2.16,"Manual rank wins over a legacy disabled checkbox")
equal(calculate("strength",{attackPower=1},{useTalents=false}).talentControls[1].source,"legacyoff")
for _, invalidRank in ipairs({-1,6,2.5,"2",true,math.huge}) do
    local invalid=FW:GetDerivedWeightOptions("strength",{attackPower=1},{talentRanks={["105328"]=invalidRank}})
    equal(invalid.available,false,"Manual rank must be a whole number within its talent bounds")
    check(invalid.params.talentRanks,"Invalid selected rank remains editable")
end
local stored={calculationOptions={talentRanks={["105332"]=0}}}
local copied=FW:GetDerivedWeightDefaults(stored)
equal(copied.talentRanks["105332"],0)
copied.talentRanks["105332"]=5
equal(stored.calculationOptions.talentRanks["105332"],0,"Calculator defaults do not mutate saved rank maps")
stats[4]=19.5
GetSpellCritChanceFromStat=function(_,value) return .05+value*.001 end
local manualBonuses={kings=true,talentRanks={["105332"]=2}}
local manualInt=calculate("intellect",{mana=1,crit=2},manualBonuses)
close(manualInt.modifiers.multiplier,1.144)
close(manualInt.value,.5+.644*15+.1144*2,"Manual rank applies once across the Intellect breakpoint")
close(calculate("mana",{intellect=manualInt.value,crit=2},manualBonuses).value,1,"Manual ranks preserve inverse Mana equivalence")
has(manualInt.modifierLines,"Divine Intellect 2/5")
has(manualInt.modifierLines,"Kings: +10%")
for _, value in ipairs(manualInt.modifierLines) do
    check(not value:find("fallback",1,true) and not value:find("First 20",1,true) and not value:find("not included",1,true),"Modifiers contain selected bonuses, not general assumptions or sources")
end
C_Traits=nil
close(calculate("strength",{attackPower=1},{talentRanks={["105328"]=1}}).value,2.04,"Manual rank works when current rank cannot be read")
reset("DRUID")
GetShapeshiftFormID=nil
close(calculate("stamina",{health=1},{talentRanks={["104939"]=0}}).value,10,"Explicit zero can omit a form-dependent bonus when form is unknown")

-- Reported level30 case: .3 total Intellect weight cannot contain a .313
-- positive Crit share and still leave a nonnegative Mana value.
reset("PALADIN",30)
local reported=FW:GetDerivedWeightOptions("mana",{intellect=.3,crit=10})
equal(reported.available,false)
close(reported.value,-.00086666666666667)
close(reported.manaBreakdown.intellectWeight,.3)
close(reported.manaBreakdown.otherValue,.313)
close(reported.manaBreakdown.remainingValue,-.013)
equal(reported.contributionHeading,"Intellect breakdown")
equal(reported.contributions[1].operation,"add")
close(reported.contributions[1].displayRate,1)
close(reported.contributions[1].displayValue,.3)
local critShare=reported.contributions[#reported.contributions]
equal(critShare.key,"crit"); equal(critShare.operation,"subtract")
check(critShare.rate<0 and critShare.value<0,"Signed inverse coefficients remain mathematically correct internally")
close(critShare.displayRate,.0313)
close(critShare.displayValue,.313,"UI shows the positive Crit share in Intellect units")
check(reported.reason:find("0.313",1,true) and reported.reason:find("0.3",1,true))
local negativeCrit=calculate("mana",{intellect=.3,crit=-10})
local negativeCritShare=negativeCrit.contributions[#negativeCrit.contributions]
equal(negativeCritShare.operation,"subtract")
check(negativeCritShare.displayValue<0,"Subtracting an intentionally negative source weight must not become subtracting its absolute value")
local almostZero=calculate("mana",{intellect=.313+1e-15,crit=10})
equal(almostZero.value,0,"Cancellation noise is clamped relative to the source values")
local tiny=calculate("mana",{intellect=1e-20})
check(tiny.value>0,"An absolute epsilon must not erase a small but genuine weight")
close(tiny.value/1e-20,1/15)
local scaledInt=calculate("intellect",{mana=2e-12,crit=3e-12}).value
local scaledMana=calculate("mana",{intellect=scaledInt,crit=3e-12}).value
close(scaledMana/1e-12,2,"Reciprocal conversion still works for profiles scaled down by1e-12")

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
