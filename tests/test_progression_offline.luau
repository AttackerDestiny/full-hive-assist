return function(P,T,runtime)
    local passed=0
    local function check(v,m) assert(v,m); passed+=1 end
    local function cell(name,gifted,x) return {x=x,y=1,bee={Type=name,Traits=gifted and {"Gifted"} or {}}} end
    for occupied=0,50 do
        local capacity=math.max(25,occupied)
        local cells={}
        for i=1,occupied do cells[i]=cell("Bubble",false,i) end
        local g=P.growth(cells,capacity,{Basic=1})
        check(g.Occupied==occupied and g.Capacity==capacity and g.Empty==capacity-occupied,"Occupied/capacity separation")
        check(g.CanReroll==(occupied>=25),"Initial acquisition precedes expensive rerolls")
        check(not g.AutomaticAcquisition,"No unverified acquisition remotes")
        if occupied<25 then
            check(g.Action=="hatch-owned-basic","Use owned Basic before buying an egg")
            check(P.growth(cells,capacity,{}).Action=="acquire-basic-egg","Missing egg is explicit")
            local p=P.plan(cells,T,{slots=capacity,starUsed=0,enforceGrowth=true})
            check(p.target==nil and p.reason=="hive-growth","No rolling a partly filled starter hive")
        elseif occupied<50 then check(g.Action=="expand-capacity","Expansion is an explicit advisory step") end
    end
    local cells={cell("Hasty",true,1),cell("Hasty",true,2),cell("Rad",true,3),cell("Tabby",false,4)}
    local p=P.plan(cells,T,{slots=35,starUsed=0,preserveUniqueGifted=true})
    check(p.keep["1,1"] and not p.keep["2,1"] and p.keep["3,1"],"Keep one gifted type without promoting duplicates")
    check(p.protected["4,1"],"Event protection survives diversity keeps")
    local leased={cell("Hasty",false,1),cell("Hasty",true,2)}
    local q=P.plan(leased,T,{slots=35,starUsed=0,preserveUniqueGifted=true})
    local lease=P.startRollTask(leased[1],leased,q);lease.Rolled=true
    leased[1].bee={Type="Hasty",Traits={"Gifted"}}
    q=P.plan(leased,T,{slots=35,starUsed=0,preserveUniqueGifted=true})
    check(not P.rollTaskDone(lease,leased[1],leased,T,q) and P.rollTaskSafe(lease,leased[1],leased,T,q),"New gifted duplicate cannot steal the established reservation")
    leased={cell("Honey",false,1)}
    q=P.plan(leased,T,{slots=35,starUsed=0,preserveUniqueGifted=true})
    lease=P.startRollTask(leased[1],leased,q);lease.Rolled=true
    leased[1].bee={Type="Hasty",Traits={"Gifted"}}
    q=P.plan(leased,T,{slots=35,starUsed=0,preserveUniqueGifted=true})
    check(P.rollTaskDone(lease,leased[1],leased,T,q) and not P.rollTaskSafe(lease,leased[1],leased,T,q),"First gifted type completes active task safely")
    local after=P.plan(cells,T,{slots=46,starUsed=2,preserveUniqueGifted=true})
    check(not after.keep["1,1"],"Post-Star-Egg stage can follow its existing recipe")
    local starter=P.plan({},T,{slots=25,starUsed=0,enforceGrowth=true,eggs={Basic=2}})
    check(starter.growth.Action=="hatch-owned-basic","Planner and runtime share owned-egg growth advisory")
    -- First-copy retention must never replace legitimate duplicate quantities.
    for _,name in ipairs({"Baby","Music","Bubble","Frosty","Fire"}) do
        for _,reason in ipairs({"collector-fallback","convert-flexible","fixed-targets"}) do
            local group={cell("Hasty",false,1),cell(name,true,2),cell("Honey",false,3)}
            local task=P.startRollTask(group[1],group,{stage="mid",reason=reason,mode="off",needs={}})
            task.Rolled=true;group[1].bee={Type=name,Traits={"Gifted"}}
            local plan=P.plan(group,T,{slots=41,starUsed=0,preserveUniqueGifted=true})
            check(P.rollTaskDone(task,group[1],group,T,plan),"Diversity preserves valid second gifted "..name.." / "..reason)
            check(not P.rollTaskSafe(task,group[1],group,T,plan),"Accepted gifted group result cannot be rerolled")
        end
    end
    for _,name in ipairs({"Baby","Music"}) do
        local group={cell("Hasty",false,1)}
        for i=2,5 do group[i]=cell(name,true,i) end
        local task=P.startRollTask(group[1],group,{stage="mid",reason="collector-fallback",mode="off",needs={}})
        task.Rolled=true;group[1].bee={Type=name,Traits={"Gifted"}}
        local plan=P.plan(group,T,{slots=41,starUsed=0,preserveUniqueGifted=true})
        check(not P.rollTaskDone(task,group[1],group,T,plan) and P.rollTaskSafe(task,group[1],group,T,plan),"Diversity still rejects fifth gifted "..name)
    end
    local lock={x=1,y=1,BasicBatchPurchased=6}
    for _,name in ipairs({"Cool","Commander","Baby","Music","Basic","Tabby","Fuzzy"}) do
        local c=cell(name,true,1)
        check(not P.basicSlotSafe(lock,c,{keep={["1,1"]=true},protected={}}),"Basic lock cannot overwrite kept "..name)
        check(lock.BasicBatchPurchased==6,"Safety decision preserves partial purchase count")
    end
    check(P.basicSlotSafe(lock,cell("Basic",false,1),{keep={},protected={}}),"Normal Basic remains eligible for alternating workflow")
    check(not P.basicSlotSafe(lock,cell("Hasty",false,2),{keep={},protected={}}),"Basic coordinate remains fixed")
    local final={}
    local function add(name,count,gifted)
        for _=1,count do final[#final+1]=cell(name,gifted,#final+1) end
    end
    for _,name in ipairs(P.trueSingles) do add(name,1,true) end
    add("Diamond",3,true);add("Music",4,true);add("Baby",3,true)
    for _,name in ipairs({"Tabby","Gummy","Vicious","Puppy","Festive"}) do add(name,1,true) end
    add("Tadpole",1,true);add("Tadpole",9,false);add("Buoyant",17,true);add("Fuzzy",1,true)
    local f=P.plan(final,T,{slots=50,starUsed=2,jelly=500000,lateStarted=true})
    check(f.capacityStatus.Conflict and f.capacityStatus.Minimum==51,"Report impossible 51-slot final combination")
    check(not f.complete,"An over-capacity fixture cannot claim endgame completion")
    add("Cobalt",1,true)
    f=P.plan(final,T,{slots=50,starUsed=2,jelly=500000,lateStarted=true})
    check(f.capacityStatus.Minimum==52,"Protected extra species contribute to capacity")
    -- Test the actual spend helper after a fresh-inventory increase; all effects
    -- are local stubs and the remote must remain uncalled.
    local spendSource=assert(runtime:match("(local function spend%(cell,item,validate,expectedTask%).-)\nlocal function shopFloor"))
    local factory=assert(loadstring('return function()\n'..
        'local Report={Actions=0,RoyalJellyUsed=8,RollMode="gifted"};local Config={MaxActions=50,MaxRoyalJellies=10};local target={x=1,y=1,bee={Type="Bubble",Traits={}}};local stats={Eggs={RoyalJelly=5},Settings={RollToGifted=true}};local modes={};local remoteCalls=0;local function checkStop() end;local function acquire() end;local function move() end;local function near() end;local function hiveFloor() end;local function refresh() return stats end;local function plan() return {protected={}}, {target} end;local function find() return target end;local function jellyBatchReady() return true end;local function mode(v) modes[#modes+1]=v end;local function invoke() remoteCalls+=1;error("Unexpected spend") end\n'..
        spendSource..'\nreturn spend(target,"RoyalJelly",function() return true end),modes,remoteCalls\nend'))()
    local result,modes,calls=factory()
    check(result==false and modes[1]=="off" and calls==0,"Fresh budget guard disables bulk mode before sending any request")
    local invokeSource=assert(runtime:match("(local function invoke%(remote, %.%.%.%).-)\nlocal function refresh"))
    local makeInvoke=assert(loadstring('return function()\nlocal env={};local function checkStop() end;local task={spawn=function(f) f() end,wait=function() error("No async wait expected") end}\n'..invokeSource..'\nreturn invoke,env\nend'))()
    local invoke,env=makeInvoke()
    local ok=pcall(invoke,{Name="ConstructHiveCellFromEgg",InvokeServer=function() error("Ambiguous transport failure") end},1,2,"RoyalJelly",1,false)
    check(not ok and env.FullHiveUncertain and env.FullHiveUncertain.Item=="RoyalJelly","Uncertain failed mutation retains item/coordinate receipt")
    local callsAfterFailure=0
    ok=pcall(invoke,{Name="ConstructHiveCellFromEgg",InvokeServer=function() callsAfterFailure+=1 end},1,2,"RoyalJelly",1,false)
    check(not ok and callsAfterFailure==0,"A completed transport cannot erase uncertain-spend block")
    invoke,env=makeInvoke()
    ok=pcall(invoke,{Name="RetrievePlayerStats",InvokeServer=function() error("Read failed") end})
    check(not ok and env.FullHiveUncertain==nil,"Read failure does not become a mutation receipt")
    return {passed=passed}
end
