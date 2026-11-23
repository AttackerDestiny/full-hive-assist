return function(P,runtime)
    local source=assert(runtime:match("(local function eventAction%(s,cells,p%).-)\nlocal function giftedBasic"))
    local make=assert(loadstring("return function(Policy,buy,scan,rollTask,progression)\n"
        .."local Config={AutoPurchase=true};local EggTypes={Get=function() return {TicketCost=500} end}\n"
        ..source.."\nreturn eventAction\nend"))()
    local cells={{x=1,y=1,bee={Type="Basic",Traits={}}}}
    local plan={starter=true,candidates=cells,keep={},protected={},temporary={}}
    local stats={Eggs={Ticket=500}}
    local purchases=0
    local worker=make(P,function(item,amount,shop,_,validate)
        assert(item=="TabbyBee" and amount==1 and shop=="TicketShop")
        assert(validate(stats))
        assert(not validate({Eggs={Ticket=499}}))
        assert(not validate({Eggs={Ticket=500,TabbyBee=1}}))
        purchases+=1
        return true
    end,function() return cells end,{x=1,y=1},{
        allowsEventPurchase=function(_,currency,cost) return currency=="Ticket" and cost==500 end,
    })
    assert(worker(stats,cells,plan) and purchases==1,"Starter Bee can buy during an active roll lease")
    assert(not worker({Eggs={Ticket=499}},cells,plan) and purchases==1,"Event buy order holds tickets for Tabby")
    assert(P.eventGumdropPack(1499,1000)==nil,"Gummy holds tickets below 1500 Gumdrops")
    assert(P.eventGumdropPack(1500,333)==nil,"Gummy waits for the full fixed-pack budget")
    local gumdrops,tickets=1500,334
    while gumdrops<2500 do
        local pack=assert(P.eventGumdropPack(gumdrops,tickets))
        assert(pack==3 or pack==30 or pack==300,"Only actual shop packs are used")
        gumdrops+=pack;tickets-=pack/3
    end
    assert(gumdrops==2502 and tickets==0,"Only the smallest attainable top-up is bought")
    local purchaseSource=assert(runtime:match("(local function buy%(item,amount,shop,inventoryCeiling,validatePurchase%).-)\nlocal function refill"))
    local purchase=assert(loadstring("return function()\n"
        .. 'local stats={Eggs={Ticket=503}};local env={};local Config={AutoPurchase=true,MaxActions=10};local Report={Actions=0};local Events={};local background={allowsHive=function()return false end};local function acquire() end;local function move()end;local function near()end;local function release()end;local function shopFloor()end;local function refresh()return stats end;local function hiveHoneyReserve()return 0 end;local function fixedShopPackage(item)return {Type=item}end;local EggTypes={Get=function()return {TicketCost=500}end};local function invoke(_,_,pack)stats.Eggs[pack.Type]=1;stats.Eggs.Ticket-=500;return true end\n'
        ..purchaseSource.."\nreturn buy,stats\nend"))()
    local buy,live=purchase()
    assert(not buy("PuppyBee",1,"TicketShop",nil,function()return false end) and live.Eggs.Ticket==503,
        "Failed event validation sends no purchase")
    assert(not buy("PuppyBee",1,"TicketShop") and live.Eggs.Ticket==503,
        "Ordinary purchases retain the background priority check")
    assert(buy("PuppyBee",1,"TicketShop",nil,function(s)return s.Eggs.Ticket>=500 end)
        and live.Eggs.PuppyBee==1 and live.Eggs.Ticket==3,"Validated ticket spending proceeds during Star Amulet honey priority")
    return {passed=12}
end
