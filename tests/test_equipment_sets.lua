local FW={}
local guid="Player-1-First"
UnitGUID=function() return guid end
local calls={options=0,info=0,locations=0,links=0}
local sets={
    [7]={name="Retribution",icon=107,locations={[1]=101,[5]=105,[11]=211,[12]=0,[13]=1,[14]=-1,[16]=216,[17]=0,[18]=318},
        ids={[1]=1001,[5]=1005,[11]=1011,[14]=1014,[16]=1016,[18]=1018},ignored={[13]=true}},
    [4]={name="Healing",icon=104,locations={},ids={},ignored={}},
}
C_EquipmentSet={
    GetEquipmentSetIDs=function() calls.options=calls.options+1; return {7,4} end,
    GetEquipmentSetInfo=function(id)
        calls.info=calls.info+1
        local set=sets[id]
        if set then return set.name,set.icon,id,false end
    end,
    GetItemLocations=function(id) calls.locations=calls.locations+1; return sets[id] and sets[id].locations end,
    GetItemIDs=function(id) return sets[id] and sets[id].ids end,
    GetIgnoredSlots=function(id) return sets[id] and sets[id].ignored end,
}
local bagLinks={
    [0]={[11]="|Hitem:1011:321:::::55:31|h[Random ring]|h"},
    [5]={[18]="item:1018:777:::::9:31"},
}
local inventoryLinks={[1]="item:1001:123:::::4:31",[5]="item:1005:789:::::0:31",[16]="item:1016:999:::::6:31"}
-- Simulate the native unpacker's returned locations, including a bank bag.
EquipmentManager_GetLocationData=function(location)
    if location==318 then return {isBank=true,isBags=true,bag=5,slot=18} end
    if location>=200 then return {isPlayer=true,isBags=true,bag=0,slot=location-200} end
    return {isPlayer=true,slot=location-100}
end
ItemLocation={
    CreateFromBagAndSlot=function(_,bag,slot) return {bagID=bag,slotIndex=slot} end,
    CreateFromEquipmentSlot=function(_,slot) return {equipmentSlotIndex=slot} end,
}
C_Item={GetItemLink=function(location)
    calls.links=calls.links+1
    if location.bagID then return bagLinks[location.bagID][location.slotIndex] end
    return inventoryLinks[location.equipmentSlotIndex]
end}
GetInventoryItemLink=function(_,slot) return inventoryLinks[slot] end
GetContainerItemLink=function(bag,slot) return bagLinks[bag] and bagLinks[bag][slot] end
assert(loadfile("EquipmentSets.lua"))("ZwykValues",FW)
local options,errorText=FW:GetEquipmentSetOptions()
assert(not errorText and #options==2 and options[1].name=="Healing" and options[2].name=="Retribution")
assert(options[2].target.character==guid and options[2].target.setID==7)
local profile={comparisonTarget=options[2].target}
local context=FW:GetProfileComparisonContext(profile)
assert(context.mode=="set" and context.label=="Set: Retribution" and not context.error)
assert(context.links[11]==bagLinks[0][11] and context.links[18]==bagLinks[5][18],
    "random suffixes and enchants must survive set resolution, including bank bags")
assert(context.links[1]==inventoryLinks[1] and context.links[5]==inventoryLinks[5])
assert(context.links[12]==nil and context.slotErrors[12]==nil,"an explicitly empty slot is zero")
assert(context.slotErrors[13] and context.slotErrors[14] and context.slotErrors[15],
    "ignored, missing and unknown slots must not be zero baselines")
local signature=FW:GetUpgradeBaselineSignature(profile)
local linkCalls,locationCalls,optionCalls=calls.links,calls.locations,calls.options
for _=1,500 do
    assert(FW:GetProfileComparisonContext(profile)==context)
    assert(FW:GetUpgradeBaselineSignature(profile)==signature)
end
assert(calls.links==linkCalls and calls.locations==locationCalls and calls.options==optionCalls,
    "hovering repeatedly must reuse set snapshots without calling equipment/bag APIs")

-- Item movement/re-enchantment is observed after inventory events invalidate snapshots.
inventoryLinks[1]="item:1001:456:::::4:31"
FW:InvalidateEquipmentSetBaselines()
context=FW:GetProfileComparisonContext(profile)
assert(context.links[1]==inventoryLinks[1] and FW:GetUpgradeBaselineSignature(profile)~=signature)

-- A stale location with another item ID is rejected, even if that item is cached.
bagLinks[0][11]="item:9999:321:::::55:31"
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).slotErrors[11])
bagLinks[0][11]=nil
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).slotErrors[11],"never synthesize item:1011 from the set's ID")

-- Renames preserve the set identity. Deletions and other characters never fall back.
sets[7].name="Renamed Retribution"
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).label=="Set: Renamed Retribution")
sets[7]=nil
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).error:find("no longer exists",1,true))
guid="Player-1-Second"
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).error:find("another character",1,true))
assert(FW:GetProfileComparisonContext({}).mode=="equipped")
local equippedSignature=FW:GetUpgradeBaselineSignature({})
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetUpgradeBaselineSignature({})==equippedSignature,
    "bag-only changes must not invalidate the equipped comparison cache")
FW.equipmentRevision=1
assert(FW:GetUpgradeBaselineSignature({})~=equippedSignature)

-- Missing APIs remain explicit instead of using equipped data.
C_EquipmentSet=nil
FW:InvalidateEquipmentSetBaselines()
options,errorText=FW:GetEquipmentSetOptions()
assert(#options==0 and errorText)
guid="Player-1-First"
FW:InvalidateEquipmentSetBaselines()
assert(FW:GetProfileComparisonContext(profile).error)
print("Equipment set tests passed")
