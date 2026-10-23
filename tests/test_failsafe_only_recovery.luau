-- User correction: ordinary gifted Hasty/Riley are not configured failsafes.
return function(P,T,runtime)
    local passed=0
    local function check(value,message) assert(value,message);passed+=1 end
    local function fixture()
        local cells,index={},0
        local function add(name,count,gifted)
            for _=1,count do
                index+=1;if index==40 then index+=1 end
                cells[#cells+1]={x=(index-1)%5+1,y=math.floor((index-1)/5)+1,
                    bee={Type=name,Traits=gifted and {"Gifted"} or {}}}
            end
        end
        for _,name in ipairs({"Bumble","Cool","Looker","Bomber","Commander","Bucko"}) do add(name,1,true) end
        add("Bubble",7,true);add("Frosty",2,true);add("Basic",1,true)
        add("Baby",1,true);add("Baby",3,false);add("Music",4,false);add("Shy",3,false)
        add("Ninja",1,true);add("Ninja",3,false);add("Lion",2,false)
        for _,row in ipairs({{"Gummy",false},{"Vicious",true},{"Festive",true},{"Photon",false},{"Tabby",true},{"Puppy",false}}) do add(row[1],1,row[2]) end
        add("Fuzzy",2,false);add("Precise",1,false)
        local target={x=5,y=8,bee={Type="Hasty",Traits={"Gifted"}}}
        cells[#cells+1]=target
        return cells,target
    end
    local function ctx(extra)
        local c={slots=43,starUsed=1,jelly=89,honey=794000000,collectorFallback=true,enforceGrowth=true}
        for k,v in pairs(extra or {}) do c[k]=v end
        return c
    end
    for _,oldOverride in ipairs({false,true}) do
        local cells,target=fixture()
        local plan=P.plan(cells,T,ctx({preserveUniqueGifted=oldOverride}))
        check(#cells==43,"Fixture matches the observed 43 occupied bees")
        check(not plan.keep[P.key(target)] and table.find(plan.fallbackCandidates,target),"Gifted Hasty remains a repair candidate despite historical diversity override")
        check(plan.collectorFallback and plan.mode=="off" and plan.reason=="collector-fallback","Normal recovery uses single collector rolls")
        check(P.refillFor(43,plan.collectorFallback)==100,"Recovery threshold is 100, not the normal 2000")
        check(P.count(cells,"Ninja")==4 and P.count(cells,"Lion")==2,"Caps remain totals, not new goals")
    end
    for _,row in ipairs({{"Hasty",true,false},{"Riley",true,false},{"Rad",true,false},
        {"Cool",true,false},{"Carpenter",true,true},{"Bubble",false,true},
        {"Frosty",false,true},{"Tabby",false,true},{"Buoyant",false,true}}) do
        local cells,target=fixture()
        local plan=P.plan(cells,T,ctx())
        local task=P.startRollTask(target,cells,plan);task.Rolled=true
        target.bee={Type=row[1],Traits=row[2] and {"Gifted"} or {}}
        plan=P.plan(cells,T,ctx())
        local done=P.rollTaskDone(task,target,cells,T,plan)
        check(done==row[3],"Recovery outcome keeps only configured results: "..row[1])
        check(P.rollTaskSafe(task,target,cells,T,plan)==not row[3],"Keep/reroll boundary matches outcome: "..row[1])
    end
    do
        local cells,target=fixture()
        local prep=P.plan(cells,T,ctx({starPrepare=true}))
        check(prep.keep[P.key(target)],"Explicit Star Egg preparation still preserves required gifted coverage")
        local ordinary=P.plan(cells,T,ctx({preserveUniqueGifted=true}))
        check(not ordinary.keep[P.key(target)],"Preparation keeps do not leak into ordinary recovery")
    end
    for _,shyCount in ipairs({2,3}) do
        local cells,target=fixture()
        if shyCount==2 then
            for _,c in ipairs(cells) do if c.bee.Type=="Shy" then c.bee={Type="Honey",Traits={}};break end end
        end
        local plan=P.plan(cells,T,ctx())
        local task=P.startRollTask(target,cells,plan);task.Rolled=true
        target.bee={Type="Fire",Traits={"Gifted"}}
        plan=P.plan(cells,T,ctx())
        check(P.rollTaskDone(task,target,cells,T,plan)==(shyCount==2),"Useful gifted Fire remains a placeholder only when the red group needs it")
        check(P.rollTaskSafe(task,target,cells,T,plan)==(shyCount==3),"Gifted Fire placeholder completion never causes a kept-slot assertion")
    end
    local source=assert(runtime:match("(local function scan%(s%).-)\nlocal function find%(cells,cell%)"))
    local make=assert(loadstring("return function(Policy,Types,env,s)\n"..
        'local Config={HoneyReserve=0,DryRun=false,AutoPurchase=true,PreserveUniqueGifted=true};local Report={};local lateStarted=false;local nextFlexible;local rollTask;local player={UserId=7};local game={JobId="test"};local function hive() return {Name="TestHive"} end;local function starEggUses() return 1 end\n'..
        source..'\nlocal p=plan(s);return p,Report,env,jellyBatchReady\nend'))()
    local cells=fixture();local comb={}
    for _,c in ipairs(cells) do local col="x"..c.x;comb[col]=comb[col] or {};comb[col]["y"..c.y]=c.bee end
    local stats={Honey=794000000,UnlockedCells=43,Honeycomb=comb,Eggs={RoyalJelly=89,StarJelly=0},
        Totals={Purchases={HiveSlots=18,Eggs={RoyalJelly=75}},EggUses={Star=1}}}
    local plan,report,state,ready=make(P,T,{},stats)
    check(report.RefillAmount==100 and report.NormalRefillAmount==2000 and report.SafeNonCollector==2,
        "Runtime repairs gifted Hasty and the newly capped surplus Fuzzy with100 recovery")
    check(not ready(stats) and state.FullHiveJellyBatch==nil,"Saved 89 jelly cannot be seeded into admission")
    check(P.jellyCost(75,report.RefillAmount-stats.Eggs.RoyalJelly)==11000000,"Recovery top-up buys only the missing 11")
    stats.Eggs.RoyalJelly=100
    check(ready(stats),"A fresh full 100 qualifies the actual recovery batch")
    return {passed=passed}
end
