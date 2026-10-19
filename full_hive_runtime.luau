-- Bundled by build_full_hive.ps1 after Policy and StarEggSource.
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
    AtlasInitiallyStopped=false, StartupDelaySeconds=60}
for k,v in pairs(env.FullHiveConfig or {}) do assert(Config[k] ~= nil, "Unknown config: "..k); Config[k]=v end
if env.FullHiveRunning then warn("[Full Hive] Already running") return end
assert(not env.AutoGiftedStarRunning, "Stop the other hive assist before starting Full Hive")
assert(not env.AutoHivePendingRequest and not env.FullHivePending, "A previous server request is pending")
env.FullHiveRunning, env.FullHiveStop = true, false
env.FullHivePreviousReport = env.FullHiveReport
local Report = {Phase="starting", Actions=0, RoyalJellyUsed=0, DryRun=Config.DryRun,StartedAt=os.time()}
env.FullHiveReport = Report
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local player, Events, Cache, Types, EggTypes
local leased, previousAtlas, previousSettings, cleanupMove = false, nil, nil, nil
local lateStarted = env.FullHiveLateStarted == true
local basicLock = env.FullHiveBasicLock
local rollTask = env.FullHiveRollTask
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
end
local function invoke(remote, ...)
    checkStop()
    assert(not env.FullHivePending and not env.AutoHivePendingRequest, "Server request already pending")
    local args = table.pack(...)
    local request = {Name=remote.Name, Started=os.clock()}
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
local function refresh()
    local s=invoke(Events.RetrievePlayerStats)
    assert(type(s)=="table" and type(s.Eggs)=="table", "Stats unavailable")
    for _,k in ipairs({"Honey","Eggs","Totals","Honeycomb","Settings","Quests"}) do
        if s[k]~=nil then Cache:Set(k,s[k]) end
    end
    return s
end
local function royalJellyPurchases(s)
    local totals=s.Totals or {}
    local purchases=totals.Purchases or {}
    local eggs=purchases.Eggs or {}
    return eggs.RoyalJelly or 0
end
local function starEggUses(s)
    local totals=s.Totals or {}
    local uses=totals.EggUses or {}
    return uses.Star or 0
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
local function root()
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    assert(h and h.Health>0,"Character unavailable")
    return assert(c:FindFirstChild("HumanoidRootPart"),"Character root unavailable")
end
local function distance(part)
    local p=root().Position
    local localPos=part.CFrame:PointToObjectSpace(p)
    local half=part.Size/2
    local closest=Vector3.new(math.clamp(localPos.X,-half.X,half.X),math.clamp(localPos.Y,-half.Y,half.Y),math.clamp(localPos.Z,-half.Z,half.Z))
    return (localPos-closest).Magnitude
