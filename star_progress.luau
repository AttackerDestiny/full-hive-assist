local Progress = {}
local function integer(value)
    return type(value)=="number" and value>=0 and value<math.huge and value%1==0
end
function Progress.usage(stats)
    local uses=stats.Totals and stats.Totals.EggUses
    if type(uses)~="table" then return {known=false,recordedKnown=false,used=0} end
    -- Live server counters omit Star before the first hatch. An absent key is
    -- a zero budget baseline, never evidence that two eggs have been hatched.
    if uses.Star==nil then return {known=true,recordedKnown=false,sparseZero=true,used=0} end
    if not integer(uses.Star) then return {known=false,recordedKnown=false,used=0} end
    return {known=true,recordedKnown=true,used=uses.Star}
end
function Progress.coverage(cells,types)
    assert(type(types)=="table", "Bee metadata unavailable")
    local required,mythics,counts={},{},{}
    local eligible={Common=true,Basic=true,Rare=true,Epic=true,Legendary=true}
    for name,info in pairs(types) do
        if type(info)=="table" then
            if eligible[info.Rarity] then required[#required+1]=name end
            if info.Rarity=="Mythic" then mythics[#mythics+1]=name end
        end
    end
    assert(table.find(required,"Basic") and #required>=29 and #mythics>=6,
        "Incomplete Star Egg prerequisite metadata")
    for _,cell in ipairs(cells) do
        if cell.bee and table.find(cell.bee.Traits or {},"Gifted") then counts[cell.bee.Type]=true end
    end
    table.sort(required);table.sort(mythics)
    local missing,missingMythics={},{}
    for _,name in ipairs(required) do if not counts[name] then missing[#missing+1]=name end end
    for _,name in ipairs(mythics) do if not counts[name] then missingMythics[#missingMythics+1]=name end end
    return {required=required,missing=missing,missingMythics=missingMythics}
end
function Progress.budget(stats,limit)
    local usage=Progress.usage(stats)
    local inventory=stats.Eggs and stats.Eggs.Star
    if not usage.known then return 0,"unknown-star-use-counter" end
    if not integer(inventory) then return 0,"unknown-star-inventory" end
    if limit~=nil and limit~=math.huge and not integer(limit) then return 0,"invalid-star-budget" end
    local remaining=math.max(0,2-usage.used)
    if remaining==0 then return 0,"two-recorded-uses" end
    return math.min(remaining,inventory,math.max(0,limit or 2))
end
function Progress.read(stats)
    local completed = stats.Quests and stats.Quests.Completed
    if type(completed) ~= "table" then return {known=false, ready=false} end
    local function done(name)
        if completed[name] == true then return true end
        for _, value in pairs(completed) do if value == name then return true end end
        return false
    end
    local mother, panda = done("Seven To Seven"), done("Royal Rumble")
    local earned = (mother and 1 or 0) + (panda and 1 or 0)
    local inventory = stats.Eggs and stats.Eggs.Star
    local usage=Progress.usage(stats)
    return {known=true, mother=mother, panda=panda, earned=earned, inventory=inventory,
        used=usage.used, recordedKnown=usage.recordedKnown,usageKnown=usage.known,
        sparseZero=usage.sparseZero,inventoryKnown=integer(inventory),
        ready=mother and panda and integer(inventory) and inventory==0
            and usage.recordedKnown and usage.used>=2}
end
return Progress
