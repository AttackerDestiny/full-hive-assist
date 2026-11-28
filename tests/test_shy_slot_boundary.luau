return function(P,Q,Progression,T,runtime,background)
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local function fixture(shy,gifted)
        local cells={}
        local function add(name,n,gift)
            for _=1,n do local i=#cells;cells[#cells+1]={x=i%5+1,y=math.floor(i/5)+1,bee={Type=name,Traits=gift and {"Gifted"}or{}}}end
        end
        add("Baby",4);add("Music",4);add("Shy",gifted,true);add("Shy",shy-gifted)
        add("Bubble",5,true);add("Frosty",4,true);add("Basic",1,true)
        add("Bomber",1,true);add("Cool",1,true);add("Bumble",1,true);add("Looker",1,true);add("Commander",1,true);add("Bucko",1,true)
        while #cells<35 do add("Hasty",1)end
        return cells
    end
    local function hasNeed(p,name,gifted)
        for _,need in ipairs(p.needs)do if need.name==name and need.gifted==gifted then return need.amount end end
    end
    for _,capacity in ipairs({25,35,41,44,46,47,48,49,50})do
        for _,completed in ipairs({false,true})do
            local quests={{name="Star Journey 2",active=true,tasks={{type="Collect Tokens",tag="Red Boost",goal=5000,current=completed and 5000 or 4999}}}}
            local retired=Q.hiveRetirements(quests,{},capacity)
            check((retired.Shy==true)==(completed and capacity>=48),"Token completion and capacity must both authorize retirement")
            retired=Q.hiveRetirements({},completed and {"Star Journey 2"}or{},capacity)
            check((retired.Shy==true)==(completed and capacity>=48),"History completion respects the identical48 boundary")
            for gifted=0,3 do
                local cells=fixture(3,gifted)
                -- Deliberately pass stale pre-131 Shy evidence to the planner.
                local ctx={slots=capacity,starUsed=capacity>=46 and 2 or 0,jelly=10000,honey=1e15,
                    questRetired={Shy=completed},bubbleMaskOwned=true,legendaryRoute="six"}
                local p=P.plan(cells,T,ctx)
                local kept=0;for _,c in ipairs(cells)do if c.bee.Type=="Shy"and p.keep[P.key(c)]then kept+=1 end end
                local retire=completed and capacity>=48
                check((p.questRetired.Shy==true)==retire,"Planner ignores early or stale retirement flags")
                check(kept==(retire and math.min(1,gifted)or 3),"Reservation counts normal and gifted copies under the exact boundary")
                check(not hasNeed(p,"Shy",false),"Full quota has no extra normal Shy goal")
                if not retire then
                    local target
                    for _,c in ipairs(cells)do if c.bee.Type=="Shy"then target=c;break end end
                    local task=P.startRollTask(target,cells,p);task.Rolled=true
                    task.Goals={{name="Tadpole",before=0,target=10,gifted=false}}
                    check(not P.rollTaskSafe(task,target,cells,T,p),"Existing active lease cannot sacrifice one of three Shy")
                end
                cells=fixture(1,1);p=P.plan(cells,T,ctx)
                local missing=hasNeed(p,"Shy",false)
                check(retire and missing==nil or not retire and missing==2,"Two missing Shy are requested until both retirement conditions are true")
                check(P.forceQuotasReady(cells,{Shy=completed},capacity)==retire,"Readiness agrees with the planner")
                if capacity==41 and completed then check(P.quotaRolling(cells,ctx),"Completed red boost still uses normal force-quota50 below48")end
                -- Gifted copies all count toward the permanent three-slot total.
                if not retire and gifted==3 then
                    local filled=fixture(3,3);local plan=P.plan(filled,T,ctx)
                    check(P.giftedLimit("Shy",plan.stage,nil,nil,nil,plan.questRetired.Shy)==3,"Gifted limit does not fight the three-copy reservation")
                end
            end
            for _,guard in ipairs({"Cobalt Guard","Crimson Guard"})do
                for shy=0,3 do
                    local f={capacity=capacity,beeCounts={Baby=4,Music=4,Shy=shy},questRetired={Shy=completed},ownedGear={["Cobalt Guard"]=true},equippedGear={["Cobalt Guard"]=true}}
                    check(Progression.gearPrerequisite(f,guard)==(shy==3 or completed and capacity>=48),"Guard admission uses the same capacity/evidence boundary")
                end
            end
        end
    end
    for _,capacity in ipairs({0,47.5,51,math.huge,"48",false})do
        check(not Q.hiveRetirements({}, {"Star Journey 2"},capacity).Shy,"Unknown or malformed capacity never retires Shy")
        check(not P.shyRetired({Shy=true},capacity),"Malformed planner capacity fails closed")
        check(not Progression.gearPrerequisite({capacity=capacity,beeCounts={Baby=4,Music=4,Shy=0},questRetired={Shy=true}},"Cobalt Guard"),"Malformed gear capacity retainsShy3")
    end
    check(not Q.hiveRetirements({}, {"Star Journey 2"}).Shy,"Missing capacity retainsShy3")
    check(Q.hiveRetirements({}, {"Star Journey 1"},35).Ninja,"Ninja retirement is independent of the new Shy gate")
    -- Exercise actual runtime reconciliation when an old task owns a now-kept Shy.
    local source=assert(runtime:match("(local function scan%(s%).-)\nlocal function find%(cells,cell%)"))
    local make=assert(loadstring('return function(Policy,Types,env,s) local Config={HoneyReserve=0,DryRun=false,AutoPurchase=true};local Report={};local lateStarted=false;local nextFlexible;local rollTask=env.FullHiveRollTask;local player={UserId=7};local game={JobId="test"};local background={hiveRetirements=function()return {Shy=true}end};local function hive()return {Name="TestHive"}end;local function starEggUses()return 2 end;'
        ..source..' local p=plan(s);return p,Report end'))()
    for _,capacity in ipairs({46,47,48})do
        local cells=fixture(3,1);local target
        for _,c in ipairs(cells)do if c.bee.Type=="Shy"and not P.gifted(c)then target=c;break end end
        local stats={Honey=1e15,UnlockedCells=capacity,Eggs={RoyalJelly=10000,Star=0},Totals={Purchases={HiveSlots=capacity-25,Eggs={RoyalJelly=75}}},Honeycomb={}}
        for _,c in ipairs(cells)do local x="x"..c.x;stats.Honeycomb[x]=stats.Honeycomb[x]or{};stats.Honeycomb[x]["y"..c.y]=c.bee end
        local task=P.startRollTask(target,cells,{stage="blue",reason="fixed-targets",mode="gifted",needs={}})
        task.Rolled=true;task.Owner=7;task.Hive="TestHive";task.Job="test"
        local batch={Version=1,Owner=7,Hive="TestHive",Job="test",Amount=10000,Remaining=10000,Recovery=false}
        local env={FullHiveRollTask=task,FullHiveJellyBatch=batch}
        local p,r=make(P,T,env,stats)
        if capacity<48 then
            check(not env.FullHiveRollTask and r.LastCompletedTarget.Reason=="target-now-reserved","Fresh held Shy retires stale lease without rolling it")
            check(target.bee.Type=="Shy"and p.keep[P.key(target)],"The original normal Shy remains held")
            for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveUncertain","AutoHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning"})do
                local marker={};local blocked={FullHiveRollTask=task,FullHiveJellyBatch=batch,[flag]=marker}
                check(not pcall(make,P,T,blocked,stats)and blocked[flag]==marker and blocked.FullHiveRollTask==task and blocked.FullHiveJellyBatch==batch,"Unresolved work blocks boundary reconciliation without altering state")
            end
        else
            check(env.FullHiveRollTask==task and p.target.x==target.x and p.target.y==target.y,"Verified48-slot retirement continues the same safe normal-Shy task")
        end
    end
    -- The background evaluator must pass the same snapshot and derived capacity.
    local segment=assert(background:match("(    function R.hiveRetirements%(s%).-)\n    local function matchingQuest"))
    local build=assert(loadstring('return function(H,Q,report,questFacts) local R={};'..segment..' return R end'))()
    for _,capacity in ipairs({47,48})do
        local stats={Quests={Completed={"Star Journey 2"}}};local seen
        local worker=build({scan=function(s)seen=s;return {},capacity end},Q,{},function(s)check(s==stats,"Background quest facts retain the original fresh snapshot");return{}end)
        check((worker.hiveRetirements(stats).Shy==true)==(capacity>=48)and seen==stats,"Actual background uses fresh capacity to enforce47/48")
    end
    return {passed=passed}
end
