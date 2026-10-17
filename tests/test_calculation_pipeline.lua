-- Exercise calculated weights through real profile persistence, item parsing,
-- score caching and equipment comparison. Run from the addon directory.
local FW, checks = {}, 0
local function check(value, message) assert(value, message); checks=checks+1 end
local function close(actual, expected, message)
    check(type(actual)=="number" and math.abs(actual-expected)<0.0000001,
        (message or "value") .. ": " .. tostring(actual) .. " ~= " .. expected)
end
local intellectRank, clientBuild, conversionCalls, itemReads = 3, 70300, 0, 0
local items = {
    [1000]={name="Intellect helmet",intellect=10},
    [1001]={name="Equipped intellect helmet",intellect=5},
    [1002]={name="Flat mana helmet",mana=150},
}
local function item(link)
    return assert(items[tonumber(link:match("item:(%d+)"))], "Unexpected item " .. tostring(link))
end
UnitClass=function() return "Paladin","PALADIN" end
UnitLevel=function() return 60 end
UnitStat=function() return 100,100,0,0 end
GetShapeshiftFormID=function() return 0 end
GetBuildInfo=function() return "1.60.1",tostring(clientBuild),"Oct 17 2026",16001 end
GetLocale=function() return "enUS" end
GetInventoryItemLink=function(_, slot) if slot==1 then return "item:1001" end end
INTELLECT_BREAK, MANA_PER_INTELLECT = 20, 15
C_ClassTalents={GetActiveConfigID=function() return 7 end}
C_Traits={GetNodeInfo=function(_, node)
    return {activeRank=node==105332 and intellectRank or 0}
end}
GetSpellCritChanceFromStat=function(index, value)
    check(index==4, "the native spell-crit conversion uses Intellect")
    conversionCalls=conversionCalls+1
    -- An additive base chance is deliberately present: only its marginal
    -- contribution (0.02 percentage points per effective Intellect) is relevant.
    return 0.03+value*0.0002
end
GetItemInfo=function(link)
    return item(link).name,link,3,60,60,"Armor","Plate",1,"INVTYPE_HEAD",nil,nil,4,4
end
C_Item={GetItemInfo=GetItemInfo,IsItemDataCachedByID=function() return true end,
    GetItemStats=function(link)
        itemReads=itemReads+1
        local data=item(link)
        return {ITEM_MOD_INTELLECT_SHORT=data.intellect,ITEM_MOD_MANA_SHORT=data.mana}
    end}
C_TooltipInfo={GetHyperlink=function(link)
    local data=item(link)
    local text=data.intellect and ("+" .. data.intellect .. " Intellect") or ("+" .. data.mana .. " Mana")
    return {lines={{leftText=data.name},{leftText=text}}}
end}
CreateFrame=nil
ZwykValuesDB, ZwykPointsDB, ForeverWeightsDB = nil,nil,nil
for _, file in ipairs({"JSON.lua","Stats.lua","Core.lua","DerivedWeights.lua","Items.lua","Compare.lua"}) do
    assert(loadfile(file))("ZwykValues",FW)
end
FW:Initialize()
local oldProfile=assert(FW:ImportProfile('{"intellect":1,"crit":10}',"Old profile"))
close(oldProfile.weights.mana,0,"old weight objects do not acquire an inferred Mana weight")
close(oldProfile.weights.meleeCrit,5,"legacy Crit splits evenly into attack crit")
close(oldProfile.weights.spellCrit,5,"legacy Crit splits evenly into spell crit")
check(oldProfile.weights.crit==nil,"legacy Crit is not retained as a third weight")
local profile=assert(FW:CreateProfile("Caster",{mana=0.25,spellCrit=10,meleeCrit=100}))
assert(FW:UpdateProfile(profile.id,{calculationOptions={kings=true,useTalents=true}}))
local function calculate(key)
    local result=FW:GetDerivedWeightOptions(key,profile.weights,FW:GetDerivedWeightDefaults(profile))
    check(result.available,result.reason or "derived weight must be available")
    return result.value
end

