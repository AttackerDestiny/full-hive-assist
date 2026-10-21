-- Pure values only; no movement, services, callbacks, or transport stubs.
return function(F)
    local passed=0
    local function check(v,message) assert(v,message);passed+=1 end
    local action={kind="buy-gear"}
    local cost={Category="Honey",Amount=4444444444}
    local stats={Honey=5464000000,Eggs={Ticket=400,Diamond=5}}
    local decision={reserveHoney=4444444444}
    check(F.check(action,decision,cost,stats,0),"Riley's funded gear price is charged once")
    stats.Honey=cost.Amount
    check(F.check(action,decision,cost,stats,0),"Exact gear price is sufficient")
    stats.Honey=cost.Amount-1
    local ok,why=F.check(action,decision,cost,stats,0)
    check(not ok and why=="waiting-purchase-funds:Honey","Changed honey defers without an exception")
    stats.Honey=cost.Amount+100
    check(F.check(action,decision,cost,stats,100),"Exact user reserve survives gear purchase")
    check(not F.check(action,decision,cost,stats,101),"User reserve is never spent")
    stats.Honey=10
    check(F.check({kind="purchase-pack"},{reserveHoney=0},{Category="Honey",Amount=10},stats,0),
        "Material acquisition does not reserve the future gear price")
    check(not F.check({kind="purchase-pack"},{reserveHoney=1},{Category="Honey",Amount=10},stats,0),
        "Material acquisition honors its actual reserve")
    check(F.check({kind="purchase-material"},{reserveHoney=0},{Category="Eggs",Type="Ticket",Amount=400},stats,0),
        "Ticket material purchase uses its exact currency balance")
    check(not F.check(action,{},{{Category="Eggs",Type="Ticket",Amount=250},
        {Category="Eggs",Type="Ticket",Amount=250}},stats,0),"Duplicate currency rows share one balance")
    stats.Honey=100
    check(not F.check(action,{},{{Category="Honey",Amount=60},{Category="Honey",Amount=60}},stats,0),
        "Duplicate honey rows cannot each spend the same honey")
    for _,invalid in ipairs({-1,math.huge,0/0,"100"}) do
        check(not F.check(action,{}, {Category="Honey",Amount=invalid},stats,0),"Invalid costs fail closed")
    end
    check(not F.check(action,{}, {},stats,0),"Empty cost is unknown")
    check(not F.check(action,{}, {Category="Tickets",Amount=1},stats,0),"Unknown currencies fail closed")
    check(not F.check(action,{}, {Category="Honey",Amount=1},stats,-1),"Invalid user reserve fails closed")
    return {passed=passed}
end
