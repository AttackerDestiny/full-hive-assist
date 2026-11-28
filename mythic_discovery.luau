-- Pure post-Star eligibility, discovery and feeding decisions.
local M={}
M.fruit={Spicy="Strawberry",Vector="SunflowerSeed",Precise="SunflowerSeed",Tadpole="Blueberry",Buoyant="Blueberry",Fuzzy="Pineapple"}
M.order={"Spicy","Vector","Precise","Tadpole","Buoyant","Fuzzy"}
function M.unlocked(history,stats,cells,capacity,child,layout50,giftedHistory)
    if not history or history.earned~=2 or capacity<44 or type(stats.Eggs)~="table" or (stats.Eggs.Star or 0)~=0 then return false end
    if child and child.Phase~="complete" then return false end
    local gifted={}
    for _,c in ipairs(cells) do if c.bee and table.find(c.bee.Traits or {},"Gifted") then gifted[c.bee.Type]=true end end
    for _,name in ipairs({"Music","Baby","Shy","Diamond","Lion","Demon"}) do
        if not gifted[name]and not(layout50 and giftedHistory and giftedHistory[name])then return false end
    end
    return true
end
function M.discovered(stats,types)
    if type(stats.DiscGiftTypes)~="table" then return nil end
    local aliases,out={},{}
    for name,info in pairs(types) do if info.ID~=nil then aliases[name]=name;aliases[info.ID]=name;aliases[tostring(info.ID)]=name end end
    for key,value in pairs(stats.DiscGiftTypes) do
        local token=value==true and key or (type(value)=="number" or type(value)=="string") and value
        if token and aliases[token] then out[aliases[token]]=true end
    end
    return out
end
function M.eventsGifted(cells,types,allowed)
    for _,c in ipairs(cells) do
        local info=c.bee and types[c.bee.Type]
        if info and info.Rarity=="Event" and c.bee.Type~="Cobalt"and (not allowed or allowed[c.bee.Type])and not table.find(c.bee.Traits or {},"Gifted") then return false end
    end
    return true
end
function M.plan(stats,cells,types,decision)
    if not decision.discoveryPreparation then return {kind="wait",reason="post-Star goals incomplete"} end
    if not decision.queueMaterialsReady then return {kind="wait",reason="preparing combined material queue"} end
    local seen=M.discovered(stats,types)
    if not seen then return {kind="wait",reason="discovery history unavailable"} end
    local missing,first={}
    for _,name in ipairs(M.order) do if not seen[name] then
        missing[#missing+1]=name;first=first or name
        for _,c in ipairs(cells) do if c.bee.Type==name and table.find(c.bee.Traits or {},"Gifted") then
            return {kind="wait",reason="waiting for gifted discovery history to synchronize",name=name}
        end end
        for _,c in ipairs(cells) do if c.bee.Type==name and not table.find(c.bee.Traits or {},"Gifted") then
            local item=M.fruit[name]
            local available=math.max(0,(stats.Eggs[item] or 0)-((decision.reservedItems or {})[item] or 0))
            if available>0 then return {kind="feed",name=name,item=item,amount=math.min(2000,available),x=c.x,y=c.y} end
            if not M.eventsGifted(cells,types,decision.layoutEvents) then return {kind="wait",reason="Event bees need Star Treats first",name=name} end
            if (stats.Eggs.StarTreat or 0)>0 then return {kind="feed",name=name,item="StarTreat",amount=1,x=c.x,y=c.y} end
            return {kind="fund-star-treat",name=name}
        end end
    end end
    return first and {kind="acquire",name=first} or {kind="complete",reason="all six gifted Mythics discovered"}
end
function M.feedBaseline(stats,cells,action)
    local before={Kind="ssa-feed",Item=action.item,Amount=action.amount,Name=action.name,X=action.x,Y=action.y,
        Inventory=stats.Eggs[action.item] or 0,Capacity=stats.UnlockedCells,Cells={}}
    for _,c in ipairs(cells) do before.Cells[c.x..","..c.y]={X=c.x,Y=c.y,Type=c.bee.Type,Birth=c.bee.Birth,Gifted=table.find(c.bee.Traits or {},"Gifted")~=nil} end
    return before
end
function M.validateFeed(before,remaining,accepted,comb,fresh)
    if accepted~=true or type(remaining)~="number" or type(comb)~="table" or type(fresh.Honeycomb)~="table" then return false,"invalid feeding response" end
    local consumed=before.Inventory-remaining
    if consumed<1 or consumed%1~=0 or consumed>before.Amount or fresh.Eggs[before.Item]~=remaining then return false,"feeding inventory mismatch" end
    if fresh.UnlockedCells~=before.Capacity then return false,"feeding capacity changed" end
    local target
    local count=0
    for _,col in pairs(fresh.Honeycomb) do for _ in pairs(col) do count+=1 end end
    local oldCount=0
    for _,old in pairs(before.Cells) do
        oldCount+=1
        local bee=fresh.Honeycomb["x"..old.X] and fresh.Honeycomb["x"..old.X]["y"..old.Y]
        local returned=comb["x"..old.X] and comb["x"..old.X]["y"..old.Y]
        if not bee or bee.Type~=old.Type or old.Birth~=nil and bee.Birth~=old.Birth
            or old.Gifted and not table.find(bee.Traits or {},"Gifted") then return false,"bee identity changed during feeding" end
        if not returned or returned.Type~=bee.Type or old.Birth~=nil and returned.Birth~=bee.Birth
            or (table.find(returned.Traits or {},"Gifted")~=nil)~=(table.find(bee.Traits or {},"Gifted")~=nil) then
            return false,"feeding response and fresh hive disagree"
        end
        if old.X==before.X and old.Y==before.Y then target=bee end
    end
    if count~=oldCount or not target or target.Type~=before.Name then return false,"feeding target changed" end
    local gifted=table.find(target.Traits or {},"Gifted")~=nil
    if before.Item=="StarTreat" and not gifted then return false,"Star Treat gift unconfirmed" end
    if consumed~=before.Amount and not gifted then return false,"partial feed without gifted result" end
    return true,consumed,gifted
end
return M