-- Each item Intellect gives 1.166 effective Intellect with Kings and 3/5
-- Divine Intellect. The Mana and crit contributions therefore total 4.6057.
local intellectWeight=calculate("intellect")
close(intellectWeight,4.6057,"calculated Intellect includes the chosen buffs once")
close(FW:GetScore("item:1000",profile),0,"calculation previews do not change applied weights")
assert(FW:UpdateProfile(profile.id,{weights={intellect=intellectWeight}}))
local score,record=FW:GetScore("item:1000",profile)
close(score,46.057,"the item score uses the applied Intellect weight")
close(record.stats.intellect,10,"the parser retains raw item Intellect")
check(record.stats.mana==nil and record.percentStats.meleeCrit==nil and record.percentStats.spellCrit==nil,
    "item parsing does not add Mana, crit or buffed attributes a second time")
close(FW:GetScore("item:1002",profile),37.5,"flat Mana is weighted without Kings or Divine Intellect")
local comparison=assert(FW:CompareItem("item:1000",profile))
close(comparison.comparisons[1].baseline,23.0285,"equipped gear uses the same applied weight")
close(comparison.comparisons[1].delta,23.0285)
check(comparison.comparisons[1].status=="upgrade","the real comparison pipeline sees the upgrade")
close(calculate("mana"),0.25,"Mana uses spell Crit alone, ignoring the different melee Crit weight")

local callsAfterCalculation=conversionCalls
local readsAfterParsing=itemReads
for _=1,10 do close(FW:GetScore("item:1000",profile),46.057) end
check(conversionCalls==callsAfterCalculation,"hover scoring never reruns stat conversion calculations")
check(itemReads==readsAfterParsing,"repeated scores reuse parsed item data")
intellectRank=5
local changedWeight=calculate("intellect")
close(changedWeight,4.7795,"a fresh calculation reads the current talent rank")
close(profile.weights.intellect,4.6057,"talent changes do not silently rewrite applied profile weights")
close(FW:GetScore("item:1000",profile),46.057,"existing cached scores remain stable until Apply")
assert(FW:UpdateProfile(profile.id,{weights={intellect=changedWeight}}))
close(FW:GetScore("item:1000",profile),47.795,"Apply replaces the weight and refreshes its score")
close(FW:GetScore("item:1002",profile),37.5,"changing Intellect assumptions leaves flat Mana unchanged")
check(itemReads==readsAfterParsing,"applying a weight reuses item stats instead of parsing again")

-- Conversion talents change the chosen weight, never the item's raw stats.
-- Manual Champion rank 2 adds spell damage only, after Kings/Divine Intellect.
assert(FW:UpdateProfile(profile.id,{weights={spellDamage=2,healing=7},
    calculationOptions={talentRanks={["110882"]=2}}}))
local withChampion=calculate("intellect")
close(withChampion,5.7475,"older Champion rank 2 contributes 40% spell damage, with no healing")
assert(FW:UpdateProfile(profile.id,{weights={intellect=withChampion}}))
close(calculate("mana"),0.25,"Mana inverse removes Champion's same spell-damage share")
close(FW:GetScore("item:1000",profile),57.475,"the item uses the applied talent-aware weight once")
check(itemReads==readsAfterParsing,"talent edits reuse parsed item stats")
clientBuild=70425
local updatedChampion=calculate("intellect")
close(updatedChampion,5.2635,"new build changes Champion rank 2 to 20% spell damage")
close(profile.weights.intellect,withChampion,"build changes require recalculation and Apply")
assert(FW:UpdateProfile(profile.id,{weights={intellect=updatedChampion}}))
local updatedScore,updatedRecord=FW:GetScore("item:1000",profile)
close(updatedScore,52.635,"Apply refreshes scores with the new conversion")
close(calculate("mana"),0.25,"new build forward and inverse coefficients remain consistent")
close(FW:GetScore("item:1002",profile),37.5,"conversion talents never modify flat-Mana item scoring")
check(updatedRecord.stats.spellDamage==nil and updatedRecord.stats.healing==nil,
    "conversion talents do not inject spell damage or healing into parsed item stats")
local readsAtNewBuild=itemReads
close(FW:GetScore("item:1000",profile),52.635)
check(itemReads==readsAtNewBuild,"the new build's parsed stats remain cached")
print("Calculation-to-item pipeline: " .. checks .. " checks passed.")
