return function(P,T)
    local checked=0
    local function check(v,m) assert(v,m); checked=checked+1 end
    local n=0
    local function cell(t,g) n=n+1; return {x=n,y=1,bee={Type=t,Traits=g and {"Gifted"} or {}}} end
    local function ctx(slots,used,jelly) return {slots=slots,starUsed=used or 0,jelly=jelly or 10000,lateStarted=true} end
    local function hive(list)
        local h={}
        for _,row in ipairs(list) do for _=1,row[2] do h[#h+1]=cell(row[1],row[3]) end end
        return h
    end
    check(P.stage(ctx(39))=="early","39 early")
    check(P.stage(ctx(40))=="mid","40 mid")
    check(P.stage(ctx(44))=="late","44 late")
    check(P.stage(ctx(50,1))=="late","No blue before two eggs")
    check(P.stage(ctx(49,2))=="blue","49 stays blue")
    check(P.stage(ctx(50,2))=="final","50 final")
    for _,slots in ipairs({25,35,40,42,43,44,45,46,47,48,49,50}) do
        local amount,pack=P.refill(slots)
        check(amount%pack==0,"Invalid refill increments")
    end
    for _,bought in ipairs({0,10,74,75,90}) do
        local slow=0
        for i=0,199 do slow=slow+math.min(250000+10000*(bought+i),1000000) end
        check(P.jellyCost(bought,200)==slow,"Jelly ramp formula")
    end
    for _,slots in ipairs({25,35,40,44,46,49,50}) do
        local h={}
        for name,info in pairs(T) do
            if info.Rarity=="Event" or info.Rarity=="Mythic" then
                h[#h+1]=cell(name,false); h[#h+1]=cell(name,true)
            end
        end
        h[#h+1]=cell("Rascal",false)
        local plan=P.plan(h,T,ctx(slots,2))
        for _,c in ipairs(h) do
            if T[c.bee.Type].Rarity=="Event" or T[c.bee.Type].Rarity=="Mythic" then
                check(plan.protected[P.key(c)],"Protected bee released: "..c.bee.Type)
                check(not plan.target or P.key(c)~=P.key(plan.target),"Protected bee targeted")
            end
        end
    end
    local h=hive({{"Bubble",4},{"Frosty",4},{"Ninja",2},{"Lion",1},{"Baby",4},{"Music",4},{"Shy",2}})
    local p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Lion","Lion replacement priority")
    h[#h+1]=cell("Rascal",false)
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Lion","Lion must precede generic safe bees")
    for _,c in ipairs(h) do if c.bee.Type=="Bubble" or c.bee.Type=="Frosty" or c.bee.Type=="Ninja" then
        check(p.keep[P.key(c)],"Collector minimum released")
    end end
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(not p.target,"Settled early collector hive keeps surplus collectors")
    h=hive({{"Baby",4},{"Music",4},{"Shy",2},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Bubble","Surplus Bubble available for Shy")
    h=hive({{"Cool",3,true},{"Looker",3,true},{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(40))
    local keptCool,keptLooker=0,0
    for _,c in ipairs(h) do
        if p.keep[P.key(c)] and P.gifted(c) and c.bee.Type=="Cool" then keptCool=keptCool+1 end
        if p.keep[P.key(c)] and P.gifted(c) and c.bee.Type=="Looker" then keptLooker=keptLooker+1 end
    end
    check(keptCool==1,"Failsafe keeps exactly one gifted Cool")
    check(keptLooker==1,"Failsafe keeps exactly one gifted Looker")
    local coolNeed=false
    for _,need in ipairs(p.needs) do if need.name=="Cool" then coolNeed=true end end
    check(not coolNeed,"Existing gifted Cool is skipped as a satisfied failsafe")
    h=hive({{"Baby",4},{"Music",2},{"Looker",1},{"Commander",1},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Looker","A full placeholder hive must upgrade Looker to Music")
    h=hive({{"Baby",4},{"Music",4},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Fire","A full placeholder hive must upgrade Fire to Shy")
    h=hive({{"Baby",4},{"Music",2},{"Looker",1,true},{"Commander",1,true},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Fire","Unique gifted crit failsafes must survive placeholder upgrades")
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4}})
    for _,name in ipairs(P.mid) do h[#h+1]=cell(name,true) end
    p=P.plan(h,T,ctx(40))
    check(p.reason=="convert-flexible","Force flexible can convert after fixed gifts")
    check(not P.gifted(p.target),"Conversion targets a normal")
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4,true},{"Frosty",4,true},{"Ninja",2}})
    for _,name in ipairs(P.mid) do h[#h+1]=cell(name,true) end
    h[#h+1]=cell("Basic",false)
    p=P.plan(h,T,ctx(40))
    check(p.target and p.target.bee.Type=="Basic" and p.mode=="gifted","New mid-stage cell uses gifted collector rolls")
    h=hive({{"Baby",4},{"Music",4,true},{"Diamond",4,true},{"Tadpole",4,true},{"Tadpole",6},{"Buoyant",17},{"Fuzzy",1,true}})
    p=P.plan(h,T,ctx(50,2))
    check(p.babyGoal==0,"Gifted Tad replaces normal Baby")
    for _,c in ipairs(h) do if c.bee.Type=="Baby" then check(not p.keep[P.key(c)],"Normal baby not released") end end
    h=hive({{"Tadpole",15},{"Buoyant",18},{"Baby",4},{"Music",4}})
    p=P.plan(h,T,ctx(46,2,9000))
    check(P.count(h,"Tadpole")==15,"Fixture")
    local protectedTad,protectedBuoy=0,0
    for _,c in ipairs(h) do if p.protected[P.key(c)] then
        if c.bee.Type=="Tadpole" then protectedTad=protectedTad+1 end
        if c.bee.Type=="Buoyant" then protectedBuoy=protectedBuoy+1 end
    end end
    check(protectedTad==15,"Low-jelly 15th Tad protected from rolling")
    check(protectedBuoy==17,"Buoyant cap")
    p=P.plan(h,T,ctx(46,2,26000)); protectedTad=0
    for _,c in ipairs(h) do if c.bee.Type=="Tadpole" and p.protected[P.key(c)] then protectedTad=protectedTad+1 end end
    check(protectedTad==14,"High-jelly 15th Tad safe")
    h=hive({{"Basic",1,true},{"Bumble",1,true},{"Cool",1,true},{"Looker",1,true},{"Bubble",1,true},
        {"Commander",1,true},{"Bucko",1,true},{"Diamond",4,true},{"Music",1,true},{"Music",3},
        {"Tadpole",4,true},{"Tadpole",6},{"Buoyant",1,true},{"Buoyant",16},{"Fuzzy",1,true},
        {"Tabby",1,true},{"Gummy",1,true},{"Vicious",1,true},{"Puppy",1,true},{"Festive",1,true},
        {"Cobalt",1},{"Frosty",1,true}})
    check(#h==50,"Final hive fixture has 50 bees")
    p=P.plan(h,T,ctx(50,2))
    check(p.complete and not p.target and #p.needs==0,"Final hive must stop rolling when all requirements hold")
    for _,c in ipairs(h) do if c.bee.Type=="Frosty" then c.bee={Type="Baby",Traits={}} end end
    p=P.plan(h,T,ctx(50,2))
    check(not p.complete and p.target and p.target.bee.Type=="Baby","Final surplus Baby must be replaced")
    for _,c in ipairs(h) do if c.bee.Type=="Cool" then c.bee={Type="Hasty",Traits={}} end end
    p=P.plan(h,T,ctx(50,2))
    local needsCool=false
    for _,need in ipairs(p.needs) do if need.name=="Cool" and need.gifted then needsCool=true end end
    check(needsCool and not p.complete,"Final stage must repair missing gifted baseline")
    do
        local base=hive({{"Honey",1},{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4},{"Ninja",2},{"Cool",1,true}})
        local q=P.plan(base,T,ctx(43))
        local task=P.startRollTask(base[1],base,q)
        local x,y=base[1].x,base[1].y
        task.Rolled=true
        local function result(name,g)
            base[1].bee={Type=name,Traits=g and {"Gifted"} or {}}
            return P.plan(base,T,ctx(43))
        end
        q=result("Exhausted",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Honey task continues through Exhausted")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Exhausted remains safe in same task")
        q=result("Cool",true)
        check(q.keep[P.key(base[1])],"Fixture duplicate sorts ahead of old gifted copy")
        check(not P.rollTaskDone(task,base[1],base,T,q),"Duplicate gifted failsafe does not end task")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Duplicate gifted safe despite reordered keep")
        q=result("Baby",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Fifth normal Baby does not end task")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Fifth normal Baby stays in active slot")
        q=result("Carpenter",true)
        check(P.rollTaskDone(task,base[1],base,T,q),"First lucky gifted Carpenter ends task")
        base[#base+1]=cell("Carpenter",true)
        q=P.plan(base,T,ctx(43))
        check(not P.rollTaskDone(task,base[1],base,T,q),"Duplicate gifted Carpenter continues")
        q=result("Bumble",true)
        check(P.rollTaskDone(task,base[1],base,T,q),"Missing gifted Bumble satisfies task")
        check(not P.rollTaskSafe(task,base[1],base,T,q),"No reroll after needed gifted result")
        q=result("Tabby",false)
        check(P.rollTaskDone(task,base[1],base,T,q),"Event ends task protected")
        check(not P.rollTaskSafe(task,base[1],base,T,q),"Event never rerolled")
        q=result("Fuzzy",false)
        check(P.rollTaskDone(task,base[1],base,T,q),"Mythic ends task protected")
        q=result("Bubble",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Unneeded normal collector does not end gifted task")
        local fallbackTask=P.startRollTask(base[1],base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
        fallbackTask.Rolled=true
        check(P.rollTaskDone(fallbackTask,base[1],base,T,q),"Fallback finishes on a collector result")
        check(task.x==x and task.y==y and task.InitialTotal.Baby==4 and task.InitialGifted.Cool==1,
            "Replanning preserves slot and starting counts")
    end
    for _,name in ipairs({"Bubble","Frosty"}) do
        local base=hive({{name,8,true},{"Baby",4},{"Music",4},{"Shy",3}})
        local q=P.plan(base,T,ctx(44));local target
        for _,c in ipairs(q.candidates) do if c.bee.Type==name then target=c;break end end
        check(target~=nil and q.reason=="fixed-targets","Fixed needs select a surplus gifted "..name)
        local task=P.startRollTask(target,base,q)
        check(not task.Rolled and P.rollTaskSafe(task,target,base,T,q),"Original unsent surplus gifted collector lease remains safe")
        local kept
        for _,c in ipairs(base) do if q.keep[P.key(c)] and c.bee.Type==name then kept=c;break end end
        check(not P.rollTaskSafe(task,kept,base,T,q),"Cannot switch the lease to a reserved collector")
        local original=task.InitialFingerprint;task.InitialFingerprint="Brave:false"
        check(not P.rollTaskSafe(task,target,base,T,q),"A changed gifted result cannot use the initial-source exception")
        task.InitialFingerprint=original;task.Rolled=true
        check(not P.rollTaskSafe(task,target,base,T,q),"Rolled gifted-result keep semantics stay unchanged")
        task.Rolled=false;q.protected[P.key(target)]=true
        check(not P.rollTaskSafe(task,target,base,T,q),"Permanent protection still wins over a source lease")
        q.protected[P.key(target)]=nil;q.reason="convert-flexible"
        check(not P.rollTaskSafe(task,target,base,T,q),"Source exception requires an active fixed-target plan")
        q.reason="fixed-targets";q.needs={}
        check(not P.rollTaskSafe(task,target,base,T,q),"Satisfied goals cannot consume surplus gifted collectors")
        q=P.plan(base,T,ctx(44))
        local removed=false
        for _,c in ipairs(base) do if not removed and q.keep[P.key(c)] and c.bee.Type==name then q.keep[P.key(c)]=nil;removed=true end end
        check(not P.rollTaskSafe(task,target,base,T,q),"Fewer than four reserved collectors fails closed")
        local exact=hive({{name,4,true},{"Baby",4},{"Music",4},{"Shy",3}})
        local exactPlan=P.plan(exact,T,ctx(44));local exactTask=P.startRollTask(exact[1],exact,exactPlan)
        check(not P.rollTaskSafe(exactTask,exact[1],exact,T,exactPlan),"A four-copy gifted force group stays reserved")
    end
    do
        local fallbackCtx=ctx(43); fallbackCtx.collectorFallback=true
        local base=hive({{"Honey",1},{"Exhausted",2},{"Baby",4},{"Music",4},{"Shy",3},
            {"Bubble",4},{"Frosty",4},{"Ninja",2},{"Lion",1},{"Tabby",1},{"Fuzzy",1}})
        local q=P.plan(base,T,fallbackCtx)
        check(#q.fallbackCandidates==3,"Honey and Exhausted are three recovery slots")
        check(q.collectorFallback and q.target.bee.Type=="Honey" and q.mode=="off","Recovery chooses noncollector with single rolls")
        check(P.collectorRecovery(43,3,100000000,75,false),"Cannot afford 2k: enter recovery")
        check(not P.collectorRecovery(43,3,2000000000,75,false),"Can afford 2k: normal refill")
        check(P.collectorRecovery(43,3,5000000000,75,true),"Recovery stays until conversion ends")
        check(not P.collectorRecovery(43,0,100000000,75,true),"No noncollector: leave recovery")
        local amount,pack=P.refillFor(43,true)
        check(amount==100 and pack==100,"Recovery buys one 100 pack")
        amount,pack=P.refillFor(43,false)
        check(amount==2000 and pack==1000,"Normal resumes two 1000 packs")
        for i=1,3 do base[i].bee={Type="Bubble",Traits={}} end
        q=P.plan(base,T,fallbackCtx)
        check(not q.collectorFallback and #q.fallbackCandidates==0,"Recovery exits when all safe sources are collectors")
        fallbackCtx.slots=42
        q=P.plan(base,T,fallbackCtx)
        check(not q.collectorFallback,"No recovery at another stage when wrong slots are already repaired")
    end
    -- Exhaustive varied duplicate mixtures: the planner cannot target any kept slot,
    -- except the explicit normal flexible conversion path.
    for i=1,80 do
        h={}
        for j,name in ipairs({"Basic","Bubble","Frosty","Baby","Music","Shy","Ninja","Lion","Tabby","Fuzzy","Tadpole","Buoyant"}) do
            for k=1,(i*j)%6 do h[#h+1]=cell(name,(i+j+k)%3==0) end
        end
        p=P.plan(h,T,ctx(({25,35,40,44,46,50})[i%6+1],2,26000))
        if p.target then
            check(not p.protected[P.key(p.target)],"Fuzz targeted protected slot")
            check(not p.keep[P.key(p.target)] or p.reason=="convert-flexible","Fuzz targeted a force slot")
        end
    end
    -- Species caps count normal and gifted copies together, at every stage.
    for _,spec in ipairs({{"Ninja",4},{"Lion",2}}) do
        local name,cap=spec[1],spec[2]
        check(P.slotCaps[name]==cap,"Configured total cap for "..name)
        for _,slots in ipairs({25,35,41,44,46,50}) do
            local base=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4},
                {name,1,true},{name,cap,false},{"Tabby",1},{"Fuzzy",1}})
            local q=P.plan(base,T,ctx(slots,2))
            local kept=0
            for _,c in ipairs(base) do if c.bee.Type==name and q.keep[P.key(c)] then kept+=1 end end
            check(kept<=cap,"Reservations respect total cap at "..slots)
            if slots<46 or (name=="Ninja" and slots<50) then
                check(q.keep[P.key(base[#base-cap-2])],"Existing gifted failsafe retained at "..slots)
            end
            check(q.target and q.target.bee.Type==name and not P.gifted(q.target),"Surplus species selected before other conversion at "..slots)
            local recovery=ctx(slots,2); recovery.collectorFallback=true; recovery.honey=1
            local r=P.plan(base,T,recovery)
            if slots>=35 then
                check(r.collectorFallback and r.target.bee.Type==name,"Over-cap collector enters repair at "..slots)
            end
        end
        for _,existing in ipairs({cap-1,cap}) do
            local base=hive({{"Hasty",1},{name,existing,false}})
            local target=base[1]
            local task=P.startRollTask(target,base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
            task.Rolled=true; target.bee={Type=name,Traits={}}
            local q=P.plan(base,T,{slots=41,starUsed=0,jelly=100,honey=1,collectorFallback=true})
            check(P.rollTaskDone(task,target,base,T,q)==(existing<cap),"Recovery result respects "..name.." cap")
            check(P.rollTaskSafe(task,target,base,T,q)==(existing>=cap),"Excess new result remains on active coordinate")
        end
        local base=hive({{"Hasty",1},{name,cap,false}})
        local task=P.startRollTask(base[1],base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
        task.Rolled=true; base[1].bee={Type=name,Traits={"Gifted"}}
        local q=P.plan(base,T,ctx(41))
        check(P.rollTaskDone(task,base[1],base,T,q),"First gifted failsafe may replace a normal at cap")
        check(q.target and q.target.bee.Type==name and not P.gifted(q.target),"Cap cleanup releases a normal after gifted upgrade")
    end
    return {passed=checked}
end
