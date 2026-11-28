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
    for _,failure in ipairs({"once","twice","exhausted","guild-exhausted","blue-exhausted","FullHivePending","AutoHivePendingRequest","FullHiveUncertain",
        "FullHiveStarRunning","AutoGiftedStarRunning","stop","release-failure"}) do
        local lease={x=4,y=8};local batch={Recovery=true};local basic={x=1,y=1}
        local env={FullHiveAtlasOwned=true,FullHiveRollTask=lease,FullHiveJellyBatch=batch,FullHiveBasicLock=basic}
        if failure:find("^FullHive")and failure~="FullHiveAtlasOwned"or failure:find("^Auto")then env[failure]={Unresolved=true}end
        local report={Actions=12,RoyalJellyUsed=54,Movement={Destination="Verified.Shop",Failure="Movement timed out"}}
        if failure=="exhausted" then report.Movement.RoutesExhausted=true end
        local c,r=character(100,true)
        r.Position=Vector3.zero
        if failure=="guild-exhausted" or failure=="blue-exhausted" then
            report.Movement.Destination=failure=="blue-exhausted" and "Workspace.Map.Ground.BlueHQShopFloor" or "Workspace.Badge Guild.Walls.Floor"
            report.Movement.RoutesExhausted=true
        end
        local runs,releases,waits=0,0,0;local token
        local loop,_,_,_,sentinel=factory({Character=c},env,report,function()
            runs+=1
            if runs==1 or (failure=="twice" and runs==2)then error(token,0)end
            check(report.Phase=="movement-recovered","Retry refreshes planning after movement cleanup")
        end,function()releases+=1;env.FullHiveAtlasOwned=failure=="release-failure"end,
        function()if failure=="stop"then error("Stopped by user",0)end end,
        {wait=function()
            waits+=1
            check(releases==runs and not env.FullHiveAtlasOwned,"Atlas is resumed before each movement recovery wait")
            if failure=="guild-exhausted" or failure=="blue-exhausted" then r.Position=Vector3.new(waits*10,0,0) end
        end})
        token=sentinel;local ok,err=pcall(loop)
        if failure=="once"then
            check(ok and runs==2 and waits==2,"One unsent movement timeout can recover after a short wait")
            check(report.LastMovementFailure==report.Movement and report.MovementRecoveries==1,"Movement failure evidence survives")
        elseif failure=="twice"then
            check(ok and runs==3 and releases==2 and waits==12,"Repeated travel failures recover with increasing delays")
            check(report.MovementRecoveries==2,"Both movement failures are recorded")
        elseif failure=="exhausted" then
            check(ok and runs==2 and releases==1 and waits==2,
                "Exhausted approaches resume Atlas and replan without replaying")
        elseif failure=="guild-exhausted" or failure=="blue-exhausted" then
            check(ok and runs==2 and releases==1 and waits==4,
                "Exhausted Guild and Blue HQ routes wait for Atlas to move before trying from a new origin")
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
    do
        local floorSource=assert(runtime:match("(local function hiveFloor%(%).-)%-%- A private error token"))
        local make=assert(loadstring("return function(hive) "..floorSource.." return hiveFloor end"))()
        local pad={IsA=function(_,class)return class=='BasePart'end}
        local model={IsA=function()return false end,FindFirstChild=function(_,name)if name=='Platform'then return pad end end}
        local function holder(value)return {IsA=function(_,class)return class=='ObjectValue'end,Value=value}end
        for _,value in ipairs({pad,model,holder(pad),holder(model)})do
            local getter=make(function()return {FindFirstChild=function()return value end}end)
            check(getter()==pad,"Every supported hive reference resolves the actual pad")
            check(select('#',getter())==1,"Hive resolver never leaks assert's message as a pickup argument")
        end
        local getter=make(function()return {FindFirstChild=function()end}end)
        check(not pcall(getter),"Missing hive floor still fails closed")
    end
    -- Run the actual movement function against fake Instances/services. Killing
    -- the fake character during Tween:Play must restore collisions/constraints.
    local movement=assert(runtime:match("(local function move%(part,pickup%).-)\nlocal function setSettings"))
    local movementFactory=assert(loadstring("return function(player,game,workspace,Instance,descendants,Report,clock)\n"..
        "local os={clock=clock or os.clock,time=os.time}\n"..
        "local RaycastParams={new=function() return {} end}\n"..
        "local Config={Speed=65,NearDistance=16}; local cleanupMove; local function acquire() end; local function checkStop() end; local function pauseCheckpoint() end; local function assertAtlasPaused() end\n"..
        helpers.."\nlocal function distance(part) local d=part.CFrame:PointToObjectSpace(player.Character:FindFirstChild().Position); local h=part.Size*0.5; return (d-Vector3.new(math.clamp(d.X,-h.X,h.X),math.clamp(d.Y,-h.Y,h.Y),math.clamp(d.Z,-h.Z,h.Z))).Magnitude end; local function near() end\n"..movement..
        "\nreturn move,CHARACTER_UNAVAILABLE,function() return cleanupMove end,MOVEMENT_TIMEOUT,Config\nend"))()
    for _,failure in ipairs({"death","replacement","detached","play-error","setup-error","timeout","success","already-near","speed-change","rotated-pad","obstructed","lateral","blocked-direct","no-route","shop-path","shop-alternate","shop-floor-arrival","shop-no-floor","guild-floor-arrival","ticket-floor-arrival","ticket-underfloor","ticket-reject-underfloor","dapper-entrance","star-hall-entrance","mountaintop-floor-arrival","blender-approach","hive-floor","hive-no-floor","hive-extra-result","pickup-true"}) do
        local c,r=character(100,true); r.Position=Vector3.zero
        r.Parent=c
        local function part(collidable)
            return {CanCollide=collidable,Parent=true,IsA=function(_,name) return name=="BasePart" end}
        end
        local player={Character=c}; local obstacle,noncollidable=part(true),part(false)
        local added,fencePart=part(true),part(false)
        local destroyed,cancelled,disconnected=0,false,0
        local goals={}
        local alternate=failure=="shop-alternate"
        local guild=failure=="guild-floor-arrival"
        local underfloor=failure=="ticket-underfloor"
        local rejectUnderfloor=failure=="ticket-reject-underfloor"
        local ticketShop=failure=="ticket-floor-arrival" or underfloor or rejectUnderfloor
        local mountaintop=failure=="mountaintop-floor-arrival"
        local blender=failure=="blender-approach"
        local dapper=failure=="dapper-entrance"
        local bronze=failure=="star-hall-entrance"
        local noFloor=failure=="shop-no-floor"
        local shopFloor=failure=="shop-floor-arrival" or noFloor or guild or ticketShop or mountaintop
        local hivePad=failure=="hive-floor"or failure=="hive-no-floor"or failure=="hive-extra-result"
        local pickup=failure=="pickup-true"
        local grounded=failure=="shop-path" or alternate or shopFloor or blender
        local humanoid={Health=100,Parent=c}
        local state=Enum.HumanoidStateType.Running
        function humanoid:GetState() return state end
        function humanoid:ChangeState(value) state=value end
        function humanoid:MoveTo() error("Movement must never walk") end
        function humanoid:Move(direction) assert(direction==Vector3.zero,"Movement must never walk") end
        if grounded or hivePad or failure=="speed-change" then c.FindFirstChildOfClass=function() return humanoid end end
        local floorProbes=0
        local landingPart
        local callbacks={}
        local function signal(name)
            return {Connect=function(_,callback)
                callbacks[name]=callback
                return {Disconnect=function() disconnected+=1;callbacks[name]=nil end}
            end}
        end
        c.DescendantAdded=signal("characterAdded")
        local fences={DescendantAdded=signal("fenceAdded")}
        local movementConfig
        local objects={}
        local services={
            RunService={PreSimulation=signal("stepped")},
            TweenService={Create=function(_,align,info,goal)
                goals[#goals+1]=goal.Position
                if failure=="speed-change" then
                    check(align.MaxVelocity==(#goals==1 and 65 or 120),"Speed change updates the active velocity cap")
                    check(state==Enum.HumanoidStateType.Physics,"Movement holds Physics state")
                    check(math.abs(info.Time-math.max(0.2,(goal.Position-r.Position).Magnitude/align.MaxVelocity))<0.001,"Tween duration follows actual speed")
                end
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
                    if failure=="speed-change" then
                        if #goals==1 then movementConfig.Speed=120 else r.Position=goal.Position end
                    elseif failure=="replacement" then player.Character=character(100,true)
                    elseif failure=="detached" then r.Parent=nil
                    elseif failure=="play-error" then error("Fake tween play failed",0)
                    elseif failure=="success" or failure=="already-near" or failure=="rotated-pad" or failure=="obstructed" or failure=="lateral" or dapper or bronze or hivePad or pickup then r.Position=goal.Position
                    elseif failure=="timeout" or failure=="no-route" or (alternate and #goals==1) then return
                    elseif grounded or failure=="blocked-direct" then r.Position=goal.Position
                    else c.FindFirstChildOfClass=function() return {Health=0} end end
                end}
            end},
        }
        local fakeGame={GetService=function(_,name) return assert(services[name],name) end}
        local map={FindFirstChild=function(_,name) if name=="Fences" then return fences end end}
        local door={Position=Vector3.new(15,bronze and 13 or 4,0),CFrame={LookVector=Vector3.new(1,0,0)},
            CanCollide=bronze,IsA=function(_,class) return class=="BasePart" end}
        local fakeWorkspace={FindFirstChild=function(_,name)
            if name=="Map" then return map end
            if dapper and name=="Gates" then
                return {FindFirstChild=function(_,gate)
                    if gate=="Dapper Shop" then return {FindFirstChild=function() return door end} end
                end}
            end
            if bronze and name=="Decorations" then
                return {FindFirstChild=function(_,hall)
                    if hall=="StarAmuletBuilding" then return {FindFirstChild=function() return door end} end
                end}
            end
        end,
            Raycast=function(_,origin,direction,params)
                if hivePad and direction.Y<-10 and direction.X==0 and direction.Z==0 then
                    if failure=="hive-no-floor"then return nil end
                    return {Position=Vector3.new(origin.X,2,origin.Z),Instance=landingPart}
                end
                if grounded then
                    if direction.Y<-10 and direction.X==0 and direction.Z==0 then
                        floorProbes+=1
                        if noFloor or (guild and floorProbes==1) then return nil end
                        if rejectUnderfloor or underfloor and params.FilterType~=Enum.RaycastFilterType.Include then
                            return {Position=Vector3.new(origin.X,-10,origin.Z),Instance=landingPart}
                        end
                        if underfloor then
                            check(params.FilterType==Enum.RaycastFilterType.Include
                                and table.find(params.FilterDescendantsInstances,landingPart),"Ticket probes are restricted to the actual shop surface")
                        end
                        return {Position=Vector3.new(origin.X,0,origin.Z),Instance=landingPart}
                    end
                    if direction.Y==-5 and direction.X==0 and direction.Z==0 then
                        if origin.Y==3 then return {Position=Vector3.new(origin.X,0,origin.Z),Instance=landingPart} end
                        return nil
                    end
                    return {} -- Force the grounded noclip approach through the blocked line.
                end
                if failure=="no-route" or failure=="blocked-direct" then return {} end
                if failure=="lateral" and origin.Y==0 and (direction.Y<10 or direction.X==0) then return {} end
                if failure=="obstructed" and origin.Y==0 and direction.X~=0 then return {} end
            end}
        local fakeInstance={new=function(class)
            local obj={Destroy=function()
                if hivePad and class=="AlignPosition"then
                    check(obstacle.CanCollide==true,"Hive collision support restores before position hold is removed")
                    check(state==Enum.HumanoidStateType.Running,"Hive humanoid state restores before position hold is removed")
                end
                destroyed+=1
            end};objects[class]=obj;return obj
        end}
        local calls=0;local report={}
        local move,token,pendingCleanup,timeoutToken,config=movementFactory(player,fakeGame,fakeWorkspace,fakeInstance,
            function(container) return container==fences and {} or {obstacle,noncollidable} end,report,
            (failure=="timeout" or failure=="no-route" or alternate) and function()calls+=1;return calls*30 end or nil)
        movementConfig=config
        local rotated=failure=="rotated-pad"
        local part={Name="Test",Position=Vector3.new(20,0,0),
            Size=rotated and Vector3.new(0.32,22,22) or Vector3.new(grounded and 32 or 8,1,grounded and 80 or 8),
            CFrame={RightVector=Vector3.new(0,rotated and -1 or 0,0),UpVector=Vector3.new(0,rotated and 0 or 1,0),LookVector=Vector3.new(0,0,-1),
                PointToObjectSpace=function(_,point) return point-Vector3.new(20,0,0) end},
            GetFullName=function()
                if hivePad then return "Workspace.HivePlatforms.Platform.Platform"end
                if guild then return "Workspace.Badge Guild.Walls.Floor" end
                if ticketShop then return "Workspace.Map.Buildings.Ticket Bee Shop.Floor" end
                if mountaintop then return "Workspace.Shops.Mountaintop.FloorPart" end
                if blender then return "Workspace.Toys.Blender.Platform" end
                if dapper then return "Workspace.Shops.DapperPlanterShop.Terrain" end
                if bronze then return "Workspace.Toys.Bronze Star Amulet Generator.Platform" end
                if shopFloor then return "Workspace.Map.Ground.BlueHQShopFloor" end
                return grounded and "Workspace.Shops.ProShop.Terrain" or "Verified.Test.Pad"
            end,IsA=function() return true end}
        landingPart=part
        if failure=="already-near"then r.Position=Vector3.new(20,3.5,0)end
        local ok,err=pcall(move,part,failure=="hive-extra-result"and "Hive platform unavailable"or pickup)
        if ok and pickup then
            check(pendingCleanup()==nil and destroyed==3,"Explicit pickup still releases its constraints immediately")
            check(goals[#goals]==part.Position,"Explicit pickup still targets exact token center")
        elseif ok then
            check(pendingCleanup()~=nil and destroyed==0 and not obstacle.CanCollide,"Every action destination retains its arrival hold across stats refresh")
            check(objects.AlignPosition.Position==goals[#goals],"Retained hold points to the exact final arrival target")
            pendingCleanup()()
            check(pendingCleanup()==nil,"Releasing the arrival hold clears its lease")
        end
        if hivePad then
            if failure=="hive-no-floor"then
                check(not ok and err==timeoutToken and #goals==0,"Unknown hive floor sends no tween or spend")
            else
                check(ok and math.abs(goals[#goals].Y-5.5)<0.001,"Hive targets actual solid floor plus standing clearance")
                check(objects.AlignPosition.RigidityEnabled,"Arrived hive retains a rigid landing hold")
                check(r.AssemblyLinearVelocity==Vector3.zero and r.AssemblyAngularVelocity==Vector3.zero,"Hive arrival/cleanup remove residual linear and angular motion")
            end
        end
        if failure=="speed-change" then
            check(ok and #goals==2 and report.Movement.Arrived,"Active speed change rebuilds the remaining tween and arrives")
            check(state==Enum.HumanoidStateType.Running,"Cleanup restores the previous humanoid state")
            check(objects.AlignOrientation.RigidityEnabled and objects.AlignOrientation.Attachment0==objects.Attachment,"Movement stabilizes orientation using its owned attachment")
        elseif noFloor or rejectUnderfloor then
            check(not ok and err==timeoutToken and #goals==0,"Blue HQ without a verified landing sends no movement or purchase")
            check(report.Movement.RoutesExhausted and not report.Movement.Arrived,"Missing shop floor blocks arrival")
        elseif grounded then
            check(ok and #goals==(alternate and 2 or 1) and goals[#goals].Y==3,
                "Blocked shop approach uses AlignPosition to reach the physical floor on "..failure..": "..tostring(err))
            check(report.Movement.Arrived and report.Movement.Method=="grounded-tween","Shop tween records verified arrival")
            if alternate or guild then
                check(report.Movement.Route==2,"A failed shop approach tries a different verified floor point")
            end
            if underfloor then
                for _,goal in ipairs(goals) do check(goal.Y>=3,"Ticket tween never aims below its floor") end
            end
        elseif dapper then
            check(ok and report.Movement.Method=="dapper-entrance" and #goals==3
                and goals[1].X==0 and goals[2].X==27 and goals[3].Y==4,
                "Dapper travel approaches the open door and aims inside at door height")
        elseif bronze then
            check(ok and report.Movement.Method=="star-hall-entrance" and #goals==3
                and goals[1].X==-3 and goals[2].X==33 and goals[1].Y==4,
                "Bronze Star travel uses the clear opening through the Star Hall model")
        elseif failure=="success" or failure=="already-near" or failure=="rotated-pad" or failure=="obstructed" or failure=="lateral" then check(ok,"Successful movement completes")
        elseif hivePad then check(failure=="hive-no-floor"and not ok or failure~="hive-no-floor"and ok,"Hive landing result matches verified support")
        elseif pickup then check(ok,"Explicit boolean pickup remains supported")
        elseif failure=="blocked-direct" then
            check(ok and #goals==1 and report.Movement.Method=="direct-noclip-tween","A blocked line still uses the noclip tween")
        elseif failure=="no-route" then
            check(not ok and err==timeoutToken and #goals==1,"A stalled noclip tween fails before arrival")
            check(report.Movement.Failure=="Movement timed out","Stalled noclip movement records a timeout")
        elseif failure=="timeout"then
            check(not ok and err==timeoutToken,"Movement timeout uses its private token")
            check(report.Movement.Failure=="Movement timed out"and report.Movement.Position~=nil,"Timed out movement records position and destination")
        elseif failure=="play-error" or failure=="setup-error" then
            check(not ok and err=="Fake tween "..(failure=="play-error" and "play" or "setup").." failed",
                "Movement preserves tween failure on "..failure)
        else check(not ok and err==token,"Movement detects character "..failure..": "..tostring(err)) end
        check((failure=="setup-error" or noFloor or rejectUnderfloor or failure=="hive-no-floor"or cancelled) and disconnected==3 and destroyed==3,
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
        if failure=="lateral" then
            check(#goals==3 and goals[1].X~=0 and goals[3].X==20,"Blocked vertical climb uses a clear angled climb")
        end
    end
    do
        local body=assert(runtime:match("setTweenSpeed=function%(value%)(.-)\n        end,"),"Tween speed callback missing")
        local config,env,report={Speed=40},{},{}
        local setter=assert(loadstring("return function(Config,env,Report) local function saveSettings() end return function(value) "..body.." end end"))()(config,env,report)
        for _,pair in ipairs({{6,60},{40,400},{1,10},{100,400},{-5,10},{6.9,60}}) do
            setter(pair[1])
            check(config.Speed==pair[2] and env.FullHiveConfig.Speed==pair[2],"Tween slider scales and persists actual speed")
            check(report.TweenSpeed==pair[2]/10 and report.MovementSpeed==pair[2],"Tween report distinguishes slider units and actual speed")
        end
        setter(0/0);setter("invalid")
        check(config.Speed==60,"Invalid slider input preserves speed")
        setter("8")
        check(config.Speed==80 and report.TweenSpeed==8,"WindUI formatted string values update movement speed")
        local normalize=assert(runtime:match("(Config.Speed=math.clamp[^\n]+)"))
        local init=assert(loadstring("return function(Config) "..normalize.." return Config.Speed end"))()
        check(init({Speed=40})==40,"Legacy actual speed40 remains40, not400")
        check(init({Speed=1000})==400 and init({Speed=0})==10,"Loaded config respects actual speed bounds")
    end
    do
        local source=assert(runtime:match("(local function near%(part%).-)\nlocal atlasPauseControl"))
        local make=assert(loadstring("return function(distance,Config,Report,MOVEMENT_TIMEOUT) "..source.." return near end"))()
        local gap=16;local report={LastMovementArrival="old"};local token={}
        local near=make(function()return gap end,{NearDistance=16},report,token)
        local part={GetFullName=function()return "Workspace.Map.Buildings.Ticket Bee Shop.Floor"end}
        check(pcall(near,part),"Exact near boundary remains allowed")
        gap=17;local ok,why=pcall(near,part)
        check(not ok and why==token,"Lost proximity enters the existing guarded movement recovery")
        check(report.Movement.Distance==17 and report.Movement.Arrived==false and report.LastMovementArrival==nil,"Lost arrival records fresh distance and invalidates stale success")
        check(report.Movement.Failure=="Lost proximity before action","Lost proximity has a diagnostic cause")
    end
    do
        local source=assert(runtime:match("(local function hiveLandingCheck%(%).-)\nlocal function run%(%)"))
        local make=assert(loadstring("return function(env,Report,root,move,release,task) local player={UserId=7};local game={JobId='test'};local Config={};local function checkStop()end;local function near()end;local function hiveFloor()return 'verified-pad'end;"..source.." return hiveLandingCheck end"))()
        local function fixture(flag)
            local request={State='requested',Owner=7,Job='test'};local e={FullHiveLandingCheck=request}
            if flag then e[flag]={}end
            local report={Actions=4,RoyalJellyUsed=17};local moves=0;local releases=0
            local run=make(e,report,function()return {Position={Y=4}}end,function(part)
                check(part=='verified-pad',"Diagnostic uses the actual hive resolver")
                moves+=1;report.Movement={LandingSurfaceY=1}
            end,function()releases+=1 end,{wait=function()end})
            return run,e,request,function()return moves,releases end,report
        end
        for _,flag in ipairs({'FullHivePending','AutoHivePendingRequest','FullHiveUncertain','AutoHiveUncertain','FullHiveStarRunning','AutoGiftedStarRunning'})do
            local run,e,request,counts=fixture(flag);local original=e[flag]
            check(not run()and counts()==0 and e[flag]==original and request.State=='requested',"Pending/uncertain/Star work blocks no-spend movement: "..flag)
        end
        local run,e,request,counts=fixture()
        check(run()and request.State=='passed'and counts()==1,"Serialized hive check executes once and passes")
        check(request.Actions==0 and request.RoyalJellyUsed==0,"Hive check cannot spend items or count purchases")
        check(not run()and counts()==1,"Completed hive check is never replayed")
        local run,e,request,counts=fixture();e.FullHiveStop=true
        check(not run()and counts()==0,"Human stop is never overridden by movement check")
        local run,e,request,counts=fixture();request.Job='other'
        check(not run()and counts()==0,"Wrong-session movement request remains inert")
        local run,e,request,counts,report=fixture();report.PauseRequested=true
        check(not run()and counts()==0,"Paused assist never runs a movement check")
    end
    return {passed=checked}
end
