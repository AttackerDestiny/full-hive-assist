return function(Q,createSwitch,source)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local cells={{x=4,y=5,bee={Type="Vicious",Birth=100,Lvl=10,Bond=1330152,Traits={}}}}
    check(not Q.motherComplete({},{}),"Missing final completion never inferred from inactive quests")
    check(not Q.motherComplete(nil,{}),"Unknown completion fails closed")
    check(not Q.motherComplete({"The Family Final"},nil),"Unknown active quests fail closed")
    check(not Q.motherComplete({"The Family Final"},{{npc="Mother Bear",active=true}}),"Active Mother Bear retains treat priority")
    check(Q.motherComplete({"The Family Final"},{}),"Final completed quest proves the main Mother Bear chain")
    check(Q.viciousTarget(true,cells,342722,4000000,1).amount==266985,"Cap feed at level 12 and keep surplus treats")
    local target,saving=Q.viciousTarget(true,cells,100,4000000,1)
    check(not target and saving.required==266985 and saving.held==100,"Insufficient owned Treats wait for a full single feed")
    check(not Q.viciousTarget(true,cells,266984,4000000,1),"One Treat short cannot begin feeding")
    check(Q.viciousTarget(true,cells,266985,4000000,1).amount==266985,"Exact full deficit qualifies one feed")
    check(Q.viciousTarget(true,cells,342722,4000000,1.2).amount==222488,"Gifted Puppy bonus reduces feed")
    check(not Q.viciousTarget(false,cells,100,4000000,1),"Unfinished Mother Bear blocks feed")
    for _,owned in ipairs({-1,0,0.5,math.huge})do check(not Q.viciousTarget(true,cells,owned,4000000,1),"Invalid or empty treats never spend")end
    check(not Q.viciousTarget(true,{},100,4000000,1),"Missing Vicious never feeds another bee")
    check(not Q.viciousTarget(true,{cells[1],cells[1]},100,4000000,1),"Ambiguous Vicious fails closed")
    cells[1].bee.Lvl=12;cells[1].bee.Bond=4000002
    check(Q.viciousTarget(true,cells,0,4000000,1).ready,"Level 12 enables crab without treats")
    local button={checked=false};local config={killcrab=false};local calls=0
    local api={Set=function(on) calls+=1;config.killcrab=on;button.checked=on end}
    local tables={{["Auto Coconut Crab"]=api}}
    local values={config,button}
    local worker=createSwitch({tables=function()return tables end,values=function()return values end,
        isButton=function(v)return v==button end,checked=function(b)return b.checked end,
        clock=function()return 0 end,wait=function()error("Unexpected delayed confirmation")end})
    check(not worker("Auto Kill Coconut Crab",true,false) and calls==0,"Inspection cannot mutate")
    check(worker("Auto Kill Coconut Crab",true,true) and calls==1,"Enable uses Atlas Set and confirms config plus UI")
    check(worker("Auto Kill Coconut Crab",true,true) and calls==1,"Already enabled is idempotent")
    local confirmed,why=worker("Auto Kill Coconut Crab",true,false)
    check(confirmed and why==nil,"Confirmed success never reports an error reason")
    check(worker("Auto Kill Coconut Crab",false,true) and calls==2,"Same API supports verified off state")
    check(not worker("Auto Oil",true,true) and calls==2,"Unrequested switches cannot change")
    tables[2]={["Auto Coconut Crab"]={Set=function()error("Must not call")end}}
    check(not worker("Auto Kill Coconut Crab",true,true) and calls==2,"Ambiguous API fails closed")
    tables[2]=nil;button.checked=true
    check(not worker("Auto Kill Coconut Crab",true,true) and calls==2,"Config UI mismatch cannot toggle")
    button.checked=false
    local callback=function()end
    local fallback=createSwitch({tables=function()return tables end,
        values=function(f)return f==callback and {config,button} or {} end,
        buttons=function()return {button} end,connections=function()return {{Function=callback}}end,
        isButton=function(v)return v==button end,checked=function(b)return b.checked end,
        clock=function()return 0 end,wait=function()error("Unexpected delayed confirmation")end})
    check(fallback("Auto Kill Coconut Crab",true,true) and calls==3,"Virtualized setter uses verified live GUI callback binding")
    -- Exercise the actual background worker with copied state and fake remotes.
    local segment=assert(source:match("(    local function treatMultiplier%(s%).-)\n    function R.level"))
    local make=assert(loadstring("return function(H,Q,BeeStats,questFacts,pending,clone,key,finish) local R={};local env=H.env;local report=H.Report;local state={};"..segment.." return R end"))()
    local function copy(t)local o={};for k,v in pairs(t)do o[k]=type(v)=="table"and copy(v)or v end;return o end
    local function fixture(mode)
        local bee={Type="Vicious",Birth=100,Lvl=10,Bond=3999900,Traits={}}
        local stats={Quests={Active={},Completed={"The Family Final"}},Eggs={Treat=40},Honeycomb={x4={y5=bee}},Amulets={}}
        local env={};local fed,switched,finished=0,0,0;local before
        local H={env=env,Report={},Config={AutoQuestAssist=true},checkStop=function()end,
            scan=function(s)return{{x=4,y=5,bee=s.Honeycomb.x4.y5}}end,
            refresh=function()return stats end,hiveFloor=function()return "hive"end,near=function()end,
            assertAtlasPaused=function()end,release=function()end,
            move=function()
                if mode=="changed"then bee.Birth=101 end
                if mode=="stock-changed"then stats.Eggs.Treat=9 end
            end,
            crabSwitch=function()switched+=1;return true,nil,true end}
        H.invokeFeed=function(b,x,y,item,count)
            check(x==4 and y==5 and item=="Treat" and count==10,"Exact Vicious coordinate and capped owned feed")
            before=b;fed+=1;env.FullHiveUncertain={FeedBefore=b}
            stats.Eggs.Treat-=count;bee.Bond+=count*10;bee.Lvl=mode=="under-level"and 11 or 12
            if mode=="uncertain"then return nil,false end
            return stats.Eggs.Treat,true
        end
        if mode=="stopped"then env.FullHiveStop=true end
        if mode=="ready"then bee.Lvl=12;bee.Bond=4000000 end
        if mode=="short"then stats.Eggs.Treat=9 end
        if mode=="exact"then stats.Eggs.Treat=10 end
        local worker=make(H,Q,{LvlToTotalBond=function()return 4000000 end},function()return{}end,
            function()return mode=="pending"end,copy,function(t)return table.concat(t,",")end,
            function()finished+=1;env.FullHiveUncertain=nil end)
        local ok,acted=pcall(worker.vicious,stats)
        return ok,acted,fed,switched,finished,env,before,worker,stats
    end
    local ok,acted,fed,switched,finished,env,before,worker,stats=fixture()
    check(ok and acted and fed==1 and finished==1 and switched==0,"Feed completes before crab enable")
    check(before.Treats==40 and before.Cells[1].bee.Bond==3999900,"Receipt baseline copied before mutation")
    check(not worker.vicious(stats) and stats.Eggs.Treat==30,"Next fresh pass enables crab without more feed")
    for _,mode in ipairs({"stopped","pending","changed","short","stock-changed"})do
        ok,acted,fed,switched=fixture(mode)
        check(ok and not acted and fed==0 and switched==0,"Stop pending or changed coordinate cannot spend")
    end
    ok,acted,fed,switched,finished,env=fixture("uncertain")
    check(not ok and fed==1 and finished==0 and env.FullHiveUncertain.FeedBefore,"Uncertain feed retains copied receipt")
    ok,acted,fed,switched,finished,env=fixture("under-level")
    check(not ok and fed==1 and finished==0 and env.FullHiveUncertain.FeedBefore,"A feed falling short of12 cannot be accepted or retried")
    ok,acted,fed,switched,finished=fixture("exact")
    check(ok and acted and fed==1 and finished==1 and switched==0,"Exact owned full deficit sends one feed only")
    ok,acted,fed,switched=fixture("ready")
    check(ok and not acted and fed==0 and switched==1,"Existing level 12 enables Atlas only")
    return {passed=passed}
end
