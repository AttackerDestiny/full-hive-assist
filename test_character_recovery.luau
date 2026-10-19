-- Exercises the actual runtime helpers in isolation; no game mutations/remotes.
return function(runtime)
    local helpers=assert(runtime:match("(local CHARACTER_UNAVAILABLE = {}.-)\nlocal function distance"),"Character helpers missing")
    local recovery=assert(runtime:match("(local function runWithCharacterRecovery%(%)%s.-)\nlocal function makeUI"),"Recovery loop missing")
    local factory=assert(loadstring("return function(player,env,Report,run,release,checkStop,task)\n"..helpers.."\n"..recovery..
        "\nreturn runWithCharacterRecovery,root,characterRoot,CHARACTER_UNAVAILABLE\nend"))()
    local checked=0
    local function check(value,message) assert(value,message); checked+=1 end
    local function character(health,hasRoot)
        local r=hasRoot and {Parent=true} or nil
        return {FindFirstChildOfClass=function() return health and {Health=health} end,
            FindFirstChild=function() return r end},r
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
    for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveStarRunning","AutoGiftedStarRunning","other-error","release-failure","stop"}) do
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
    -- Run the actual movement function against fake Instances/services. Killing
    -- the fake character during Tween:Play must restore collisions/constraints.
    local movement=assert(runtime:match("(local function move%(part%).-)\nlocal function setSettings"))
    local movementFactory=assert(loadstring("return function(player,game,workspace,Instance,descendants,Report)\n"..
        "local Config={Speed=65}; local cleanupMove; local function acquire() end; local function checkStop() end; local function assertAtlasPaused() end\n"..
        helpers.."\nlocal function distance() return 20 end; local function near() end\n"..movement..
        "\nreturn move,CHARACTER_UNAVAILABLE,function() return cleanupMove end\nend"))()
    for _,failure in ipairs({"death","replacement","detached"}) do
        local c,r=character(100,true); r.Position=Vector3.zero
        local player={Character=c}; local obstacle={CanCollide=true,Parent=true}
        local destroyed,cancelled,disconnected=0,false,false
        local services={
            RunService={Stepped={Connect=function(_,callback)
                callback()
                return {Disconnect=function() disconnected=true end}
            end}},
            TweenService={Create=function()
                return {Cancel=function() cancelled=true end,Play=function()
                    if failure=="replacement" then player.Character=character(100,true)
                    elseif failure=="detached" then r.Parent=nil
                    else c.FindFirstChildOfClass=function() return {Health=0} end end
                end}
            end},
        }
        local fakeGame={GetService=function(_,name) return assert(services[name],name) end}
        local fakeWorkspace={FindFirstChild=function() return nil end}
        local fakeInstance={new=function() return {Destroy=function() destroyed+=1 end} end}
        local move,token,pendingCleanup=movementFactory(player,fakeGame,fakeWorkspace,fakeInstance,
            function() return {obstacle} end,{})
        local part={Name="Test",Position=Vector3.new(20,0,0),Size=Vector3.new(4,1,4),IsA=function() return true end}
        local ok,err=pcall(move,part)
        check(not ok and err==token,"Movement detects character "..failure..": "..tostring(err))
        check(cancelled and disconnected and destroyed==2,"Movement objects removed on "..failure)
        check(obstacle.CanCollide==true and pendingCleanup()==nil,"Collision restored on "..failure)
    end
    return {passed=checked}
end