end
local function near(part) assert(distance(part)<=Config.NearDistance,"Too far from "..part:GetFullName()) end
local function atlasToggle()
    local coreGui = game:GetService("CoreGui")
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
                            if state then return b,state,c.Function end
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
end
local function move(part)
    acquire(); checkStop()
    if typeof(part)=="Vector3" then error("Full Hive movement requires a verified destination part") end
    assert(part and part:IsA("BasePart"),"Invalid movement destination")
    Report.Activity="Moving to "..part.Name
    if distance(part)<=5 then return end
    local r=root()
    local target=part.Position+Vector3.new(0,part.Size.Y/2+3,0)
    local attachment=Instance.new("Attachment"); attachment.Name="FullHiveAttachment"; attachment.Parent=r
    local align=Instance.new("AlignPosition")
    align.Name="FullHiveAlign"; align.Mode=Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0=attachment; align.MaxForce=1000000; align.MaxVelocity=Config.Speed
    align.Responsiveness=45; align.Position=r.Position; align.Parent=r
    local collision={}
    local noclipParts={}
    for _,p in ipairs(descendants(r.Parent,"BasePart")) do noclipParts[#noclipParts+1]=p end
    local map=workspace:FindFirstChild("Map")
    local fences=map and map:FindFirstChild("Fences")
    if fences then for _,p in ipairs(descendants(fences,"BasePart")) do noclipParts[#noclipParts+1]=p end end
    local connection=game:GetService("RunService").Stepped:Connect(function()
        if not r.Parent then return end
        for _,p in ipairs(noclipParts) do
            if collision[p]==nil then collision[p]=p.CanCollide end
            p.CanCollide=false
        end
    end)
    local tween=game:GetService("TweenService"):Create(align,TweenInfo.new(math.max(0.2,(target-r.Position).Magnitude/Config.Speed),Enum.EasingStyle.Linear),{Position=target})
    local cleaned=false
    local function cleanup()
        if cleaned then return end
        cleaned=true; tween:Cancel(); connection:Disconnect(); align:Destroy(); attachment:Destroy()
        for p,v in pairs(collision) do if p.Parent then p.CanCollide=v end end
        if r.Parent then r.AssemblyLinearVelocity=Vector3.zero end
    end
    cleanupMove=cleanup
    tween:Play()
    local deadline=os.clock()+(target-r.Position).Magnitude/Config.Speed+15
    local ok,err=pcall(function()
        while (r.Position-target).Magnitude>4 do
            checkStop(); assert(r.Parent and os.clock()<deadline,"Movement timed out")
            assertAtlasPaused()
            task.wait(0.1)
        end
    end)
    cleanup(); cleanupMove=nil
    assert(ok,err)
    near(part)
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
    local cells={}
    for x,col in pairs(s.Honeycomb or {}) do
        local nx=tonumber(tostring(x):match("^x(%d+)$"))
        if nx and type(col)=="table" then for y,b in pairs(col) do
            local ny=tonumber(tostring(y):match("^y(%d+)$"))
            if ny and type(b)=="table" and b.Type then cells[#cells+1]={x=nx,y=ny,bee=b} end
        end end
    end
    table.sort(cells,function(a,b) if a.y~=b.y then return a.y<b.y end return a.x<b.x end)
    local slots=25+((s.Totals and s.Totals.Purchases and s.Totals.Purchases.HiveSlots) or 0)
    return cells,math.max(slots,#cells)
end
local function context(s,slots)
    local stage=Policy.stage({slots=slots,starUsed=starEggUses(s)})
    local jelly=s.Eggs.RoyalJelly or 0
    if slots>=44 and jelly>=10000 then lateStarted=true; env.FullHiveLateStarted=true end
    local bought=s.Totals and s.Totals.Purchases and s.Totals.Purchases.Eggs or {}
    local usable=math.max(0,(s.Honey or 0)-Config.HoneyReserve)
    local used=s.Totals and s.Totals.EggUses and s.Totals.EggUses.Star or 0
    local collectorFallback=stage=="mid" and Policy.collectorRecovery(slots,1,usable,
        bought.RoyalJelly or 0,env.FullHiveCollectorFallback==true)
    return {slots=slots,starUsed=used,jelly=jelly,lateStarted=lateStarted,nextFlexible=nextFlexible,
        collectorFallback=collectorFallback,
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
    if rollTask then
        local current
        for _,c in ipairs(cells) do if c.x==rollTask.x and c.y==rollTask.y then current=c; break end end
        local h=hive()
        local invalid=rollTask.Version~=2 or rollTask.Owner~=player.UserId or rollTask.Hive~=(h and h.Name)
            or rollTask.Job~=game.JobId
        local done,why
        if not invalid then done,why=Policy.rollTaskDone(rollTask,current,cells,Types,p) end
        if invalid or done then
            Report.LastCompletedTarget={X=rollTask.x,Y=rollTask.y,Reason=invalid and "hive-or-stage-changed" or why}
            rollTask=nil; env.FullHiveRollTask=nil; Report.ActiveTarget=nil
        else
            assert(Policy.rollTaskSafe(rollTask,current,cells,Types,p),"Active roll slot became a force slot; stopped before switching")
            p.target=current
            p.reason=rollTask.Reason
            p.mode=rollTask.Mode
            if rollTask.Reason=="collector-fallback" and slots==43 then
                p.collectorFallback=true; env.FullHiveCollectorFallback=true
            end
            Report.ActiveTarget={X=rollTask.x,Y=rollTask.y,Reason=rollTask.Reason,StartedType=rollTask.StartedType}
        end
    end
    Report.CollectorFallback=p.collectorFallback
    Report.SafeNonCollector=#p.fallbackCandidates
    Report.RefillMode=p.collectorFallback and "fallback-100" or (slots==43 and "normal-2000" or "stage-refill")
    p._cells=cells
    return p,cells,slots
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
    local s=refresh(); local p,cells=plan(s)
    local current=find(cells,cell)
    if not current or not validate(current,cells,p,s) then
        if expectedTask then return false end -- No request sent: replan safely.
        error("Target disappeared or became protected",0)
    end
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    local before=s.Eggs[item] or 0
    assert(before>0,"No "..item)
    if item=="RoyalJelly" then
        assert(Report.RoyalJellyUsed<Config.MaxRoyalJellies,"Royal Jelly limit reached")
        local settings=s.Settings or {}
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
    if item=="RoyalJelly" then Report.RoyalJellyUsed=Report.RoyalJellyUsed+consumed end
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
local function buy(item,amount,shop)
    assert(Config.AutoPurchase,"Purchasing disabled")
    acquire(); move(shopFloor(shop)); near(shopFloor(shop))
    local before=refresh().Eggs[item] or 0
    assert(Report.Actions<Config.MaxActions,"Action limit reached")
    local accepted=invoke(Events.ItemPackageEvent,"Purchase",{Category="Eggs",Type=item,Amount=amount})
    assert(accepted,"Purchase rejected; no retry")
    local s=refresh()
    assert((s.Eggs[item] or 0)-before==amount,"Purchase inventory uncertain; no retry")
    Report.Actions=Report.Actions+1; Report.LastPurchase={Item=item,Amount=amount}
    return s
end
local function refill(entryTopup)
    local s=refresh(); local _,slots=scan(s)
    local fallback=env.FullHiveCollectorFallback == true and slots == 43
    local target,pack=Policy.refillFor(slots,fallback)
    -- A refill starts only at zero, and a partial completed refill is not topped up repeatedly.
    if not entryTopup and (s.Eggs.RoyalJelly or 0)>0 then return true end
    if entryTopup and (s.Eggs.RoyalJelly or 0)>=10000 then return true end
    local inventoryGoal=(entryTopup and (s.Eggs.RoyalJelly or 0) or 0)+target
    local bought=royalJellyPurchases(s)
    if not Config.AutoPurchase or (s.Honey or 0)-Config.HoneyReserve<Policy.jellyCost(bought,target) then return false end
    Report.RefillMode=fallback and "fallback-100" or (slots==43 and "normal-2000" or "stage-refill")
    Report.Activity=fallback and "Buying one 100-jelly fallback pack" or "Refilling Royal Jelly"
    for _=1,target/pack do
        checkStop(); s=refresh()
        if (s.Eggs.RoyalJelly or 0)>=inventoryGoal then break end
        local cost=Policy.jellyCost(royalJellyPurchases(s),pack)
        if s.Honey-Config.HoneyReserve<cost then break end
        buy("RoyalJelly",pack,"JellyDispenser")
    end
    move(hiveFloor())
    return (Cache:Get().Eggs.RoyalJelly or 0)>0
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
                        assert(Report.Actions<Config.MaxActions,"Action limit reached")
                        Events.ToyEvent:FireServer(toy.Name)
                        local deadline=os.clock()+8
                        repeat task.wait(0.25); s=refresh() until (s.Eggs.ViciousBee or 0)>0 or os.clock()>deadline
                        assert((s.Eggs.ViciousBee or 0)>0,"Vicious purchase uncertain; no retry")
                        Report.Actions=Report.Actions+1; return true
                    end
                else
                    local cost=assert(EggTypes.Get(egg).TicketCost,"Unknown ticket cost")
                    if (s.Eggs.Ticket or 0)>=cost then buy(egg,1,"TicketShop"); return true end
                    -- Save tickets for the next bee; only Vicious can be skipped.
                    return false
                end
            end
        end
    end
    if normalEvent then
        if Config.AutoPurchase and (s.Eggs.Ticket or 0)>=1000 then buy("StarTreat",1,"TicketShop"); return true end
    end
    return false
end
local function giftedBasic(s,cells,p)
    if Policy.count(cells,"Basic",true)>0 then basicLock=nil; env.FullHiveBasicLock=nil; return false end
    local _,slots=scan(s)
    if slots<40 or (not basicLock and (s.Honey or 0)<3000000000) then return false end
    if not basicLock then
        local c=p.candidates[1]
        if not c then return false end
        basicLock={x=c.x,y=c.y,BasicBatchTarget=10,BasicBatchPurchased=0}
        env.FullHiveBasicLock=basicLock
    end
    basicLock.BasicBatchTarget=basicLock.BasicBatchTarget or 10
    basicLock.BasicBatchPurchased=basicLock.BasicBatchPurchased or 0
    local current=assert(find(cells,basicLock),"Gifted Basic locked slot missing")
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
                buy("Basic",1,"EggDispenser")
                basicLock.BasicBatchPurchased=basicLock.BasicBatchPurchased+1
                env.FullHiveBasicLock=basicLock
            end
            move(hiveFloor())
            return true
        end
    end
    if jelly==0 and not refill() then return false end
    mode("off")
    local function locked(c)
        local r=Types[c.bee.Type].Rarity
        return Policy.key(c)==Policy.key(basicLock) and r~="Event" and r~="Mythic" and not (c.bee.Type=="Basic" and Policy.gifted(c))
    end
    if not basicLock.NeedsJelly then
        spend(basicLock,"Basic",locked)
        basicLock.NeedsJelly=true
    else
        spend(basicLock,"RoyalJelly",locked)
        basicLock.NeedsJelly=false
    end
    return true
end
local function starReady(s,cells)
    if Config.MaxActions < math.huge or Config.MaxRoyalJellies < math.huge then
        Report.StarEggDeferred="Existing Star Egg workflow requires an unlimited progression run"
        return false
    end
    local _,slots=scan(s)
    if slots<44 or s.Honey<Config.StarEggHoney or (s.Eggs.Star or 0)==0 then return false end
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
    local used=starEggUses(s)
    -- Existing Star Egg workflow is embedded unchanged, with integration hooks at build time.
    env.FullHiveStarBudget=math.min(2-used,Config.MaxActions-Report.Actions)
    env.FullHiveMove=function() move(hiveFloor()) end
    env.FullHiveRefill=refill
    env.FullHiveNear=function() near(hiveFloor()) end
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
    assert(ok,err); assert(not env.AutoGiftedStarError,env.AutoGiftedStarError)
    s=refresh(); assert((s.Eggs.Star or 0)<before,"Star Egg workflow made no progress")
    Report.Actions=Report.Actions+before-(s.Eggs.Star or 0)
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
        local p,cells,slots=plan(s)
        Report.Stage,Report.Slots,Report.Bees,Report.Needs=p.stage,slots,#cells,p.needs
        Report.RoyalJelly,Report.Honey=s.Eggs.RoyalJelly or 0,s.Honey
        Report.Counts={Baby=Policy.count(cells,"Baby"),Music=Policy.count(cells,"Music"),Shy=Policy.count(cells,"Shy"),
            Tadpole=Policy.count(cells,"Tadpole"),Buoyant=Policy.count(cells,"Buoyant"),
            GiftedTadpole=Policy.count(cells,"Tadpole",true),GiftedBuoyant=Policy.count(cells,"Buoyant",true)}
        Report.StarEggsUsed=starEggUses(s)
        Report.SafeSlots=#p.candidates
        Report.NextTarget=p.target and {X=p.target.x,Y=p.target.y,Type=p.target.bee.Type} or nil
        if Config.DryRun then Report.Phase="dry-run"; return end
        if p.complete then Report.Phase="endgame-complete"; Report.Activity="Final hive requirements reached"; return end
        local fallbackReady=p.collectorFallback and slots==43
        if #cells==0 or ((s.Eggs.RoyalJelly or 0)==0 and Report.Actions==0 and not env.FullHiveStarted and not fallbackReady) then
            waitFor("Waiting for at least one bee and one Royal Jelly"); s=refresh(); continue
        end
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
        if slots>=44 and not lateStarted then
            if Config.AutoPurchase and refill(true) and (Cache:Get().Eggs.RoyalJelly or 0)>=10000 then continue end
            waitFor("Waiting for 10,000 Royal Jelly to enter the legendary stage"); s=refresh(); continue
        end
        if not p.target then waitFor("Targets held; waiting for Atlas, inventory, or Star Egg prerequisites"); s=refresh(); continue end
        if (s.Eggs.RoyalJelly or 0)==0 and not refill() then
            waitFor("Waiting for enough honey for the stage refill"); s=refresh(); continue
        end
        Report.Phase="rolling"; Report.Activity=p.reason
        local item=p.stage=="early" and (s.Eggs.StarJelly or 0)>0 and "StarJelly" or "RoyalJelly"
        ensureRollTask(p)
        local fallbackMode=p.collectorFallback or Report.CollectorFallback or p.reason=="collector-fallback"
        mode(item=="StarJelly" and "off" or (fallbackMode and "off" or p.mode))
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
local function makeUI()
    local pg=waitForChild(player,"PlayerGui")
    local old=pg:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local parent=uiParent()
    old=parent:FindFirstChild("FullHiveStatus"); if old then old:Destroy() end
    local gui=Instance.new("ScreenGui"); gui.Name="FullHiveStatus"; gui.ResetOnSpawn=false; gui.DisplayOrder=10000; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=parent
    local frame=Instance.new("Frame"); frame.Size=UDim2.fromOffset(310,145); frame.Position=UDim2.fromOffset(18,80)
    frame.BackgroundColor3=Color3.fromRGB(24,28,38); frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
    local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.Size=UDim2.new(1,-20,1,-48)
    text.Position=UDim2.fromOffset(10,8); text.TextColor3=Color3.new(1,1,1); text.TextSize=14
    text.TextWrapped=true; text.Font=Enum.Font.Gotham; text.TextXAlignment=Enum.TextXAlignment.Left; text.Parent=frame
    local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-20,0,28); button.Position=UDim2.new(0,10,1,-36)
    button.Text="Stop assist"; button.BackgroundColor3=Color3.fromRGB(160,65,65); button.TextColor3=Color3.new(1,1,1); button.Parent=frame
    local function stopAssist()
        env.FullHiveStop=true
        if env.FullHiveStarRunning then env.AutoGiftedStarStop=true end
    end
    button.Activated:Connect(stopAssist)
    task.spawn(function()
        repeat
            local c=Report.Counts or {}
            local progress=Report.Stage=="early" and string.format("Baby %d/4 • Music %d/4 • Shy %d/3",c.Baby or 0,c.Music or 0,c.Shy or 0)
                or string.format("Actions %d • Jelly used %d",Report.Actions,Report.RoyalJellyUsed)
            local active=Report.ActiveTarget
            if active then
                progress=string.format("Slot (%d,%d) • %s",active.X,active.Y,
                    Report.CollectorFallback and "100-jelly collector recovery" or active.Reason)
            end
            text.Text=string.format("Full Hive • %s • %s slots\n%s\n%s",Report.Stage or "inspect",tostring(Report.Slots or "?"),Report.Error or Report.CleanupError or Report.Activity or Report.Phase,progress)
            task.wait(0.4)
        until not gui.Parent or not env.FullHiveRunning
        if gui.Parent then text.Text=Report.Error or ("Full Hive • "..Report.Phase); button.Text="Finished" end
    end)
end
local ok,err=xpcall(function()
    if not waitForStartupDelay() then return end
    initializePlayer()
    makeUI()
    initializeModules()
    run()
end,function(e) return tostring(e) end)
release()
if not ok then
    Report.Phase=stoppedByUser and "stopped" or "error"
    if not stoppedByUser then Report.Error=err; warn("[Full Hive] "..err) end
end
env.FullHiveRunning=false
