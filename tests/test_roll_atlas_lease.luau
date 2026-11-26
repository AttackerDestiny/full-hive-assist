return function(backgroundSource,runtime)
    local source=assert(backgroundSource:match("(    function R.step%(s%).-)\n    return R"))
    local make=assert(loadstring("return function(H,R,state,A,canSpendHoney,generate,pending) local env=H.env;local function assistQuest()return false end\n"..source.."\nreturn R.step end"))()
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local releases,generated=0,0
    local lease={x=2,y=4};local env={FullHiveRollTask=lease}
    local H={env=env,Config={AutoAmulets=true,AutoQuestAssist=false},release=function()releases+=1 end}
    local target={name="Gold Star Amulet Generator",price=250000000,minimumPollenTotal=0}
    local ready,blocked=false,false
    local R={inspect=function()return target,{},{}end,consumables=function()return false end}
    local step=make(H,R,{}, {moonGood=function()return true end,read=function()end},function()return ready end,
        function()generated+=1;return true end,function()return blocked end)
    for i=1,10 do
        check(step({Eggs={}})==false,"Passive savings pass returns without spending")
        check(releases==0 and env.FullHiveRollTask==lease,"Rolling lease stays held across passive passes")
    end
    env.FullHiveRollTask=nil;env.FullHiveBasicLock={x=1,y=1}
    check(not step({Eggs={}})and releases==0,"Gifted Basic continuation also retains Atlas")
    env.FullHiveBasicLock=nil
    check(not step({Eggs={}})and releases==1,"Idle savings still releases Atlas")
    env.FullHiveRollTask=lease;ready=true
    check(step({Eggs={}})and generated==1,"Actually funded amulet work retains its existing priority")
    blocked=true
    check(not step({Eggs={}})and generated==1 and releases==1,"Pending work is not retried or released by passive step")
    local waitSource=assert(runtime:match("(local function waitFor%(reason,seconds%).-)\nlocal function run"))
    local report={};local waited
    local wait=assert(loadstring("return function(Report,release,task,Config) "..waitSource.." return waitFor end"))()(report,
        function()releases+=1 end,{wait=function(seconds)waited=seconds end},{PollSeconds=3})
    wait("Waiting for refill")
    check(releases==2 and waited==3 and report.Phase=="waiting","A real refill wait resumes farming")
    local idleSource=assert(runtime:match("(local function releaseIdle%(%).-)%s*local function scan"))
    local idle=assert(loadstring("return function(leased,rollTask,basicLock,env,Report,release) "..idleSource.." return releaseIdle end"))()
    local function exercise(held,task,lock,flags,report,shouldHold)
        local calls=0
        report=report or {}
        idle(held,task,lock,flags or {},report,function()calls+=1 end)()
        check(calls==(shouldHold and 0 or 1),"Only active uninterrupted rolling retains the lease")
        check((report.RollLeaseHeld==true)==shouldHold,"Lease telemetry matches the decision")
    end
    exercise(true,lease,nil,nil,nil,true)
    exercise(true,nil,lease,nil,nil,true)
    exercise(true,nil,nil,nil,nil,false)
    exercise(false,lease,nil,nil,nil,false)
    for _,flag in {"FullHiveStop","FullHivePending","AutoHivePendingRequest","FullHiveUncertain","AutoHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning"}do
        local flags={[flag]={}}
        exercise(true,lease,nil,flags,nil,false)
        check(flags[flag]~=nil,"Request/stop/workflow flags are never cleared")
    end
    exercise(true,lease,nil,nil,{PauseRequested=true},false)
    exercise(true,lease,nil,nil,{CleanupError="test"},false)
    check(runtime:find("near=near,release=releaseIdle,",1,true)~=nil,"Workers use the idle-only release")
    return {passed=passed}
end
