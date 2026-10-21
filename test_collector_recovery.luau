-- Pure policy and isolated runtime-plan regressions; no live inventory changes.
return function(P,T,runtime)
    local passed,n=0,0
    local function check(v,m) assert(v,m); passed+=1 end
    local function cell(name,gifted)
        n+=1; return {x=n,y=1,bee={Type=name,Traits=gifted and {"Gifted"} or {}}}
    end
    local function fixture()
        local cells={}
        for _,row in ipairs({{"Exhausted",1},{"Brave",1},{"Bumble",2},{"Rad",1},{"Stubborn",1},
            {"Honey",1,true},{"Hasty",1,true},{"Baby",4},{"Music",4},{"Shy",3},
            {"Bubble",5},{"Frosty",4},{"Ninja",2},{"Lion",1},{"Cool",1,true},
            {"Tabby",1},{"Vicious",1,true},{"Fuzzy",1},{"Vector",1,true}}) do
            for _=1,row[2] do cells[#cells+1]=cell(row[1],row[3]) end
        end
        return cells
    end
    local function ctx(slots,honey)
        return {slots=slots,starUsed=slots>=46 and 2 or 0,jelly=0,honey=honey or 100000000,
            lateStarted=false,collectorFallback=true}
    end
    for _,slots in ipairs({25,34,35,39,40,41,42,43,44,45,46,47,48,49,50}) do
        local base,normalPack=P.refill(slots)
        local enabled=base>100
        check(P.collectorRecovery(slots,3,0,75,false)==enabled,"Recovery availability at "..slots)
        check(not P.collectorRecovery(slots,3,P.jellyCost(75,base),75,false),"Affordable refill does not trigger recovery")
        check(P.collectorRecovery(slots,3,1e15,75,true)==enabled,"Active recovery persists through honey growth")
        check(not P.collectorRecovery(slots,0,0,75,true),"Recovery exits without wrong slots")
        local amount,pack=P.refillFor(slots,true)
        check(amount==(enabled and 100 or base) and pack==(enabled and 100 or normalPack),"Recovery pack at "..slots)
        amount,pack=P.refillFor(slots,false)
        check(amount==base and pack==normalPack,"Normal refill restored at "..slots)
        local cells=fixture(); local q=P.plan(cells,T,ctx(slots))
        if enabled then
            check(q.collectorFallback and q.mode=="off" and q.reason=="collector-fallback","Single-roll recovery at "..slots)
            check(q.target.bee.Type=="Exhausted","Wrong slot precedes surplus collector")
            local found={}
            for _,c in ipairs(q.fallbackCandidates) do
                found[c.bee.Type]=(found[c.bee.Type] or 0)+1
                check(not P.isCollectorSection(c) and not q.keep[P.key(c)] and not q.protected[P.key(c)],"Recovery respects forces/protection")
            end
            check(found.Brave==1 and found.Bumble==2 and found.Rad==1 and found.Stubborn==1,"All unlisted normal slots are safe")
            check(found.Honey==1 and found.Hasty==1,"Unlisted gifted bees remain safe")
            for _,c in ipairs(cells) do
                if T[c.bee.Type].Rarity=="Event" or T[c.bee.Type].Rarity=="Mythic" then
                    check(q.protected[P.key(c)] and not found[c.bee.Type],"Event/Mythic protection in recovery")
                end
            end
            for _,c in ipairs(q.fallbackCandidates) do c.bee={Type="Bubble",Traits={}} end
            q=P.plan(cells,T,ctx(slots))
            check(not q.collectorFallback,"Recovery ends after all safe wrong slots are repaired")
        end
    end
    local mode,reason=P.recoveryMode(19999999999)
    check(mode=="off" and reason=="collector-fallback","Below 20B single-roll mode")
    mode,reason=P.recoveryMode(20000000000)
    check(mode=="gifted" and reason=="gifted-collector-fallback","20B gifted mode boundary")
    do
        local cells=fixture(); local q=P.plan(cells,T,ctx(46,20000000000))
        check(q.collectorFallback and q.mode=="gifted" and q.reason==reason,"Gifted recovery at a later stage")
        local target=q.target; local task=P.startRollTask(target,cells,q); task.Rolled=true
        for _,name in ipairs({"Bubble","Frosty","Lion","Ninja"}) do
            target.bee={Type=name,Traits={}}
            local plan=P.plan(cells,T,ctx(46,20000000000))
            check(not P.rollTaskDone(task,target,cells,T,plan),"Normal collector cannot end gifted recovery")
            check(P.rollTaskSafe(task,target,cells,T,plan),"Normal collector remains in the gifted recovery lease")
        end
        target.bee={Type="Bubble",Traits={"Gifted"}}
        check(P.rollTaskDone(task,target,cells,T,P.plan(cells,T,ctx(46,20000000000))),"Gifted Bubble completes recovery slot")
        task.Reason="collector-fallback"; task.Mode="off"
        for _,name in ipairs({"Bubble","Frosty","Lion","Ninja"}) do
            target.bee={Type=name,Traits={}}
            check(P.rollTaskDone(task,target,cells,T,P.plan(cells,T,ctx(41))),"Any collector completes normal recovery")
        end
    end
    -- Keep/failsafe behavior must also apply to outcomes on a leased recovery
    -- coordinate, including a new result that sorts before an existing copy.
    for _,honey in ipairs({100000000,20000000000}) do
        local function outcome(name,gifted,existingGifted,existingNormal,slots)
            slots=slots or 41
            local cells=fixture(); local target=cells[1]
            for i=2,#cells do if cells[i].bee.Type==name then cells[i].bee={Type="Hasty",Traits={}} end end
            for _=1,existingGifted or 0 do cells[#cells+1]=cell(name,true) end
            for _=1,existingNormal or 0 do cells[#cells+1]=cell(name,false) end
            local before=P.plan(cells,T,ctx(slots,honey))
            local task=P.startRollTask(target,cells,before); task.Rolled=true
            target.bee={Type=name,Traits=gifted and {"Gifted"} or {}}
            return task,target,cells,P.plan(cells,T,ctx(slots,honey))
        end
        local names={"Basic","Bumble","Cool","Looker","Bomber","Bubble","Commander","Bucko","Frosty",
            "Baby","Carpenter","Demon","Lion","Diamond","Music","Ninja","Shy"}
        for _,name in ipairs(names) do
            local task,target,cells,q=outcome(name,true,0,0)
            check(P.rollTaskDone(task,target,cells,T,q),"Recovery keeps first gifted "..name)
            check(not P.rollTaskSafe(task,target,cells,T,q),"Kept gifted "..name.." cannot be rerolled")
            if name~="Bubble" and name~="Frosty" then
                local limit=P.giftedLimit(name,"mid")
                task,target,cells,q=outcome(name,true,limit,0)
                check(not P.rollTaskDone(task,target,cells,T,q),"Extra gifted "..name.." does not steal a kept slot")
                check(P.rollTaskSafe(task,target,cells,T,q),"Excess gifted "..name.." remains eligible")
            end
        end
        for _,name in ipairs({"Baby","Music"}) do
            local task,target,cells,q=outcome(name,true,0,4)
            check(P.rollTaskDone(task,target,cells,T,q),"Gifted "..name.." upgrades a full normal group")
            local normals=0
            for _,c in ipairs(cells) do if c.bee.Type==name and not P.gifted(c) and q.keep[P.key(c)] then normals+=1 end end
            check(normals==3,"Gifted upgrade releases exactly one normal "..name)
        end
        for _,spec in ipairs({{"Baby",4},{"Music",4},{"Shy",3}}) do
            local name,cap=spec[1],spec[2]
            local task,target,cells,q=outcome(name,false,0,cap-1)
            check(P.rollTaskDone(task,target,cells,T,q),"Recovery keeps a needed normal "..name)
            check(not P.rollTaskSafe(task,target,cells,T,q),"Needed force result cannot be rerolled")
            task,target,cells,q=outcome(name,false,0,cap)
            check(not P.rollTaskDone(task,target,cells,T,q) and P.rollTaskSafe(task,target,cells,T,q),"Surplus normal "..name.." stays eligible")
        end
        for _,name in ipairs({"Tabby","Gummy","Fuzzy","Vector"}) do
            for _,gifted in ipairs({false,true}) do
                local task,target,cells,q=outcome(name,gifted,0,0)
                check(P.rollTaskDone(task,target,cells,T,q) and not P.rollTaskSafe(task,target,cells,T,q),"New Event/Mythic remains protected")
            end
        end
        for _,name in ipairs({"Honey","Brave","Hasty"}) do
            local task,target,cells,q=outcome(name,true,0,0)
            check(not P.rollTaskDone(task,target,cells,T,q) and P.rollTaskSafe(task,target,cells,T,q),"Unlisted gifted "..name.." does not become a failsafe")
        end
    end
    -- Mid/late recovery still uses the planner's cheap crit/red keeps when the
    -- higher-ranked force group is short.
    for _,slots in ipairs({35,41,44}) do
        for _,name in ipairs({"Commander","Looker","Fire"}) do
            local cells=fixture(); local target=cells[1]
            local removed=false
            for _,c in ipairs(cells) do
                if not removed and c.bee.Type==(name=="Fire" and "Shy" or "Music") then
                    c.bee={Type="Hasty",Traits={}}; removed=true
                end
            end
            local before=P.plan(cells,T,ctx(slots))
            local task=P.startRollTask(target,cells,before); task.Rolled=true
            target.bee={Type=name,Traits={}}
            local q=P.plan(cells,T,ctx(slots))
            check(q.keep[P.key(target)],"Fixture reserves temporary "..name)
            check(P.rollTaskDone(task,target,cells,T,q) and not P.rollTaskSafe(task,target,cells,T,q),"Recovery retains needed temporary "..name.." at "..slots)
        end
    end
    -- Execute the actual context()/plan() with a fake hive and server snapshot.
    local source=assert(runtime:match("(local function scan%(s%).-)\nlocal function find%(cells,cell%)"))
    local make=assert(loadstring("return function(Policy,Types,env,s)\n"..
        'local Config={HoneyReserve=0,DryRun=false,AutoPurchase=true}; local Report={}; local lateStarted=false; local nextFlexible; local rollTask=env.FullHiveRollTask; local player={UserId=7}; local game={JobId="test"}; local function hive() return {Name="TestHive"} end; local function starEggUses(s) return s.Totals.EggUses.Star or 0 end\n'..
        source.."\nlocal p=plan(s); return p,Report,env,jellyBatchReady\nend"))()
    local function stats(cells,honey)
        local comb={}
        for _,c in ipairs(cells) do comb["x"..c.x]={["y"..c.y]=c.bee} end
        return {Honey=honey or 100000000,Eggs={RoyalJelly=0},Honeycomb=comb,
            Totals={Purchases={HiveSlots=16,Eggs={RoyalJelly=75}},EggUses={Star=0}}}
    end
    local cells=fixture(); local initial=P.plan(cells,T,{slots=41,starUsed=0,jelly=0,lateStarted=false})
    local task=P.startRollTask(cells[1],cells,initial)
    task.Owner=7; task.Hive="TestHive"; task.Job="test"
    local env={FullHiveRollTask=task}
    local q,report=make(P,T,env,stats(cells))
    check(q.collectorFallback and q.mode=="off" and q.reason=="collector-fallback","Existing gifted lease switches to single-roll recovery")
    check(env.FullHiveRollTask==task and q.target.x==cells[1].x,"Same coordinate survives recovery migration")
    check(report.RefillAmount==100 and report.NormalRefillAmount==600,"41-slot runtime uses 100 instead of 600")
    task.Rolled=true; cells[1].bee={Type="Lion",Traits={}}
    q,report=make(P,T,env,stats(cells))
    check(env.FullHiveRollTask==nil and report.LastCompletedTarget.Reason=="collector-result","Collector outcome releases recovery lease")
    check(q.target and not P.isCollectorSection(q.target),"Next wrong slot selected")
    for _,target in ipairs(q.fallbackCandidates) do
        for _,c in ipairs(cells) do if P.key(c)==P.key(target) then c.bee={Type="Bubble",Traits={}} end end
    end
    q,report=make(P,T,env,stats(cells))
    check(not q.collectorFallback and env.FullHiveCollectorFallback==nil,"Runtime exits recovery")
    check(report.RefillAmount==600 and report.NormalRefillAmount==600,"Runtime restores original refill")
    -- Existing collector leases must not consume collectors ahead of wrong bees.
    cells=fixture(); initial=P.plan(cells,T,{slots=41,starUsed=0,jelly=0,lateStarted=false})
    local collector
    for _,c in ipairs(cells) do if c.bee.Type=="Lion" then collector=c; break end end
    task=P.startRollTask(collector,cells,initial); task.Owner=7; task.Hive="TestHive"; task.Job="test"
    q,report,env=make(P,T,{FullHiveRollTask=task},stats(cells))
    check(env.FullHiveRollTask==nil and q.reason=="collector-fallback","Recovery holds an existing collector and selects a wrong slot")
    -- The actual context/plan must prefer admitted normal jelly over the cost
    -- of the next refill, including intermediate noncollector roll results.
    for _,slotCount in ipairs({40,41,42,43,44,45,46,48,50}) do
        for _,remaining in ipairs({1,99,P.refill(slotCount)-1,P.refill(slotCount)+1}) do
            cells=fixture()
            local target
            for _,c in ipairs(cells) do if c.bee.Type=="Bubble" then target=c; break end end
            local original=P.plan(cells,T,{slots=slotCount,starUsed=slotCount>=46 and 2 or 0,jelly=P.refill(slotCount),honey=1e15,lateStarted=true})
            original.reason="convert-flexible"; original.mode="gifted"
            task=P.startRollTask(target,cells,original); task.Owner=7; task.Hive="TestHive"; task.Job="test"; task.Rolled=true
            target.bee={Type="Stubborn",Traits={}}
            local snapshot=stats(cells,0); snapshot.Totals.Purchases.HiveSlots=slotCount-25
            snapshot.Totals.EggUses.Star=slotCount>=46 and 2 or 0; snapshot.Eggs.RoyalJelly=remaining
            local batch={Version=1,Owner=7,Hive="TestHive",Job="test",Amount=P.refill(slotCount),Remaining=remaining,Recovery=false}
            local state={FullHiveRollTask=task,FullHiveJellyBatch=batch}
            q,report,env=make(P,T,state,snapshot)
            check(not q.collectorFallback and not env.FullHiveCollectorFallback,"Admitted normal batch prevents recovery at "..slotCount.." / "..remaining)
            check(q.target.x==target.x and q.target.y==target.y and q.mode=="gifted" and q.reason=="convert-flexible","Intermediate result keeps original gifted task")
            check(env.FullHiveRollTask==task and task.Reason=="convert-flexible","Recovery does not rewrite task lease")
            check(env.FullHiveJellyBatch==batch and not batch.Recovery,"Normal admission survives replanning")
        end
    end
    do
        cells=fixture(); local snapshot=stats(cells,0); snapshot.Eggs.RoyalJelly=600
        q,report=make(P,T,{},snapshot)
        check(not q.collectorFallback and report.RefillAmount==600,"A full normal amount prevents recovery entry before admission")
        snapshot.Eggs.RoyalJelly=1
        q,report=make(P,T,{},snapshot)
        check(q.collectorFallback and report.RefillAmount==100,"Unadmitted small drops do not disable genuine recovery")
        snapshot.Eggs.RoyalJelly=99
        local state={FullHiveJellyBatch={Version=1,Owner=7,Hive="TestHive",Job="test",Amount=100,Remaining=99,Recovery=true},FullHiveCollectorFallback=true}
        q,report=make(P,T,state,snapshot)
        check(q.collectorFallback and report.RefillAmount==100,"A genuine recovery batch keeps repair behavior")
        for _,c in ipairs(cells) do if not P.isCollectorSection(c) and T[c.bee.Type].Rarity~="Event" and T[c.bee.Type].Rarity~="Mythic" then c.bee={Type="Bubble",Traits={}} end end
        snapshot=stats(cells,0); snapshot.Eggs.RoyalJelly=45
        q,report,env=make(P,T,state,snapshot)
        check(not q.collectorFallback and report.RefillAmount==600 and env.FullHiveJellyBatch==nil,"Recovery completion closes admission and saves leftover inventory")
        local _,_,_,ready=make(P,T,state,snapshot)
        check(not ready(snapshot) and snapshot.Eggs.RoyalJelly==45,"A repaired hive cannot use45 leftovers to start a600 conversion")
        cells[1].bee={Type="Stubborn",Traits={}}; snapshot=stats(cells,0); snapshot.Eggs.RoyalJelly=44
        q,report=make(P,T,state,snapshot)
        check(q.collectorFallback,"A new wrong slot without a funded normal task can use genuine recovery")
    end
    for _,case in ipairs({{41,1},{41,200},{41,599},{43,200}}) do
        local slotCount,left=case[1],case[2]
        local base=P.refill(slotCount)
        cells=fixture(); local target=cells[1]
        local original=P.plan(cells,T,{slots=slotCount,starUsed=0,jelly=base,honey=1e15,lateStarted=true})
        original.reason="convert-flexible"; original.mode="gifted"
        task=P.startRollTask(target,cells,original)
        task.Owner=7; task.Hive="TestHive"; task.Job="test"; task.Rolled=true
        target.bee={Type="Rad",Traits={}}
        local snapshot=stats(cells,0); snapshot.Eggs.RoyalJelly=left
        snapshot.Totals.Purchases.HiveSlots=slotCount-25
        local state={FullHiveRollTask=task}
        if left>0 then state.FullHiveJellyBatch={Version=1,Owner=7,Hive="TestHive",Job="test",Amount=base,Remaining=left,Recovery=false} end
        q,report,env=make(P,T,state,snapshot)
        check(not q.collectorFallback and q.mode=="gifted" and q.reason=="convert-flexible","A funded normal task never downgrades at "..left)
        check(report.RefillAmount==base and env.FullHiveRollTask==task,"Active normal batch retains its task/refill")
        target.bee={Type="Bubble",Traits={"Gifted"}}
        snapshot=stats(cells,0); snapshot.Eggs.RoyalJelly=left
        snapshot.Totals.Purchases.HiveSlots=slotCount-25
        local _,_,_,ready
        q,report,env,ready=make(P,T,state,snapshot)
        check(env.FullHiveRollTask==nil and env.FullHiveJellyBatch==nil,"A completed conversion closes its batch at "..left)
        check(not ready(snapshot) and snapshot.Eggs.RoyalJelly==left,"The next conversion cannot spend a small remainder")
    end
    -- A Star Jelly upgrade remains on its original task even with RJ0/honey0.
    for _,name in ipairs({"Bubble","Frosty"}) do
        for _,slotCount in ipairs({40,41,43,44,45}) do
            cells=fixture(); local target=cells[1]
            target.bee={Type=name,Traits={}}
            local original={stage="mid",reason="convert-flexible",mode="gifted",needs={}}
            task=P.startRollTask(target,cells,original)
            task.Owner=7; task.Hive="TestHive"; task.Job="test"; task.Rolled=true
            target.bee={Type="Hasty",Traits={"Gifted"}}
            local snapshot=stats(cells,0); snapshot.Totals.Purchases.HiveSlots=slotCount-25
            snapshot.Eggs.StarJelly=2
            local state={FullHiveRollTask=task}
            q,report=make(P,T,state,snapshot)
            check(not q.collectorFallback and q.reason=="convert-flexible","Star Jelly prevents intermediate upgrade result from entering recovery")
            check(q.target.x==target.x and q.target.y==target.y and report.StarJellyUpgrade,"Star Jelly upgrade keeps original coordinate")
            snapshot.Eggs.StarJelly=0
            q,report=make(P,T,state,snapshot)
            check(q.collectorFallback,"Exhausted Star Jelly with no funded Royal Jelly permits existing repair")
        end
    end
    -- Partial purchases must not turn an affordable normal top-up into recovery.
    -- Exercise the real runtime planner after each supported pack boundary.
    for _,slotCount in ipairs({35,39,40,41,42,43,44,45,46,47,48,49,50}) do
        local base=P.refill(slotCount)
        local target=slotCount>=44 and math.max(10000,base) or base
        for _,inventory in ipairs({1,math.floor(target/2),target-1}) do
            cells=fixture()
            -- This general fixture has 36 bees; its 35-slot snapshot must
            -- remove one spare normal before testing the refill boundary.
            if #cells>slotCount then
                for i,c in ipairs(cells) do
                    if c.bee.Type=="Bumble" and not P.gifted(c) then table.remove(cells,i);break end
                end
            end
            local missingCost=P.jellyCost(75,target-inventory)
            local snapshot=stats(cells,missingCost)
            snapshot.Totals.Purchases.HiveSlots=slotCount-25
            snapshot.Eggs.RoyalJelly=inventory
            q,report,env=make(P,T,{},snapshot)
            check(not q.collectorFallback and report.RefillAmount==target,"Affordable missing top-up retains normal refill at "..slotCount.." / "..inventory)
            check(env.FullHiveJellyBatch==nil,"Partial top-up never admits a batch before reaching its threshold")
            snapshot.Honey=missingCost-1
            q,report=make(P,T,{},snapshot)
            check(q.collectorFallback and report.RefillAmount==100,"Unaffordable missing top-up still permits genuine repair")
            snapshot.Honey=missingCost
            q,report=make(P,T,{FullHiveCollectorFallback=true},snapshot)
            check(q.collectorFallback and report.RefillAmount==100,"Active repair persists despite an affordable normal top-up")
        end
    end
    return {passed=passed}
end
