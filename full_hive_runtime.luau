-- Bundled by build_full_hive.ps1 after Policy and StarEggSource.
local SCRIPT_VERSION = "1.6.7"
local env = (type(getgenv) == "function" and getgenv()) or _G
local compile = loadstring or load
if not table.pack then
    function table.pack(...) return {n = select("#", ...), ...} end
end
if not table.unpack then
    if unpack then
        table.unpack = unpack
    else
        local function unpackCompat(t, first, last)
            first, last = first or 1, last or #t
            if first > last then return end
            return t[first], unpackCompat(t, first + 1, last)
        end
        table.unpack = unpackCompat
    end
end
local function descendants(root, className)
    local ok, result = pcall(function() return root:QueryDescendants(className) end)
    if ok and type(result) == "table" then return result end
    local out, queue = {}, {root}
    while #queue > 0 do
        local node = table.remove(queue, 1)
        for _, child in ipairs(node:GetChildren()) do
            if not className or child:IsA(className) then out[#out + 1] = child end
            queue[#queue + 1] = child
        end
    end
    return out
end
local function findText(root, text)
    local ok, result = pcall(function()
        return root:QueryDescendants('TextLabel[Text = "' .. text .. '"]')
    end)
    if ok and type(result) == "table" then return result end
    local out = {}
    for _, label in ipairs(descendants(root, "TextLabel")) do
        if label.Text == text then out[#out + 1] = label end
    end
    return out
end
local function uiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    return game:GetService("CoreGui")
end
local function activate(button, callback)
    -- Native GuiButton activation is the reliable path on Arceus Android.
    -- Executor signal APIs may return success without dispatching the UI event.
    local nativeOk = pcall(function() button:Activate() end)
    if nativeOk then return true end
    if callback then
        local ok = pcall(callback)
        if ok then return true end
        if type(firesignal) == "function" then
            local okSignal = pcall(firesignal, button.MouseButton1Click)
            if okSignal then return true end
        end
    end
    if type(firesignal) == "function" then
        local signalOk = pcall(firesignal, button.MouseButton1Click)
        if signalOk then return true end
    end
    return false
end
local function loadModule(module)
    assert(module, "Game module did not load before require")
    local ok, value = pcall(require, module)
    if ok then return value end
    local setIdentity = setthreadidentity or setidentity
    local getIdentity = getthreadidentity or getidentity
    if type(setIdentity) == "function" and type(getIdentity) == "function" then
        local got, original = pcall(getIdentity)
        if got and pcall(setIdentity, 2) then
            ok, value = pcall(require, module)
            pcall(setIdentity, original)
            if ok then return value end
        end
    end
    error("Cannot load game module " .. module.Name .. ": " .. tostring(value), 0)
end
local Config = {DryRun=false, PollSeconds=3, Speed=65, NearDistance=16,
    MaxActions=math.huge, MaxRoyalJellies=math.huge, AutoPurchase=true,
    HoneyReserve=0, RollDelay=0.3, StarEggHoney=100000000000,
    AtlasInitiallyStopped=false, StartupDelaySeconds=60, PreserveUniqueGifted=false, AutoProgression=true,
    UseBlenderTickets=false}
for k,v in pairs(env.FullHiveConfig or {}) do assert(Config[k] ~= nil, "Unknown config: "..k); Config[k]=v end
-- Retain the old option for config compatibility; ordinary keeps must still
-- follow the user's failsafe/force lists even if an old override was true.
Config.PreserveUniqueGifted=false
if env.FullHiveRunning then
    warn("[Full Hive] Already running v"..tostring(env.FullHiveVersion or "unversioned").."; stop the old instance before loading v"..SCRIPT_VERSION)
    return
end
assert(not env.AutoGiftedStarRunning, "Stop the other hive assist before starting Full Hive")
assert(not env.AutoHivePendingRequest and not env.FullHivePending, "A previous server request is pending")
assert(not env.FullHiveUncertain, "An earlier hive mutation needs reconciliation; do not retry")
env.FullHiveRunning, env.FullHiveStop = true, false
env.FullHiveVersion = SCRIPT_VERSION
env.FullHivePreviousReport = env.FullHiveReport
local Report = {Version=SCRIPT_VERSION, Phase="starting", Actions=0, RoyalJellyUsed=0, DryRun=Config.DryRun,StartedAt=os.time()}
env.FullHiveReport = Report
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local player, Events, Cache, Types, EggTypes
local progression,atlasFarmOnly
local fixedShopPackage
local Packages, Recipes, Reqs, Accessories, CellTools, OsTime
local leased, previousAtlas, previousSettings, cleanupMove = false, nil, nil, nil
local lateStarted = env.FullHiveLateStarted == true
local basicLock = env.FullHiveBasicLock
local rollTask = env.FullHiveRollTask
-- Drop an old, unowned continuation batch when upgrading from use-all mode.
if env.FullHiveJellyBatch and not env.FullHiveJellyBatch.Recovery and not rollTask and not basicLock then
    env.FullHiveJellyBatch=nil
end
local nextFlexible
local stoppedByUser = false
local function checkStop()
    if env.FullHiveStop then stoppedByUser=true; error("Stopped by user",0) end
end
local function waitForChild(parent,name)
    local deadline=os.clock()+30
    repeat
        checkStop()
        local child=parent:FindFirstChild(name)
        if child then return child end
        task.wait(0.25)
    until os.clock()>=deadline
    error("Game object did not load within 30 seconds: "..name,0)
end
local function initializePlayer()
    Report.Phase="waiting-for-player"; Report.Activity="Waiting for the game and player to load"
    while not Players.LocalPlayer do checkStop(); task.wait(0.25) end
    player=Players.LocalPlayer
end
local function initializeModules()
    Report.Phase="loading-modules"; Report.Activity="Atlas ready; loading hive data"
    Events=waitForChild(RS,"Events")
    Cache=loadModule(waitForChild(RS,"ClientStatCache"))
    Types=loadModule(waitForChild(RS,"BeeTypes")):GetTypes()
    EggTypes=loadModule(waitForChild(RS,"EggTypes"))
    if ProgressionPolicy and createProgressionFacts and createProgression then
        Packages=loadModule(waitForChild(RS,"ItemPackages"))
        Recipes=loadModule(waitForChild(RS,"BlenderRecipes"))
        Reqs=loadModule(waitForChild(RS,"StatReqs"))
        Accessories=loadModule(waitForChild(RS,"Accessories"))
        CellTools=loadModule(waitForChild(RS,"CellTools"))
        OsTime=loadModule(waitForChild(RS,"OsTime"))
    end
end
local function invokeRequest(remote, receiptBefore, ...)
    checkStop()
    assert(not env.FullHivePending and not env.AutoHivePendingRequest, "Server request already pending")
    local args = table.pack(...)
    local request = {Name=remote.Name, Started=os.clock(),Owner=player and player.UserId,Job=game.JobId}
    local mutation=remote.Name~="RetrievePlayerStats"
    if mutation then
        assert(not env.FullHiveUncertain,"An earlier mutation needs reconciliation")
        if remote.Name=="ConstructHiveCellFromEgg" then
            request.X,request.Y,request.Item,request.Amount=args[1],args[2],args[3],args[4]
            request.HatchBefore=receiptBefore -- Copied before the request can yield.
        elseif remote.Name=="ItemPackageEvent" and type(args[2])=="table" then
            request.Item,request.Amount=args[2].Type,args[2].Amount
            request.Category=args[2].Category
        elseif remote.Name=="BlenderCommand" then
            request.Kind=args[1]
            local order=type(args[2])=="table" and args[2] or (Cache:Get().BlenderState or {})
            request.Item,request.Amount=order.Recipe,order.Count
            request.BlenderBefore=receiptBefore
        end
        env.FullHiveUncertain=request -- Retain until operation-specific validation.
    end
    env.FullHivePending = request
    local done, ok, values = false, false, nil
    task.spawn(function()
        ok, values = pcall(function() return table.pack(remote:InvokeServer(table.unpack(args,1,args.n))) end)
        done=true
        if env.FullHivePending == request then env.FullHivePending=nil end
    end)
    local deadline=os.clock()+(remote.Name=="ConstructHiveCellFromEgg" and 180 or 45)
    while not done and os.clock()<deadline do task.wait(0.1) end
    assert(done,"Uncertain server response; no retry: "..remote.Name)
    assert(ok,"Server request failed; no retry: "..tostring(values))
    return table.unpack(values,1,values.n)
end
local function invoke(remote, ...)
    return invokeRequest(remote,nil,...)
end
local function refresh()
    local s=invoke(Events.RetrievePlayerStats)
    assert(type(s)=="table" and type(s.Eggs)=="table", "Stats unavailable")
    for _,k in ipairs({"Honey","Eggs","Totals","Honeycomb","Settings","Quests","UnlockedCells","Accessories","Collectors","Sprinklers","Codes","PlaytimeAtLoad","LoadTime","OfflineProgressTime","MiscInfo","ItemTimes","Treasures"}) do
        if s[k]~=nil then Cache:Set(k,s[k]) end
    end
    Cache:Set("BlenderState",s.BlenderState or nil)
    return s
end
local function royalJellyPurchases(s)
    local totals=s.Totals or {}
    local purchases=totals.Purchases or {}
    local eggs=purchases.Eggs or {}
    return eggs.RoyalJelly or 0
end
local function starEggUses(s)
    local usage=StarState.usage(s)
    -- Unknown counters cannot unlock later stages, but must not prevent a
    -- brand-new hive from acquiring its first bees through unrelated actions.
    return usage.used
end
local function hive()
    local ref=player:FindFirstChild("Honeycomb")
    local refHive=ref and ref.Value
    local refOwner=refHive and refHive:FindFirstChild("Owner")
    if refOwner and refOwner.Value==player then return refHive end
    local hives=workspace:FindFirstChild("Honeycombs")
    if not hives then return nil end
    for _,h in ipairs(hives:GetChildren()) do
        if h:FindFirstChild("Owner") and h.Owner.Value==player then return h end
    end
end
local function hiveFloor()
    local h=assert(hive(),"Atlas has not claimed a hive yet")
    local p=h:FindFirstChild("Platform")
    if p and p:IsA("ObjectValue") then p=p.Value end
    if p and p:IsA("BasePart") then return p end
    return assert(p and p:FindFirstChild("Platform"),"Hive platform unavailable")
end
-- A private error token distinguishes a lost character from an uncertain spend.
local CHARACTER_UNAVAILABLE = {}
local function characterRoot()
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and h.Health>0 and r and r.Parent then return r end
end
local function root()
    local r=characterRoot()
    if not r then error(CHARACTER_UNAVAILABLE,0) end
    return r
end
local function distance(part)
    local p=root().Position
    local localPos=part.CFrame:PointToObjectSpace(p)
    local half=part.Size/2
    local closest=Vector3.new(math.clamp(localPos.X,-half.X,half.X),math.clamp(localPos.Y,-half.Y,half.Y),math.clamp(localPos.Z,-half.Z,half.Z))
    return (localPos-closest).Magnitude
end
local function near(part) assert(distance(part)<=Config.NearDistance,"Too far from "..part:GetFullName()) end
local atlasPauseControl
local function atlasToggle()
    local coreGui = game:GetService("CoreGui")
    local cached=atlasPauseControl
    if cached and cached.Button.Parent and cached.Label.Parent==cached.Button
        and cached.Label.Text=="Stop Everything" and cached.Button:IsDescendantOf(coreGui)
        and type(cached.State[1])=="boolean" then
        return cached.Button,cached.State,cached.Callback
    end
    atlasPauseControl=nil
    local upvalueReader = (type(debug) == "table" and debug.getupvalues) or getupvalues
    local fallbackButton
    local callbacksPending=false
    for _,label in ipairs(findText(coreGui, "Stop Everything")) do
        local b=label.Parent
        if b and b:IsA("TextButton") then
            fallbackButton=fallbackButton or b
            if type(getconnections) == "function" and type(upvalueReader) == "function" then
                local ok, connections = pcall(getconnections, b.MouseButton1Click)
                if ok and type(connections)=="table" then
                    local callable=false
                    for _,connection in ipairs(connections) do
                        if type(connection.Function)=="function" then callable=true; break end
                    end
                    if not callable then callbacksPending=true end
                    for _,c in ipairs(connections) do
                    if type(c.Function)=="function" then
                        local okUp, u=pcall(upvalueReader, c.Function)
                        if okUp and type(u) == "table" then
                            local state
                            for _,value in pairs(u) do
                                if type(value)=="table" and type(value[1])=="boolean" then state=value; break end
                            end
                            if state then
                                atlasPauseControl={Button=b,Label=label,State=state,Callback=c.Function}
                                return b,state,c.Function
                            end
                        end
                    end
                end end
            end
        end
    end
    -- Arceus X builds commonly expose the button but omit signal hooks.
    -- The caller must provide the initial switch state in that case.
    if fallbackButton then return fallbackButton,nil,nil end
    error("Atlas Stop Everything control unavailable",0)
end
local atlasState
local function readAtlasState(cell)
    if type(cell) == "table" and type(cell[1]) == "boolean" then return cell[1] end
end
local function atlasControl(timeout)
    local deadline=os.clock()+(timeout or 30)
    local lastError
    repeat
        local ok,b,cell,callback=pcall(atlasToggle)
        if ok and b then return b,cell,callback end
        lastError=b
        task.wait(0.25)
    until os.clock()>=deadline
    error("Atlas Stop Everything was not ready: "..tostring(lastError),0)
end
local function assertAtlasPaused()
    local _,cell=atlasControl(2)
    local current=readAtlasState(cell)
    if current ~= nil then atlasState=current end
    assert(atlasState == true,"Atlas state unavailable or Atlas is not paused; wait for Atlas UI callbacks")
end
local function setAtlas(value)
    local b,cell,callback=atlasControl()
    local current=readAtlasState(cell)
    if current==nil then current=atlasState end
    if current==nil then current=Config.AtlasInitiallyStopped end
    if current~=value then
        assert(activate(b,callback),"Could not activate Atlas Stop Everything on this executor")
        atlasState=value
    end
    local untilTime=os.clock()+4
    if type(cell) == "table" then
        while readAtlasState(cell)~=value and os.clock()<untilTime do task.wait(0.05) end
        assert(readAtlasState(cell)==value,"Atlas toggle did not synchronize")
    end
    atlasState=value
    env.FullHiveAtlasOwned=value
    Report.AtlasPaused=value
end
local function acquire()
    checkStop()
    if leased then
        assertAtlasPaused()
        if atlasFarmOnly and Config.AutoProgression then
            local safe,why,rows=atlasFarmOnly(true)
            Report.AtlasSpenderControls=rows
            assert(safe,why)
        end
        return
    end
    local _,cell=atlasControl()
    previousAtlas=readAtlasState(cell) or (atlasState ~= nil and atlasState or Config.AtlasInitiallyStopped)
    previousSettings={}
    for _,k in ipairs({"RollToGifted","RollToLegendary","RollToMythic","RollToMutation"}) do
        previousSettings[k]=(Cache:Get().Settings or {})[k]==true
    end
    -- Own the lease before toggling so failures also restore it.
    leased=true
    setAtlas(true)
    if atlasFarmOnly and Config.AutoProgression then
        local safe,why,rows=atlasFarmOnly(true)
        Report.AtlasSpenderControls=rows
        assert(safe,why)
    end
end
local function move(part)
    acquire(); checkStop()
    if typeof(part)=="Vector3" then error("Full Hive movement requires a verified destination part") end
    assert(part and part:IsA("BasePart"),"Invalid movement destination")
    Report.Activity="Moving to "..part.Name
    if distance(part)<=5 then return end
    local r=root()
    -- Hive and Blender pads are rotated: local Size.Y is not their world height.
    local cf,size=part.CFrame,part.Size
    local height=math.abs(cf.RightVector.Y)*size.X/2+math.abs(cf.UpVector.Y)*size.Y/2
        +math.abs(cf.LookVector.Y)*size.Z/2
    local target=part.Position+Vector3.new(0,height+3,0)
    Report.Movement={Destination=part:GetFullName(),Target=tostring(target),StartedAt=os.time(),
        Distance=(target-r.Position).Magnitude,Arrived=false}
    local attachment=Instance.new("Attachment"); attachment.Name="FullHiveAttachment"; attachment.Parent=r
    local align=Instance.new("AlignPosition")
    align.Name="FullHiveAlign"; align.Mode=Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0=attachment; align.MaxForce=1000000; align.MaxVelocity=Config.Speed
    align.ApplyAtCenterOfMass=true
    align.Responsiveness=45; align.Position=r.Position; align.Parent=r
    local collision={}
    local movingCharacter=r.Parent
    local map=workspace:FindFirstChild("Map")
    local fences=map and map:FindFirstChild("Fences")
    local connections={}
    local tween,cleaned
    local function enroll(p)
        if cleaned or not p:IsA("BasePart") then return end
        if collision[p]==nil then collision[p]=p.CanCollide end
        p.CanCollide=false
    end
    local function cleanup()
        if cleaned then return end
        cleaned=true
        if tween then tween:Cancel() end
        for _,connection in ipairs(connections) do connection:Disconnect() end
        align:Destroy(); attachment:Destroy()
        for p,v in pairs(collision) do if p.Parent then p.CanCollide=v end end
        if r.Parent then r.AssemblyLinearVelocity=Vector3.zero end
    end
    cleanupMove=cleanup
    local ok,err=pcall(function()
        -- Enable noclip before the first tween frame, and enroll accessories or
        -- other parts added during movement so cleanup restores their values.
        for _,container in ipairs(fences and {movingCharacter,fences} or {movingCharacter}) do
            connections[#connections+1]=container.DescendantAdded:Connect(enroll)
            for _,p in ipairs(descendants(container,"BasePart")) do enroll(p) end
        end
        connections[#connections+1]=game:GetService("RunService").Stepped:Connect(function()
            if not r.Parent then return end
            for p in pairs(collision) do if p.Parent then p.CanCollide=false end end
            local humanoid=movingCharacter:FindFirstChildOfClass("Humanoid")
            if humanoid and type(humanoid.Move)=="function" then humanoid:Move(Vector3.zero,false) end
        end)
        tween=game:GetService("TweenService"):Create(align,TweenInfo.new(math.max(0.2,(target-r.Position).Magnitude/Config.Speed),Enum.EasingStyle.Linear),{Position=target})
        local deadline=os.clock()+(target-r.Position).Magnitude/Config.Speed+15
        tween:Play()
        while (r.Position-target).Magnitude>4 do
            checkStop()
            if characterRoot()~=r then error(CHARACTER_UNAVAILABLE,0) end
            Report.Movement.Distance=(target-r.Position).Magnitude
            assert(os.clock()<deadline,"Movement timed out")
            assertAtlasPaused()
            task.wait(0.1)
        end
    end)
    cleanup(); cleanupMove=nil
    if not ok then error(err,0) end
    near(part)
    Report.Movement.Arrived=true
    Report.Movement.Distance=(target-r.Position).Magnitude
end
local function setSettings(desired)
    acquire(); move(hiveFloor()); near(hiveFloor())
    local current=Cache:Get().Settings or {}
    for k,v in pairs(desired) do
        if (current[k]==true)~=v then Events.PlayerSettingsEvent:FireServer(k,v) end
    end
    local deadline=os.clock()+8
    repeat
        task.wait(0.15)
        local fresh=refresh(); local matches=true
        local freshSettings=fresh.Settings or {}
        for k,v in pairs(desired) do if (freshSettings[k]==true)~=v then matches=false end end
        if matches then return end
    until os.clock()>deadline
    error("Roll settings failed to synchronize")
end
local function mode(name)
    if name~="off" and (Cache:Get().Eggs.RoyalJelly or 0)>Config.MaxRoyalJellies-Report.RoyalJellyUsed then
        name="off" -- A finite per-run budget cannot be delegated to an unbounded server auto-roll.
    end
    setSettings({RollToGifted=name=="gifted",RollToLegendary=name=="legendary",RollToMythic=false,RollToMutation=false})
    Report.RollMode=name
end
local function restoreSettingsDirect(desired)
    if not desired then return end
    local current=Cache:Get().Settings or {}
    for k,v in pairs(desired) do
        if (current[k]==true)~=v then Events.PlayerSettingsEvent:FireServer(k,v) end
    end
    local deadline=os.clock()+8
    repeat
        task.wait(0.15)
        local fresh=refresh(); local settings=fresh.Settings or {}; local matches=true
        for k,v in pairs(desired) do if (settings[k]==true)~=v then matches=false end end
        if matches then return end
    until os.clock()>deadline
    error("Roll settings cleanup did not synchronize",0)
end
local function release()
    if cleanupMove then cleanupMove(); cleanupMove=nil end
    local shouldRestore=leased or Report.AtlasPaused==true or atlasState==true or env.FullHiveAtlasOwned==true
    if not shouldRestore then return end
    local errors={}
    local hadLease=leased
    local stop=env.FullHiveStop; env.FullHiveStop=false
    -- Resume Atlas first so a refill wait never leaves the farm paused while
    -- settings cleanup is synchronizing.
    leased=false
    local ok,err=pcall(setAtlas,false)
    if not ok then errors[#errors+1]=tostring(err) end
    if hadLease and previousSettings and not env.FullHivePending then
        local settingsOk,settingsErr=pcall(restoreSettingsDirect,previousSettings)
        if not settingsOk then errors[#errors+1]=tostring(settingsErr) end
    end
    env.FullHiveStop=stop
    leased=false
    if #errors>0 then Report.CleanupError=table.concat(errors,"; "); warn("[Full Hive] Cleanup: "..Report.CleanupError) end
end
local function scan(s)
    return Policy.snapshot(s,Types)
end
local function progressionToyPart(name)
    local toys=workspace:FindFirstChild("Toys")
    local toy=toys and toys:FindFirstChild(name)
    local part=toy and toy:FindFirstChild("Platform")
    return part and part:IsA("BasePart") and part or nil
end

local function activeJellyBatch(s)
    local batch=env.FullHiveJellyBatch
    local h=hive()
    if batch and batch.Version==1 and batch.Owner==player.UserId
        and batch.Job==game.JobId and batch.Hive==(h and h.Name)
        and (s.Eggs.RoyalJelly or 0)>0 then return batch end
end
local function context(s,slots)
    local stage=Policy.stage({slots=slots,starUsed=starEggUses(s)})
    local jelly=s.Eggs.RoyalJelly or 0
    local bought=s.Totals and s.Totals.Purchases and s.Totals.Purchases.Eggs or {}
    local usable=math.max(0,(s.Honey or 0)-Config.HoneyReserve)
    local used=starEggUses(s)
    local normalRefill=Policy.refill(slots)
    if slots>=44 and not lateStarted then normalRefill=math.max(10000,normalRefill) end
    local collectorFallback=Policy.collectorRecovery(slots,1,usable,
        bought.RoyalJelly or 0,env.FullHiveCollectorFallback==true,jelly,normalRefill)
    local batch=activeJellyBatch(s)
    -- Honey for the NEXT refill must not downgrade a batch already admitted.
    -- A full normal amount or affordable remaining top-up precedes recovery.
    -- Recheck the missing amount after each pack, not the cost of a new batch.
    if (batch and not batch.Recovery)
        or ((s.Eggs.StarJelly or 0)>0 and Policy.starJellyUpgradeTask(rollTask))
        or (env.FullHiveCollectorFallback~=true and jelly>=normalRefill) then
        collectorFallback=false
    end
    return {slots=slots,starUsed=used,jelly=jelly,honey=s.Honey or 0,lateStarted=lateStarted,nextFlexible=nextFlexible,
        collectorFallback=collectorFallback,enforceGrowth=true,eggs=s.Eggs,
        canRefill30k=Config.AutoPurchase and usable>=Policy.jellyCost(bought.RoyalJelly or 0,30000)}
end
local function plan(s)
    local cells,slots=scan(s)
    local ctx=context(s,slots)
    local p=Policy.plan(cells,Types,ctx)
    if ctx.collectorFallback and #p.fallbackCandidates==0 then
        ctx.collectorFallback=false
        p=Policy.plan(cells,Types,ctx)
    end
    if not Config.DryRun then env.FullHiveCollectorFallback=p.collectorFallback or nil end
    local admitted=activeJellyBatch(s)
    if admitted and not p.collectorFallback and not Config.DryRun then
        if admitted.Recovery then
            -- The repair is finished. Save its remainder; a new normal
            -- objective must qualify against the normal refill amount.
            env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
        end
    end
    if rollTask then
        local current
        for _,c in ipairs(cells) do if c.x==rollTask.x and c.y==rollTask.y then current=c; break end end
        local h=hive()
        local invalid=rollTask.Version~=2 or rollTask.Owner~=player.UserId or rollTask.Hive~=(h and h.Name)
            or rollTask.Job~=game.JobId
        local done,why
        if not invalid and p.collectorFallback and current and Policy.isUsableCollector(current,cells)
            and not Policy.isRecoveryTask(rollTask) then
            done,why=true,"collector-held-during-recovery"
        elseif not invalid and p.collectorFallback and current and not Policy.isUsableCollector(current,cells)
            and Policy.rollTaskSafe(rollTask,current,cells,Types,p) then
            -- The existing coordinate stays leased, but an older gifted task
            -- must adopt recovery mode before its next request.
            rollTask.Mode,rollTask.Reason=Policy.recoveryMode(ctx.honey)
        end
        if not invalid and not done then done,why=Policy.rollTaskDone(rollTask,current,cells,Types,p) end
        if invalid or done then
            Report.LastCompletedTarget={X=rollTask.x,Y=rollTask.y,Reason=invalid and "hive-or-stage-changed" or why}
            if invalid or not Policy.isRecoveryTask(rollTask) then
                env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
            end
            rollTask=nil; env.FullHiveRollTask=nil; Report.ActiveTarget=nil
        else
            assert(Policy.rollTaskSafe(rollTask,current,cells,Types,p),"Active roll slot became a force slot; stopped before switching")
            p.target=current
            p.reason=rollTask.Reason
            p.mode=rollTask.Mode
            if Policy.isRecoveryTask(rollTask) and Policy.refill(slots)>100 then
                p.collectorFallback=true; env.FullHiveCollectorFallback=true
            end
            Report.ActiveTarget={X=rollTask.x,Y=rollTask.y,Reason=rollTask.Reason,StartedType=rollTask.StartedType}
        end
    end
    Report.CollectorFallback=p.collectorFallback
    Report.SafeNonCollector=#p.fallbackCandidates
    Report.NormalRefillAmount=Policy.refill(slots)
    Report.RefillAmount=Policy.refillFor(slots,p.collectorFallback)
    Report.RefillMode=p.collectorFallback and "fallback-100" or (slots==43 and "normal-2000" or "stage-refill")
    Report.StarJelly=s.Eggs.StarJelly or 0
    Report.StarJellyMissing=Policy.starJellyMissing(cells)
    Report.StarJellyUpgrade=Policy.starJellyUpgrade(p,rollTask)
    local batch=env.FullHiveJellyBatch
    -- The first legendary batch also satisfies the original 10k entry gate.
    if slots>=44 and not p.collectorFallback and (not lateStarted
        or (batch and batch.Entry and (batch.Remaining or 0)>0 and ctx.jelly>0)) then
        Report.RefillAmount=math.max(10000,Report.RefillAmount)
        Report.RefillMode="legendary-entry"
    end
    p._cells=cells
    return p,cells,slots
end
local function jellyBatchReady(s)
    local inventory=s.Eggs.RoyalJelly or 0
    local target=Report.RefillAmount
    local recovery=Report.CollectorFallback==true
    local h=hive()
    local batch=env.FullHiveJellyBatch
    local valid=activeJellyBatch(s)~=nil
    if not valid then
        batch=nil; env.FullHiveJellyBatch=nil
        -- Only a full refill amount or more can open a new batch. An incidental
        -- +1 gift after an exhausted batch cannot restart Until Gifted.
        if inventory>=target and inventory>0 then
            batch={Version=1,Owner=player.UserId,Job=game.JobId,Hive=h and h.Name,
                Amount=target,Remaining=inventory,Recovery=recovery,
                Entry=Report.RefillMode=="legendary-entry",StartedAt=os.time()}
            env.FullHiveJellyBatch=batch
            if batch.Entry then lateStarted=true; env.FullHiveLateStarted=true end
        end
    end
    if batch then batch.Remaining=inventory end
    Report.JellyBatch=batch and {Amount=batch.Amount,Remaining=inventory,StartedAt=batch.StartedAt} or nil
    return batch~=nil
end
local function jellyBatchSpent(remaining)
    local batch=env.FullHiveJellyBatch
    if batch then batch.Remaining=remaining end
    if remaining==0 then env.FullHiveJellyBatch=nil; Report.JellyBatch=nil end
end
local function initializeProgression()
    if not ProgressionPolicy or not createProgressionFacts or not createProgression then return end
    local reader=(type(debug)=="table" and debug.getupvalues) or getupvalues
    assert(type(reader)=="function" and type(getconnections)=="function","Atlas spending controls cannot be verified on this executor")
    atlasFarmOnly=createAtlasProgressionControl({core=game:GetService("CoreGui"),
        upvalues=reader,connections=getconnections,activate=activate})
    if Config.AutoProgression and not Config.DryRun then acquire();release() end
    local makeFacts=createProgressionFacts({
        Policy=ProgressionPolicy,Packages=Packages,Recipes=Recipes,Reqs=Reqs,
        Accessories=Accessories,CellTools=CellTools,OsTime=OsTime,Shops=workspace:FindFirstChild("Shops"),
        Hive=hive,HoneyReserve=Config.HoneyReserve,UseBlenderTickets=function() return Config.UseBlenderTickets end,
        Uncertain=function() return env.FullHiveUncertain end,
    })
    local buffTiles=loadModule(waitForChild(waitForChild(waitForChild(RS,"Gui"),"TileDisplay"),"BuffTile"))
    local function nectarSeconds(name)
        local tile=buffTiles.GetBuffTile(name.." Nectar")
        if not tile then return 0 end
        if type(tile.TimerStart)~="number" or type(tile.TimerDur)~="number" then return nil end
        return math.max(0,tile.TimerStart+tile.TimerDur-OsTime())
    end
    local function buildFacts(s)
        local facts,catalog=makeFacts(s)
        catalog.blenderSpeedUp={perTicket=1}
        for _,nectar in ipairs({"Comforting","Refreshing"}) do
            local item=nectar.."Vial"
            local seconds=nectarSeconds(nectar)
            local key="nectar:"..nectar
            if seconds then
                facts.conditions[key]=(facts.occupied or 0)>=35 and seconds>=43200 and (s.Eggs[item] or 0)<10
                    and OsTime()-(env.FullHiveLastNectarCondenserAt or 0)>=5
            end
            catalog.sources[item]={kind="nectar-vial",id=nectar,nectar=nectar,
                readyCondition=key,part=progressionToyPart("Nectar Condenser")}
        end
        return facts,catalog
    end
    progression=createProgression({
        Policy=ProgressionPolicy,Funds=ProgressionFunds,HatchReceipt=ProgressionHatchReceipt,
        BlenderReceipt=ProgressionBlenderReceipt,
        env=env,Report=Report,Config=Config,Events=Events,
        Packages=Packages,Recipes=Recipes,Reqs=Reqs,buildFacts=buildFacts,nectarSeconds=nectarSeconds,OsTime=OsTime,
        checkStop=checkStop,refresh=refresh,invoke=invoke,move=move,near=near,release=release,
        invokeHatch=function(before,x,y)
            return invokeRequest(Events.ConstructHiveCellFromEgg,before,x,y,"Basic",1,false)
        end,
        invokeSpeedup=function(before)
            return invokeRequest(Events.BlenderCommand,before,"SpeedUpOrder")
        end,
        fixedShopPackage=function(...) return fixedShopPackage(...) end,
        assertAtlasPaused=assertAtlasPaused,
        scan=scan,hiveFloor=hiveFloor,toyPart=progressionToyPart,jellyBatchSpent=jellyBatchSpent,
        Types=Types,
    })
end
local function find(cells,cell)
    for _,c in ipairs(cells) do if c.x==cell.x and c.y==cell.y then return c end end
end
local function ensureRollTask(p)
    if rollTask or not p.target then return end
    local h=assert(hive(),"Hive unavailable before roll task")
    rollTask=Policy.startRollTask(p.target,p._cells,p)
    rollTask.Owner=player.UserId
    rollTask.Hive=h.Name
    rollTask.Job=game.JobId
    env.FullHiveRollTask=rollTask
    Report.ActiveTarget={X=rollTask.x,Y=rollTask.y,Reason=rollTask.Reason,StartedType=rollTask.StartedType}
end
local function spend(cell,item,validate,expectedTask)
    checkStop(); acquire(); move(hiveFloor()); near(hiveFloor())
    local s=refresh()
    if progression and not progression.allowsHive(s) then return false end
    local p,cells=plan(s)
    local current=find(cells,cell)
    if not current or not validate(current,cells,p,s) then
        if expectedTask then return false end -- No request sent: replan safely.
        error("Target disappeared or became protected",0)
    end
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    if item=="StarJelly" then
        -- Inventory, failsafes and the selected upgrade can change during movement.
        if Policy.rollItem(cells,s.Eggs,p,rollTask)~="StarJelly" then return false end
        local settings=s.Settings or {}
        assert(not settings.RollToGifted and not settings.RollToLegendary
            and not settings.RollToMythic and not settings.RollToMutation,
            "Roll settings changed before Star Jelly spending")
    end
    local before=s.Eggs[item] or 0
    assert(before>0,"No "..item)
    if item=="RoyalJelly" then
        if not jellyBatchReady(s) then return false end -- No request sent; refill/replan.
        assert(Report.RoyalJellyUsed<Config.MaxRoyalJellies,"Royal Jelly limit reached")
        local settings=s.Settings or {}
        -- Recheck fresh inventory after movement: an incidental gift can make
        -- a previously bounded bulk roll exceed the remaining test budget.
        if before>Config.MaxRoyalJellies-Report.RoyalJellyUsed
            and (settings.RollToGifted or settings.RollToLegendary) then
            mode("off"); return false -- No request sent; retry with fresh planning.
        end
        assert((settings.RollToGifted==true)==(Report.RollMode=="gifted")
            and (settings.RollToLegendary==true)==(Report.RollMode=="legendary")
            and not settings.RollToMythic and not settings.RollToMutation,"Roll settings changed before spending")
    end
    near(hiveFloor())
    local remaining,accepted,comb,discovered,eggUses=invoke(Events.ConstructHiveCellFromEgg,current.x,current.y,item,1,false)
    assert(accepted and type(remaining)=="number" and type(comb)=="table","Item response rejected or uncertain; no retry")
    Cache:Set({"Eggs",item},remaining); Cache:Set("Honeycomb",comb)
    if discovered then Cache:Set("DiscoveredBees",discovered) end
    if eggUses then Cache:Set({"Totals","EggUses"},eggUses) end
    local consumed=before-remaining
    assert(consumed>=1 and consumed<=before,"Unknown item consumption")
    if item~="RoyalJelly" then assert(consumed==1,"Unexpected item consumption") end
    Report.Actions=Report.Actions+1
    if item=="RoyalJelly" then
        Report.RoyalJellyUsed=Report.RoyalJellyUsed+consumed
        jellyBatchSpent(remaining)
    end
    local b=assert(comb["x"..cell.x] and comb["x"..cell.x]["y"..cell.y],"Result bee missing")
    Report.LastResult={X=cell.x,Y=cell.y,Type=b.Type,Gifted=table.find(b.Traits or {},"Gifted")~=nil,Item=item,Consumed=consumed}
    if expectedTask and rollTask==expectedTask then
        rollTask.Rolled=true
        env.FullHiveRollTask=rollTask
    end
    -- Every protected Event/Mythic is checked after every request. A Star Treat may add Gifted.
    for _,old in ipairs(cells) do
        local temporaryHatch=Policy.key(old)==Policy.key(current) and p.temporary[Policy.key(old)] and EggTypes.Get(item).TrueEgg
        if p.protected[Policy.key(old)] and not temporaryHatch then
            local after=comb["x"..old.x] and comb["x"..old.x]["y"..old.y]
            assert(after and after.Type==old.bee.Type and (not Policy.gifted(old) or table.find(after.Traits or {},"Gifted")),"Protected bee changed")
        end
    end
    if Report.LastResult.Gifted and (b.Type=="Bubble" or b.Type=="Frosty") then nextFlexible=b.Type end
    if env then env.FullHiveUncertain=nil end -- Response/delta/hive protection verified.
    task.wait(Config.RollDelay)
    return b
end
local function shopFloor(name)
    local shops=assert(workspace:FindFirstChild("Shops"),"Shops not loaded")
    local shop=assert(shops:FindFirstChild(name),"Shop not loaded: "..name)
    local floor=shop:FindFirstChild("Floor")
    if floor and floor:IsA("ObjectValue") then floor=floor.Value end
    return assert(floor,"Shop floor missing: "..name)
end
fixedShopPackage=function(item,amount,shopName)
    assert(type(amount)=="number" and amount>0 and amount%1==0,"Invalid fixed pack amount")
    local shops=workspace:FindFirstChild("Shops")
    local shop=shops and shops:FindFirstChild(shopName)
    local options=shop and shop:FindFirstChild("Items")
    for _,option in ipairs(options and options:GetChildren() or {}) do
        local category=option:FindFirstChild("ItemCategory")
        local kind=option:FindFirstChild("ItemType")
        local count=option:FindFirstChild("ItemAmount")
        if category and category.Value=="Eggs" and kind and kind.Value==item
            and (count and count.Value or 1)==amount then
            return {Category=category.Value,Type=kind.Value,Amount=amount}
        end
    end
    error("No verified fixed shop option: "..item.." x"..amount,0)
end
local function buy(item,amount,shop,inventoryCeiling)
    assert(Config.AutoPurchase,"Purchasing disabled")
    acquire(); move(shopFloor(shop)); near(shopFloor(shop))
    local s=refresh()
    if progression and not progression.allowsHive(s) then return false end
    local before=s.Eggs[item] or 0
    if inventoryCeiling then
        if before>=inventoryCeiling then return false end
        while amount>inventoryCeiling-before do amount=amount/10 end
    end
    local usable=math.max(0,(s.Honey or 0)-Config.HoneyReserve)
    if item=="RoyalJelly" then
        plan(s)
        if inventoryCeiling~=Report.RefillAmount or usable<Policy.jellyCost(royalJellyPurchases(s),inventoryCeiling-before) then return false end
    elseif item=="Basic" then
        assert(amount==1,"Basic purchases must remain separate")
        if usable<10000000 then return false end
    else
        local cost=EggTypes.Get(item).TicketCost
        if type(cost)~="number" or (s.Eggs.Ticket or 0)<cost*amount then return false end
    end
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    local fixedPackage=fixedShopPackage(item,amount,shop)
    local accepted=invoke(Events.ItemPackageEvent,"Purchase",fixedPackage)
    assert(accepted,"Purchase rejected; no retry")
    s=refresh()
    assert((s.Eggs[item] or 0)-before==amount,"Purchase inventory uncertain; no retry")
    env.FullHiveUncertain=nil
    Report.Actions=Report.Actions+1; Report.LastPurchase={Item=item,Amount=amount}
    return s
end
local function refill()
    local s=refresh()
    if progression and not progression.allowsHive(s) then return false end
    local _,_,slots=plan(s)
    if jellyBatchReady(s) then return true end
    local target=Report.RefillAmount
    local inventory=s.Eggs.RoyalJelly or 0
    local missing=target-inventory
    if not Config.AutoPurchase or (s.Honey or 0)-Config.HoneyReserve
        <Policy.jellyCost(royalJellyPurchases(s),missing) then return false end
    local fallback=Report.CollectorFallback==true
    local _,pack=Policy.refillFor(slots,fallback)
    if Report.RefillMode=="legendary-entry" then pack=math.max(pack,10000) end
    Report.Activity="Refilling Royal Jelly to "..target.." before starting a batch"
    while true do
        checkStop(); s=refresh(); plan(s)
        if Report.RefillAmount~=target or (Report.CollectorFallback==true)~=fallback then return false end
        inventory=s.Eggs.RoyalJelly or 0
        if inventory>=target then break end
        missing=target-inventory
        -- Preserve the normal pack size; use supported smaller packs for an
        -- incidental gift/partial refill so the inventory reaches the exact goal.
        local amount=pack
        while amount>missing do amount=amount/10 end
        local cost=Policy.jellyCost(royalJellyPurchases(s),amount)
        if s.Honey-Config.HoneyReserve<cost then return false end
        if buy("RoyalJelly",amount,"JellyDispenser",target)==false then return false end
    end
    local ready=jellyBatchReady(s)
    if ready then move(hiveFloor()) end
    return ready
end
local function eventAction(s,cells,p)
    local function safe(c) return not p.keep[Policy.key(c)] and not p.protected[Policy.key(c)] end
    local target
    for _,c in ipairs(p.candidates) do if safe(c) then target=c; break end end
    if not target then for _,c in ipairs(cells) do if p.temporary[Policy.key(c)] then target=c; break end end end
    local normalEvent
    for _,name in ipairs({"Tabby","Vicious","Festive","Cobalt","Puppy","Gummy"}) do
        for _,c in ipairs(cells) do
            if c.bee.Type==name and not Policy.gifted(c) then normalEvent=c; break end
        end
        if normalEvent then break end
    end
    if normalEvent and (s.Eggs.StarTreat or 0)>0 then
        mode("off")
        spend(normalEvent,"StarTreat",function(c) return Types[c.bee.Type].Rarity=="Event" and not Policy.gifted(c) end)
        return true
    end
    local order={"Tabby","Festive","Cobalt","Vicious","Puppy"}
    for _,name in ipairs(order) do
        local egg=name.."Bee"
        if Policy.count(cells,name)==0 then
            if (s.Eggs[egg] or 0)>0 and target then
                mode("off")
                spend(target,egg,function(c,_,fresh)
                    return (not fresh.keep[Policy.key(c)] and not fresh.protected[Policy.key(c)]) or fresh.temporary[Policy.key(c)]
                end)
                return true
            end
            -- Jelly ownership indicates a previously acquired unique bee; do not rebuy it.
            local owned=(s.Eggs[egg] or 0)>0 or (s.Eggs[egg.."Jelly"] or 0)>0
            if not owned and target and Config.AutoPurchase then
                if name=="Vicious" then
                    if (s.Eggs.Stinger or 0)>=250 then
                        local toys=assert(workspace:FindFirstChild("Toys"),"Toys not loaded")
                        local toy=assert(toys:FindFirstChild("Vicious Bee Claimer"),"Vicious claimer not loaded")
                        move(toy.Platform); near(toy.Platform)
                        s=refresh()
                        if progression and not progression.allowsHive(s) then return false end
                        if (s.Eggs.Stinger or 0)<250 then return false end
                        assert(Report.Actions<Config.MaxActions,"Action limit reached")
                        Events.ToyEvent:FireServer(toy.Name)
                        local deadline=os.clock()+8
                        repeat task.wait(0.25); s=refresh() until (s.Eggs.ViciousBee or 0)>0 or os.clock()>deadline
                        assert((s.Eggs.ViciousBee or 0)>0,"Vicious purchase uncertain; no retry")
                        Report.Actions=Report.Actions+1; return true
                    end
                else
                    local cost=assert(EggTypes.Get(egg).TicketCost,"Unknown ticket cost")
                    if (s.Eggs.Ticket or 0)>=cost then return buy(egg,1,"TicketShop")~=false end
                    -- Save tickets for the next bee; only Vicious can be skipped.
                    return false
                end
            end
        end
    end
    if normalEvent then
        if Config.AutoPurchase and (s.Eggs.Ticket or 0)>=1000 then return buy("StarTreat",1,"TicketShop")~=false end
    end
    return false
end
local function giftedBasic(s,cells,p)
    if basicLock then
        local h=hive()
        assert(basicLock.Owner==player.UserId and basicLock.Job==game.JobId
            and basicLock.Hive==(h and h.Name),
            "Basic continuation identity needs reconciliation; purchases and lock preserved")
    end
    if Policy.count(cells,"Basic",true)>0 then
        if basicLock then env.FullHiveJellyBatch=nil; Report.JellyBatch=nil end
        basicLock=nil; env.FullHiveBasicLock=nil; return false
    end
    local _,slots=scan(s)
    if slots<40 or (not basicLock and (s.Honey or 0)<3000000000) then return false end
    if not basicLock then
        local c=p.candidates[1]
        if not c then return false end
        local h=assert(hive(),"Hive unavailable for Basic continuation")
        basicLock={x=c.x,y=c.y,Owner=player.UserId,Hive=h.Name,Job=game.JobId,
            BasicBatchTarget=10,BasicBatchPurchased=0}
        env.FullHiveBasicLock=basicLock
    end
    basicLock.BasicBatchTarget=basicLock.BasicBatchTarget or 10
    basicLock.BasicBatchPurchased=basicLock.BasicBatchPurchased or 0
    local current=assert(find(cells,basicLock),"Gifted Basic locked slot missing")
    assert(Policy.basicSlotSafe(basicLock,current,p),
        "Gifted Basic slot became a kept bee; preserve lock and purchases for review")
    local rarity=Types[current.bee.Type].Rarity
    -- This permanent rule overrides the lock when a Basic Egg yields a Mythic/Event.
    if rarity=="Event" or rarity=="Mythic" then error("Gifted Basic lock now contains a protected bee; stopped") end
    local eggs=s.Eggs.Basic or 0
    local jelly=s.Eggs.RoyalJelly or 0
    if not basicLock.NeedsJelly then
        if eggs==0 and basicLock.BasicBatchPurchased>=basicLock.BasicBatchTarget then
            -- The previous ten-egg batch has been consumed. Start a fresh
            -- batch and keep its purchase count across interruptions.
            basicLock.BasicBatchPurchased=0
        end
        if basicLock.BasicBatchPurchased < basicLock.BasicBatchTarget then
            if not Config.AutoPurchase then return false end
            while basicLock.BasicBatchPurchased < basicLock.BasicBatchTarget do
                checkStop()
                local current=refresh()
                if (current.Honey or 0)-Config.HoneyReserve < 10000000 then return false end
                -- Each request is exactly one Basic Egg. buy() verifies the
                -- inventory delta before this count advances, and we remain
                -- at the shop until all ten verified purchases finish.
                if buy("Basic",1,"EggDispenser")==false then return false end
                basicLock.BasicBatchPurchased=basicLock.BasicBatchPurchased+1
                env.FullHiveBasicLock=basicLock
            end
            move(hiveFloor())
            return true
        end
    end
    if not (jellyBatchReady(s) or refill()) then return false end
    mode("off")
    local function locked(c,_,freshPlan)
        local r=Types[c.bee.Type].Rarity
        return r~="Event" and r~="Mythic" and Policy.basicSlotSafe(basicLock,c,freshPlan)
    end
    if not basicLock.NeedsJelly then
        if spend(basicLock,"Basic",locked)==false then return false end
        basicLock.NeedsJelly=true
    else
        if spend(basicLock,"RoyalJelly",locked)==false then return false end
        basicLock.NeedsJelly=false
    end
    return true
end
local function starReady(s,cells)
    Report.StarEggDeferred=nil
    local coverage=StarState.coverage(cells,Types)
    Report.StarEggPrerequisitesMissing=coverage.missing
    Report.StarEggMythicsMissing=coverage.missingMythics
    if #coverage.missingMythics==0 then
        Report.StarEggDeferred="all-gifted-mythics-present"
        return false
    end
    if Config.MaxActions < math.huge or Config.MaxRoyalJellies < math.huge then
        Report.StarEggDeferred="Existing Star Egg workflow requires an unlimited progression run"
        return false
    end
    local _,slots=scan(s)
    if slots<44 or s.Honey<Config.StarEggHoney or (s.Eggs.Star or 0)==0 then return false end
    local budget,budgetReason=StarState.budget(s,2)
    if budget==0 then Report.StarEggDeferred=budgetReason;return false end
    local used=starEggUses(s)
    if used>=2 then return false end
    local missing={}
    -- Honor the requested handoff trigger; the existing script owns its preparation rules.
    for _,name in ipairs(Policy.legendary) do
        if Policy.count(cells,name,true)==0 then missing[#missing+1]=name end
    end
    table.sort(missing); Report.StarEggMissing=missing
    return #missing==0
end
local function useStarScript(s)
    acquire(); move(hiveFloor())
    s=refresh()
    if progression and not progression.allowsHive(s) then release();return false end
    local cells=scan(s)
    if not starReady(s,cells) then release();return false end
    local used=starEggUses(s)
    -- Shared Star Egg workflow is embedded with reviewed host integration hooks.
    local budget=StarState.budget(s,Config.MaxActions-Report.Actions)
    assert(budget>0,"No qualified Star Egg budget")
    env.FullHiveStarBudget=budget
    env.FullHiveMove=function() move(hiveFloor()) end
    env.FullHiveRefill=refill
    env.FullHiveJellyReady=function(stats)
        if progression and not progression.allowsHive(stats) then return false end
        plan(stats); return jellyBatchReady(stats)
    end
    env.FullHiveJellySpent=jellyBatchSpent
    env.FullHiveNear=function()
        near(hiveFloor())
        assert(not progression or progression.allowsHive(refresh()),"Gear progression now has priority; Star workflow paused")
    end
    env.FullHiveStarRunning=true
    local before=s.Eggs.Star or 0
    local ok,err=pcall(function()
        assert(type(compile)=="function","Arceus X does not expose loadstring/load; Star Egg handoff unavailable")
        local chunk,loadError=compile(StarEggSource)
        assert(chunk,loadError)
        chunk()
    end)
    env.FullHiveStarRunning=false
    env.FullHiveStarBudget,env.FullHiveMove,env.FullHiveRefill,env.FullHiveNear=nil,nil,nil,nil
    env.FullHiveJellyReady,env.FullHiveJellySpent=nil,nil
    assert(ok,err); assert(not env.AutoGiftedStarError,env.AutoGiftedStarError)
    s=refresh()
    assert(StarState.usage(s).known,"Star Egg result counter unavailable for reconciliation")
    local afterUses=starEggUses(s)
    local child=env.AutoGiftedStarReport or {}
    local delta=afterUses-used
    assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain,
        "Star Egg handoff left an unresolved request")
    if delta==0 then
        local freshCells=scan(s)
        assert(child.DeferredReason=="all-gifted-mythics-present"
            and child.StarEggsUsed==0 and (s.Eggs.Star or 0)==before
            and #StarState.coverage(freshCells,Types).missingMythics==0,
            "Star Egg workflow made no verified progress")
    else
        assert(delta>0 and delta<=budget and delta==child.StarEggsUsed
            and before-(s.Eggs.Star or 0)==delta,
            "Star Egg recorded usage disagrees with workflow result")
        Report.Actions=Report.Actions+delta
    end
    Report.StarEggDeferred=child.DeferredReason
    env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
    release()
    return delta>0
end
local function waitFor(reason)
    Report.Phase="waiting"; Report.Activity=reason
    release(); task.wait(Config.PollSeconds)
end
local function waitForStartupDelay()
    local duration=math.max(0,tonumber(Config.StartupDelaySeconds) or 60)
    Report.Phase="startup-delay"
    Report.Activity=string.format("Waiting %d seconds before starting hive assist",duration)
    Report.AtlasReady=false
    local deadline=os.clock()+duration
    while os.clock()<deadline do
        checkStop()
        task.wait(math.min(0.25,math.max(0,deadline-os.clock())))
    end
    Report.AtlasReady=true
    Report.AtlasReadiness="fixed-delay"
    return true
end
local function run()
    assert(Report.AtlasReady,"Startup delay must finish before starting")
    local s=refresh()
    while not env.FullHiveStop do
        checkStop()
        if Report.Actions>=Config.MaxActions or Report.RoyalJellyUsed>=Config.MaxRoyalJellies then break end
        s=Cache:Get()
        if not hive() then waitFor("Waiting for Atlas to claim a hive"); s=refresh(); continue end
        if progression then
            local did,why=progression.step(s)
            if did then
                if Config.DryRun then Report.Phase="dry-run";return end
                if why then waitFor(why) end
                s=refresh(); continue
            end
        end
        local p,cells,slots=plan(s)
        Report.Stage,Report.Slots,Report.Bees,Report.Needs=p.stage,slots,#cells,p.needs
        Report.Growth=p.growth
        Report.CapacityStatus=p.capacityStatus
        Report.RoyalJelly,Report.Honey=s.Eggs.RoyalJelly or 0,s.Honey
        Report.Counts={Baby=Policy.count(cells,"Baby"),Music=Policy.count(cells,"Music"),Shy=Policy.count(cells,"Shy"),
            Tadpole=Policy.count(cells,"Tadpole"),Buoyant=Policy.count(cells,"Buoyant"),
            GiftedTadpole=Policy.count(cells,"Tadpole",true),GiftedBuoyant=Policy.count(cells,"Buoyant",true)}
        Report.StarEggsUsed=starEggUses(s)
        Report.StarEggUsesKnown=StarState.usage(s).known
        Report.SafeSlots=#p.candidates
        Report.NextTarget=p.target and {X=p.target.x,Y=p.target.y,Type=p.target.bee.Type} or nil
        if Config.DryRun then Report.Phase="dry-run"; return end
        if not Report.Growth.CanReroll then
            if progression and progression.grow(s,math.min(50,math.max(25,slots))) then s=refresh();continue end
            waitFor("Fill empty hive cells before rerolling: "..#cells.." bees / "..slots.." slots (Atlas or manual hatching)")
            s=refresh(); continue
        end
        if p.complete then Report.Phase="endgame-complete"; Report.Activity="Final hive requirements reached"; return end
        local item=Policy.rollItem(cells,s.Eggs,p,rollTask)
        env.FullHiveStarted=true
        if basicLock then
            if giftedBasic(s,cells,p) then continue end
            if basicLock then waitFor("Waiting for honey or jelly for the locked Basic slot"); s=refresh(); continue end
        end
        -- A current slot finishes before another hive task claims a slot.
        if not rollTask then
            if eventAction(s,cells,p) then continue end
            if giftedBasic(s,cells,p) then continue end
            if starReady(s,cells) then Report.Phase="star-eggs"; useStarScript(s); continue end
        end
        if not p.target then
            if progression and not rollTask and not basicLock and progression.grow(s,math.min(50,slots+1)) then s=refresh();continue end
            local reason=p.stage=="final" and p.growth.Empty>0
                and ("Waiting to fill "..p.growth.Empty.." empty hive cells (Atlas or manual hatching)")
                or p.capacityStatus.Conflict and ("Kept bees and current targets require at least "
                    ..p.capacityStatus.Minimum.." cells; capacity is "..slots)
                or "Targets held; waiting for Atlas, inventory, or Star Egg prerequisites"
            waitFor(reason); s=refresh(); continue
        end
        if item=="RoyalJelly" and not (jellyBatchReady(s) or refill()) then
            waitFor("Waiting for at least "..Report.RefillAmount.." Royal Jelly to start a batch"); s=refresh(); continue
        end
        Report.Phase="rolling"; Report.Activity=p.reason
        ensureRollTask(p)
        mode(item=="StarJelly" and "off" or p.mode)
        local taskCell=rollTask and {x=rollTask.x,y=rollTask.y} or p.target
        local expected=Policy.key(taskCell)
        local activeTask=rollTask
        local spent=spend(taskCell,item,function(c,freshCells,fresh)
            return activeTask and rollTask==activeTask and Policy.key(c)==expected
                and Policy.rollTaskSafe(activeTask,c,freshCells,Types,fresh)
        end,activeTask)
        if spent==false then continue end
    end
    Report.Phase=env.FullHiveStop and "stopped" or "limit-reached"
end
-- A stop button affects both the main assist and the existing Star Egg handoff.
local function runWithCharacterRecovery()
    while true do
        local ok,err=pcall(run)
        if ok then return end
        -- Never replay an uncertain request or an embedded Star Egg workflow.
        if err~=CHARACTER_UNAVAILABLE or env.FullHivePending or env.AutoHivePendingRequest
            or env.FullHiveStarRunning or env.AutoGiftedStarRunning then error(err,0) end
        release()
        assert(not env.FullHiveAtlasOwned,"Atlas release failed during character recovery")
        Report.RespawnRecoveries=(Report.RespawnRecoveries or 0)+1
        Report.Phase="waiting-character"; Report.Activity="Waiting for the character to respawn"
        repeat checkStop(); task.wait(0.25) until characterRoot()
        checkStop()
        -- run() refreshes server stats and revalidates the existing coordinate
        -- lease before another action. Counters and verified purchases survive.
        Report.Phase="character-recovered"; Report.Activity="Character ready; refreshing hive data"
    end
end
local function makeUI()
    local pg=waitForChild(player,"PlayerGui")
    local old=pg:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local parent=uiParent()
    old=parent:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local gui=Instance.new("ScreenGui"); gui.Name="FullHiveStatus"; gui.ResetOnSpawn=false; gui.DisplayOrder=10000; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=parent
    local make=FeatherTheme.make
    local frame=make("Frame","StatusPanel",gui,{Size=UDim2.fromOffset(350,350),Position=UDim2.fromOffset(18,80)})
    FeatherTheme.panel(frame)
    local statusScale=make("UIScale","ResponsiveScale",frame,{Scale=1})
    local function fitStatus()
        local camera=workspace.CurrentCamera
        if camera then
            local size=camera.ViewportSize
            statusScale.Scale=math.max(0.2,math.min(1,(size.X-36)/350,(size.Y-124)/350))
        end
    end
    fitStatus()
    local camera=workspace.CurrentCamera
    if camera then
        local resize=camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStatus)
        gui.AncestryChanged:Connect(function() if not gui.Parent then resize:Disconnect() end end)
    end
    FeatherTheme.brand(frame,UDim2.fromOffset(18,10),2)
    make("TextLabel","Subtitle",frame,{Position=UDim2.fromOffset(18,43),Size=UDim2.fromOffset(180,16),
        BackgroundTransparency=1,Text="ATLAS HIVE ASSIST",Font=Enum.Font.GothamMedium,TextSize=10,
        TextColor3=Color3.fromRGB(143,171,210),TextXAlignment=Enum.TextXAlignment.Left})
    local version=make("TextLabel","VersionBadge",frame,{Position=UDim2.new(1,-87,0,17),Size=UDim2.fromOffset(69,22),
        BackgroundColor3=Color3.fromRGB(35,50,79),BorderSizePixel=0,Text="v"..SCRIPT_VERSION,Font=Enum.Font.GothamMedium,
        TextSize=11,TextColor3=Color3.fromRGB(184,215,255)})
    make("UICorner","Corner",version,{CornerRadius=UDim.new(1,0)})
    make("Frame","Divider",frame,{Position=UDim2.fromOffset(18,66),Size=UDim2.new(1,-36,0,1),
        BackgroundColor3=Color3.fromRGB(124,163,216),BackgroundTransparency=0.75,BorderSizePixel=0})
    FeatherTheme.draggable(frame,64,10)
    local phase=make("TextLabel","PhaseBadge",frame,{Position=UDim2.fromOffset(18,78),Size=UDim2.new(1,-36,0,22),
        BackgroundColor3=Color3.fromRGB(34,54,85),BorderSizePixel=0,Text="STARTING",Font=Enum.Font.GothamBold,
        TextSize=10,TextColor3=Color3.fromRGB(164,214,255),TextXAlignment=Enum.TextXAlignment.Left})
    make("UICorner","Corner",phase,{CornerRadius=UDim.new(0,6)})
    make("UIPadding","Inset",phase,{PaddingLeft=UDim.new(0,10)})
    local text=make("TextLabel","Activity",frame,{Position=UDim2.fromOffset(18,108),Size=UDim2.new(1,-36,0,38),
        BackgroundTransparency=1,Text="Preparing progression...",TextColor3=Color3.fromRGB(230,239,253),TextSize=13,
        TextWrapped=true,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
    local metrics=make("Frame","Metrics",frame,{Position=UDim2.fromOffset(18,154),Size=UDim2.new(1,-36,0,32),BackgroundTransparency=1})
    make("UIListLayout","Layout",metrics,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    local function metric(name,order)
        local item=make("TextLabel",name,metrics,{Size=UDim2.new(1/3,-16/3,1,0),LayoutOrder=order,
            BackgroundColor3=Color3.fromRGB(33,47,76),BorderSizePixel=0,Font=Enum.Font.GothamMedium,TextSize=12,
            TextColor3=Color3.fromRGB(201,223,251),Text="-"})
        make("UICorner","Corner",item,{CornerRadius=UDim.new(0,8)})
        return item
    end
    local slotsMetric,jellyMetric,refillMetric=metric("Slots",1),metric("Jelly",2),metric("Refill",3)
    local progressText=make("TextLabel","Progress",frame,{Position=UDim2.fromOffset(18,190),Size=UDim2.new(1,-36,0,20),
        BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(160,183,217),
        TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
    local progressionText=make("TextLabel","Progression",frame,{Position=UDim2.fromOffset(18,214),Size=UDim2.new(1,-36,0,58),
        BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(146,179,221),
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true})
    local blenderTicketButton=Instance.new("TextButton"); blenderTicketButton.Name="BlenderTicketToggle"
    blenderTicketButton.Size=UDim2.fromOffset(150,18); blenderTicketButton.Position=UDim2.fromOffset(18,278)
    blenderTicketButton.Text="Blender tickets: OFF"; blenderTicketButton.Parent=frame; FeatherTheme.button(blenderTicketButton,false)
    blenderTicketButton.Activated:Connect(function()
        Config.UseBlenderTickets=not Config.UseBlenderTickets
        env.FullHiveConfig=env.FullHiveConfig or {}
        env.FullHiveConfig.UseBlenderTickets=Config.UseBlenderTickets
        blenderTicketButton.Text="Blender tickets: "..(Config.UseBlenderTickets and "ON" or "OFF")
    end)
    local viewButton=Instance.new("TextButton"); viewButton.Name="ViewHiveButton"
    viewButton.Size=UDim2.new(0.5,-23,0,32); viewButton.Position=UDim2.new(0,18,1,-48)
    viewButton.Text="View hive"; viewButton.Parent=frame; FeatherTheme.button(viewButton,true)
    local button=Instance.new("TextButton"); button.Name="StopAssistButton"; button.Size=UDim2.new(0.5,-23,0,32); button.Position=UDim2.new(0.5,5,1,-48)
    button.Text="Stop assist"; button.Parent=frame; FeatherTheme.button(button,false)
    local function stopAssist()
        env.FullHiveStop=true
        if env.FullHiveStarRunning then env.AutoGiftedStarStop=true end
    end
    button.Activated:Connect(stopAssist)
    createHiveView(gui,frame,viewButton,function()
        if not Cache or not Types then return nil end
        return Cache:Get(),Types,Report.ActiveTarget
    end)
    local function setText(label,value)
        if label.Text~=value then label.Text=value end
    end
    task.spawn(function()
        repeat
            if frame.Visible then
            local c=Report.Counts or {}
            local progress=Report.Stage=="early" and string.format("Baby %d/4 | Music %d/4 | Shy %d/3",c.Baby or 0,c.Music or 0,c.Shy or 0)
                or string.format("Actions %d | Jelly used %d",Report.Actions,Report.RoyalJellyUsed)
            local active=Report.ActiveTarget
            if active then
                progress=string.format("Slot (%d,%d) | %s",active.X,active.Y,
                    Report.CollectorFallback and (active.Reason=="gifted-collector-fallback" and "100-jelly gifted recovery" or "100-jelly collector recovery") or active.Reason)
            end
            setText(phase,string.upper((Report.Stage or "inspect").."  |  "..(Report.Phase or "starting")))
            phase.TextColor3=Report.Error and Color3.fromRGB(255,176,192) or Color3.fromRGB(164,214,255)
            setText(text,Report.Error or Report.CleanupError or Report.Activity or Report.Phase)
            setText(progressText,progress)
            local pg=Report.Progression or {}
            local status=pg.Status or {}
            local title=pg.Gear and ("Target: "..pg.Gear) or "Gear route complete"
            local lines={title}
            lines[#lines+1]=status.label or pg.Reason or pg.Action or "Inspecting gear"
            local counts={}
            local names={BlueExtract="Blue Extract",RedExtract="Red Extract",ComfortingVial="Comforting Vial"}
            for _,row in ipairs(status.materials or {}) do
                if (row.actual or 0)<row.required then
                    local count=(names[row.item] or row.item).." "..tostring(row.actual or 0).."/"..row.required
                    if (row.queued or 0)>0 then count=count.." (+"..row.queued.." crafting)" end
                    counts[#counts+1]=count
                end
            end
            if #counts>0 then lines[#lines+1]=table.concat(counts,", ") end
            if pg.FundsRequired and pg.MissingRJ then
                local function money(n)
                    if n>=1000000000 then return string.format("%.2fB",n/1000000000) end
                    if n>=1000000 then return string.format("%.1fM",n/1000000) end
                    return tostring(math.floor(n))
                end
                lines[#lines+1]="Need "..pg.MissingRJ.." jelly | Honey "..money(pg.Honey or 0).."/"..money(pg.FundsRequired)
            end
            local blender=Report.Blender
            if blender and blender.Recipe then
                lines[#lines+1]="Blender: "..blender.Recipe.." x"..tostring(blender.Count).." | "
                    ..(blender.Complete and "ready to collect" or math.ceil(blender.RemainingSeconds or 0).."s left")
            end
            setText(progressionText,table.concat(lines,"\n"))
            setText(blenderTicketButton,"Blender tickets: "..(Config.UseBlenderTickets and "ON" or "OFF"))
            setText(slotsMetric,tostring(Report.Slots or "?").." slots")
            setText(jellyMetric,tostring(Report.RoyalJelly or 0).." jelly")
            setText(refillMetric,tostring(Report.RefillAmount or "-").." / refill")
            end
            task.wait(0.75)
        until not gui.Parent or not env.FullHiveRunning
        if gui.Parent then phase.Text=string.upper(Report.Phase or "finished"); text.Text=Report.Error or "Assist finished"; button.Text="Finished" end
    end)
end
local ok,err=xpcall(function()
    if not waitForStartupDelay() then return end
    initializePlayer()
    makeUI()
    initializeModules()
    initializeProgression()
    runWithCharacterRecovery()
end,function(e) return tostring(e) end)
release()
if not ok then
    Report.Phase=stoppedByUser and "stopped" or "error"
    if not stoppedByUser then Report.Error=err; warn("[Full Hive] "..err) end
end
env.FullHiveRunning=false
