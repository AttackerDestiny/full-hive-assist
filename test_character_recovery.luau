-- Exercises the actual runtime helpers in isolation; no game mutations/remotes.
return function(runtime)
    local helpers=assert(runtime:match("(local CHARACTER_UNAVAILABLE = {}.-)\nlocal function distance"),"Character helpers missing")
    local recovery=assert(runtime:match("(local function runWithCharacterRecovery%(%)%s.-)\nlocal function makeUI"),"Recovery loop missing")
    local factory=assert(loadstring("return function(player,env,Report,run,release,checkStop,task)\nlocal STATS_READ_TIMEOUT={}\nlocal PAUSE_REQUESTED={}\n"..helpers.."\n"..recovery..
        "\nreturn runWithCharacterRecovery,root,characterRoot,CHARACTER_UNAVAILABLE,MOVEMENT_TIMEOUT,STATS_READ_TIMEOUT,PAUSE_REQUESTED\nend"))()
    local checked=0
    local function check(value,message) assert(value,message); checked+=1 end
    if runtime:find("err==PAUSE_REQUESTED",1,true) then
        for _,scenario in ipairs({"resume","stop","pending","uncertain","cleanup"}) do
            local lease,batch,basic={},{},{}
            local env={FullHiveRollTask=lease,FullHiveJellyBatch=batch,FullHiveBasicLock=basic,FullHiveAtlasOwned=true}
            local report={PauseRequested=true,Actions=13}
            local runs,releases,waits=0,0,0
            local pause
            local loop,_,_,_,_,_,token=factory({},env,report,function()
                runs+=1
                if runs==1 then error(pause,0) end
            end,function()
                releases+=1
                env.FullHiveAtlasOwned=false
                if scenario=="cleanup" then report.CleanupError="test cleanup failure" end
            end,function()
                if env.FullHiveStop then error("test hard stop",0) end
            end,{wait=function()
                waits+=1
                assert(report.Phase=="paused" and not env.FullHiveAtlasOwned and runs==1)
                if scenario=="stop" then env.FullHiveStop=true else report.PauseRequested=false end
            end})
            pause=token
            if scenario=="pending" then env.FullHivePending={} end
            if scenario=="uncertain" then env.FullHiveUncertain={} end
            local ok=pcall(loop)
            check(releases==1,"Pause releases Atlas once")
            check(env.FullHiveRollTask==lease and env.FullHiveJellyBatch==batch
                and env.FullHiveBasicLock==basic and report.Actions==13,"Pause preserves work and counters")
            if scenario=="resume" then
                check(ok and waits==1 and runs==2 and report.Phase=="resuming","Resume re-enters planning without loading a new instance")
            elseif scenario=="stop" then
                check(not ok and waits==1 and runs==1,"External stop still terminates a paused assist")
            else
                check(not ok and waits==0 and runs==1,"Unsafe cleanup or unresolved work prevents resume")
                check(scenario~="pending" or env.FullHivePending,"Pending request preserved")
                check(scenario~="uncertain" or env.FullHiveUncertain,"Uncertain request preserved")
            end
        end
    end
    local function character(health,hasRoot)
        local r=hasRoot and {Parent=true} or nil
        return {FindFirstChildOfClass=function() return health and {Health=health} end,
            FindFirstChild=function() return r end},r
    end
    for _,failure in ipairs({"once","twice","FullHivePending","AutoHivePendingRequest","FullHiveUncertain",
        "FullHiveStarRunning","AutoGiftedStarRunning","stop","release-failure"}) do
        local lease={x=4,y=8};local batch={Recovery=true};local basic={x=1,y=1}
        local env={FullHiveAtlasOwned=true,FullHiveRollTask=lease,FullHiveJellyBatch=batch,FullHiveBasicLock=basic}
        if failure:find("^FullHive")and failure~="FullHiveAtlasOwned"or failure:find("^Auto")then env[failure]={Unresolved=true}end
        local report={Actions=12,RoyalJellyUsed=54,Movement={Destination="Verified.Shop",Failure="Movement timed out"}}
        local runs,releases,waits=0,0,0;local token
        local loop,_,_,_,sentinel=factory({Character=character(100,true)},env,report,function()
            runs+=1
            if runs==1 or failure=="twice"then error(token,0)end
            check(report.Phase=="movement-recovered","Retry refreshes planning after movement cleanup")
        end,function()releases+=1;env.FullHiveAtlasOwned=failure=="release-failure"end,
        function()if failure=="stop"then error("Stopped by user",0)end end,
        {wait=function()
            waits+=1
            check(releases==1 and not env.FullHiveAtlasOwned,"Atlas is resumed before movement recovery wait")
        end})
        token=sentinel;local ok,err=pcall(loop)
        if failure=="once"then
            check(ok and runs==2 and waits==8,"One unsent movement timeout recovers once")
            check(report.LastMovementFailure==report.Movement and report.MovementRecoveries==1,"Movement failure evidence survives")
        elseif failure=="twice"then
            check(not ok and runs==2 and releases==1 and waits==8,"Second timeout stops; recovery is bounded")
            check(tostring(err):find("Movement timed out again",1,true)~=nil,"Repeated timeout has a readable error")
        elseif failure=="stop"or failure=="release-failure"then
            check(not ok and runs==1 and releases==1 and waits==0,"Stop or failed Atlas release blocks recovery")
        else
            check(not ok and runs==1 and releases==0 and waits==0,"Unresolved state blocks movement recovery: "..failure)
            check(type(env[failure])=="table"and env[failure].Unresolved,"Original unresolved state is retained")
        end
        check(env.FullHiveRollTask==lease and env.FullHiveJellyBatch==batch and env.FullHiveBasicLock==basic,
            "Movement recovery preserves all active objectives and admission")
        check(report.Actions==12 and report.RoyalJellyUsed==54,"Movement recovery never resets spending counters")
    end
    do
        local player={}
        local _,root,ready,token=factory(player,{},{},function() end,function() end,function() end,{})
        for _,c in ipairs({false,character(nil,true),character(0,true),character(100,false)}) do
            player.Character=c or nil
            local ok,err=pcall(root)
            check(not ok and err==token,"Missing/dead/unloaded character must use the private token")
            check(ready()==nil,"Unavailable character cannot be ready")
        end
        local c,r=character(100,true); player.Character=c
        check(root()==r and ready()==r,"Alive character root is returned")
        r.Parent=nil
        check(ready()==nil,"Detached root cannot be ready")
    end
    do
        local player={}; local env={FullHiveAtlasOwned=true,FullHiveRollTask={x=4,y=8}}
        local lease=env.FullHiveRollTask
        local report={Actions=18,RoyalJellyUsed=614}
        local token; local runs,releases,waits=0,0,0
        local loop,_,_,sentinel=factory(player,env,report,function()
            runs+=1
            if runs==1 then error(token,0) end
            check(player.Character~=nil,"Replan waits until respawn")
        end,function() releases+=1; env.FullHiveAtlasOwned=false end,function() end,
        {wait=function()
            waits+=1
            check(releases==1 and not env.FullHiveAtlasOwned,"Atlas is released before waiting")
            if waits==3 then player.Character=character(100,true) end
        end})
        token=sentinel; loop()
        check(runs==2 and waits==3 and releases==1,"Character loss recovers once")
        check(report.RespawnRecoveries==1,"Recovery count is visible")
        check(report.Actions==18 and report.RoyalJellyUsed==614,"Verified action budgets survive recovery")
        check(env.FullHiveRollTask==lease,"Coordinate lease survives recovery")
    end
    for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning","other-error","release-failure","stop"}) do
        local env={}; local report={}; local runs,releases,waits=0,0,0
        if flag~="other-error" and flag~="release-failure" and flag~="stop" then env[flag]=true end
        local token
        local loop,_,_,sentinel=factory({},env,report,function()
            runs+=1; error(flag=="other-error" and "Uncertain server response; no retry" or token,0)
        end,function() releases+=1; env.FullHiveAtlasOwned=flag=="release-failure" end,
        function() if flag=="stop" then error("Stopped by user",0) end end,
        {wait=function() waits+=1; error("Unexpected recovery wait",0) end})
        token=sentinel; local ok,err=pcall(loop)
        check(not ok and runs==1 and waits==0,"No replay on "..flag)
        if flag=="release-failure" or flag=="stop" then
            check(releases==1,"Cleanup runs before "..flag)
        else
            check(releases==0,"Recovery does not intercept "..flag)
            check(err==(flag=="other-error" and "Uncertain server response; no retry" or token),"Original failure propagates")
        end
    end
    -- Scheduler-only stats recovery tests. No transport wrapper or remote is
    -- run: the rejected historical transport fixture remains excluded.
    for _,failure in ipairs({"resolved","late-read","stuck","twice","mutation-pending","uncertain",
        "star-pending","star-running","child-running","request-replaced","uncertain-during-wait","stop","release-failure"})do
        local read={Name="RetrievePlayerStats"};local lease={x=4,y=8};local batch={Amount=4000}
        local env={FullHiveRollTask=lease,FullHiveJellyBatch=batch,FullHiveAtlasOwned=true}
        if failure=="late-read"or failure=="stuck"or failure=="request-replaced"or failure=="uncertain-during-wait"then env.FullHivePending=read end
        if failure=="mutation-pending"then env.FullHivePending={Name="ItemPackageEvent"}end
        if failure=="uncertain"then env.FullHiveUncertain={Unresolved=true}end
        if failure=="star-pending"then env.AutoHivePendingRequest={Unresolved=true}end
        if failure=="star-running"then env.FullHiveStarRunning=true end
        if failure=="child-running"then env.AutoGiftedStarRunning=true end
        local report={Actions=19,RoyalJellyUsed=285,StatsReadFailure={Name="RetrievePlayerStats"}}
        local runs,releases,waits=0,0,0;local token
        local loop,_,_,_,_,sentinel=factory({Character=character(100,true)},env,report,function()
            runs+=1
            if runs==1 or failure=="twice"then error(token,0)end
            check(report.Phase=="stats-recovered"and not env.FullHivePending,"Fresh planning waits until original stats request completes")
        end,function()releases+=1;env.FullHiveAtlasOwned=failure=="release-failure"end,
        function()if failure=="stop"then error("Stopped by user",0)end end,
        {wait=function()
            waits+=1
            if waits==1 or waits==240 then
                check(releases==1 and not env.FullHiveAtlasOwned,"Atlas is released before waiting on a late stats read")
                check(env.FullHivePending==read,"The original pending read is not cleared by recovery")
            end
            if failure=="late-read"and waits==3 then env.FullHivePending=nil end -- Simulated completion callback.
            if failure=="request-replaced"then env.FullHivePending={Name="ItemPackageEvent"}end
            if failure=="uncertain-during-wait"then env.FullHiveUncertain={Unresolved=true}end
        end})
        token=sentinel;local ok,err=pcall(loop)
        if failure=="resolved"or failure=="late-read"then
            check(ok and runs==2 and releases==1,"Stats timeout recovers after resolution")
            check(waits==(failure=="late-read"and 3 or 0)and report.StatsReadRecoveries==1,"One bounded read recovery is reported")
        elseif failure=="twice"then
            check(not ok and runs==2 and releases==1,"A second stats timeout stops")
            check(tostring(err):find("timed out again",1,true)~=nil,"Repeated stats failure is readable")
        elseif failure=="stuck"then
            check(not ok and runs==1 and waits==240 and env.FullHivePending==read,"Stuck stats read stops without clearing or overlapping it")
        elseif failure=="request-replaced"or failure=="uncertain-during-wait"then
            check(not ok and runs==1 and waits==1,"A changed workflow cannot slip through the recovery wait")
        elseif failure=="stop"or failure=="release-failure"then
            check(not ok and runs==1 and waits==0 and releases==1,"Human stop or failed Atlas release prevents read retry")
        else
            check(not ok and runs==1 and waits==0 and releases==0,"Any unresolved mutation or Star workflow blocks read recovery")
        end
        check(env.FullHiveRollTask==lease and env.FullHiveJellyBatch==batch,"Read recovery preserves task/admission identity")
        check(report.Actions==19 and report.RoyalJellyUsed==285,"Read recovery preserves spending counters")
    end
    -- Run the actual movement function against fake Instances/services. Killing
    -- the fake character during Tween:Play must restore collisions/constraints.
    local movement=assert(runtime:match("(local function move%(part%).-)\nlocal function setSettings"))
    local movementFactory=assert(loadstring("return function(player,game,workspace,Instance,descendants,Report,clock)\n"..
        "local os={clock=clock or os.clock,time=os.time}\n"..
        "local Config={Speed=65}; local cleanupMove; local function acquire() end; local function checkStop() end; local function assertAtlasPaused() end\n"..
        helpers.."\nlocal function distance() return 20 end; local function near() end\n"..movement..
        "\nreturn move,CHARACTER_UNAVAILABLE,function() return cleanupMove end,MOVEMENT_TIMEOUT\nend"))()
    for _,failure in ipairs({"death","replacement","detached","play-error","setup-error","timeout","success","rotated-pad","obstructed"}) do
        local c,r=character(100,true); r.Position=Vector3.zero
        r.Parent=c
        local function part(collidable)
            return {CanCollide=collidable,Parent=true,IsA=function(_,name) return name=="BasePart" end}
        end
        local player={Character=c}; local obstacle,noncollidable=part(true),part(false)
        local added,fencePart=part(true),part(false)
        local destroyed,cancelled,disconnected=0,false,0
        local goals={}
        local callbacks={}
        local function signal(name)
            return {Connect=function(_,callback)
                callbacks[name]=callback
                return {Disconnect=function() disconnected+=1;callbacks[name]=nil end}
            end}
        end
        c.DescendantAdded=signal("characterAdded")
        local fences={DescendantAdded=signal("fenceAdded")}
        local services={
            RunService={Stepped=signal("stepped")},
            TweenService={Create=function(_,_,_,goal)
                goals[#goals+1]=goal.Position
                if failure=="rotated-pad" then
                    check(math.abs(goal.Position.Y-3.16)<0.0001,"Rotated pad approaches world surface rather than local tall axis")
                end
                if failure=="setup-error" then error("Fake tween setup failed",0) end
                return {Cancel=function() cancelled=true end,Play=function()
                    check(not obstacle.CanCollide and not noncollidable.CanCollide,
                        "Noclip is enabled before Tween:Play on "..failure)
                    callbacks.characterAdded(added)
                    callbacks.fenceAdded(fencePart)
                    check(not added.CanCollide and not fencePart.CanCollide,
                        "New parts immediately enter noclip on "..failure)
                    obstacle.CanCollide=true;added.CanCollide=true
                    callbacks.stepped()
                    check(not obstacle.CanCollide and not added.CanCollide,
                        "Stepped reapplies noclip to old and new parts on "..failure)
                    if failure=="replacement" then player.Character=character(100,true)
                    elseif failure=="detached" then r.Parent=nil
                    elseif failure=="play-error" then error("Fake tween play failed",0)
                    elseif failure=="success" or failure=="rotated-pad" or failure=="obstructed" then r.Position=goal.Position
                    elseif failure=="timeout"then return
                    else c.FindFirstChildOfClass=function() return {Health=0} end end
                end}
            end},
        }
        local fakeGame={GetService=function(_,name) return assert(services[name],name) end}
        local map={FindFirstChild=function(_,name) if name=="Fences" then return fences end end}
        local fakeWorkspace={FindFirstChild=function(_,name) if name=="Map" then return map end end,
            Raycast=function(_,origin,direction)
                if failure=="obstructed" and origin.Y==0 and direction.X~=0 then return {} end
            end}
        local fakeInstance={new=function() return {Destroy=function() destroyed+=1 end} end}
        local calls=0;local report={}
        local move,token,pendingCleanup,timeoutToken=movementFactory(player,fakeGame,fakeWorkspace,fakeInstance,
            function(container) return container==fences and {} or {obstacle,noncollidable} end,report,
            failure=="timeout"and function()calls+=1;return calls==1 and 0 or 30 end or nil)
        local rotated=failure=="rotated-pad"
        local part={Name="Test",Position=Vector3.new(20,0,0),Size=rotated and Vector3.new(0.32,22,22) or Vector3.new(4,1,4),
            CFrame={RightVector=Vector3.new(0,rotated and -1 or 0,0),UpVector=Vector3.new(0,rotated and 0 or 1,0),LookVector=Vector3.new(0,0,-1)},
            GetFullName=function() return "Verified.Test.Pad" end,IsA=function() return true end}
        local ok,err=pcall(move,part)
        if failure=="success" or failure=="rotated-pad" or failure=="obstructed" then check(ok,"Successful movement completes")
        elseif failure=="timeout"then
            check(not ok and err==timeoutToken,"Movement timeout uses its private token")
            check(report.Movement.Failure=="Movement timed out"and report.Movement.Position~=nil,"Timed out movement records position and destination")
        elseif failure=="play-error" or failure=="setup-error" then
            check(not ok and err=="Fake tween "..(failure=="play-error" and "play" or "setup").." failed",
                "Movement preserves tween failure on "..failure)
        else check(not ok and err==token,"Movement detects character "..failure..": "..tostring(err)) end
        check((failure=="setup-error" or cancelled) and disconnected==3 and destroyed==2,
            "Movement objects and all signals removed on "..failure)
        check(obstacle.CanCollide==true and not noncollidable.CanCollide and pendingCleanup()==nil,
            "Original true and false collisions restored on "..failure)
        check(added.CanCollide==true and not fencePart.CanCollide,
            "New part collisions restored on "..failure)
        check(next(callbacks)==nil,"No descendant or Stepped listeners survive "..failure)
        if failure=="obstructed" then
            check(#goals==3 and goals[1].X==0 and goals[1].Y>24 and goals[2].Y==goals[1].Y
                and goals[2].X==20 and goals[3].Y==3.5,"Blocked routes climb, cross, and descend to the verified pad")
        end
    end
    return {passed=checked}
end
