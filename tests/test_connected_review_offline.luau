-- Data-only regression specification built from read-only MCP observations.
-- Compiled, not executed, while fixture execution remains blocked.
return function(P,T,source)
    local body=assert(source:match("local StarProgress = %(function%(%)\n(.-)\nend%)%(%)"))
    local Star=assert(loadstring(body))()
    local passed=0
    local function check(value,message) assert(value,message);passed+=1 end
    local function rejects(fn,message) check(not pcall(fn),message) end
    local function stats(used,inventory)
        return {Eggs={Star=inventory},Totals={EggUses={Star=used},Purchases={HiveSlots=0}},
            Honeycomb={},UnlockedCells=25,Quests={Completed={['Seven To Seven']=true,['Royal Rumble']=true}}}
    end
    local riley=stats(nil,2)
    check(Star.usage(riley).sparseZero and Star.budget(riley,2)==2,
        "Observed sparse zero allows a first hatch budget without inferring completed hatches")
    check(not Star.read(riley).ready,"Two owned eggs and completed quests do not imply two uses")
    local luneri=stats(1,1)
    check(Star.budget(luneri,2)==1 and not Star.read(luneri).ready,"Observed one use leaves only one authorized hatch")
    check(Star.budget(stats(2,4),2)==0,"Repeated standalone runs cannot spend beyond two recorded uses")
    check(Star.budget(stats(1,4),1)==1,"Host remaining budget cannot expand in the child")
    check(Star.budget(stats(0,2),0)==0,"Explicit zero host budget is preserved")
    local unknown=stats(nil,2);unknown.Totals.EggUses=nil
    check(Star.budget(unknown,2)==0 and not Star.usage(unknown).known,"Missing parent is distinct from observed sparse zero")
    for _,bad in ipairs({-1,0.5,'2',true,math.huge,0/0}) do
        check(Star.budget(stats(bad,2),2)==0,"Invalid nonnil counters never fund a hatch")
    end
    local missingInventory=stats(2,nil)
    check(not Star.read(missingInventory).ready and Star.budget(missingInventory,2)==0,
        "Missing inventory cannot establish readiness or a spend budget")
    local cells={}
    for _,name in ipairs(Star.coverage({},T).required) do
        cells[#cells+1]={x=#cells+1,y=1,bee={Type=name,Traits={'Gifted'}}}
    end
    local coverage=Star.coverage(cells,T)
    check(#coverage.missing==0 and #coverage.missingMythics==6,"All 29 prerequisites still leave six Mythic opportunities")
    for _,name in ipairs({'Buoyant','Fuzzy','Precise','Spicy','Tadpole','Vector'}) do
        cells[#cells+1]={x=#cells+1,y=1,bee={Type=name,Traits={'Gifted'}}}
    end
    check(#Star.coverage(cells,T).missingMythics==0,"All current gifted Mythics save remaining eggs")
    table.remove(cells)
    check(#Star.coverage(cells,T).missingMythics==1,"One current missing Mythic is eligible regardless of discovery history")
    cells[#cells+1]={x=#cells+1,y=1,bee={Type='Vector',Traits={}}}
    check(#Star.coverage(cells,T).missingMythics==1,"A normal Mythic is not current gifted coverage")
    local incomplete=table.clone(T);incomplete.Vector=nil
    rejects(function() Star.coverage(cells,incomplete) end,"Incomplete metadata cannot mean all outcomes obtained")
    check(T.Basic.Rarity=='Common' and T.Bomber.Rarity=='Rare',"Fixture matches connected BeeTypes")
    local function snapshot(n,capacity)
        local s=stats(0,2);s.UnlockedCells=capacity;s.Totals.Purchases.HiveSlots=capacity-25
        for i=1,n do
            local x,y=(i-1)%5+1,math.floor((i-1)/5)+1
            local col='x'..x;s.Honeycomb[col]=s.Honeycomb[col] or {}
            s.Honeycomb[col]['y'..y]={Type='Bubble',Traits={}}
        end
        return s
    end
    for n=0,50 do
        local capacity=math.max(25,n)
        local decoded,actual=P.snapshot(snapshot(n,capacity),T)
        check(#decoded==n and actual==capacity,"Occupancy never manufactures unlocked capacity")
    end
    rejects(function() P.snapshot(snapshot(26,25),T) end,"Overfull snapshot is rejected instead of expanding capacity")
    local s=snapshot(25,26);s.UnlockedCells=25
    rejects(function() P.snapshot(s,T) end,"Unlocked capacity cannot be below purchased capacity")
    s=snapshot(25,25);s.UnlockedCells=26
    local _,grantedCapacity=P.snapshot(s,T)
    check(grantedCapacity==26,"Granted unlocked cells need not increment the shop purchase counter")
    s=snapshot(1,25);s.Honeycomb.x01={y1={Type='Bubble',Traits={}}}
    rejects(function() P.snapshot(s,T) end,"Normalized duplicate coordinates cannot inflate occupancy")
    s=snapshot(1,25);s.Honeycomb.x1.y1.Type='UnknownBee'
    rejects(function() P.snapshot(s,T) end,"Unknown bee metadata cannot enter a spending plan")
    s=snapshot(1,25);s.Honeycomb.x1.y1.Traits='Gifted'
    rejects(function() P.snapshot(s,T) end,"Malformed traits cannot be miscounted")
    for _,bad in ipairs({false,-1,26,0.5,'16'}) do
        s=snapshot(1,25);s.Totals.Purchases.HiveSlots=bad
        rejects(function() P.snapshot(s,T) end,"Invalid purchase counters cannot select a stage")
    end
    return {passed=passed}
end
