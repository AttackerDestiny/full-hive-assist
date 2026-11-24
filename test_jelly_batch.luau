-- Exercise the actual admission/refill helpers without game changes or remotes.
return function(runtime,Policy,Types)
    local source=assert(runtime:match("(local function jellyBatchReady%(s%).-)\nlocal function find%(cells,cell%)"))
    local active=assert(runtime:match("(local function activeJellyBatch%(s%).-)\nlocal function context"))
    local reserve=assert(runtime:match("(local function hiveHoneyReserve%(s%).-)\nlocal function activeJellyBatch"))
    local scan=assert(runtime:match("(local function scan%(s%).-)\nlocal function progressionToyPart"))
    local refillSource=assert(runtime:match("(local function refill%(%)%s.-)\nlocal function eventAction"))
    local factory=assert(loadstring('return function(env,Report,player,game,hive,Policy,Config,refresh,plan,buy,move,hiveFloor,checkStop,royalJellyPurchases,progression,Types)\nlocal lateStarted=false; local pauseCheckpoint=checkStop\n'..
        scan..'\n'..reserve..'\n'..active..'\n'..source..'\n'..refillSource..'\nreturn jellyBatchReady,jellyBatchSpent,refill\nend'))()
    local passed=0
    local function check(v,message) assert(v,message); passed+=1 end
    local function fixture(target,inventory,gearReserve)
        local env={}; local report={RefillAmount=target,CollectorFallback=false}
        local s={Eggs={RoyalJelly=inventory},Honey=1e15,Totals={Purchases={Eggs={RoyalJelly=75}}}}
        local purchases={}; local config={AutoPurchase=true,HoneyReserve=0}
        local function plan()
            return {},s.Honeycomb and Policy.snapshot(s,Types) or table.create(41,true),41
        end
        local ready,spent,refill=factory(env,report,{UserId=7},{JobId='test'},function() return {Name='Hive'} end,
            Policy,config,function() return s end,plan,function(_,amount,_,ceiling)
                check(amount==1 or amount==10 or amount==100 or amount==1000 or amount==10000 or amount==100000,'Only supported pack amounts')
                check(s.Eggs.RoyalJelly+amount<=ceiling,'Top-up never overbuys')
                purchases[#purchases+1]=amount; s.Eggs.RoyalJelly+=amount
            end,function() end,function() end,function() end,function() return 75 end,
            gearReserve and {inspect=function()return {reserveHoney=gearReserve}end,
                allowsHive=function()return true end},Types)
        return env,report,s,ready,spent,refill,purchases,config
    end
    for _,occupied in ipairs({1,7,29,30,32,33,34,35}) do
        for _,inventory in ipairs({0,1,2,99}) do
            local env,_,s,ready,spent=fixture(600,inventory)
            s.Honeycomb={};s.UnlockedCells=38;s.Totals.Purchases.HiveSlots=13
            for i=1,occupied do s.Honeycomb["x"..i]={y1={Type="Brave",Traits={}}}end
            check(ready(s)==(occupied<33 and inventory>0),"Single jelly admission uses occupied count at "..occupied)
            check(not env.FullHiveJellyBatch,"Small inventories never seed a persistent batch")
            spent(0);s.Eggs.RoyalJelly=1
            check(ready(s)==(occupied<33),"New one-jelly gift is usable only below 33 bees")
        end
    end
    do
        local _,_,s,_,_,refill,purchases=fixture(100,0)
        s.Honeycomb={};s.UnlockedCells=38
        for i=1,32 do s.Honeycomb["x"..i]={y1={Type="Brave",Traits={}}} end
        check(not refill() and #purchases==0,"A wealthy 32-bee hive cannot buy jelly for rolling")
        s.Honeycomb.x33={y1={Type="Brave",Traits={}}}
        check(refill() and #purchases>0,"At 33 occupied bees the normal refill resumes")
    end
    do
        local _,_,s,_,_,refill,purchases=fixture(100,0,100000000)
        s.Honey=100000000
        check(not refill() and #purchases==0,"Refill cannot spend the planned gear reserve")
        s.Honey+=Policy.jellyCost(75,100)
        check(refill() and #purchases>0,"Refill may use the exact surplus above gear funds")
    end
    for _,target in ipairs({100,200,600,1000,2000,4000,10000,100000,200000,400000,500000}) do
        for _,inventory in ipairs({0,1,target-1,target,target+1}) do
            local env,_,s,ready=fixture(target,inventory)
            check(ready(s)==(inventory>=target),'Fresh batch needs at least '..target..', got '..inventory)
            check((env.FullHiveJellyBatch~=nil)==(inventory>=target),'Admission state matches refill threshold')
        end
        local env,report,s,ready,spent=fixture(target,target)
        check(ready(s),'Full inventory opens a batch')
        for _,remaining in ipairs({target-1,math.floor(target/2),1}) do
            spent(remaining); s.Eggs.RoyalJelly=remaining
            check(ready(s),'Admitted batch continues below target')
        end
        spent(0); s.Eggs.RoyalJelly=1
        check(not ready(s) and env.FullHiveJellyBatch==nil,'A gift after exhaustion cannot revive batch')
        s.Eggs.RoyalJelly=target; check(ready(s),'Next exact refill reopens batch')
        report.RefillAmount=target*2
        check(ready(s),'A changed refill preserves admitted jelly until exhaustion')
        s.Eggs.RoyalJelly=target+5
        check(ready(s),'Gifts received during an admitted batch remain usable')
        spent(0); s.Eggs.RoyalJelly=1
        check(not ready(s),'After exhausting a continued batch a small drop is blocked')
    end
    for _,field in ipairs({'Owner','Hive','Job','Version'}) do
        local env,_,s,ready=fixture(100,100); ready(s)
        s.Eggs.RoyalJelly=50
        env.FullHiveJellyBatch[field]=field=='Remaining' and 49 or 'changed'
        check(not ready(s),'Changed '..field..' cannot reuse batch')
    end
    do
        local _,report,s,ready,spent=fixture(100,100); ready(s)
        spent(99); s.Eggs.RoyalJelly=99
        report.CollectorFallback=true
        check(ready(s),'Recovery/refill changes do not strand admitted jelly')
        spent(0); s.Eggs.RoyalJelly=1
        check(not ready(s),'Exhaustion still requires a new full batch')
    end
    for _,inventory in ipairs({0,1,57,599}) do
        local _,_,s,ready,_,refill,purchases=fixture(600,inventory)
        check(refill() and ready(s) and s.Eggs.RoyalJelly==600,'Top-up reaches exact 600 from '..inventory)
        local total=0; for _,amount in ipairs(purchases) do total+=amount end
        check(total==600-inventory,'Only missing inventory purchased')
        local count=#purchases; s.Eggs.RoyalJelly=599
        check(refill() and #purchases==count,'Running batch is never topped up per roll')
    end
    do
        local _,_,s,ready,_,refill,purchases,config=fixture(600,1)
        s.Honey=598e6
        check(not refill() and not ready(s) and #purchases==0,'Cannot afford full missing amount: preserve gift and honey')
        s.Honey=1e15; config.AutoPurchase=false
        check(not refill() and #purchases==0,'AutoPurchase false waits without spending')
        s.Eggs.RoyalJelly=600
        check(refill() and #purchases==0,'Exact owned inventory works with AutoPurchase disabled')
        s.Eggs.RoyalJelly=601
        check(refill() and #purchases==0,'Excess inventory starts a batch without purchases')
    end
    -- Verify that 44-slot hives use their ordinary refill from the first batch.
    local planning=assert(runtime:match('(local function scan%(s%).-)\nlocal function find%(cells,cell%)'))
    local make=assert(loadstring('return function(Policy,Types,env)\n'..
        'local Config={HoneyReserve=0,DryRun=false,AutoPurchase=true}; local Report={}; local lateStarted=false; local nextFlexible; local rollTask; local player={UserId=7}; local game={JobId="test"}; local function hive() return {Name="Hive"} end; local function starEggUses(s) return 0 end\n'..
        planning..'\nreturn plan,jellyBatchReady,jellyBatchSpent,Report\nend'))()
    local s={Honey=1e15,Eggs={RoyalJelly=1},Honeycomb={x1={y1={Type='Bubble',Traits={}}}},Totals={Purchases={HiveSlots=19,Eggs={RoyalJelly=75}},EggUses={}}}
    for i=2,35 do s.Honeycomb["x"..i]={y1={Type="Tabby",Traits={}}}end
    local env={}; local plan,ready,spent,report=make(Policy,Types,env)
    plan(s); check(report.RefillAmount==4000 and report.NormalRefillAmount==4000,'44-slot hive advertises its ordinary 4k refill')
    check(not ready(s),'A small gift cannot open a batch')
    s.Eggs.RoyalJelly=4000; plan(s); check(ready(s),'Ordinary 4k admits the first batch')
    s.Eggs.RoyalJelly=3900; spent(3900); plan(s)
    check(report.RefillAmount==4000 and ready(s),'Admitted batch continues below threshold')
    spent(0); s.Eggs.RoyalJelly=1; plan(s)
    check(report.RefillAmount==4000 and not ready(s),'After exhaustion, base 4k is required')
    s.Eggs.RoyalJelly=4000; plan(s); check(ready(s),'Exact base refill starts next batch')
    local spending=assert(runtime:match('(local function spend%(cell,item,validate,expectedTask,eventBee%).-)\nshopFloor=function'))
    local makeSpend=assert(loadstring('return function(s,ready,low,eventBee,background,progression)\nlocal env={} -- Fixture state must never resolve an executor global.\n'..
        'local Report={Actions=0,RoyalJellyUsed=0,RollMode="off"}; local Config={MaxActions=100,MaxRoyalJellies=1000,RollDelay=0}; local Events={ConstructHiveCellFromEgg={}}; local target={x=1,y=1,bee={Type="Bubble",Traits={}}}; local calls=0; local function checkStop() end; local function acquire() end; local function move() end; local function near() end; local function release() end; local function hiveFloor() end; local function refresh() return s end; local function plan() return {protected={},temporary={}}, {target} end; local function find() return target end; local jellyBatchReady=ready; local function jellyBatchSpent() end; local function invoke(_,_,_,item) calls+=1; return s.Eggs[item]-1,true,{x1={y1=eventBee and {Type=eventBee,Traits={}} or target.bee}} end; local Cache={Set=function() end}; local function mode(name) s.Settings={}; Report.RollMode=name end; local Policy={key=function() return "1,1" end,singleJelly=function()return low==true end}; local task={wait=function() end}\n'..
        spending..'\nreturn function() return spend(target,eventBee and eventBee.."Bee" or "RoyalJelly",function() return true end,nil,eventBee) end,function() return calls end\nend'))()
    do
        local _,_,snapshot,batchReady,spent=fixture(600,1)
        local spend,calls=makeSpend(snapshot,batchReady)
        check(spend()==false and calls()==0,'Fresh incidental gift is blocked immediately before the remote')
        snapshot.Eggs.RoyalJelly=600
        check(spend()~=false and calls()==1,'Exact inventory can send a verified roll')
        spent(599); snapshot.Eggs.RoyalJelly=599
        check(spend()~=false and calls()==2,'An admitted batch sends its next roll below target')
        spent(0); snapshot.Eggs.RoyalJelly=1
        check(spend()==false and calls()==2,'Post-exhaustion gift sends no remote')
    end
    do
        local lowEnv={}
        local lowPlan,lowReady,_,lowReport=make(Policy,Types,lowEnv)
        local lowStats={Honey=1e15,Eggs={RoyalJelly=1},Honeycomb={},Totals={Purchases={HiveSlots=19,Eggs={RoyalJelly=75}},EggUses={}}}
        for i=1,32 do lowStats.Honeycomb["x"..i]={y1={Type="Brave",Traits={}}}end
        local q=lowPlan(lowStats)
        check(lowReport.RefillAmount==1 and q.mode=="off" and lowReady(lowStats),"Actual 32-bee planner permits one normal jelly")
        lowStats.Honeycomb.x33={y1={Type="Brave",Traits={}}}
        check(not lowReady(lowStats) and lowReport.RefillAmount==4000,"Fresh 33-bee boundary rechecks its ordinary threshold before admission")
    end
    do
        local snapshot={Eggs={PuppyBee=1,RoyalJelly=1}}
        local reserve={allowsHive=function()return false end}
        local hatch,count=makeSpend(snapshot,function()return true end,false,"Puppy",reserve,
            {eventCurrency=function()return 0 end})
        check(hatch()~=false and count()==1,"Owned Puppy egg may hatch during Star Amulet honey priority")
        local blocked,blockedCount=makeSpend(snapshot,function()return true end,false,"Puppy",reserve,
            {eventCurrency=function()return nil end})
        check(blocked()==false and blockedCount()==0,"Event placement still honors fresh progression priority")
        local roll,rollCount=makeSpend(snapshot,function()return true end,false,nil,reserve)
        check(roll()==false and rollCount()==0,"Normal rolls still honor Star Amulet priority")
    end
    for _,flag in ipairs({"RollToGifted","RollToLegendary","RollToMythic","RollToMutation"})do
        local snapshot={Eggs={RoyalJelly=1},Settings={[flag]=true}}
        local spend,calls=makeSpend(snapshot,function()return true end,true)
        check(spend()==false and calls()==0,"Low-bee guard disables "..flag.." before any remote")
        check(spend()~=false and calls()==1,"Normal low-bee request consumes exactly one jelly")
    end
    return {passed=passed}
end
