-- Pure immutable snapshots and result tables only; no transport fixture.
return function(R)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local function copy(t) local r={};for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end;return r end
    local function state(basic)
        return {Eggs={Basic=basic},UnlockedCells=26,Totals={Purchases={HiveSlots=1}},
            Honeycomb={x1={y1={Type="Cool",Lvl=8,Traits={"Gifted",Mutation={Stat="Attack",Amount=1}}}}}}
    end
    local function result(s)
        local fresh=copy(s);fresh.Eggs.Basic=(s.Eggs.Basic or 0)-1
        fresh.Honeycomb.x4={y9={Type="Basic",Lvl=1,Traits={}}}
        return {accepted=true,remaining=fresh.Eggs.Basic,comb=copy(fresh.Honeycomb)},fresh
    end
    local s=state(1)
    local before=assert(R.capture(s,4,9));local response,fresh=result(s)
    -- Model replication mutating the caller's original nested tables while a
    -- request yields. The copied snapshot must retain the pre-request facts.
    s.Eggs.Basic=0;s.UnlockedCells=50
    s.Honeycomb.x1.y1.Type="Brave";s.Honeycomb.x1.y1.Lvl=1
    s.Honeycomb.x1.y1.Traits.Mutation.Amount=99
    check(before.Item=="Basic" and before.Inventory==1 and before.Capacity==26 and before.Count==1,"Capture retains scalar pre-request values")
    check(before.Cells["1,1"].Type=="Cool" and before.Cells["1,1"].Lvl==8
        and before.Cells["1,1"].Traits.Mutation.Amount==1,"Capture copies nested trait and bee identity")
    check(R.validate(before,response,fresh),"Successful zero-remaining hatch reconciles despite source mutation")
    fresh.Eggs.Basic=nil
    check(R.validate(before,response,fresh),"Sparse zero inventory readback is accepted")
    for _,field in ipairs({"accepted","remaining","comb"}) do
        local bad=copy(response);bad[field]=nil
        check(not R.validate(before,bad,fresh),"Missing response field fails closed: "..field)
    end
    local bad=copy(response);bad.accepted=false
    check(not R.validate(before,bad,fresh),"Rejected response cannot reconcile")
    bad=copy(response);bad.remaining=1
    check(not R.validate(before,bad,fresh),"Unchanged response inventory fails consumption validation")
    bad=copy(fresh);bad.Eggs.Basic=1
    check(not R.validate(before,response,bad),"Unchanged fresh inventory remains uncertain")
    bad=copy(fresh);bad.UnlockedCells=27
    check(not R.validate(before,response,bad),"Hatching cannot change unlocked capacity")
    bad=copy(fresh);bad.Honeycomb.x4=nil
    check(not R.validate(before,response,bad),"Absent target never proves a hatch")
    bad=copy(fresh);bad.Honeycomb.x4.y9.Type="Bumble"
    check(not R.validate(before,response,bad),"Target readback must match response")
    bad=copy(fresh);bad.Honeycomb.x2={y1={Type="Basic",Traits={}}}
    check(not R.validate(before,response,bad),"More than one new bee fails closed")
    for _,field in ipairs({"Type","Traits"}) do
        bad=copy(fresh)
        bad.Honeycomb.x1.y1[field]=field=="Type" and "Brave" or {}
        check(not R.validate(before,response,bad),"Prior bee fingerprint preserved: "..field)
    end
    bad=copy(fresh);bad.Honeycomb.x1.y1.Lvl=9;bad.Honeycomb.x4.y9.Lvl=4
    check(R.validate(before,response,bad),"Natural old and new bee level increases do not invalidate a hatch")
    bad=copy(fresh);bad.Honeycomb.x1.y1.Traits.Mutation.Amount=2
    check(R.validate(before,response,bad),"Incidental trait progress is not a stronger preservation policy")
    bad=copy(response);bad.comb.x1.y1.Traits.Mutation.Amount=2
    check(R.validate(before,bad,fresh),"Response trait progress retains the existing species/gifted contract")
    bad=copy(response);bad.comb.x4.y9.Traits={"Gifted"}
    check(not R.validate(before,bad,fresh),"A gifted hatch response cannot lose Gifted in fresh readback")
    for _,basic in ipairs({0,-1,1.5,"1",math.huge,0/0}) do
        check(R.capture(state(basic),4,9)==nil,"Invalid or empty initial Basic inventory cannot be captured")
    end
    check(R.capture(state(nil),4,9)==nil,"Missing initial inventory is not a hatch baseline")
    check(R.capture(state(1),1,1)==nil,"Occupied coordinates cannot be captured")
    check(R.capture(state(1),0,9)==nil,"Invalid coordinate cannot be captured")
    local noRoom=state(1);noRoom.UnlockedCells=1
    check(R.capture(noRoom,4,9)==nil,"Invalid unlocked capacity cannot be captured")
    check(not R.validate(nil,response,fresh),"Missing snapshot fails closed")
    for _,item in ipairs({"Silver","Gold"}) do
        local s=state(1);s.Eggs[item]=1
        local before=assert(R.capture(s,4,9,item))
        local response,after=result(s)
        after.Eggs.Basic=1
        check(not R.validate(before,response,after),"The selected "..item.." egg must be consumed")
        after.Eggs[item]=nil
        check(R.validate(before,response,after),"A sparse zero count reconciles for "..item)
    end
    return {passed=passed}
end
