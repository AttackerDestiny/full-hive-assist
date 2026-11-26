return function(runtime,M)
    local source=assert(runtime:match("(local function mythicDiscoveryStep%(s,p%).-)\nlocal function starReady"))
    local factory=assert(loadstring("return function(H)\n"..
        "local Report,env,Config,Events,MythicDiscovery=H.Report,H.env,H.Config,{},H.M\n"..
        "local rollTask,basicLock;local discoverySnapshot=H.snapshot;local acquire,move,near,release=H.acquire,H.move,H.near,H.release\n"..
        "local refresh,invokeRequest=H.refresh,H.invoke;local mode=function(name)assert(name=='off')end\n"..
        "local function hiveFloor()return {}end;local function assertAtlasPaused()assert(H.leased)end\n"..
        "local buy,fixedShopPackage,Packages,Reqs,hiveHoneyReserve=H.buy,H.package,H.Packages,H.Reqs,H.reserve\n"..
        "local AmuletPolicy={starTarget=function()end};local progression={eventCurrency=function(s)return s.Eggs.Ticket or 0 end}\n"..
        "local function ensureRollTask(p)H.task={x=p.target.x,y=p.target.y,DiscoveryMythic=p.discoveryMythic}end\n"..
        source.."\nreturn mythicDiscoveryStep\nend"))()
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    for _,scenario in ipairs({"feed","early-gift","reject","changed-decision","tickets","overshoot","treat","unaffordable","acquire"})do
        local H={M=M,Report={Actions=0,Progression={DiscoveryPreparation=true}},env={},Config={AutoPurchase=true,MaxActions=100},calls=0}
        local cell={x=1,y=1,bee={Type="Fuzzy",Traits={},Birth=9}}
        if scenario=="acquire"then cell.bee.Type="Brave"end
        local s={Honey=1000,UnlockedCells=44,Eggs={Pineapple=2500,Ticket=750},Honeycomb={x1={y1=cell.bee}}}
        local action={kind="feed",name="Fuzzy",item="Pineapple",amount=2000,x=1,y=1}
        if scenario=="tickets" or scenario=="overshoot" or scenario=="treat" or scenario=="unaffordable"then action={kind="fund-star-treat",name="Fuzzy"}end
        if scenario=="overshoot"then s.Eggs.Ticket=999 end
        if scenario=="treat"then s.Eggs.Ticket=1250 end
        if scenario=="unaffordable"then s.Honey=99 end
        if scenario=="acquire"then action={kind="acquire",name="Spicy"}end
        H.snapshot=function()
            if scenario=="changed-decision"and H.leased then return {kind="wait"},{cell},{}end
            return action,{cell},{discoveryPreparation=true,queueMaterialsReady=true}
        end
        H.acquire=function()H.leased=true end;H.move=function()end;H.near=function()end;H.release=function()H.leased=false end
        H.refresh=function()return s end
        H.invoke=function(_,baseline,x,y,item,amount,untilGifted)
            H.calls+=1
            check(H.leased and item=="Pineapple"and amount==2000 and untilGifted==false,"Feed uses serialized game quantity and no until-gifted flag")
            check(baseline.Inventory==2500 and baseline.Cells["1,1"].Type=="Fuzzy","Copied pre-request feeding baseline")
            H.env.FullHiveUncertain={FeedBefore=baseline}
            local used=scenario=="early-gift"and 5 or amount
            s.Eggs[item]-=used
            if scenario=="early-gift"then cell.bee.Traits={"Gifted"}end
            return s.Eggs[item],scenario~="reject",s.Honeycomb
        end
        H.reserve=function()return 0 end;H.package=function(item,amount)return {Type=item,Amount=amount}end
        H.Packages={GetCost=function()return {Category="Honey",Amount=100}end,CanPurchase=function()return true end,CanGive=function()return true end,PurchaseRequirements=function()end}
        H.Reqs={Check=function()return true end}
        H.buy=function(item,amount,shop,_,validate)
            check(validate(s),"Fresh purchase validator passes")
            if scenario=="treat"then check(item=="StarTreat"and amount==1 and shop=="TicketShop","Funded tickets buy exactly one Star Treat")
            else check(item=="Ticket"and amount==500 and shop=="TicketDispenser","Ticket funding uses only500 even near1000")end
            H.bought=true;return true
        end
        local worker=factory(H);local p={candidates={cell},complete=true}
        local ok,did=pcall(worker,s,p)
        if scenario=="reject"then check(not ok and H.env.FullHiveUncertain~=nil and H.calls==1,"Rejected feed stays unresolved and is never replayed")
        elseif scenario=="feed"or scenario=="early-gift"then
            check(ok and did and H.env.FullHiveUncertain==nil and not H.leased,"Verified feed clears only its own receipt and releases Atlas")
            check(H.Report.LastMythicFeed.Consumed==(scenario=="early-gift"and 5 or 2000),"Actual server consumption recorded")
        elseif scenario=="changed-decision"then check(ok and not did and H.calls==0 and not H.leased,"Changed resource decision aborts unsent feed")
        elseif scenario=="unaffordable"then check(ok and did and not H.bought,"Unaffordable500 pack waits")
        elseif scenario=="acquire"then check(ok and not did and p.mode=="off"and H.task.DiscoveryMythic=="Spicy"and not p.complete,"Acquisition hands safe coordinate to existing single-roll task")
        else check(ok and did and H.bought,"Funded fallback purchase completes")end
    end
    local modeSource=assert(runtime:match("(local function mode%(name%).-)\nlocal function restoreSettingsDirect"))
    local makeMode=assert(loadstring("return function(Cache,Config,Report,setSettings) "..modeSource.." return mode end"))()
    local s={Eggs={RoyalJelly=100},Settings={}}
    local changes=0;local report={RoyalJellyUsed=0}
    local mode=makeMode({Get=function()return s end},{MaxRoyalJellies=math.huge},report,function(values)changes+=1;s.Settings=values end)
    mode("off");check(changes==0,"Unchanged off settings skip a redundant synchronization")
    mode("gifted");check(changes==1 and s.Settings.RollToGifted,"Changed roll mode still synchronizes")
    mode("gifted");check(changes==1,"Repeated gifted rolls skip redundant synchronization")
    s.Settings.RollToMythic=true;mode("gifted");check(changes==2 and not s.Settings.RollToMythic,"Unexpected flags require synchronization")
    s.Settings=nil;mode("off");check(changes==3,"Unknown settings never skip synchronization")
    return {passed=passed}
end
