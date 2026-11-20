-- Pure policy and real spend helper tests; no live requests or inventory changes.
return function(P,T,runtime)
    local passed=0
    local function check(v,m) assert(v,m); passed+=1 end
    local function fixture(missing)
        local cells={}
        for i,name in ipairs(P.mid) do
            cells[#cells+1]={x=i,y=1,bee={Type=name,Traits=name==missing and {} or {"Gifted"}}}
        end
        return cells
    end
    check(#P.mid==8,"The Star Jelly goal is the eight existing Rare/Epic failsafes")
    for _,name in ipairs(P.mid) do
        check(T[name].Rarity=="Rare" or T[name].Rarity=="Epic","Goal excludes Basic/Legendary/Event/Mythic")
        for _,slots in ipairs({25,35,39,40,41,43,44,45,46,48,49,50}) do
            local cells=fixture(name)
            local ctx={slots=slots,starUsed=slots>=46 and 2 or 0,jelly=2000,honey=1e15,lateStarted=true}
            local plan=P.plan(cells,T,ctx)
            check(P.rollItem(cells,{StarJelly=1,RoyalJelly=2000})=="StarJelly","Missing "..name.." enables Star Jelly at "..slots)
            check(#P.starJellyMissing(cells)==1 and P.starJellyMissing(cells)[1]==name,"Only gifted ownership satisfies goal")
            check(P.rollItem(cells,{StarJelly=0,RoyalJelly=2000})=="RoyalJelly","Empty Star Jelly falls back to Royal Jelly")
            check(P.rollItem(cells,{StarJelly=1,RoyalJelly=0})=="StarJelly","Star Jelly does not require a Royal Jelly batch")
            check(plan.stage==P.stage(ctx),"Item choice leaves stage rules intact")
        end
    end
    local all=fixture()
    check(#P.starJellyMissing(all)==0,"Eight gifted failsafes complete the goal")
    check(P.count(all,"Basic",true)==0 and P.rollItem(all,{StarJelly=50,RoyalJelly=2000})=="RoyalJelly","Missing Gifted Basic does not consume Star Jelly")
    do
        local basic={x=9,y=1,bee={Type="Basic",Traits={}}}
        local plan={target=basic,starter=true,protected={}}
        check(P.rollItem(all,{StarJelly=1},plan)=="StarJelly","A selected normal Basic allows Star Jelly even after the eight failsafes")
        plan.protected[P.key(basic)]=true
        check(P.rollItem(all,{StarJelly=1},plan)=="RoyalJelly","Protected Basic is excluded from the Star Jelly exception")
        plan.protected={};basic.bee.Traits={"Gifted"}
        check(P.rollItem(all,{StarJelly=1},plan)=="RoyalJelly","Gifted Basic is excluded from the Star Jelly exception")
    end
    for _,name in ipairs(P.legendary) do
        check(P.count(all,name,true)==0,"Fixture intentionally has no gifted legendary")
        check(P.rollItem(all,{StarJelly=50})=="RoyalJelly","Missing legendary "..name.." does not prolong Star Jelly")
    end
    check(P.rollItem({}, {})=="RoyalJelly","Missing inventory fields are handled")
    -- Run the actual last-moment spend guard and one-item accounting.
    local spending=assert(runtime:match('(local function spend%(cell,item,validate,expectedTask%).-)\nshopFloor=function'))
    local make=assert(loadstring('return function(Policy,cells,settings,upgradeTask,results)\n'..
        'local rollTask=upgradeTask; local env={}; local nextFlexible; local Report={Actions=0,RoyalJellyUsed=0,RollMode="off"}; local Config={MaxActions=100,MaxRoyalJellies=1000,RollDelay=0}; local Events={ConstructHiveCellFromEgg={}}; local target=cells[#cells]; local calls=0; local stats={Eggs={StarJelly=2,RoyalJelly=0},Settings=settings}; local function checkStop() end; local function acquire() end; local function move() end; local function near() end; local function hiveFloor() end; local function refresh() return stats end; local function plan() return {protected={},temporary={},keep={},stage="mid",target=target,reason=upgradeTask and "convert-flexible"},cells end; local function find() return target end; local function jellyBatchReady() error("Star Jelly must not require Royal Jelly admission") end; local function jellyBatchSpent() error("Star Jelly must not consume Royal Jelly budget") end; local function invoke(_,x,y,item,amount,flag) assert(item=="StarJelly" and amount==1 and flag==false); calls+=1; local result=table.remove(results or {},1) or {Type="Bomber",Traits={"Gifted"}}; return stats.Eggs.StarJelly-1,true,{["x"..x]={["y"..y]=result}} end; local Cache={Set=function(_,key,value) if type(key)=="table" then stats.Eggs[key[2]]=value elseif key=="Honeycomb" then target.bee=value["x"..target.x]["y"..target.y] end end}; local task={wait=function() end}\n'..
        spending..'\nreturn function() return spend(target,"StarJelly",function(c,cs,p) return not upgradeTask or Policy.rollTaskSafe(upgradeTask,c,cs,{},p) end,upgradeTask) end,function() return calls end,Report,stats\nend'))()
    local cells=fixture("Bomber")
    cells[#cells+1]={x=9,y=1,bee={Type="Rascal",Traits={}}}
    local spend,calls,report,stats=make(P,cells,{})
    check(spend()~=false and calls()==1,"A missing failsafe allows exactly one Star Jelly request without Royal Jelly")
    check(report.Actions==1 and report.RoyalJellyUsed==0 and report.LastResult.Consumed==1,"Star Jelly accounting preserves Royal Jelly budget")
    check(P.rollItem(cells,stats.Eggs)=="RoyalJelly","Obtaining the final missing failsafe stops Star Jelly immediately")
    check(spend()==false and calls()==1 and stats.Eggs.StarJelly==1,"Final pre-remote guard saves unused Star Jelly")
    for _,flag in ipairs({"RollToGifted","RollToLegendary","RollToMythic","RollToMutation"}) do
        cells=fixture("Bomber"); cells[#cells+1]={x=9,y=1,bee={Type="Rascal",Traits={}}}
        local spend,calls=make(P,cells,{[flag]=true})
        local ok=pcall(spend)
        check(not ok and calls()==0,"Changed "..flag.." prevents Star Jelly spending")
    end
    for _,name in ipairs({"Bubble","Frosty"}) do
        for _,inventory in ipairs({0,1,1999,2000}) do
            cells=fixture();local target={x=9,y=1,bee={Type=name,Traits={}}};cells[#cells+1]=target
            local p={target=target,reason="convert-flexible",mode="gifted",needs={},protected={},keep={},stage="mid"}
            local lease=P.startRollTask(target,cells,p)
            check(P.rollItem(cells,{StarJelly=20,RoyalJelly=inventory},p,lease)=="RoyalJelly","All eight gifts stop Star Jelly even for a normal collector upgrade")
            target.bee={Type="Hasty",Traits={"Gifted"}};lease.Rolled=true
            check(P.rollItem(cells,{StarJelly=20,RoyalJelly=inventory},p,lease)=="RoyalJelly","An active intermediate result cannot spend saved Star Jelly after all eight goals")
        end
        cells=fixture();cells[#cells+1]={x=9,y=1,bee={Type=name,Traits={}}}
        local p={target=cells[#cells],reason="convert-flexible",mode="gifted",needs={},protected={},keep={},stage="mid"}
        local lease=P.startRollTask(cells[#cells],cells,p)
        local send,counter,_,inventory=make(P,cells,{},lease)
        check(send()==false and counter()==0 and inventory.Eggs.StarJelly==2,"Actual pre-remote guard saves Star Jelly for a completed eight-type list")
    end
    for _,name in ipairs({"Baby","Music","Lion","Ninja","Tabby","Buoyant"}) do
        local target={x=9,y=1,bee={Type=name,Traits={}}}
        check(P.rollItem(all,{StarJelly=50},{target=target,reason="convert-flexible"})=="RoyalJelly","New upgrade rule does not add "..name.." targets")
    end
    for _,name in ipairs({"Bubble","Frosty"}) do
        check(P.rollItem(all,{StarJelly=50},{target={x=9,y=1,bee={Type=name,Traits={"Gifted"}}},reason="convert-flexible"})=="RoyalJelly","Already gifted "..name.." cannot start an upgrade")
    end
    return {passed=passed}
end
