-- Pure values only. No callbacks, host, game services, or transport fixtures.
return function(R)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local function copy(t) local r={};for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end;return r end
    local function fixture()
        local stats={Eggs={Ticket=200,BlueExtract=22},BlenderState={Recipe="BlueExtract",Count=231,StartTime=600}}
        local action={kind="speedup-blender",item="BlueExtract",amount=231,remainingUnits=118,
            orderCount=231,orderStartTime=600,tickets=118}
        return stats,action
    end
    local s,a=fixture();local before=assert(R.capture(s,a))
    s.Eggs.Ticket=82;s.Eggs.BlueExtract=253;s.BlenderState.Count=999;s.BlenderState.StartTime=900
    a.amount=999;a.tickets=999
    check(before.Count==231 and before.StartTime==600 and before.RemainingUnits==118,
        "Snapshot captures full output and quoted remaining units independently")
    check(before.BeforeTickets==200 and before.BeforeOutput==22 and before.Tickets==118,
        "Yielding updates cannot rewrite captured inventory or expected debit")
    local fresh={Eggs={Ticket=82,BlueExtract=253}}
    check(R.validate(before,fresh),"231 full output and 118 tickets reconcile a partially elapsed order")
    fresh.BlenderState=false
    check(R.validate(before,fresh),"Explicit false Blender state denotes no active order")
    local bad=copy(fresh);bad.Eggs.BlueExtract=22+118
    check(not R.validate(before,bad),"Remaining units cannot replace the full output count")
    bad=copy(fresh);bad.Eggs.BlueExtract=254
    check(not R.validate(before,bad),"Excess unexplained output also remains uncertain")
    bad=copy(fresh);bad.Eggs.BlueExtract=nil
    check(not R.validate(before,bad),"Missing output does not prove completion")
    bad=copy(fresh);bad.Eggs.Ticket=200
    check(not R.validate(before,bad),"Unchanged tickets cannot acknowledge the quote")
    bad=copy(fresh);bad.Eggs.Ticket=81
    check(not R.validate(before,bad),"Unexpected additional ticket consumption fails closed")
    for _,order in ipairs({{Recipe="BlueExtract",Count=231,StartTime=600},
        {Recipe="BlueExtract",Count=231,StartTime=601},{Recipe="Oil",Count=1,StartTime=700},true}) do
        bad=copy(fresh);bad.BlenderState=order
        check(not R.validate(before,bad),"Any residual or replacement queue prevents acknowledgment")
    end
    for _,field in ipairs({"amount","orderCount","orderStartTime","item"}) do
        local stats,action=fixture()
        action[field]=field=="item" and "Oil" or action[field]+1
        check(R.capture(stats,action)==nil,"Travel quote must retain exact order identity: "..field)
    end
    s,a=fixture();a.amount=118
    check(R.capture(s,a)==nil,"Legacy remaining-only output quote is rejected")
    for _,invalid in ipairs({-1,0,1.5,"118",math.huge,0/0}) do
        s,a=fixture();a.tickets=invalid
        check(R.capture(s,a)==nil,"Invalid ticket quotes fail closed")
    end
    s,a=fixture();s.Eggs.Ticket=117
    check(R.capture(s,a)==nil,"Insufficient tickets cannot begin speedup")
    s,a=fixture();a.remainingUnits=232
    check(R.capture(s,a)==nil,"Remaining units cannot exceed the queued count")
    s,a=fixture();s.Eggs.BlueExtract=-1
    check(R.capture(s,a)==nil,"Malformed output baseline cannot be captured")
    s,a=fixture();s.Eggs.BlueExtract=nil
    local zero=assert(R.capture(s,a))
    check(R.validate(zero,{Eggs={Ticket=82,BlueExtract=231}}),"A sparse missing output baseline is zero")
    s,a=fixture();s.Eggs.Ticket=118
    local exact=assert(R.capture(s,a))
    check(R.validate(exact,{Eggs={BlueExtract=253}}),"A depleted ticket readback can omit its zero key")
    check(not R.validate(nil,fresh),"Missing snapshot fails closed")
    check(not R.validate(before,{}),"Missing fresh inventory fails closed")
    do
        local definition={Ingredients={{Category="Eggs",Type="Strawberry",Amount=50},{Category="Eggs",Type="RoyalJelly",Amount=10}}}
        local action={kind="cancel-craft",item="RedExtract",amount=3,orderCount=3,orderStartTime=100}
        for completed=0,3 do
            local stats={Eggs={RedExtract=2,Strawberry=7,RoyalJelly=5,Ticket=8},BlenderState={Recipe="RedExtract",Count=3,StartTime=100}}
            local before=assert(R.captureCancel(stats,action,definition,completed))
            local fresh={Eggs={RedExtract=2+completed,Strawberry=7+(3-completed)*50,RoyalJelly=5+(3-completed)*10,Ticket=8},BlenderState=false}
            local ok,_,proof=R.validateCancel(before,fresh)
            check(ok and proof.Completed==completed,"Cancel reconciles completed units and remaining refund at "..completed)
            stats.Eggs.Strawberry=999;stats.BlenderState.Count=99
            check(before.Inputs.Strawberry.Before==7 and before.Count==3,"Cancel baseline survives yielding cache mutation")
            fresh.Eggs.RoyalJelly-=1;check(not R.validateCancel(before,fresh),"Incomplete Royal Jelly refund fails closed")
            fresh.Eggs.RoyalJelly+=1;fresh.BlenderState={};check(not R.validateCancel(before,fresh),"Uncleared Blender queue cannot confirm cancellation")
        end
        local stats={Eggs={RedExtract=2},BlenderState={Recipe="RedExtract",Count=3,StartTime=100}}
        local before=assert(R.captureCancel(stats,action,definition,1))
        check(not R.validateCancel(before,{Eggs={RedExtract=2,Strawberry=150,RoyalJelly=30}}),"Already completed output cannot disappear during cancellation")
        check(R.validateCancel(before,{Eggs={RedExtract=4,Strawberry=50,RoyalJelly=10}}),"Progress during the original request is reconciled from actual returned output")
        action.orderStartTime=101;check(not R.captureCancel(stats,action,definition,1),"Changed server order identity blocks cancellation")
        action.orderStartTime=100
        definition.Ingredients[1].Category="Unknown";check(not R.captureCancel(stats,action,definition,1),"Unknown refund category blocks cancellation")
    end
    return {passed=passed}
end
