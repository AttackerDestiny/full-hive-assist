-- New explicit blue/final profile, plus actual runtime handoff/admission checks.
return function(P,T,runtime,G,M,Q,background)
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local function add(cells,name,n,gifted)
        for _=1,n do local i=#cells+1;cells[i]={x=(i-1)%5+1,y=math.floor((i-1)/5)+1,bee={Type=name,Traits=gifted and {"Gifted"}or{}}}end
    end
    local function fixture(bear)
        local c={};add(c,"Baby",4,false);add(c,"Music",4,false);add(c,"Shy",1,true)
        for _,n in ipairs(P.layoutSingles)do add(c,n,1,true)end
        for _,n in ipairs(P.layoutEvents)do add(c,n,1,true)end
        add(c,"Tadpole",10,false);add(c,"Buoyant",15,false)
        if bear then add(c,"Bear",1,true)end
        add(c,"Diamond",bear and 2 or 3,true)
        return c
    end
    local function ctx(slots)return {layout50=true,slots=slots or 50,starUsed=2,jelly=1000000,honey=1e15,enforceGrowth=true,eggs={}}end
    local function coordinate(cells,name)
        for _,c in ipairs(cells)do if c.bee.Type==name then return c end end
    end
    for _,bear in ipairs({false,true})do
        local c=fixture(bear);local p=P.plan(c,T,ctx())
        check(#c==50 and p.layout50 and p.complete,"Exact50 composition completes with/without Bear")
        check(p.capacityStatus.Minimum==50 and not p.capacityStatus.Conflict,"Projection fits exactly50")
        check(p.layout.FixedSlots==(bear and 23 or 22),"Fixed force count accounts for optional Bear")
        check(p.layout.Diamond==(bear and 3 or 4),"Bear replaces exactly one extra gifted Diamond")
        check(p.babyGoal==4 and P.count(c,"Baby")==4,"Gifted Tadpoles never reduce requested Baby4")
        for _,bee in ipairs(c)do check(p.keep[P.key(bee)]and p.protected[P.key(bee)],"Every exact-profile force is protected")end
        for _,name in ipairs({"Photon","Cobalt","Fuzzy","Vector","Spicy","Precise","Demon","Lion","Ninja","Bomber","Carpenter"})do
            local copy=fixture(bear);local last=copy[#copy];last.bee={Type=name,Traits={"Gifted"}}
            local q=P.plan(copy,T,ctx());local task=P.startRollTask(last,copy,q)
            check(not q.keep[P.key(last)]and not q.protected[P.key(last)],"Excluded Event/Mythic/gifted type is a safe replacement: "..name)
            check(P.rollTaskSafe(task,last,copy,T,q),"Final roll guard agrees with the new safe slot: "..name)
            check(not P.rollTaskDone(task,last,copy,T,q),"Old protected/failsafe keeps cannot finish this task: "..name)
        end
        local copy=fixture(bear);local f=copy[#copy];f.bee={Type="Frosty",Traits={"Gifted"}}
        local q=P.plan(copy,T,ctx());check(q.temporary[P.key(f)]and not q.keep[P.key(f)],"Gifted Frosty is temporary safe,not an extra force")
        check(q.capacityStatus.Minimum==50,"Temporary Frosty is not double-counted into required capacity")
        local copy=fixture(bear);coordinate(copy,"Baby").bee.Traits={"Gifted"}
        coordinate(copy,"Tadpole").bee.Traits={"Gifted"}
        check(P.plan(copy,T,ctx()).complete,"Gifted Baby/Tadpole still occupy existing total quotas")
    end
    for _,name in ipairs({"Baby","Music"})do
        local c=fixture(false);local target=c[#c];target.bee={Type=name,Traits={"Gifted"}}
        local task={x=target.x,y=target.y,Rolled=true,Reason="fixed-targets"}
        local x=ctx();x.activeRollTask=task;local q=P.plan(c,T,x)
        local kept,normalSafe=0,0
        for _,bee in ipairs(c)do if bee.bee.Type==name then if q.keep[P.key(bee)]then kept+=1 elseif not P.gifted(bee)then normalSafe+=1 end end end
        check(kept==4 and normalSafe==1,"A lucky gifted force makes exactly one normal surplus: "..name)
        check(q.keep[P.key(target)]and P.rollTaskDone(task,target,c,T,q),"Lucky gifted result completes its existing coordinate: "..name)
        check(q.target and q.target.bee.Type==name and not P.gifted(q.target),"Surplus normal cleanup precedes other targets: "..name)
    end
    for _,slots in ipairs({46,47,48,49,50})do for _,bear in ipairs({false,true})do
        local c=fixture(bear);while #c>slots do for i,b in ipairs(c)do if b.bee.Type=="Buoyant"then table.remove(c,i);break end end end
        local p=P.plan(c,T,ctx(slots));local expected=math.max(slots,bear and 48 or 47)
        check(p.capacityStatus.Minimum==expected,"Capacity projection matches current available Diamond extras")
        check(p.capacityStatus.Minimum<=50,"No blue/final plan invents a66-cell requirement")
    end end
    for _,capacity in ipairs({44,45,46,47,48,50})do
        local c=fixture(false);local x=ctx(capacity);x.starUsed=0
        local q=P.plan(c,T,x)
        check(not q.layout50,"Pre-Star workflow is not replaced by the blue profile")
        check(q.questRetired.Shy==(capacity>=45 and true or nil),"Shy reduction begins at45 independent of completed quest")
        local facts={layout50=true,capacity=capacity,beeCounts={Baby=4,Music=4,Shy=1},giftedBeeCounts={Shy=1},ownedGear={["Cobalt Guard"]=true},equippedGear={["Cobalt Guard"]=true}}
        check(G.gearPrerequisite(facts,"Crimson Guard")== (capacity>=45),"Guard quota agrees with45-slot gifted-Shy force")
        if capacity>=45 then facts.giftedBeeCounts.Shy=0;check(not G.gearPrerequisite(facts,"Crimson Guard"),"Normal Shy cannot replace the gifted force from45")end
    end
    local c=fixture(true);local q=P.plan(c,T,ctx());local missing=P.starJellyMissing(c,q)
    check(#missing==0,"Removed Bomber/Frosty failsafes cannot prolong new-profile Star Jelly use")
    check(P.rollItem(c,{StarJelly=5},q)=="RoyalJelly","Complete new singles save remaining Star Jelly")
    local source=assert(runtime:match("(local function scan%(s%).-)\nlocal function find%(cells,cell%)"))
    local make=assert(loadstring("return function(Policy,Types,env,s) local Config={Layout50=true,HoneyReserve=0,DryRun=false,AutoPurchase=true}; local Report={};local Packages={PlayerHas=function()return true end};local rollTask=env.FullHiveRollTask;local player={UserId=7};local game={JobId='test'};local function hive()return {Name='TestHive'}end;local function starEggUses(s)return s.Totals.EggUses.Star or 0 end;"..source.." local p=plan(s);return p,Report,env end"))()
    local function stats(cells)
        local comb={};for _,cell in ipairs(cells)do local col='x'..cell.x;comb[col]=comb[col]or{};comb[col]['y'..cell.y]=cell.bee end
        return {Honey=1e15,UnlockedCells=50,Eggs={RoyalJelly=1000000},Honeycomb=comb,Totals={Purchases={Eggs={RoyalJelly=75}},EggUses={Star=2}}}
    end
    local c=fixture(true);local p,r=make(P,T,{},stats(c))
    check(p.layout50 and p.complete and r.Layout50.Required==50,"Actual runtime context enables the new profile")
    local target=coordinate(c,"Baby");local lease=P.startRollTask(target,c,p);lease.Owner=7;lease.Job='test';lease.Hive='TestHive'
    for _,flag in ipairs({'FullHivePending','AutoHivePendingRequest','FullHiveUncertain','AutoHiveUncertain','FullHiveStarRunning','AutoGiftedStarRunning'})do
        local e={FullHiveRollTask=lease};local marker={};e[flag]=marker
        local ok=pcall(make,P,T,e,stats(c))
        check(not ok and e.FullHiveRollTask==lease and e[flag]==marker,"A newly reserved force never clears unresolved work: "..flag)
    end
    local e={FullHiveRollTask=lease};p,r,e=make(P,T,e,stats(c))
    check(not e.FullHiveRollTask and r.LastCompletedTarget.Reason=='target-now-reserved',"Clean existing lease retires through ordinary reconciliation")
    check(M.eventsGifted({{bee={Type='Photon',Traits={}}}},T,{Tabby=true}),"Safe unlisted Events cannot stall the listed Events-first goal")
    check(not M.eventsGifted({{bee={Type='Tabby',Traits={}}}},T,{Tabby=true}),"A listed ungifted Event still blocks Mythic Star Treats")
    local response=assert(runtime:match("(    for _,old in ipairs%(cells%) do.-)\n    if Report.LastResult.Gifted"))
    local guard=assert(loadstring("return function(Policy,cells,current,p,comb) local item='RoyalJelly';local releasedFuzzy=false;local EggTypes={Get=function()return {}end};"..response.."\nend"))()
    local c=fixture(false);local target=c[#c];target.bee={Type='Photon',Traits={}}
    local p=P.plan(c,T,ctx());local comb=stats(c).Honeycomb
    comb['x'..target.x]['y'..target.y]={Type='Basic',Traits={}}
    check(pcall(guard,P,c,target,p,comb),"Actual response shield permits an explicitly released Event coordinate")
    local tabby=coordinate(c,'Tabby');comb['x'..tabby.x]['y'..tabby.y]={Type='Basic',Traits={}}
    check(not pcall(guard,P,c,target,p,comb),"Actual response shield still catches a changed protected Tabby")
    comb=stats(c).Honeycomb;local bubble=coordinate(c,'Bubble');comb['x'..bubble.x]['y'..bubble.y]={Type='Bubble',Traits={}}
    check(not pcall(guard,P,c,target,p,comb),"Actual response shield retains gifted-force protection")
    local history={Music=true,Baby=true,Shy=true,Diamond=true,Lion=true,Demon=true}
    check(M.unlocked({earned=2},{Eggs={Star=0}},fixture(true),50,nil,true,history),"Verified discovery history survives removal of old gifted Legendary keeps")
    history.Lion=nil
    check(not M.unlocked({earned=2},{Eggs={Star=0}},fixture(true),50,nil,true,history),"Unknown discovery history cannot fabricate old six-goal completion")
    history.Lion=true
    check(not M.unlocked({earned=2},{Eggs={Star=0}},fixture(true),50,{Phase='running'},true,history),"Active Star workflow still blocks the discovery handoff")
    local eventSource=assert(runtime:match("(local function eventAction%(s,cells,p%).-)\nlocal function giftedBasic"))
    local makeEvent=assert(loadstring("return function(Policy,Types,cells,spend) local Config={AutoPurchase=true};local EggTypes={Get=function()return {TicketCost=500}end};local function mode()end;local function buy()error('No unwanted Event funding')end;local function scan()return cells end;"..eventSource.." return eventAction end"))()
    local c=fixture(false);local photon=c[#c];photon.bee={Type='Photon',Traits={}};local p=P.plan(c,T,ctx())
    local worker=makeEvent(P,T,c,function()error('Photon cannot be gifted in the new layout')end)
    check(not worker({Eggs={StarTreat=1}},c,p),"Safe Photon cannot consume a Star Treat or trigger funding")
    local c=fixture(true);local bear=coordinate(c,'Bear');bear.bee.Traits={};local p=P.plan(c,T,ctx());local gifted=false
    local worker=makeEvent(P,T,c,function(target,item,validate)
        check(target==bear and item=='StarTreat',"Owned Bear remains eligible for Event gifting")
        check(validate(bear,c,p),"Final gift guard accepts the retained Bear")
        check(not validate({x=photon.x,y=photon.y,bee={Type='Photon',Traits={}}},c,p),"Final gift guard rejects unlisted Event substitution")
        gifted=true;return {}
    end)
    check(worker({Eggs={StarTreat=1}},c,p)and gifted,"Retained Bear gifting remains independent of excluded Events")
    if Q and background then
        local body=assert(background:match("(    function R.hiveRetirements%(s%).-)\n    local function matchingQuest"))
        local make=assert(loadstring("return function(Q,capacity) local H={Config={Layout50=true},scan=function()return {},capacity end};local R={};local report={};local function questFacts()return {}end;"..body.." return R,report end"))()
        for _,capacity in ipairs({44,45,47,48,50})do
            local worker,report=make(Q,capacity);local retired=worker.hiveRetirements({Quests={Completed={}}})
            check((retired.Shy==true)==(capacity>=45),"Actual background applies the45-slot stage rule even before quest completion")
            if capacity>=45 then check(report.QuestHiveRetirements.Evidence.Shy.reason=='stage-force-reduction',"Stage override is not fabricated quest-completion evidence")end
        end
    end
    return {passed=passed}
end
