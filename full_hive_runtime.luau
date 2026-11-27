-- Bundled by build_full_hive.ps1 after Policy and StarEggSource.
local SCRIPT_VERSION = "1.8.134"
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
local function atlasValues(callback)
    local reader=(type(debug)=="table" and debug.getupvalues) or getupvalues
    return atlasCallbackValues(reader,callback)
end
local function atlasWindow(root)
    for _,window in ipairs(descendants(root,"Frame")) do
        if window.Name=="Window" and window:FindFirstChild("TabButtons") then return window end
    end
end
local function atlasTabs(root)
    local window=atlasWindow(root)
    local tabs=window and window:FindFirstChild("TabButtons")
    local buttons=tabs and tabs:FindFirstChild("ScrollingFrame")
    local roots,seen={},{}
    for _,button in ipairs(buttons and buttons:GetChildren() or {}) do
        if button:IsA("TextButton") then
            for _,connection in ipairs(getconnections(button.MouseButton1Click)) do
                if type(connection.Function)=="function" then
                    for _,value in pairs(atlasValues(connection.Function)) do
                        if typeof(value)=="Instance" and value:IsA("ScrollingFrame") and not seen[value] then
                            seen[value]=true;roots[#roots+1]=value
                        end
                    end
                end
            end
        end
    end
    return roots
end
local function findText(root, text)
    local ok, result = pcall(function()
        return root:QueryDescendants('TextLabel[Text = "' .. text .. '"]')
    end)
    if ok and type(result) == "table" and #result>0 then return result end
    local out = {}
    for _, label in ipairs(descendants(root, "TextLabel")) do
        if label.Text == text then out[#out + 1] = label end
    end
    if #out==0 and text=="Stop Everything" and type(getconnections)=="function" then
        for _,tab in ipairs(atlasTabs(root)) do
            for _,label in ipairs(descendants(tab,"TextLabel")) do
                if label.Text==text then out[#out+1]=label end
            end
        end
    end
    return out
end
-- Atlas callbacks/executor resumes may run with a lower thread identity.
-- Scope protected UI access and restore the caller even if a callback changes it.
local function atlasAccess(callback,...)
    local getIdentity=getthreadidentity or getidentity
    local setIdentity=setthreadidentity or setidentity
    if type(getIdentity)~="function" or type(setIdentity)~="function" then return callback(...) end
    local got,previous=pcall(getIdentity)
    assert(got and type(previous)=="number","Cannot read Atlas UI thread identity")
    local elevated,why=pcall(setIdentity,8)
    assert(elevated,"Cannot access Atlas UI: "..tostring(why))
    local results=table.pack(pcall(callback,...))
    local restored,restoreError=pcall(setIdentity,previous)
    assert(restored,"Cannot restore Atlas UI thread identity: "..tostring(restoreError))
    if not results[1] then error(results[2],0) end
    return table.unpack(results,2,results.n)
end
local function uiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    return game:GetService("CoreGui")
end
local function activateRaw(button, callback)
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
local function activate(button,callback)
    return atlasAccess(activateRaw,button,callback)
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
local Config = {DryRun=false, PollSeconds=3, Speed=60, NearDistance=16,
    MaxActions=math.huge, MaxRoyalJellies=math.huge, AutoPurchase=true,
    HoneyReserve=0, RollDelay=0.3, StarEggHoney=100000000000,
    AtlasInitiallyStopped=false, PreserveUniqueGifted=false, AutoProgression=true,
    UseBlenderTickets=false, AutoAmulets=true, AutoQuestAssist=true, SuperMaterialFarm=false}
local settingsPlayer=game:GetService("Players").LocalPlayer
local settingsHttp=game:GetService("HttpService")
local settingsStore=FeatherSettings.new({userId=settingsPlayer.UserId,read=readfile,write=writefile,exists=isfile,
    encode=function(value) return settingsHttp:JSONEncode(value) end,
    decode=function(value) return settingsHttp:JSONDecode(value) end})
local savedPreferences=settingsStore.load()
for k,v in pairs(savedPreferences) do if k~="AssistEnabled" then Config[k]=v end end
for k,v in pairs(env.FullHiveConfig or {}) do
    if k~="StartupDelaySeconds" then
        assert(Config[k] ~= nil, "Unknown config: "..k)
        Config[k]=v
    end
end
-- Retain the old option for config compatibility; ordinary keeps must still
-- follow the user's failsafe/force lists even if an old override was true.
Config.PreserveUniqueGifted=false
-- Speed remains actual studs/second for compatibility with saved configurations.
Config.Speed=math.clamp(tonumber(Config.Speed) or 60,10,400)
local restartToken=FeatherRestart.prepare(env,os.clock,task.wait)
assert(not env.AutoGiftedStarRunning, "Stop the other hive assist before starting Full Hive")
assert(not env.AutoHivePendingRequest and not env.FullHivePending, "A previous server request is pending")
assert(not env.FullHiveUncertain, "An earlier hive mutation needs reconciliation; do not retry")
env.FullHiveRunning, env.FullHiveStop = true, false
FeatherRestart.finish(env,restartToken)
env.FullHiveVersion = SCRIPT_VERSION
env.FullHivePreviousReport = env.FullHiveReport
local Report = {Version=SCRIPT_VERSION, Phase="starting", Actions=0, RoyalJellyUsed=0, DryRun=Config.DryRun,StartedAt=os.time()}
Report.TweenSpeed=Config.Speed/10
Report.MovementSpeed=Config.Speed
Report.PauseRequested=savedPreferences.AssistEnabled==false
if env.FullHiveStartPaused~=nil then Report.PauseRequested=env.FullHiveStartPaused==true end
local function saveSettings()
    settingsStore.save(Config,not Report.PauseRequested)
    Report.SettingsError=settingsStore.error
    Report.SettingsFile=settingsStore.path
end
saveSettings()
env.FullHiveStartPaused=nil -- One-time handoff for maintenance of a paused/stopped session.
env.FullHiveReport = Report
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local player, Events, Cache, Types, EggTypes
local progression,atlasFarmOnly
local background,shopFloor
local fixedShopPackage
local customShopPackage
local Packages, Recipes, Reqs, Accessories, CellTools, OsTime
local leased, previousAtlas, previousSettings, cleanupMove = false, nil, nil, nil
local legendaryChoice = math.random()
local basicLock = env.FullHiveBasicLock
local rollTask = env.FullHiveRollTask
-- Drop an old, unowned continuation batch when upgrading from use-all mode.
if env.FullHiveJellyBatch and not env.FullHiveJellyBatch.Recovery and not rollTask and not basicLock then
    env.FullHiveJellyBatch=nil
end
local nextFlexible
local materialFarm
local materialFarmThread,materialFarmBusy
local stoppedByUser = false
local PAUSE_REQUESTED = {}
local function checkStop()
    if env.FullHiveStop then stoppedByUser=true; error("Stopped by user",0) end
end
local function pauseCheckpoint()
    checkStop()
    -- Embedded Star Egg work must finish its own receipt reconciliation.
    if Report.PauseRequested and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning then
        while materialFarmBusy do task.wait(0.05) end
        if materialFarm then materialFarm.restore() end
        error(PAUSE_REQUESTED,0)
    end
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
    Report.Phase="loading-modules"; Report.Activity="Loading hive data"
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
local STATS_READ_TIMEOUT = {}
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
            if receiptBefore and receiptBefore.Kind=="roll" then request.RollBefore=receiptBefore
            elseif receiptBefore and (receiptBefore.Kind=="ssa-feed" or receiptBefore.Kind=="vicious-feed") then request.FeedBefore=receiptBefore
            else request.HatchBefore=receiptBefore end -- Copied before the request can yield.
        elseif remote.Name=="ItemPackageEvent" and type(args[2])=="table" then
            request.Item,request.Amount=args[2].Type,args[2].Amount
            request.Category=args[2].Category
            if request.Category=="HiveSlot" then
                local before=Cache:Get()
                request.HiveSlotBefore={Capacity=before.UnlockedCells,Honey=before.Honey,
                    Purchased=((before.Totals or {}).Purchases or {}).HiveSlots or 0}
            end
            if request.Category=="Eggs"and request.Item=="Ticket"then
                local before=Cache:Get()
                request.TicketBefore={Honey=before.Honey,Inventory=before.Eggs.Ticket or 0,
                    Purchased=((((before.Totals or{}).Purchases or{}).Eggs or{}).Ticket or 0)}
            end
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
    if not done and not mutation then
        Report.StatsReadFailure={Name=request.Name,Started=request.Started,At=os.time()}
        error(STATS_READ_TIMEOUT,0) -- The original read retains its pending flag.
    end
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
    -- Progression can yield for gear before the hive planner runs.
    local capacityKnown,capacity=pcall(Policy.hiveCapacity,s)
    Report.Slots=capacityKnown and capacity or nil
    Report.RoyalJelly=s.Eggs.RoyalJelly or 0
    for _,k in ipairs({"Honey","Eggs","Totals","Honeycomb","Settings","Quests","UnlockedCells","Accessories","Collectors","Sprinklers","Codes","PlaytimeAtLoad","LoadTime","OfflineProgressTime","MiscInfo","ItemTimes","Treasures","Amulets","IncomingAmulets","DiscGiftTypes","ToyTimes","ToyPlaytimes","PlayerActiveTimes"}) do
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
local MOVEMENT_TIMEOUT = {}
local ATLAS_UNAVAILABLE = {}
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
local function near(part)
    local gap=distance(part)
    if gap<=Config.NearDistance then return end
    local movement=Report.Movement or {}
    movement.Destination=part:GetFullName();movement.Arrived=false
    movement.Distance=gap;movement.Failure="Lost proximity before action"
    Report.Movement=movement;Report.LastMovementArrival=nil
    error(MOVEMENT_TIMEOUT,0)
end
local atlasPauseControl
local function atlasToggleRaw()
    local coreGui = uiParent()
    local cached=atlasPauseControl
    if cached and cached.Button.Parent and cached.Label.Parent==cached.Button
        and cached.Label.Text=="Stop Everything" and cached.Button:IsDescendantOf(coreGui)
        and type(rawget(cached.State.Cell,cached.State.Key))=="boolean" then
        return cached.Button,cached.State,cached.Callback
    end
    atlasPauseControl=nil
    local upvalueReader = atlasValues
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
                            local bound=false
                            for _,value in pairs(u) do if value==b then bound=true;break end end
                            for _,value in pairs(u) do
                                if type(value)=="table" then
                                    local key=type(rawget(value,1))=="boolean" and 1
                                        or bound and type(rawget(value,4))=="boolean" and 4
                                    if key then
                                        if state and (state.Cell~=value or state.Key~=key) then
                                            error("Ambiguous Atlas Stop Everything state",0)
                                        end
                                        state={Cell=value,Key=key}
                                    end
                                end
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
local function atlasToggle()
    return atlasAccess(atlasToggleRaw)
end
local atlasState
local function readAtlasState(cell)
    if cell then
        local value=rawget(cell.Cell,cell.Key)
        if type(value)=="boolean" then return value end
    end
end
local function atlasControl(timeout)
    local deadline=os.clock()+(timeout or 30)
    local lastError
    repeat
        local ok,b,cell,callback=pcall(atlasToggle)
        if ok and b and (cell or type(getconnections)~="function") then return b,cell,callback end
        lastError=ok and "Switch callback state is unreadable" or b
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
local function setAtlasRaw(value)
    local b,cell,callback=atlasControl()
    local current=readAtlasState(cell)
    if current==nil then current=atlasState end
    if current==nil then current=Config.AtlasInitiallyStopped end
    if current~=value then
        local ok
        if callback then ok=pcall(atlasAccess,callback) else ok=activate(b,callback) end
        assert(ok,"Could not activate Atlas Stop Everything on this executor")
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
local function setAtlas(value)
    return atlasAccess(setAtlasRaw,value)
end
local function acquire()
    checkStop()
    local function verifySpenders()
        if not atlasFarmOnly or not Config.AutoProgression then return end
        local ok,safe,why,rows=pcall(atlasAccess,atlasFarmOnly,true)
        Report.AtlasSpenderControls=ok and rows or nil
        if ok and safe then return end
        Report.AtlasControlError=tostring(ok and why or safe)
        assert(not env.FullHivePending and not env.AutoHivePendingRequest
            and not env.FullHiveUncertain and not env.AutoHiveUncertain
            and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
            "Atlas spending controls unavailable with unresolved work; state preserved")
        error(ATLAS_UNAVAILABLE,0)
    end
    if leased then
        assertAtlasPaused()
        verifySpenders()
        return
    end
    local available,button,cell=pcall(atlasControl)
    if not available then
        Report.AtlasControlError=tostring(button)
        error(ATLAS_UNAVAILABLE,0)
    end
    previousAtlas=readAtlasState(cell) or (atlasState ~= nil and atlasState or Config.AtlasInitiallyStopped)
    previousSettings={}
    for _,k in ipairs({"RollToGifted","RollToLegendary","RollToMythic","RollToMutation"}) do
        previousSettings[k]=(Cache:Get().Settings or {})[k]==true
    end
    -- Own the lease before toggling so failures also restore it.
    leased=true
    setAtlas(true)
    verifySpenders()
end
local function move(part,pickup)
    acquire(); checkStop()
    if cleanupMove then cleanupMove();cleanupMove=nil end
    if typeof(part)=="Vector3" then error("Full Hive movement requires a verified destination part") end
    assert(part and part:IsA("BasePart"),"Invalid movement destination")
    Report.Activity="Moving to "..part.Name
    local destination=part:GetFullName()
    local guild=destination=="Workspace.Badge Guild.Walls.Floor"
    local ticketShop=destination=="Workspace.Map.Buildings.Ticket Bee Shop.Floor"
    local blender=destination=="Workspace.Toys.Blender.Platform"
    local blueHQ=destination=="Workspace.Map.Ground.BlueHQShopFloor"
    local checkFloor=guild or ticketShop or blueHQ or destination=="Workspace.Shops.Mountaintop.FloorPart"
    local grounded=checkFloor or blender or destination=="Workspace.Shops.ProShop.Terrain"
    local r=root()
    -- Hive and Blender pads are rotated: local Size.Y is not their world height.
    local cf,size=part.CFrame,part.Size
    local height=math.abs(cf.RightVector.Y)*size.X/2+math.abs(cf.UpVector.Y)*size.Y/2
        +math.abs(cf.LookVector.Y)*size.Z/2
    local target=pickup and part.Position or part.Position+Vector3.new(0,height+3,0)
    Report.Movement={Destination=part:GetFullName(),Target=tostring(target),StartedAt=os.time(),
        Distance=(target-r.Position).Magnitude,Arrived=false}
    local attachment=Instance.new("Attachment"); attachment.Name="FullHiveAttachment"; attachment.Parent=r
    local align=Instance.new("AlignPosition")
    align.Name="FullHiveAlign"; align.Mode=Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0=attachment; align.MaxForce=1000000; align.MaxVelocity=Config.Speed
    align.ApplyAtCenterOfMass=true
    align.Responsiveness=45; align.Position=r.Position; align.Parent=r
    local orientation=Instance.new("AlignOrientation")
    orientation.Name="FullHiveOrientation"; orientation.Attachment0=attachment
    orientation.Mode=Enum.OrientationAlignmentMode.OneAttachment
    orientation.RigidityEnabled=true; orientation.CFrame=r.CFrame; orientation.Parent=r
    local movingHumanoid=r.Parent:FindFirstChildOfClass("Humanoid")
    local previousHumanoidState=movingHumanoid and type(movingHumanoid.GetState)=="function" and movingHumanoid:GetState()
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
        if cleanupMove==cleanup then cleanupMove=nil end
        if tween then tween:Cancel() end
        for _,connection in ipairs(connections) do connection:Disconnect() end
        align:Destroy(); orientation:Destroy(); attachment:Destroy()
        if previousHumanoidState and movingHumanoid.Parent and movingHumanoid.Health>0
            and type(movingHumanoid.ChangeState)=="function" then
            movingHumanoid:ChangeState(previousHumanoidState)
        end
        for p,v in pairs(collision) do if p.Parent then p.CanCollide=v end end
        if r.Parent then r.AssemblyLinearVelocity=Vector3.zero end
    end
    cleanupMove=cleanup
    local ok,err=pcall(function()
        if movingHumanoid and type(movingHumanoid.ChangeState)=="function" then
            movingHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
        -- Enable noclip before the first tween frame, and enroll accessories or
        -- other parts added during movement so cleanup restores their values.
        for _,container in ipairs(fences and {movingCharacter,fences} or {movingCharacter}) do
            connections[#connections+1]=container.DescendantAdded:Connect(enroll)
            for _,p in ipairs(descendants(container,"BasePart")) do enroll(p) end
        end
        connections[#connections+1]=game:GetService("RunService").PreSimulation:Connect(function()
            if not r.Parent then return end
            for p in pairs(collision) do if p.Parent then p.CanCollide=false end end
            local humanoid=movingCharacter:FindFirstChildOfClass("Humanoid")
            if humanoid and type(humanoid.Move)=="function" then humanoid:Move(Vector3.zero,false) end
        end)
        local params=RaycastParams.new()
        params.RespectCanCollide=true
        params.FilterDescendantsInstances={movingCharacter}
        local floorParams=params
        local doormat
        if ticketShop then
            doormat=part.Parent and part.Parent:FindFirstChild("Doormat")
            if doormat and not doormat:IsA("BasePart") then doormat=nil end
            floorParams=RaycastParams.new()
            floorParams.RespectCanCollide=true
            floorParams.FilterType=Enum.RaycastFilterType.Include
            floorParams.FilterDescendantsInstances=doormat and {part,doormat} or {part}
        end
        local function ticketSurface(hit)
            return hit and (hit.Instance==part or doormat and hit.Instance==doormat)
                and hit.Position.Y>=part.Position.Y+height-0.5
                and hit.Position.Y<=part.Position.Y+height+2
        end
        local function blocked(from,to)
            return workspace:Raycast(from,to-from,params)~=nil
        end
        local start=r.Position
        local function flightTo(goal)
            if not blocked(start,goal) then return {goal} end
            local waypoints
            local function overhead(clearance,offsets)
                local height=math.max(start.Y,goal.Y)+clearance
                local entries,exits={},{}
                for _,offset in ipairs(offsets) do
                    local lift=Vector3.new(start.X,height,start.Z)+offset
                    local above=Vector3.new(goal.X,height,goal.Z)+offset
                    if not blocked(start,lift) then entries[#entries+1]=lift end
                    if not blocked(above,goal) then exits[#exits+1]=above end
                end
                for _,lift in ipairs(entries) do
                    for _,above in ipairs(exits) do
                        if not blocked(lift,above) then
                            Report.Movement.DetourHeight=height
                            return {lift,above,goal}
                        end
                    end
                end
            end
            for _,clearance in ipairs({24,48,72}) do
                waypoints=overhead(clearance,{Vector3.zero})
                if waypoints then break end
            end
            if not waypoints then
                -- Try angled climbs and approaches when a roof or cliff
                -- blocks the direct climb, overhead leg or descent.
                local offsets={Vector3.zero}
                for _,width in ipairs({24,48,96}) do
                    offsets[#offsets+1]=Vector3.new(width,0,0)
                    offsets[#offsets+1]=Vector3.new(-width,0,0)
                    offsets[#offsets+1]=Vector3.new(0,0,width)
                    offsets[#offsets+1]=Vector3.new(0,0,-width)
                end
                for _,clearance in ipairs({24,48,72,120}) do
                    waypoints=overhead(clearance,offsets)
                    if waypoints then break end
                end
            end
            return waypoints
        end
        local waypoints
        local dapper=destination=="Workspace.Shops.DapperPlanterShop.Terrain"
        local bronze=destination=="Workspace.Toys.Bronze Star Amulet Generator.Platform"
        if dapper or bronze then
            local door
            if dapper then
                local gates=workspace:FindFirstChild("Gates")
                local gate=gates and gates:FindFirstChild("Dapper Shop")
                door=gate and gate:FindFirstChild("Door")
            else
                local decorations=workspace:FindFirstChild("Decorations")
                local hall=decorations and decorations:FindFirstChild("StarAmuletBuilding")
                door=hall and hall:FindFirstChild("Gate")
            end
            if door and door:IsA("BasePart") and (bronze or not door.CanCollide) then
                local forward=door.CFrame.LookVector
                local entrance=door.Position-Vector3.new(0,bronze and 9 or 0,0)
                local outside=entrance-forward*(bronze and 18 or 15)
                local inside=entrance+forward*(bronze and 18 or 12)
                if dapper then target=Vector3.new(part.Position.X,door.Position.Y,part.Position.Z) end
                if not blocked(outside,inside) and not blocked(inside,target) then
                    waypoints=flightTo(outside)
                    if waypoints then
                        waypoints[#waypoints+1]=inside
                        waypoints[#waypoints+1]=target
                        Report.Movement.Method=dapper and "dapper-entrance" or "star-hall-entrance"
                        Report.Movement.Target=tostring(target)
                        Report.Activity=dapper and "Moving to Dapper Bear's shop" or "Moving to the Bronze Star Amulet Generator"
                    end
                end
            end
        elseif not grounded then
            waypoints=flightTo(target)
        end
        local movement=Report.Movement
        local tweenService=game:GetService("TweenService")
        local function checkTravel()
            pauseCheckpoint()
            if characterRoot()~=r then error(CHARACTER_UNAVAILABLE,0) end
            assertAtlasPaused()
        end
        local function travel(points)
            for i,point in ipairs(points) do
                checkTravel()
                local tolerance=i==#points and (pickup and 0.75 or grounded and 1.5 or 4) or 2
                local segmentSpeed,deadline
                local function startSegment()
                    if tween then tween:Cancel() end
                    segmentSpeed=Config.Speed
                    align.MaxVelocity=segmentSpeed
                    align.Position=r.Position
                    local duration=math.max(0.2,(point-r.Position).Magnitude/segmentSpeed)
                    deadline=os.clock()+duration+15
                    movement.Speed=segmentSpeed
                    tween=tweenService:Create(align,TweenInfo.new(duration,Enum.EasingStyle.Linear),{Position=point})
                    tween:Play()
                end
                startSegment()
                local reached
                repeat
                    checkTravel()
                    movement.Distance=(target-r.Position).Magnitude
                    reached=(r.Position-point).Magnitude<=tolerance
                    if reached or os.clock()>=deadline then break end
                    if Config.Speed~=segmentSpeed then startSegment() end
                    task.wait(0.1)
                until false
                tween:Cancel()
                tween=nil
                if not reached then return false end
                align.Position=point
            end
            return true
        end
        local function groundedArrival()
            if distance(part)>(checkFloor and 5 or Config.NearDistance) then return false end
            if checkFloor then
                local localPosition=part.CFrame:PointToObjectSpace(r.Position)
                if math.abs(localPosition.X)>size.X/2 or math.abs(localPosition.Z)>size.Z/2 then return false end
            end
            local hit=workspace:Raycast(r.Position,Vector3.new(0,-5,0),floorParams)
            if ticketShop then
                return r.Position.Y>=part.Position.Y+height+1 and ticketSurface(hit)
            end
            return hit~=nil
        end
        if grounded then
            movement.Method="grounded-tween"
            if checkFloor and groundedArrival() then return end
            local side,depth=guild and 12 or 8,guild and 36 or ticketShop and 32 or 8
            local approaches=blender and {Vector3.zero,Vector3.new(8,0,0),Vector3.new(0,0,-8)}
                or {Vector3.zero,Vector3.new(-side,0,0),Vector3.new(side,0,0),
                    Vector3.new(0,0,-depth),Vector3.new(0,0,depth)}
            local attempted={}
            for index,offset in ipairs(approaches) do
                checkTravel()
                local probe=target+offset+Vector3.new(0,ticketShop and 3 or -2,0)
                local hit=workspace:Raycast(probe,Vector3.new(0,-(2*height+16),0),floorParams)
                if not hit then continue end
                if ticketShop and not ticketSurface(hit) then continue end
                local groundTarget=hit.Position+Vector3.new(0,3,0)
                if checkFloor then
                    local point=cf:PointToObjectSpace(groundTarget)
                    if math.abs(point.X)>size.X/2 or math.abs(point.Z)>size.Z/2 then continue end
                end
                if table.find(attempted,groundTarget) then continue end
                attempted[#attempted+1]=groundTarget
                movement.Route=index
                movement.Target=tostring(groundTarget)
                start=r.Position
                local route=flightTo(groundTarget) or {groundTarget}
                if travel(route) and groundedArrival() then return end
                movement.StalledAt=tostring(r.Position)
            end
            movement.Failure="No grounded tween approach worked"
            movement.RoutesExhausted=true
        elseif (dapper or bronze) and not waypoints then
            movement.Failure="No clear entrance route"
        else
            if not movement.Method then movement.Method=waypoints and "tween-route" or "direct-noclip-tween" end
            if travel(waypoints or {target}) then return end
            movement.Failure="Movement timed out"
        end
        movement.Position=tostring(r.Position)
        error(MOVEMENT_TIMEOUT,0)
    end)
    -- Keep every verified action landing stable across yielding stats and the
    -- final nearby check. Release/next move owns cleanup; pickups finish here.
    if (not ok or pickup) and cleanupMove then cleanupMove(); cleanupMove=nil end
    if not ok then error(err,0) end
    if not pickup or part.Parent then near(part) end
    Report.Movement.Arrived=true
    Report.LastMovementArrival=Report.Movement.Destination
    Report.Movement.Distance=pickup and (root().Position-target).Magnitude or distance(part)
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
    local desired={RollToGifted=name=="gifted",RollToLegendary=name=="legendary",RollToMythic=false,RollToMutation=false}
    local current=Cache:Get().Settings
    local matches=type(current)=="table"
    for key,value in pairs(desired) do if not current or (current[key]==true)~=value then matches=false end end
    if not matches then setSettings(desired) end
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
    Report.RollLeaseHeld=false
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
local function releaseIdle()
    if leased and (rollTask or basicLock) and not env.FullHiveStop and not Report.PauseRequested
        and not env.FullHivePending and not env.AutoHivePendingRequest
        and not env.FullHiveUncertain and not env.AutoHiveUncertain
        and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning and not Report.CleanupError then
        Report.RollLeaseHeld=true
        return
    end
    release()
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

local function hiveHoneyReserve(s)
    local reserve=Config.HoneyReserve
    if progression then
        local decision=progression.inspect(s)
        reserve=math.max(reserve,decision.reserveHoney or 0)
    end
    return reserve
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
    local usable=math.max(0,(s.Honey or 0)-hiveHoneyReserve(s))
    local used=starEggUses(s)
    local legendaryRoute
    if StarState then legendaryRoute=Policy.legendaryRoute(StarState.read(s),s.Eggs.Star or 0) end
    local retirements=background and background.hiveRetirements(s)or{}
    local quotaRolling=Policy.quotaRolling(Policy.snapshot(s,Types),{slots=slots,starUsed=used,questRetired=retirements})
    local normalRefill=quotaRolling and 50 or Policy.refill(slots)
    local collectorFallback=Policy.collectorRecovery(slots,1,usable,
        bought.RoyalJelly or 0,env.FullHiveCollectorFallback==true,jelly,normalRefill)
    local batch=activeJellyBatch(s)
    local bubbleMaskOwned=Packages and Packages.PlayerHas({Category="Accessory",Type="Bubble Mask"},s)==true
    -- Honey for the NEXT refill must not downgrade a batch already admitted.
    -- A full normal amount or affordable remaining top-up precedes recovery.
    -- Recheck the missing amount after each pack, not the cost of a new batch.
    if (batch and not batch.Recovery)
        or (bubbleMaskOwned and (s.Eggs.StarJelly or 0)>0 and #Policy.starJellyMissing(Policy.snapshot(s,Types))>0 and Policy.starJellyUpgradeTask(rollTask))
        or (env.FullHiveCollectorFallback~=true and jelly>=normalRefill) then
        collectorFallback=false
    end
    return {slots=slots,starUsed=used,jelly=jelly,honey=s.Honey or 0,legendaryChoice=legendaryChoice,legendaryRoute=legendaryRoute,nextFlexible=nextFlexible,
        questRetired=retirements,bubbleMaskOwned=bubbleMaskOwned,
        collectorFallback=collectorFallback,enforceGrowth=true,eggs=s.Eggs,
        canRefill30k=Config.AutoPurchase and usable>=Policy.jellyCost(bought.RoyalJelly or 0,30000)}
end
local function plan(s)
    local cells,slots=scan(s)
    local ctx=context(s,slots)
    local p=Policy.plan(cells,Types,ctx)
    Report.StarEggRoute=ctx.legendaryRoute
    -- The exception activates only when the actual Star handoff is funded,
    -- has a verified egg budget and still has a missing gifted Mythic outcome.
    local starEligible=slots>=44 and ctx.legendaryRoute=="eggs" and not Policy.hasCollectorUpgrade(cells)
        and(s.Honey or 0)>=(Config.StarEggHoney or 100000000000)
    local starCoverage=starEligible and StarState.coverage(cells,Types)
    if starEligible and StarState.budget(s,2)>0 and #starCoverage.missingMythics>0
        and Policy.count(cells,"Basic",true)>0 then
        ctx.starPrepare=true
        p=Policy.plan(cells,Types,ctx)
        local safe={};for _,c in ipairs(p.candidates)do safe[Policy.key(c)]=true end
        local space=StarState.slotPressure(cells,Types,safe,#starCoverage.missing+1)
        ctx.starReleased=space.shortfall==0 and space.released or{}
        p=Policy.plan(cells,Types,ctx)
        Report.StarSlotPressure={Needed=space.needed,Shortfall=space.shortfall,Released=space.released}
    else Report.StarSlotPressure=nil end
    if ctx.collectorFallback and #p.fallbackCandidates==0 then
        ctx.collectorFallback=false
        p=Policy.plan(cells,Types,ctx)
    end
    if not Config.DryRun then env.FullHiveCollectorFallback=p.collectorFallback or nil end
    if rollTask then
        local current
        for _,c in ipairs(cells) do if c.x==rollTask.x and c.y==rollTask.y then current=c; break end end
        local h=hive()
        local invalid=rollTask.Version~=2 or rollTask.Owner~=player.UserId or rollTask.Hive~=(h and h.Name)
            or rollTask.Job~=game.JobId
        local done,why,safe
        if not invalid and p.collectorFallback and current and Policy.isUsableCollector(current,cells,p)
            and not Policy.isRecoveryTask(rollTask) then
            done,why=true,"collector-held-during-recovery"
        elseif not invalid and p.collectorFallback and current and not Policy.isUsableCollector(current,cells,p)
            and Policy.rollTaskSafe(rollTask,current,cells,Types,p) then
            -- The existing coordinate stays leased, but an older gifted task
            -- must adopt recovery mode before its next request.
            rollTask.Mode,rollTask.Reason=Policy.recoveryMode(ctx.honey)
        end
        if not invalid and not done then done,why,safe=Policy.reconcileRollTask(rollTask,current,cells,Types,p) end
        if invalid or done then
            if why=="target-now-reserved" then
                assert(not env.FullHivePending and not env.AutoHivePendingRequest
                    and not env.FullHiveUncertain and not env.AutoHiveUncertain
                    and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                    "Reserved target has unresolved work; lease preserved")
                env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
            end
            Report.LastCompletedTarget={X=rollTask.x,Y=rollTask.y,Reason=invalid and "hive-or-stage-changed" or why}
            if invalid or not Policy.isRecoveryTask(rollTask) then
                env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
            end
            rollTask=nil; env.FullHiveRollTask=nil; Report.ActiveTarget=nil
        else
            if not safe then
                -- Preserve the unfinished coordinate and admission. A later
                -- fresh snapshot may make it usable; never spend or switch now.
                p.target=nil;p.reason="waiting-safe-roll-target";p.rollBlocked=true
                Report.RollTargetBlocked={X=rollTask.x,Y=rollTask.y,Reason="Target is currently unsafe"}
            else
                Report.RollTargetBlocked=nil
                p.target=current
                p.reason=rollTask.Reason
                p.mode=rollTask.Mode
                p.legendaryHunt=rollTask.LegendaryHunt==true
                if rollTask.DiscoveryMythic then p.complete=false end
                if Policy.isRecoveryTask(rollTask) and Policy.refill(slots)>100 then
                    p.collectorFallback=true; env.FullHiveCollectorFallback=true
                end
            end
            Report.ActiveTarget={X=rollTask.x,Y=rollTask.y,Reason=rollTask.Reason,StartedType=rollTask.StartedType}
        end
    end
    local admitted=activeJellyBatch(s)
    if admitted and admitted.Recovery and not p.collectorFallback and not rollTask and not Config.DryRun
        and not env.FullHivePending and not env.AutoHivePendingRequest
        and not env.FullHiveUncertain and not env.AutoHiveUncertain
        and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning then
        -- Close only after task reconciliation. Unsafe unfinished leases and
        -- unresolved receipts retain their exact admission until resolved.
        env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
    end
    if not rollTask then Report.RollTargetBlocked=nil end
    if p.quotaRolling then
        p.mode="off"
        if rollTask then rollTask.Mode="off"end
    end
    Report.CollectorFallback=p.collectorFallback
    Report.SafeNonCollector=#p.fallbackCandidates
    Report.NormalRefillAmount=p.quotaRolling and 50 or Policy.refill(slots)
    Report.RefillAmount=Policy.refillFor(slots,p.collectorFallback,p.quotaRolling)
    Report.RefillMode=p.quotaRolling and "force-quota-50" or p.collectorFallback and "fallback-100" or (slots==43 and "normal-2000" or "stage-refill")
    Report.StarJelly=s.Eggs.StarJelly or 0
    Report.StarJellyMissing=Policy.starJellyMissing(cells)
    Report.StarJellyUpgrade=false -- Only the eight missing gifted Rare/Epic failsafes admit Star Jelly.
    if Policy.singleJelly(cells) then
        p.mode="off"
        Report.RefillAmount=1;Report.RefillMode="single-jelly"
    end
    Report.JellyGoal={Stage=p.stage,Reason=p.reason,Mode=p.mode,HasTarget=p.target~=nil,
        Item=p.target and Policy.rollItem(cells,s.Eggs,p,rollTask),
        MissingFailsafes=Report.StarJellyMissing,FailsafeGoalsActive=p.failsafeGoalsActive,ForceQuotasReady=p.forceQuotasReady,LegendaryHunt=p.legendaryHunt}
    p._cells=cells
    return p,cells,slots
end
local function jellyBatchReady(s)
    local inventory=s.Eggs.RoyalJelly or 0
    if type(s.Honeycomb)=="table" and Policy.singleJelly(scan(s)) then
        env.FullHiveJellyBatch=nil;Report.JellyBatch=nil
        return inventory>0
    end
    local target=Report.RefillAmount
    if Report.RefillMode=="single-jelly" then
        plan(s);target=Report.RefillAmount
        if target==1 then return false end
    end
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
                StartedAt=os.time()}
            env.FullHiveJellyBatch=batch
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
    local reader=atlasValues
    assert(type(reader)=="function" and type(getconnections)=="function","Atlas spending controls cannot be verified on this executor")
    atlasFarmOnly=createAtlasProgressionControl({core=uiParent(),
        findLabels=function(text) return findText(uiParent(),text) end,
        window=function() return atlasWindow(uiParent()) end,
        upvalues=reader,connections=getconnections,activate=activate})
    local lastGateRefresh
    local shopGates={BlueHQ="Blue HQ Gate",BadgeBearersGuild="Badge Build Gate",DapperPlanterShop="Dapper Shop"}
    local function shopAccess(shop,s)
        local gateName=shopGates[shop]
        if not gateName then return nil end
        local gates=workspace:FindFirstChild("Gates")
        local gate=gates and gates:FindFirstChild(gateName)
        local requirements=gate and gate:FindFirstChild("Requirements")
        local door=gate and gate:FindFirstChild("Door")
        if not requirements or not door or not door:IsA("BasePart")
            or Reqs.Check(s,loadModule(requirements))~=true then return false end
        if door.CanCollide and (lastGateRefresh==nil or os.clock()-lastGateRefresh>=10)
            and not Config.DryRun then
            lastGateRefresh=os.clock()
            local manager=RS:FindFirstChild("GateManager")
            if manager then
                -- The game's own refresh checks the current stats for every gate.
                -- Newly discovered bees need not trigger that refresh immediately.
                loadModule(manager).UpdateGateColors()
            end
        end
        return not door.CanCollide
    end
    env.FullHiveMaterialFarm=env.FullHiveMaterialFarm or {}
    local function fieldAccess(callback,...)
        local getIdentity=getthreadidentity or getidentity
        local setIdentity=setthreadidentity or setidentity
        local previous=type(getIdentity)=="function" and getIdentity() or nil
        if type(setIdentity)=="function" then pcall(setIdentity,8) end
        local ok,result=pcall(callback,...)
        if previous and type(setIdentity)=="function" then pcall(setIdentity,previous) end
        Report.MaterialFarmError=not ok and tostring(result) or nil
        return ok and result or nil
    end
    local cachedFieldControl
    local function fieldControl()
        if cachedFieldControl and cachedFieldControl.Parent and MaterialFarm.isMainField(cachedFieldControl)then
            return cachedFieldControl
        end
        local roots={uiParent()}
        for _,tab in ipairs(atlasTabs(roots[1]))do roots[#roots+1]=tab end
        cachedFieldControl=MaterialFarm.mainFieldControl(roots)
        return cachedFieldControl
    end
    materialFarm=MaterialFarm.new({state=env.FullHiveMaterialFarm,
        occupied=function() return #scan(Cache:Get()) end,
        get=function()
            return fieldAccess(function()
            local control=fieldControl()
            return control and control.Text:match("^%s*Field:%s*(.-)%s*$")
            end)
        end,
        set=function(field)
            return fieldAccess(function()
            local control=fieldControl()
            if not control or type(getconnections)~="function" then return false end
            if control.Text:match("^%s*Field:%s*(.-)%s*$")==field then return true end
            local objects=MaterialFarm.fieldOptions(control)
            if not objects then return false end
            for _,button in ipairs(objects:GetChildren()) do
                if button:IsA("TextButton") and button.Text:match("^%s*(.-)%s*$")==field then
                    local connections=getconnections(button.MouseButton1Click)
                    if #connections~=1 then return false end
                    connections[1]:Fire()
                    local deadline=os.clock()+1
                    repeat
                        task.wait(0.05)
                    until control.Text:match("^%s*Field:%s*(.-)%s*$")==field or os.clock()>=deadline
                    return control.Text:match("^%s*Field:%s*(.-)%s*$")==field
                end
            end
            return false
            end)
        end,
        allowed=function(route)
            if not route.gate then return true end
            local gates=workspace:FindFirstChild("Gates")
            local gate=gates and gates:FindFirstChild(route.gate)
            local requirements=gate and gate:FindFirstChild("Requirements")
            return requirements and Reqs.Check(Cache:Get(),loadModule(requirements))==true
        end,
    })
    local makeFacts=createProgressionFacts({
        Policy=ProgressionPolicy,Packages=Packages,Recipes=Recipes,Reqs=Reqs,
        Accessories=Accessories,CellTools=CellTools,OsTime=OsTime,Shops=workspace:FindFirstChild("Shops"),
        Hive=hive,HoneyReserve=Config.HoneyReserve,UseBlenderTickets=function() return Config.UseBlenderTickets end,
        Uncertain=function() return env.FullHiveUncertain end,
        HiveRetirements=function(s) return background and background.hiveRetirements(s)or{}end,
        BlenderGoal=function()
            local goal=env.FullHiveBlenderGoal
            if type(goal)=="table"and goal.Owner==player.UserId and goal.Job==game.JobId then return goal end
        end,
        ShopAccess=shopAccess,
        PreviewModel=function(package)
            local definition
            if package.Category=="Accessory" then definition=Accessories.Get(package.Type)
            elseif package.Category=="Collector" then
                local folder=RS:FindFirstChild("CollectorModels")
                return folder and folder:FindFirstChild(package.Type)
            elseif package.Category=="Sprinkler" then
                local module=RS:FindFirstChild("Sprinklers")
                if module then definition=loadModule(module).Get(package.Type) end
            end
            return definition and definition.Model
        end,
    })
    local buffTiles=loadModule(waitForChild(waitForChild(waitForChild(RS,"Gui"),"TileDisplay"),"BuffTile"))
    local function nectarSeconds(name)
        local tile=buffTiles.GetBuffTile(name.." Nectar")
        if not tile then return 0 end
        if type(tile.TimerStart)~="number" or type(tile.TimerDur)~="number" then return nil end
        return math.max(0,tile.TimerStart+tile.TimerDur-OsTime())
    end
    local function buildFacts(s,includeRoute)
        local facts,catalog=makeFacts(s,includeRoute)
        local cells,capacity=scan(s)
        facts.discoveryPreparation=MythicDiscovery.unlocked(StarState.read(s),s,cells,capacity,env.AutoGiftedStarReport)
        if background and (s.Eggs.Gold or 0)>0 then
            facts.questGoldReserve=background.goldEggReserve(s)
        end
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
        if (facts.occupied or 0)>=30 and type(s.Treasures)=="table"
            and os.time()-(env.FullHiveDiamondTokenAttemptAt or 0)>=120 then
            local npcs=workspace:FindFirstChild("NPCs")
            local onett=npcs and npcs:FindFirstChild("Onett")
            local icon=EggTypes.Get("Diamond").Icon
            local token
            if onett and onett:IsA("Model") and type(icon)=="string" then
                local origin=onett:GetPivot().Position
                for _,folderName in ipairs({"Collectibles","TreasureCollectibles"}) do
                    local folder=workspace:FindFirstChild(folderName)
                    for _,part in ipairs(folder and folder:GetChildren() or {}) do
                        local front=part:FindFirstChild("FrontDecal")
                        if part:IsA("BasePart") and not part.CanCollide and front and front:IsA("Decal")
                            and front.Texture==icon and front.Transparency<0.5 and part:FindFirstChildOfClass("Sparkles") then
                            local delta=part.Position-origin
                            if delta.Y< -4 and delta.Y> -85 and delta.X^2+delta.Z^2<80^2 then
                                if token then return facts,catalog end -- Ambiguous token identity.
                                token=part
                            end
                        end
                    end
                end
            end
            if token then
                facts.conditions["onett-diamond-token"]=true
                catalog.sources.Diamond={kind="claim-token",id="onett-diamond-token",readyCondition="onett-diamond-token",part=token}
            end
        end
        return facts,catalog
    end
    progression=createProgression({
        Policy=ProgressionPolicy,Funds=ProgressionFunds,HatchReceipt=ProgressionHatchReceipt,
        BlenderReceipt=ProgressionBlenderReceipt,
        env=env,Report=Report,Config=Config,Events=Events,
        Packages=Packages,Recipes=Recipes,Reqs=Reqs,buildFacts=buildFacts,nectarSeconds=nectarSeconds,OsTime=OsTime,
        checkStop=checkStop,refresh=refresh,invoke=invoke,move=move,near=near,release=releaseIdle,
        invokeHatch=function(before,x,y,item)
            return invokeRequest(Events.ConstructHiveCellFromEgg,before,x,y,item,1,false)
        end,
        invokeSpeedup=function(before)
            return invokeRequest(Events.BlenderCommand,before,"SpeedUpOrder")
        end,
        invokeCancel=function(before)
            return invokeRequest(Events.BlenderCommand,before,"StopOrder")
        end,
        rememberBlenderGoal=function(action,order)
            env.FullHiveBlenderGoal={Owner=player.UserId,Job=game.JobId,Gear=action.gear,
                Recipe=order.Recipe,Count=order.Count,StartTime=order.StartTime}
        end,
        fixedShopPackage=function(...) return fixedShopPackage(...) end,
        customShopPackage=function(...) return customShopPackage(...) end,
        assertAtlasPaused=assertAtlasPaused,
        scan=scan,hiveFloor=hiveFloor,toyPart=progressionToyPart,jellyBatchSpent=jellyBatchSpent,
        Types=Types,
        materialFarm=function(s,decision)
            local missing=decision.farmMissing or decision.missingItems or {}
            materialFarm.update(Config.SuperMaterialFarm and not Config.DryRun,missing)
            local status=materialFarm.snapshot(Config.SuperMaterialFarm and not Config.DryRun,missing)
            status.held=status.item and ((s.Eggs or {})[status.item]or 0)or nil
            status.gear=decision.materialFarmGear or decision.gear
            Report.SuperMaterialFarm=status
            Report.MaterialFarm=env.FullHiveMaterialFarm.item
        end,
    })
    if createBackground then
        local crabSwitch=createAtlasSwitchControl({
            tables=function()
                assert(type(filtergc)=="function","Atlas switch API discovery unavailable")
                return filtergc("table",{Keys={"Auto Coconut Crab","Stop Everything"}},false)
            end,
            values=atlasValues,clock=os.clock,wait=task.wait,
            connections=getconnections,
            buttons=function(name)
                local roots={uiParent()};for _,tab in ipairs(atlasTabs(uiParent())) do roots[#roots+1]=tab end
                local buttons,seen={},{}
                for _,root in ipairs(roots) do
                    for _,label in ipairs(root:QueryDescendants('TextLabel[Text = "Auto Kill Coconut Crab"]')) do
                        local b=label.Parent
                        if b and b:IsA("TextButton") and not seen[b] then seen[b]=true;buttons[#buttons+1]=b end
                    end
                end
                return buttons
            end,
            isButton=function(v,name)
                if typeof(v)~="Instance" or not v:IsA("TextButton") or not v.Parent then return false end
                local title=v:FindFirstChild("Title")
                return title and title:IsA("TextLabel") and title.Text==name or false
            end,
            checked=function(button) return button.Text==utf8.char(10003) end,
        })
        background=createBackground({AmuletPolicy=AmuletPolicy,QuestPolicy=QuestAssistPolicy,
            env=env,Report=Report,Config=Config,RS=RS,player=player,load=loadModule,
            Events=Events,Reqs=Reqs,Packages=Packages,Funds=ProgressionFunds,
            checkStop=checkStop,refresh=refresh,invoke=invoke,move=move,near=near,release=releaseIdle,
            assertAtlasPaused=assertAtlasPaused,scan=scan,hiveFloor=hiveFloor,
            honeyReserve=hiveHoneyReserve,crabSwitch=crabSwitch,
            invokeFeed=function(before,...) return invokeRequest(Events.ConstructHiveCellFromEgg,before,...) end,
            shopFloor=function(name)return shopFloor(name)end,
            fixedShopPackage=function(...)return fixedShopPackage(...)end,
            customShopPackage=function(...)return customShopPackage(...)end,
            levelHoneyAllowed=function(s)
                local decision,facts,catalog=progression.inspect(s)
                if (decision.action.kind~="wait" and decision.action.kind~="hive") or decision.saveCraftingJelly or decision.savingGearHoney then return false end
                local capacity=facts.capacity
                if capacity and facts.occupied then
                    local target=facts.occupied<capacity and capacity or math.min(50,capacity+1)
                    local growth=ProgressionPolicy.growth(facts,catalog,target,decision.reserveHoney,decision.reservedItems)
                    if growth.kind~="wait" and growth.kind~="gate-ready" then return false end
                end
                return plan(s).target==nil
            end,jellyBatchSpent=jellyBatchSpent})
    end
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
local function spend(cell,item,validate,expectedTask,eventBee)
    checkStop(); acquire(); move(hiveFloor()); near(hiveFloor())
    local s=refresh()
    if progression and not (eventBee and progression.eventCurrency(s,"Ticket")~=nil
        or not eventBee and progression.allowsHive(s,item)) then release();return false end
    if not eventBee and background and not background.allowsHive(s) then release();return false end
    local p,cells=plan(s)
    local current=find(cells,cell)
    if not current or not validate(current,cells,p,s) then
        if expectedTask or eventBee then release();return false end -- Unsent; replan safely.
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
        if (Policy.singleJelly(cells) or p.quotaRolling) and (settings.RollToGifted or settings.RollToLegendary
            or settings.RollToMythic or settings.RollToMutation) then
            mode("off");return false
        end
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
    -- A newly rolled surplus normal Fuzzy may sort before the retained copy.
    -- The existing task guard explicitly permits repairing this exact slot;
    -- its response check must honor the same exception, keeping every other
    -- protected coordinate and the last/sole gifted Fuzzy protected.
    local releasedFuzzy=expectedTask and rollTask==expectedTask
        and Policy.fuzzyRollRelease(expectedTask,current,cells,Types,p)==true
    local rollBefore={Kind="roll",Inventory=before,Item=item,X=current.x,Y=current.y,Cells={},ReleasedFuzzy=releasedFuzzy==true}
    for _,c in ipairs(cells) do
        rollBefore.Cells[#rollBefore.Cells+1]={x=c.x,y=c.y,Type=c.bee.Type,Birth=c.bee.Birth,Gifted=Policy.gifted(c),Protected=p.protected[Policy.key(c)]==true}
    end
    local requestStarted=os.clock()
    local remaining,accepted,comb,discovered,eggUses=invokeRequest(Events.ConstructHiveCellFromEgg,rollBefore,current.x,current.y,item,1,false)
    assert(accepted and type(remaining)=="number" and type(comb)=="table","Item response rejected or uncertain; no retry")
    Cache:Set({"Eggs",item},remaining); Cache:Set("Honeycomb",comb)
    if discovered then Cache:Set("DiscoveredBees",discovered) end
    if eggUses then Cache:Set({"Totals","EggUses"},eggUses) end
    local consumed=before-remaining
    assert(consumed>=1 and consumed<=before,"Unknown item consumption")
    if item~="RoyalJelly" or Policy.singleJelly(cells) or p.quotaRolling then assert(consumed==1,"Unexpected item consumption") end
    Report.Actions=Report.Actions+1
    if item=="RoyalJelly" then
        Report.RoyalJellyUsed=Report.RoyalJellyUsed+consumed
        jellyBatchSpent(remaining)
    end
    local b=assert(comb["x"..cell.x] and comb["x"..cell.x]["y"..cell.y],"Result bee missing")
    if eventBee then assert(b.Type==eventBee,"Event Bee placement uncertain; no retry") end
    Report.LastResult={X=cell.x,Y=cell.y,Type=b.Type,Gifted=table.find(b.Traits or {},"Gifted")~=nil,Item=item,Consumed=consumed}
    if env.FullHiveUncertain then
        env.FullHiveUncertain.RollResult={Accepted=true,Remaining=remaining,Consumed=consumed,Type=b.Type,Gifted=Report.LastResult.Gifted}
    end
    if expectedTask and rollTask==expectedTask then
        rollTask.Rolled=true
        env.FullHiveRollTask=rollTask
    end
    -- Every protected Event/Mythic is checked after every request. A Star Treat may add Gifted.
    for _,old in ipairs(cells) do
        local temporaryHatch=Policy.key(old)==Policy.key(current) and p.temporary[Policy.key(old)] and EggTypes.Get(item).TrueEgg
        local authorizedFuzzy=Policy.key(old)==Policy.key(current) and releasedFuzzy
        if p.protected[Policy.key(old)] and not temporaryHatch and not authorizedFuzzy then
            local after=comb["x"..old.x] and comb["x"..old.x]["y"..old.y]
            assert(after and after.Type==old.bee.Type and (not Policy.gifted(old) or table.find(after.Traits or {},"Gifted")),"Protected bee changed")
        end
    end
    if Report.LastResult.Gifted and (b.Type=="Bubble" or b.Type=="Frosty") then nextFlexible=b.Type end
    if env then env.FullHiveUncertain=nil end -- Response/delta/hive protection verified.
    if item=="RoyalJelly" then
        local remainingDelay=Policy.rollWait(requestStarted,os.clock(),Config.RollDelay)
        Report.RollTiming={Elapsed=os.clock()-requestStarted,ExtraWait=remainingDelay,MinimumInterval=math.max(0.3,Config.RollDelay)}
        if remainingDelay>0 then task.wait(remainingDelay) else task.wait() end
    else task.wait(Config.RollDelay) end
    return b
end
shopFloor=function(name)
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
customShopPackage=function(item,amount,shopName)
    assert((item=="RoyalJelly" and shopName=="JellyDispenser") or (item=="Treat" and shopName=="TreatShop"),"Unsupported custom quantity item")
    assert(type(amount)=="number" and amount>0 and amount%1==0 and amount<=999999999999999,"Invalid custom quantity")
    local pkg=fixedShopPackage(item,1,shopName)
    pkg.Amount=amount
    return pkg
end
local function buy(item,amount,shop,inventoryCeiling,validatePurchase)
    assert(Config.AutoPurchase,"Purchasing disabled")
    acquire(); move(shopFloor(shop)); near(shopFloor(shop))
    local s=refresh()
    if validatePurchase then
        -- Event purchases revalidate their own ticket and gear priority rules.
        if not validatePurchase(s) then release();return false end
    elseif (progression and not progression.allowsHive(s)) or (background and not background.allowsHive(s)) then
        release();return false
    end
    local before=s.Eggs[item] or 0
    if inventoryCeiling then
        if before>=inventoryCeiling then return false end
        amount=inventoryCeiling-before
    end
    local usable=math.max(0,(s.Honey or 0)-hiveHoneyReserve(s))
    if item=="RoyalJelly" then
        local _,cells=plan(s)
        if not Policy.canBuyRollJelly(cells) then release();return false end
        if inventoryCeiling~=Report.RefillAmount or usable<Policy.jellyCost(royalJellyPurchases(s),inventoryCeiling-before) then return false end
    elseif item=="Basic" then
        assert(amount==1,"Basic purchases must remain separate")
        if usable<10000000 then return false end
    elseif item~="Gumdrops" and item~="Ticket" then
        local cost=EggTypes.Get(item).TicketCost
        if type(cost)~="number" or (s.Eggs.Ticket or 0)<cost*amount then return false end
    end
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    local fixedPackage=item=="RoyalJelly" and customShopPackage(item,amount,shop) or fixedShopPackage(item,amount,shop)
    if item=="Ticket" then
        assert(shop=="TicketDispenser" and amount==500 and validatePurchase,"Unverified Star Treat ticket purchase")
    end
    if item=="RoyalJelly" then
        local quote=Packages.GetCost(fixedPackage,s)
        local requirements=Packages.PurchaseRequirements(fixedPackage,s)
        if not quote or quote.Category~="Honey" or quote.Amount~=Policy.jellyCost(royalJellyPurchases(s),amount)
            or not Packages.CanPurchase(fixedPackage,s) or not Packages.CanGive(fixedPackage,s)
            or (requirements and not Reqs.Check(s,requirements)) then release();return false end
    end
    local ticketBefore=s.Eggs.Ticket or 0
    if item=="Gumdrops" then
        local cost=Packages.GetCost(fixedPackage,s)
        if type(cost)~="table" or cost.Category~="Eggs" or cost.Type~="Ticket"
            or cost.Amount~=amount/3 or (s.Eggs.Ticket or 0)<cost.Amount then release();return false end
    end
    local accepted=invoke(Events.ItemPackageEvent,"Purchase",fixedPackage)
    assert(accepted,"Purchase rejected; no retry")
    s=refresh()
    assert((s.Eggs[item] or 0)-before==amount,"Purchase inventory uncertain; no retry")
    if item=="Gumdrops" then
        assert(ticketBefore-(s.Eggs.Ticket or 0)==amount/3,"Gumdrop ticket debit uncertain; no retry")
    elseif item=="Ticket" then
        local receipt=assert(env.FullHiveUncertain and env.FullHiveUncertain.TicketBefore,"Ticket purchase baseline missing")
        local bought=((((s.Totals or {}).Purchases or {}).Eggs or {}).Ticket or 0)
        assert(bought==receipt.Purchased+amount,"Ticket purchase counter uncertain; no retry")
    end
    env.FullHiveUncertain=nil
    Report.Actions=Report.Actions+1; Report.LastPurchase={Item=item,Amount=amount}
    return s
end
local function refill()
    local s=refresh()
    if progression and not progression.allowsHive(s) then return false end
    local _,cells=plan(s)
    if jellyBatchReady(s) then return true end
    if not Policy.canBuyRollJelly(cells) then return false end
    local target=Report.RefillAmount
    local inventory=s.Eggs.RoyalJelly or 0
    local missing=target-inventory
    if not Config.AutoPurchase or (s.Honey or 0)-hiveHoneyReserve(s)
        <Policy.jellyCost(royalJellyPurchases(s),missing) then return false end
    local fallback=Report.CollectorFallback==true
    Report.Activity="Refilling Royal Jelly to "..target.." before starting a batch"
    while true do
        pauseCheckpoint(); s=refresh()
        local _,freshCells=plan(s)
        if not Policy.canBuyRollJelly(freshCells) then return false end
        if Report.RefillAmount~=target or (Report.CollectorFallback==true)~=fallback then return false end
        inventory=s.Eggs.RoyalJelly or 0
        if inventory>=target then break end
        missing=target-inventory
        local cost=Policy.jellyCost(royalJellyPurchases(s),missing)
        if s.Honey-hiveHoneyReserve(s)<cost then return false end
        if buy("RoyalJelly",missing,"JellyDispenser",target)==false then return false end
    end
    local ready=jellyBatchReady(s)
    if ready then move(hiveFloor()) end
    return ready
end
local function eventAction(s,cells,p)
    local function safe(c,plan)
        local key=Policy.key(c)
        return not plan.keep[key] and not plan.protected[key]
            and not (rollTask and Policy.key(rollTask)==key) and not (basicLock and Policy.key(basicLock)==key)
    end
    local target
    local canPlace=not rollTask and not basicLock
    for _,c in ipairs(p.candidates) do if safe(c,p) then target=c; break end end
    local normalEvent
    for _,name in ipairs({"Tabby","Vicious","Festive","Cobalt","Puppy","Gummy"}) do
        for _,c in ipairs(cells) do
            if c.bee.Type==name and not Policy.gifted(c) then normalEvent=c; break end
        end
        if normalEvent then break end
    end
    if not normalEvent then
        for _,c in ipairs(cells) do
            local info=Types and Types[c.bee.Type]
            if info and info.Rarity=="Event" and not Policy.gifted(c) then normalEvent=c;break end
        end
    end
    if canPlace and normalEvent and (s.Eggs.StarTreat or 0)>0 then
        mode("off")
        if spend(normalEvent,"StarTreat",function(c) return Types[c.bee.Type].Rarity=="Event" and not Policy.gifted(c) end)~=false then
            return true
        end
    end
    local order={"Tabby","Gummy","Festive","Cobalt","Vicious","Puppy"}
    for _,name in ipairs(order) do
        local egg=name.."Bee"
        if Policy.count(cells,name)==0 then
            if (s.Eggs[egg] or 0)>0 then
                local hatched,_,empty
                if progression then hatched,_,empty=progression.hatchEvent(s,egg,name) end
                if hatched then return true end
                if target and not empty and (not progression or progression.eventCurrency(s,"Ticket")~=nil) then
                    mode("off")
                    if spend(target,egg,function(c,freshCells,fresh,freshStats)
                        return (freshStats.Eggs[egg] or 0)>0 and Policy.count(freshCells,name)==0 and safe(c,fresh)
                    end,nil,name)~=false then return true end
                end
            end
            -- Jelly ownership indicates a previously acquired unique bee; do not rebuy it.
            local owned=(s.Eggs[egg] or 0)>0 or (s.Eggs[egg.."Jelly"] or 0)>0
            if not owned and Config.AutoPurchase then
                local function canBuy(fresh,currency,cost)
                    return (fresh.Eggs[currency] or 0)>=cost and (fresh.Eggs[egg] or 0)==0
                        and (fresh.Eggs[egg.."Jelly"] or 0)==0 and Policy.count(scan(fresh),name)==0
                        and (not progression or progression.allowsEventPurchase(fresh,currency,cost))
                end
                if name=="Vicious" or name=="Gummy" then
                    local currency=name=="Gummy" and "Gumdrops" or "Stinger"
                    local cost=name=="Gummy" and 2500 or 250
                    if canBuy(s,currency,cost) then
                        local toys=assert(workspace:FindFirstChild("Toys"),"Toys not loaded")
                        local toy=assert(toys:FindFirstChild(name.." Bee Claimer"),"Event Bee claimer not loaded")
                        move(toy.Platform); near(toy.Platform)
                        s=refresh()
                        if not canBuy(s,currency,cost) then release();return false end
                        assert(Report.Actions<Config.MaxActions,"Action limit reached")
                        assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain,
                            "Unresolved request before the Event Bee claim")
                        local balance=s.Eggs[currency] or 0
                        local receipt={Name="ToyEvent",Kind="claim-event-bee",Item=egg,Amount=1,Started=os.clock()}
                        env.FullHiveUncertain=receipt
                        Events.ToyEvent:FireServer(toy.Name)
                        local deadline=os.clock()+8
                        repeat task.wait(0.25); s=refresh() until (s.Eggs[egg] or 0)>0 or os.clock()>deadline
                        assert((s.Eggs[egg] or 0)==1 and balance-(s.Eggs[currency] or 0)==cost,"Event Bee purchase uncertain; no retry")
                        env.FullHiveUncertain=nil
                        Report.LastPurchase={Item=egg,Amount=1}
                        Report.Actions=Report.Actions+1; return true
                    end
                    if name=="Gummy" then
                        local function pack(fresh)
                            local gumdrops=fresh.Eggs.Gumdrops or 0
                            local tickets=fresh.Eggs.Ticket or 0
                            if progression then
                                gumdrops=progression.eventCurrency(fresh,"Gumdrops")
                                tickets=progression.eventCurrency(fresh,"Ticket")
                                if gumdrops==nil or tickets==nil then return nil end
                            end
                            if (fresh.Eggs[egg] or 0)>0 or (fresh.Eggs[egg.."Jelly"] or 0)>0
                                or Policy.count(scan(fresh),name)>0 then return nil end
                            return Policy.eventGumdropPack(gumdrops,tickets)
                        end
                        local amount=pack(s)
                        if amount and buy("Gumdrops",amount,"GumdropDispenser",nil,
                            function(fresh) return pack(fresh)==amount end)~=false then return true end
                    end
                else
                    local cost=assert(EggTypes.Get(egg).TicketCost,"Unknown ticket cost")
                    if canBuy(s,"Ticket",cost) then
                        return buy(egg,1,"TicketShop",nil,function(fresh) return canBuy(fresh,"Ticket",cost) end)~=false
                    end
                    -- Save tickets for the next ticket-only bee.
                    return false
                end
            end
        end
    end
    if normalEvent then
        if not Config.AutoPurchase or not canPlace or (s.Eggs.StarTreat or 0)>0 then return false end
        local name=normalEvent.bee.Type
        local function available(fresh)
            if (fresh.Eggs.StarTreat or 0)>0 then return nil end
            local cells=scan(fresh)
            if Policy.count(cells,name)==0 or Policy.count(cells,name,true)>0 then return nil end
            if progression then return progression.eventCurrency(fresh,"Ticket") end
            return fresh.Eggs.Ticket or 0
        end
        local tickets=available(s)
        if not tickets then return false end
        if tickets>=1000 then
            return buy("StarTreat",1,"TicketShop",nil,function(fresh) return (available(fresh) or 0)>=1000 end)~=false
        end
        local function fund(fresh,spendable)
            if not spendable or spendable>=1000 then return false end
            if progression then
                local d=progression.inspect(fresh)
                if d.saveCraftingJelly or d.savingGearHoney or d.requiredTickets then return false end
            end
            local pkg=fixedShopPackage("Ticket",500,"TicketDispenser")
            local quote=Packages.GetCost(pkg,fresh)
            local req=Packages.PurchaseRequirements(pkg,fresh)
            local star=Config.AutoAmulets and AmuletPolicy and AmuletPolicy.starTarget(#(fresh.DiscGiftTypes or {}),(fresh.Amulets or {}).Star)
            local honey=(fresh.Honey or 0)-hiveHoneyReserve(fresh)-(star and star.price or 0)
            return quote and quote.Category=="Honey" and type(quote.Amount)=="number" and quote.Amount>0
                and honey>=quote.Amount and Packages.CanPurchase(pkg,fresh) and Packages.CanGive(pkg,fresh)
                and (not req or Reqs.Check(fresh,req))
        end
        if fund(s,tickets) then
            return buy("Ticket",500,"TicketDispenser",nil,function(fresh) return fund(fresh,available(fresh)) end)~=false
        end
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
    if not Policy.basicSlotSafe(basicLock,current,p) then
        assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain
            and not env.AutoHiveUncertain,"Gifted Basic slot changed with an unresolved request")
        local replacement=Policy.basicReplacement(p)
        if not replacement then return false end
        basicLock.x,basicLock.y=replacement.x,replacement.y
        basicLock.NeedsJelly=false
        env.FullHiveJellyBatch=nil; Report.JellyBatch=nil
        current=replacement
    end
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
                pauseCheckpoint()
                local current=refresh()
                if (current.Honey or 0)-hiveHoneyReserve(current) < 10000000 then return false end
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
local function discoverySnapshot(s)
    local cells=scan(s)
    local decision=progression and progression.inspect(s) or {}
    return MythicDiscovery.plan(s,cells,Types,decision),cells,decision
end
local function mythicDiscoveryStep(s,p)
    if not Report.Progression or not Report.Progression.DiscoveryPreparation then return false end
    local action,cells,decision=discoverySnapshot(s)
    Report.MythicDiscovery={Action=action.kind,Reason=action.reason,Type=action.name,Item=action.item,
        Amount=action.amount,MaterialsReady=decision.queueMaterialsReady}
    if rollTask and not rollTask.DiscoveryMythic or basicLock then return false end
    if action.kind=="wait" then
        if rollTask and rollTask.DiscoveryMythic then return true,action.reason end
        return false
    end
    if action.kind=="complete" then return false end
    if action.kind=="acquire" then
        if rollTask then return false end
        local target=p.candidates[1]
        if not target then return false end
        -- Ordinary admission, spending and keep rules own these single rolls.
        p.target=target;p.reason="ssa-mythic-acquire";p.mode="off";p.complete=false
        p.discoveryMythic=action.name
        ensureRollTask(p)
        return false
    end
    if rollTask then return false end
    if action.kind=="fund-star-treat" then
        if not Config.AutoPurchase then return true,"Star Treat purchasing is disabled" end
        local function eligible(fresh)
            local a,_,d=discoverySnapshot(fresh)
            if a.kind~="fund-star-treat" or a.name~=action.name or d.saveCraftingJelly or d.savingGearHoney then return nil end
            return progression and progression.eventCurrency(fresh,"Ticket") or fresh.Eggs.Ticket or 0
        end
        local tickets=eligible(s)
        if tickets==nil then return false end
        if tickets>=1000 then
            return buy("StarTreat",1,"TicketShop",nil,function(fresh)return (eligible(fresh) or -1)>=1000 end)~=false
        end
        local function funded(fresh)
            local available=eligible(fresh)
            if available==nil or available>=1000 then return false end
            local package=fixedShopPackage("Ticket",500,"TicketDispenser")
            local quote=Packages.GetCost(package,fresh)
            local req=Packages.PurchaseRequirements(package,fresh)
            local star=Config.AutoAmulets and AmuletPolicy.starTarget(#(fresh.DiscGiftTypes or {}),(fresh.Amulets or {}).Star)
            return quote and quote.Category=="Honey" and type(quote.Amount)=="number" and quote.Amount>0
                and (fresh.Honey or 0)-hiveHoneyReserve(fresh)-(star and star.price or 0)>=quote.Amount
                and Packages.CanPurchase(package,fresh) and Packages.CanGive(package,fresh)
                and (not req or Reqs.Check(fresh,req))
        end
        if funded(s) then return buy("Ticket",500,"TicketDispenser",nil,funded)~=false end
        return true,"Saving honey for the next 500-ticket Star Treat pack"
    end
    if action.kind~="feed" then return false end
    mode("off");acquire();move(hiveFloor());near(hiveFloor())
    s=refresh()
    local freshAction,freshCells=discoverySnapshot(s)
    if freshAction.kind~="feed" or freshAction.name~=action.name or freshAction.item~=action.item
        or freshAction.amount~=action.amount or freshAction.x~=action.x or freshAction.y~=action.y then release();return false end
    assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain and not env.AutoHiveUncertain,
        "Unresolved request before Mythic feeding")
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    local baseline=MythicDiscovery.feedBaseline(s,freshCells,freshAction)
    near(hiveFloor());assertAtlasPaused()
    Report.Phase="mythic-discovery";Report.Activity="Feeding "..action.amount.." "..action.item.." to "..action.name
    local remaining,accepted,comb=invokeRequest(Events.ConstructHiveCellFromEgg,baseline,action.x,action.y,action.item,action.amount,false)
    local receipt=assert(env.FullHiveUncertain,"Feeding receipt missing")
    local after=refresh()
    local valid,consumed,gifted=MythicDiscovery.validateFeed(baseline,remaining,accepted,comb,after)
    assert(valid,"Mythic feeding uncertain; no retry: "..tostring(consumed))
    assert(env.FullHiveUncertain==receipt,"Feeding receipt changed")
    env.FullHiveUncertain=nil;Report.Actions+=1
    Report.LastMythicFeed={Type=action.name,Item=action.item,Consumed=consumed,Gifted=gifted,At=os.time()}
    release();return true
end
local function starReady(s,cells)
    Report.StarEggDeferred=nil
    local history=StarState.read(s)
    if Policy.legendaryRoute(history,s.Eggs.Star or 0)~="eggs" or Policy.hasCollectorUpgrade(cells) then return false end
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
    if progression and (not progression.allowsHive(s)
        or hiveHoneyReserve(s)>Config.HoneyReserve) then release();return false end
    local cells=scan(s)
    if not starReady(s,cells) then release();return false end
    local used=starEggUses(s)
    -- Shared Star Egg workflow is embedded with reviewed host integration hooks.
    local budget=StarState.budget(s,Config.MaxActions-Report.Actions)
    assert(budget>0,"No qualified Star Egg budget")
    env.FullHiveStarBudget=budget
    env.FullHiveMove=function(part) move(part or hiveFloor()) end
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
local function waitFor(reason,seconds)
    Report.Phase="waiting"; Report.Activity=reason
    release(); task.wait(seconds or Config.PollSeconds)
end
local function run()
    pauseCheckpoint()
    local s=refresh()
    while not env.FullHiveStop do
        pauseCheckpoint()
        if Report.Actions>=Config.MaxActions or Report.RoyalJellyUsed>=Config.MaxRoyalJellies then break end
        s=Cache:Get()
        if background and Config.AutoAmulets and background.offers(s) then s=refresh();continue end
        if not Config.DryRun then
            local available,button,state=pcall(atlasToggle)
            if not available or not button or (not state and type(getconnections)=="function") then
                Report.AtlasControlError=not available and tostring(button) or "Switch callback state is not readable"
                waitFor("Waiting for Atlas Stop Everything switch",math.min(Config.PollSeconds,0.5))
                s=refresh()
                continue
            end
            Report.AtlasControlError=nil
        end
        if not hive() then waitFor("Waiting for Atlas to claim a hive"); s=refresh(); continue end
        if background and background.consumables(s)then s=refresh();continue end
        if progression then
            local did,why=progression.step(s)
            if did then
                if Config.DryRun then Report.Phase="dry-run";return end
                if why then
                    if background and background.vicious(s) then s=refresh();continue end
                    local eventPlan,eventCells=plan(s)
                    if eventAction(s,eventCells,eventPlan) then s=refresh();continue end
                    if background and background.questGold(s) then s=refresh();continue end
                    waitFor(why)
                end
                s=refresh(); continue
            end
        end
        if background then
            if background.vicious(s) then s=refresh();continue end
            if background.questGold(s) then s=refresh();continue end
            local did,why=background.step(s)
            if did then if why then waitFor(why)end;s=refresh();continue end
        end
        local p,cells,slots=plan(s)
        Report.Stage,Report.Slots,Report.Bees,Report.Needs=p.stage,slots,#cells,p.needs
        Report.Growth=p.growth
        Report.CapacityStatus=p.capacityStatus
        Report.RoyalJelly,Report.Honey=s.Eggs.RoyalJelly or 0,s.Honey
        Report.DiscoveredGiftedTypes=FeatherWindUI.giftedDiscoveryCount(s,Types)
        Report.Counts={Baby=Policy.count(cells,"Baby"),Music=Policy.count(cells,"Music"),Shy=Policy.count(cells,"Shy"),
            Tadpole=Policy.count(cells,"Tadpole"),Buoyant=Policy.count(cells,"Buoyant"),
            GiftedTadpole=Policy.count(cells,"Tadpole",true),GiftedBuoyant=Policy.count(cells,"Buoyant",true)}
        Report.StarEggsUsed=starEggUses(s)
        Report.StarEggUsesKnown=StarState.usage(s).known
        Report.SafeSlots=#p.candidates
        Report.NextTarget=p.target and {X=p.target.x,Y=p.target.y,Type=p.target.bee.Type} or nil
        if Config.DryRun then Report.Phase="dry-run"; return end
        if eventAction(s,cells,p) then s=refresh();continue end
        if Report.Growth.Empty>0 then
            if progression and progression.grow(s,math.min(50,math.max(25,slots))) then s=refresh();continue end
            if not Report.Growth.CanReroll then
                waitFor("Waiting for an affordable Basic Egg to hatch the first bee")
                s=refresh();continue
            end
        end
        if progression and Config.AutoPurchase and Report.Growth.Empty==0 and slots<50
            and progression.grow(s,slots+1) then s=refresh();continue end
        local discoveryDid,discoveryWhy=mythicDiscoveryStep(s,p)
        if discoveryDid then if discoveryWhy then waitFor(discoveryWhy) end;s=refresh();continue end
        if p.complete then
            if background and background.level(s,true) then s=refresh();continue end
            if background and(Config.AutoAmulets or Config.AutoQuestAssist)then
                waitFor("Hive complete; monitoring amulets and active quests");s=refresh();continue
            end
            Report.Phase="endgame-complete"; Report.Activity="Final hive requirements reached"; return
        end
        local item=Policy.rollItem(cells,s.Eggs,p,rollTask)
        local savingCraftingJelly=Report.Progression and Report.Progression.SavingCraftingJelly
        if savingCraftingJelly and (item~="StarJelly" or not p.target) then
            waitFor("Saving Royal Jelly for "..tostring(Report.Progression.Gear))
            s=refresh();continue
        end
        env.FullHiveStarted=true
        if basicLock and not p.starter and not savingCraftingJelly then
            if giftedBasic(s,cells,p) then continue end
            if basicLock then waitFor("Waiting for honey or jelly for the locked Basic slot"); s=refresh(); continue end
        end
        -- A current slot finishes before another hive task claims a slot.
        if not rollTask and not p.starter and not savingCraftingJelly then
            if giftedBasic(s,cells,p) then continue end
            if starReady(s,cells) then Report.Phase="star-eggs"; useStarScript(s); continue end
        end
        if not p.target then
            if background and background.level(s,true) then s=refresh();continue end
            local reason=p.rollBlocked and "Waiting for a safe roll target; protected bees are held"
                or p.stage=="final" and p.growth.Empty>0
                and ("Checking funds to fill "..p.growth.Empty.." empty hive cells; current bees are held")
                or p.capacityStatus.Conflict and ("Kept bees and current targets require at least "
                    ..p.capacityStatus.Minimum.." cells; capacity is "..slots)
                or "Targets held; waiting for Atlas, inventory, or Star Egg prerequisites"
            waitFor(reason); s=refresh(); continue
        end
        if item=="RoyalJelly" and not (jellyBatchReady(s) or refill()) then
            if background and background.level(s,false) then s=refresh();continue end
            local gear=Report.Progression
            waitFor(gear and gear.AllMaterialDeferred and next(gear.CraftingBlocked or {})
                and "Crafting blocked; see Progression for recipe requirements"
                or gear and gear.SavingGearHoney and ("Saving honey for "..gear.Gear)
                or not Policy.canBuyRollJelly(cells) and "Waiting for owned Royal Jelly to roll"
                or ("Waiting for at least "..Report.RefillAmount.." Royal Jelly to start a batch"))
            s=refresh(); continue
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
local function runWithCharacterRecovery()
    local movementRetries={}
    local statsRecoveryUsed=false
    while true do
        local ok,err=pcall(run)
        if ok then return end
        if err==ATLAS_UNAVAILABLE then
            assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain
                and not env.AutoHiveUncertain and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                "Atlas controls unavailable with unresolved work")
            release()
            assert(not leased and not env.FullHiveAtlasOwned and not Report.CleanupError,
                "Atlas controls unavailable with failed cleanup")
            waitFor("Waiting for Atlas controls; amulet offers remain active")
            continue
        end
        if err==PAUSE_REQUESTED then
            release()
            local function assertSafe()
                assert(not env.FullHivePending and not env.AutoHivePendingRequest
                    and not env.FullHiveUncertain and not env.AutoHiveUncertain
                    and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning
                    and not env.FullHiveAtlasOwned and not Report.CleanupError,
                    "Pause/resume blocked by unresolved work or cleanup failure")
            end
            assertSafe()
            Report.Phase="paused"; Report.Activity="Assist paused. Use Controls to resume."
            while Report.PauseRequested do
                checkStop()
                task.wait(0.25)
            end
            checkStop()
            assertSafe()
            Report.Phase="resuming"; Report.Activity="Refreshing player stats before continuing"
            continue
        end
        if err==STATS_READ_TIMEOUT then
            local request=env.FullHivePending
            local readPending=request==nil or(type(request)=="table"and request.Name=="RetrievePlayerStats")
            assert(not statsRecoveryUsed,"Player stats read timed out again; stopped without replaying any spend")
            assert(readPending and not env.AutoHivePendingRequest and not env.FullHiveUncertain
                and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                "Player stats read timed out with an unresolved workflow; pending state preserved")
            release()
            assert(not env.FullHiveAtlasOwned,"Atlas release failed during stats recovery")
            statsRecoveryUsed=true
            Report.StatsReadRecoveries=(Report.StatsReadRecoveries or 0)+1
            Report.Phase="waiting-stats-read";Report.Activity="Waiting for the previous stats read to finish"
            -- Never overlap the original request or clear its flag. Only its
            -- completion callback may release it. A stuck read stops after60s.
            for _=1,240 do
                checkStop()
                assert(not env.AutoHivePendingRequest and not env.FullHiveUncertain
                    and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                    "Workflow changed during stats recovery; pending state preserved")
                if not env.FullHivePending then break end
                assert(env.FullHivePending==request,"Pending request changed during stats recovery")
                task.wait(0.25)
            end
            assert(not env.FullHivePending,"Previous stats read is still pending; no overlapping retry")
            checkStop()
            assert(not env.AutoHivePendingRequest and not env.FullHiveUncertain
                and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                "Workflow changed after stats recovery; pending state preserved")
            Report.Phase="stats-recovered";Report.Activity="Refreshing player stats before continuing"
            continue
        end
        -- Never replay an uncertain request or an embedded Star Egg workflow.
        local movementTimeout=err==MOVEMENT_TIMEOUT
        local message=movementTimeout and "Movement timed out; no action sent from the failed movement" or err
        if (err~=CHARACTER_UNAVAILABLE and not movementTimeout) or env.FullHivePending or env.AutoHivePendingRequest
            or env.FullHiveUncertain or env.AutoHiveUncertain
            or env.FullHiveStarRunning or env.AutoGiftedStarRunning then error(message,0) end
        release()
        assert(not env.FullHiveAtlasOwned,"Atlas release failed during character recovery")
        if movementTimeout then
            assert(not Report.CleanupError,"Movement cleanup failed")
            local arrived=Report.LastMovementArrival
            if arrived then movementRetries[arrived]=nil end
            Report.LastMovementArrival=nil
            local movement=Report.Movement or {}
            local destination=movement.Destination or "destination"
            local attempts=math.min(4,(movementRetries[destination] or 0)+1)
            movementRetries[destination]=attempts
            local delay=({2,10,30,60})[attempts]
            Report.MovementRecoveries=(Report.MovementRecoveries or 0)+1
            Report.LastMovementFailure=Report.Movement
            local retryShop=destination=="Workspace.Badge Guild.Walls.Floor" and "Badge Guild"
                or destination=="Workspace.Map.Buildings.Ticket Bee Shop.Floor" and "Ticket Tent"
                or destination=="Workspace.Shops.Mountaintop.FloorPart" and "Mountaintop shop"
                or destination=="Workspace.Toys.Blender.Platform" and "Blender"
                or destination=="Workspace.Map.Ground.BlueHQShopFloor" and "Blue HQ"
                or destination=="Workspace.Shops.ProShop.Terrain" and "Pro Shop"
            local waitForNewOrigin=movement.RoutesExhausted and retryShop
            Report.Phase="waiting-movement"
            Report.Activity=waitForNewOrigin and ("Waiting for a new approach to the "..retryShop)
                or string.format("Travel blocked at %s. Retrying in %ds",destination:match("[^.]+$") or destination,delay)
            local originalRoot=waitForNewOrigin and characterRoot()
            local origin=originalRoot and originalRoot.Position
            local seconds=0
            repeat
                checkStop()
                if Report.PauseRequested then break end
                assert(not env.FullHivePending and not env.AutoHivePendingRequest
                    and not env.FullHiveUncertain and not env.AutoHiveUncertain
                    and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,
                    "Workflow changed during travel recovery; pending state preserved")
                task.wait(1)
                seconds+=1
                local current=origin and characterRoot()
            until seconds>=delay and (not current or current~=originalRoot or (current.Position-origin).Magnitude>=32)
        else
            Report.RespawnRecoveries=(Report.RespawnRecoveries or 0)+1
            Report.Phase="waiting-character"; Report.Activity="Waiting for the character to respawn"
            repeat checkStop(); task.wait(0.25) until characterRoot()
        end
        checkStop()
        -- run() refreshes server stats and revalidates the existing coordinate
        -- lease before another action. Counters and verified purchases survive.
        Report.Phase=movementTimeout and "movement-recovered" or "character-recovered"
        Report.Activity="Refreshing hive data before continuing"
    end
end
local function makeStatusGui()
    local pg=waitForChild(player,"PlayerGui")
    local old=pg:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local parent=uiParent()
    old=parent:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local gui=Instance.new("ScreenGui"); gui.Name="FullHiveStatus"; gui.ResetOnSpawn=false; gui.DisplayOrder=10000; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=parent
    return gui,parent
end
local function readUIStatus()
    local c=Report.Counts or {}
    local progress=Report.Stage=="early" and string.format("Baby %d/4 | Music %d/4 | Shy %d/3",c.Baby or 0,c.Music or 0,c.Shy or 0)
        or string.format("Actions %d | Jelly used %d",Report.Actions,Report.RoyalJellyUsed)
    local active=Report.ActiveTarget
    if active then
        progress=string.format("Slot (%d,%d) | %s",active.X,active.Y,
            Report.CollectorFallback and (active.Reason=="gifted-collector-fallback" and "100-jelly gifted recovery" or "100-jelly collector recovery") or active.Reason)
    end
    local pg=Report.Progression or {}
    local status=pg.Status or {}
    local title=pg.Gear and ("Target: "..pg.Gear) or pg.AllMaterialDeferred and "Waiting for material drops or unlocks"
        or pg.DeferredRequirementGear and next(pg.DeferredRequirementGear)and "Waiting for gear unlocks"or"Gear route complete"
    local lines={title}
    lines[#lines+1]=status.label or pg.Reason or pg.Action or "Inspecting gear"
    if pg.Gear then
        local requirements=FeatherWindUI.describeGear(pg,true):match("^[^\n]*\n(.*)$")
        if requirements then lines[#lines+1]=requirements end
    end
    if pg.FundsRequired and(pg.MissingRJ or pg.RequiredTickets)then
        local function money(n)
            if n>=1000000000 then return string.format("%.2fB",n/1000000000) end
            if n>=1000000 then return string.format("%.1fM",n/1000000) end
            return tostring(math.floor(n))
        end
        local missing=pg.RequiredTickets and(pg.RequiredTickets.." tickets")or(pg.MissingRJ.." jelly")
        lines[#lines+1]="Need "..missing.." | Honey "..money(pg.Honey or 0).."/"..money(pg.FundsRequired)
    end
    local blender=Report.Blender
    if blender and blender.Recipe then
        lines[#lines+1]="Blender: "..blender.Recipe.." x"..tostring(blender.Count).." | "
            ..(blender.Complete and "ready to collect" or math.ceil(blender.RemainingSeconds or 0).."s left")
    end
    local bg=Report.Background or {}
    local slots=tostring(Report.Slots or "?").." slots"
    local jelly=tostring(Report.RoyalJelly or 0).." jelly"
    local refill=tostring(Report.RefillAmount or "-").." / refill"
    local giftedTypes
    if Cache and Types then
        local ok,stats=pcall(function()return Cache:Get()end)
        if ok then giftedTypes=FeatherWindUI.giftedDiscoveryCount(stats,Types) end
    end
    return {
        giftedTypes=giftedTypes,
        mythicDiscovery=pg.DiscoveryPreparation and not pg.QueueMaterialsReady and "Preparing combined gear materials"
            or Report.MythicDiscovery and (Report.MythicDiscovery.Reason or (Report.MythicDiscovery.Action.." · "..tostring(Report.MythicDiscovery.Type or ""))),
        phase=string.upper((Report.Stage or "inspect").."  |  "..(Report.Phase or "starting")),
        activity=tostring(Report.RestartError or Report.Error or Report.CleanupError
            or (Report.PauseRequested and Report.Phase~="paused" and env.FullHiveRunning and "Pausing after the current action...")
            or Report.Activity or Report.Phase),
        progress=progress,gear=table.concat(lines,"\n"),
        gearTarget=FeatherWindUI.describeGear(pg),
        gearQueues=FeatherWindUI.describeQueues(pg),
        materialFarm=FeatherWindUI.describeMaterialFarm(Report.SuperMaterialFarm,
            Config.SuperMaterialFarm and not Config.DryRun,Report.PauseRequested or not env.FullHiveRunning),
        jellyGoal=FeatherWindUI.describeJelly(Report.JellyGoal),
        nextSlot=FeatherWindUI.describeSlot(Report.Slots,Report.NextHiveSlotPrice),
        background="Amulets: "..tostring(bg.Amulet or "Inspecting").."\nQuest assist: "..tostring(bg.Quest or "Inspecting")
            .."\nVicious: "..tostring(bg.Vicious or "Waiting for Mother Bear completion")
            .."\nAtlas Coconut Crab: "..tostring(bg.CoconutCrab or "Waiting for Vicious level 12"),
        slots=slots,jelly=jelly,refill=refill,metrics=slots.."  |  "..jelly.."  |  "..refill,
        finished=not env.FullHiveRunning,
        enabled=not Report.PauseRequested and env.FullHiveRunning,
    }
end
local function watchUI(gui,render)
    task.spawn(function()
        while gui.Parent do
            local state=readUIStatus()
            render(state)
            if state.finished then break end
            task.wait(0.75)
        end
    end)
end
local function setAssistEnabled(enabled)
    if env.FullHiveRunning and not env.FullHiveStop then
        Report.PauseRequested=not enabled
        saveSettings()
    end
end
local function setBlenderTickets(enabled)
    Config.UseBlenderTickets=enabled
    env.FullHiveConfig=env.FullHiveConfig or {}
    env.FullHiveConfig.UseBlenderTickets=enabled
    saveSettings()
end
local function setSuperMaterialFarm(enabled)
    Config.SuperMaterialFarm=enabled==true
    env.FullHiveConfig=env.FullHiveConfig or {}
    env.FullHiveConfig.SuperMaterialFarm=Config.SuperMaterialFarm
    saveSettings()
    if not enabled and materialFarm and not materialFarmBusy then materialFarm.restore() end
end
local function hiveSnapshot()
    if not Cache or not Types then return nil end
    return Cache:Get(),Types,Report.ActiveTarget
end
local function makeUI()
    local gui,parent=makeStatusGui()
    local openHive,openRoute
    local function routeSnapshot()
        if not progression or not Cache then return nil end
        local route=progression.route(Cache:Get());route.hiveStage=Report.Stage
        return route
    end
    local wind,windError=FeatherWindUI.mount(parent,gui,SCRIPT_VERSION,{
        routeSnapshot=routeSnapshot,
        viewRoute=function()if openRoute then openRoute()end end,
        reexecute=function()
            task.spawn(function()
                local ok,why=pcall(function()
                    assert(not env.FullHiveReloadBusy,"A restart is already in progress")
                    local source=game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/start.luau?reload="..tostring(os.time()),true)
                    assert(compile(source))()
                end)
                if not ok then Report.RestartError=tostring(why);warn("[Feather restart] "..tostring(why)) end
            end)
        end,
        viewHive=function() if openHive then openHive() end end,
        assistEnabled=function() return not Report.PauseRequested end,
        setAssistEnabled=setAssistEnabled,
        ticketsEnabled=function() return Config.UseBlenderTickets end,
        setTickets=setBlenderTickets,
        materialFarmEnabled=function() return Config.SuperMaterialFarm end,
        setMaterialFarm=setSuperMaterialFarm,
        tweenSpeed=function() return Config.Speed/10 end,
        setTweenSpeed=function(value)
            value=tonumber(value)
            if type(value)~="number" or value~=value then return end
            Config.Speed=math.clamp(math.floor(value),1,40)*10
            env.FullHiveConfig=env.FullHiveConfig or {}
            env.FullHiveConfig.Speed=Config.Speed
            Report.TweenSpeed=Config.Speed/10
            Report.MovementSpeed=Config.Speed
            saveSettings()
        end,
    })
    if wind then
        gui:SetAttribute("FeatherRenderer","WindUI")
        openHive=createHiveView(gui,wind.showWindow,nil,hiveSnapshot)
        openRoute=createRouteDashboard.mount(gui,wind.showWindow,routeSnapshot,FeatherWindUI.describeRouteGear,wind.openRouteList)
        FeatherWindUI.mountToggle(parent,gui,wind.syncVisibility)
        watchUI(gui,wind.render)
    else
        Report.UIWarning=windError
        gui:SetAttribute("FeatherRenderer","Unavailable")
        warn("[Full Hive] WindUI unavailable: "..windError)
        FeatherWindUI.mountToggle(parent,gui)
    end
    gui:SetAttribute("FeatherVersion",SCRIPT_VERSION)
end
local function startMaterialFarmBackground()
    materialFarmThread=task.spawn(function()
        local setIdentity=setthreadidentity or setidentity
        if type(setIdentity)=="function" then pcall(setIdentity,8) end
        while env.FullHiveRunning and not env.FullHiveStop do
            Report.MaterialFarmBackgroundAt=os.time()
            if not Report.PauseRequested and progression
                and (Config.SuperMaterialFarm or env.FullHiveMaterialFarm.previous) then
                materialFarmBusy=true
                local worked,why=pcall(function() progression.materials(Cache:Get()) end)
                materialFarmBusy=false
                Report.MaterialFarmWorkerError=not worked and tostring(why) or nil
            end
            task.wait(Config.PollSeconds)
        end
    end)
end
local ok,err=xpcall(function()
    initializePlayer()
    makeUI()
    initializeModules()
    initializeProgression()
    startMaterialFarmBackground()
    runWithCharacterRecovery()
end,function(e) return tostring(e) end)
release()
if materialFarmThread then pcall(task.cancel,materialFarmThread);materialFarmBusy=false end
if materialFarm then pcall(materialFarm.restore) end
if not ok then
    Report.Phase=stoppedByUser and "stopped" or "error"
    if not stoppedByUser then Report.Error=err; warn("[Full Hive] "..err) end
end
env.FullHiveRunning=false

