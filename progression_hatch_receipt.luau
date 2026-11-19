-- Pure empty-cell hatch reconciliation. No game services or mutation APIs.
-- capture(stats,x,y) -> immutable-by-copy snapshot, or nil,reason.
-- validate(snapshot,{remaining=...,accepted=...,comb=...},freshStats) -> boolean,reason.
-- Call capture BEFORE a yielding request; never clear an uncertain receipt on false.
local R={}
local supported={Basic=true,Silver=true,Gold=true}
local function integer(n)
    return type(n)=="number" and n>=0 and n<math.huge and n%1==0
end
local function clone(value,seen,depth)
    local kind=type(value)
    if kind=="string" or kind=="boolean" then return value,true end
    if kind=="number" then return value,value==value and value>-math.huge and value<math.huge end
    if kind~="table" or depth>12 or seen[value] then return nil,false end
    seen[value]=true
    local result={}
    for k,v in pairs(value) do
        if type(k)~="string" and not integer(k) then seen[value]=nil;return nil,false end
        local copied,ok=clone(v,seen,depth+1)
        if not ok then seen[value]=nil;return nil,false end
        result[k]=copied
    end
    seen[value]=nil
    return result,true
end
local function fingerprint(bee)
    if type(bee)~="table" or type(bee.Type)~="string" or bee.Type=="" then return nil end
    if bee.Traits~=nil and type(bee.Traits)~="table" then return nil end
    if bee.Lvl~=nil and not integer(bee.Lvl) then return nil end
    if bee.Level~=nil and not integer(bee.Level) then return nil end
    local traits,ok=clone(bee.Traits or {},{},0)
    if not ok then return nil end
    return {Type=bee.Type,Traits=traits,Lvl=bee.Lvl,Level=bee.Level}
end
local function hasGifted(record)
    for _,trait in pairs(record.Traits) do if trait=="Gifted" then return true end end
    return false
end
local function sameIdentity(before,after)
    -- Levels and other traits may progress during a yielding hatch/readback.
    -- Match the existing hive protection contract: species cannot change and
    -- a previously gifted bee cannot lose Gifted. Retain full copies for audit.
    return before.Type==after.Type and (not hasGifted(before) or hasGifted(after))
end
local function scan(comb)
    if type(comb)~="table" then return nil,nil end
    local cells,count={},0
    for x,column in pairs(comb) do
        local nx=type(x)=="string" and tonumber(x:match("^x(%d+)$"))
        if not integer(nx) or nx==0 or type(column)~="table" then return nil,nil end
        for y,bee in pairs(column) do
            local ny=type(y)=="string" and tonumber(y:match("^y(%d+)$"))
            if not integer(ny) or ny==0 then return nil,nil end
            local key=nx..","..ny
            local record=fingerprint(bee)
            if not record or cells[key] then return nil,nil end
            cells[key]=record;count+=1
        end
    end
    return cells,count
end
local function capacity(stats)
    local purchased=type(stats.Totals)=="table" and stats.Totals.Purchases
    local bought=type(purchased)=="table" and purchased.HiveSlots
    if bought==nil then bought=0 end
    if not integer(bought) or bought>25 then return nil end
    local unlocked=stats.UnlockedCells
    if unlocked==nil then unlocked=25+bought end
    if not integer(unlocked) or unlocked<25+bought or unlocked>50 then return nil end
    return unlocked
end
function R.capture(stats,x,y,item)
    item=item or "Basic"
    if not supported[item] then return nil,"unsupported-hatch-egg" end
    if type(stats)~="table" or type(stats.Eggs)~="table" then return nil,"unknown-hatch-stats" end
    if not integer(x) or x==0 or not integer(y) or y==0 then return nil,"invalid-hatch-coordinate" end
    local inventory=stats.Eggs[item]
    if not integer(inventory) or inventory<1 then return nil,"unknown-or-empty-egg-inventory" end
    local cells,count=scan(stats.Honeycomb)
    local unlocked=capacity(stats)
    if not cells or not unlocked or count>=unlocked then return nil,"invalid-hatch-capacity" end
    local key=x..","..y
    if cells[key] then return nil,"hatch-cell-occupied" end
    return {Item=item,Inventory=inventory,Capacity=unlocked,Count=count,Cells=cells,Target=key}
end
local function validComb(before,comb)
    local cells,count=scan(comb)
    if not cells or count~=before.Count+1 or not cells[before.Target] then return nil,"hatch-occupancy-uncertain" end
    for key,record in pairs(before.Cells) do
        if not cells[key] or not sameIdentity(record,cells[key]) then return nil,"existing-bee-changed:"..key end
    end
    return cells
end
function R.validate(before,response,fresh)
    if type(before)~="table" then return false,"invalid-hatch-snapshot" end
    local item=before.Item or "Basic"
    local inventory=before.Inventory or (item=="Basic" and before.Basic)
    if not supported[item] or not integer(inventory) or inventory<1
        or not integer(before.Capacity) or not integer(before.Count)
        or type(before.Cells)~="table" or type(before.Target)~="string" then return false,"invalid-hatch-snapshot" end
    if type(response)~="table" or response.accepted~=true or not integer(response.remaining)
        or response.remaining~=inventory-1 then return false,"hatch-response-uncertain" end
    local returned,reason=validComb(before,response.comb)
    if not returned then return false,reason end
    if type(fresh)~="table" or type(fresh.Eggs)~="table" then return false,"unknown-hatch-readback" end
    local remaining=fresh.Eggs[item]
    if remaining==nil then remaining=0 end -- The server can omit a depleted inventory key.
    if not integer(remaining) or remaining~=response.remaining then return false,"hatch-inventory-delta-uncertain" end
    if capacity(fresh)~=before.Capacity then return false,"hatch-capacity-changed" end
    local current,why=validComb(before,fresh.Honeycomb)
    if not current then return false,why end
    if not sameIdentity(returned[before.Target],current[before.Target]) then return false,"hatch-target-readback-mismatch" end
    return true
end
return R
