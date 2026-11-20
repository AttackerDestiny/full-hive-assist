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
    return {passed=5}
end
