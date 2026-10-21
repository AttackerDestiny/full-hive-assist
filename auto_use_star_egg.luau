-- Walk/claim, collect Star Egg requirements, use up to two eggs, then rebuild the honey hive.
-- Running with DryRun=false SPENDS items, up to the limits below.
-- Stop: env.AutoGiftedStarStop = true
local env = (type(getgenv) == "function" and getgenv()) or _G
local Config = {
    DryRun = false,
    MaxRoyalJellies = math.huge, -- Stop manually or set a per-run jelly limit.
    JellyReserve = 0,
    AutoRefill = true,
    MinRefill = 10000,
    MaxRefill = 20000,
    HoneyReserve = 0, -- Honey kept untouched when planning purchases.
    MaxStarEggs = 2, -- Recheck all current gifted types before EACH egg.
    RebuildHoney = false, -- Starts after the egg phase finishes (or no eggs exist).
    GiftedJellyThreshold = 5000,
    RollDelay = 0.25,
}
if env.AutoGiftedStarRunning then
    warn("[Gifted Star] Already running")
    return
end
env.AutoGiftedStarRunning = true
env.AutoGiftedStarStop = false
env.AutoGiftedStarError = nil
local function run()
env.AutoGiftedStarReport = {Phase = 'starting'}
-- Status view only: the workflow owns movement, settings, and item requests.
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
assert(playerGui, "PlayerGui unavailable")
local old = playerGui:FindFirstChild("AutoHiveStatus")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "AutoHiveStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(350, 380)
panel.Position = UDim2.fromOffset(16, 70)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner", panel)
corner.CornerRadius = UDim.new(0, 12)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -85, 0, 44)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "Bee Hive • Status"
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = Color3.fromRGB(255, 218, 108)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = panel
local body = Instance.new("TextLabel")
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(14, 50)
scroll.Size = UDim2.new(1, -28, 1, -116)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
body.Size = UDim2.new(1, -8, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.TextColor3 = Color3.fromRGB(231, 235, 244)
body.TextSize = 14
body.Font = Enum.Font.Gotham
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.Parent = scroll
local stop = Instance.new("TextButton")
stop.Position = UDim2.new(0, 14, 1, -51)
stop.Size = UDim2.new(1, -28, 0, 44)
stop.BackgroundColor3 = Color3.fromRGB(179, 65, 69)
stop.TextColor3 = Color3.new(1, 1, 1)
stop.Text = "Stop"
stop.Font = Enum.Font.GothamBold
stop.TextSize = 14
stop.Parent = panel
Instance.new("UICorner", stop).CornerRadius = UDim.new(0, 8)
local minimize = Instance.new("TextButton")
minimize.Position = UDim2.new(1, -50, 0, 0)
minimize.Size = UDim2.fromOffset(44, 44)
minimize.BackgroundTransparency = 1
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Text = "−"
minimize.TextSize = 22
minimize.Parent = panel
local collapsed = false
local lastViewport
local function fitPanel()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local topLeft, bottomRight = game:GetService("GuiService"):GetGuiInset()
    local viewport = camera.ViewportSize - topLeft - bottomRight
    if viewport.X <= 0 or viewport.Y <= 0 then return end
    local width = math.min(350, math.max(180, viewport.X - 24))
    local height = collapsed and 44 or math.min(380, math.max(170, viewport.Y - 24))
    panel.Size = UDim2.fromOffset(width, height)
    local x = math.clamp(panel.Position.X.Offset, 0, math.max(0, viewport.X - width))
    local y = math.clamp(panel.Position.Y.Offset, 0, math.max(0, viewport.Y - height))
    panel.Position = UDim2.fromOffset(x, y)
    lastViewport = camera.ViewportSize
end
minimize.Activated:Connect(function()
    collapsed = not collapsed
    fitPanel()
    scroll.Visible, stop.Visible = not collapsed, not collapsed
    minimize.Text = collapsed and "+" or "−"
end)
stop.Activated:Connect(function()
    env.AutoGiftedStarStop = true
    stop.Text = "Stopping after current request…"
    stop.Active = false
end)
local inputService = game:GetService("UserInputService")
local dragStart, origin, dragging
local connections = {}
connections[#connections + 1] = title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, origin = input, input.Position, panel.Position
    end
end)
connections[#connections + 1] = inputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
        local delta = input.Position - dragStart
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        local x, y = origin.X.Offset + delta.X, origin.Y.Offset + delta.Y
        if viewport then
            local topLeft, bottomRight = game:GetService("GuiService"):GetGuiInset()
            viewport = viewport - topLeft - bottomRight
            x = math.clamp(x, 0, math.max(0, viewport.X - panel.AbsoluteSize.X))
            y = math.clamp(y, 0, math.max(0, viewport.Y - panel.AbsoluteSize.Y))
        end
        panel.Position = UDim2.new(origin.X.Scale, x, origin.Y.Scale, y)
    end
end)
connections[#connections + 1] = inputService.InputEnded:Connect(function(input)
    if dragging and input == dragging then dragging = nil end
end)
gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)
local function number(value)
    value = tonumber(value) or 0
    if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
    if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
    return tostring(math.floor(value))
end
task.spawn(function()
    fitPanel()
    while gui.Parent do
        if workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize ~= lastViewport then fitPanel() end
        local r = env.AutoGiftedStarReport or {}
        local pending = env.AutoHivePendingRequest
        local status = env.AutoGiftedStarError and "Stopped: error"
            or (r.DryRun and "Preview • no items used")
            or (not env.AutoGiftedStarRunning and "Finished")
            or (env.AutoGiftedStarStop and "Stopping") or (r.Phase or "Starting")
        local lines = {"Status: " .. status}
        if r.Activity then lines[#lines + 1] = r.Activity end
        if pending then lines[#lines + 1] = "Waiting for server: " .. pending.Name end
        lines[#lines + 1] = "Roll mode: " .. (r.RollMode or "—")
        lines[#lines + 1] = "Jelly: " .. number(r.RoyalJelly) .. "   Used: " .. number(r.JelliesUsed)
        lines[#lines + 1] = "Honey: " .. number(r.Honey) .. "   Refills: " .. number(r.Purchases)
        lines[#lines + 1] = "Star Eggs: " .. number(r.StarEggs) .. "   Used: " .. number(r.StarEggsUsed)
        if r.LastResult then
            local last = r.LastResult
            lines[#lines + 1] = "Last: " .. (last.Gifted and "Gifted " or "") .. last.Type
        end
        if r.Phase == "prepare" or r.DryRun then
            lines[#lines + 1] = "Missing gifted: " .. table.concat(r.Missing or {}, ", ")
        end
        if r.Phase == "rebuild" or r.DryRun then
            local needs = {}
            for _, need in ipairs(r.HoneyNeeds or {}) do
                needs[#needs + 1] = need.amount .. " " .. (need.gifted and "gifted " or "") .. need.type
            end
            lines[#lines + 1] = "Needed: " .. (#needs > 0 and table.concat(needs, ", ") or "none")
        end
        if env.AutoGiftedStarError then lines[#lines + 1] = env.AutoGiftedStarError end
        body.Text = table.concat(lines, "\n\n")
        if not env.AutoGiftedStarRunning then
            stop.Text = r.DryRun and "Preview complete" or "Stopped"
            stop.Active = false
        end
        task.wait(0.5)
    end
end)

-- Serialized requests; an uncertain response must never trigger a duplicate spend.
assert(not env.AutoHivePendingRequest, "An earlier server request is still pending; wait before rerunning")
local function invokeServer(target, ...)
    assert(not env.AutoHivePendingRequest, "Another server request is pending")
    local args = table.pack(...)
    local request = {Name = target.Name, Started = os.clock()}
    env.AutoHivePendingRequest = request
    local finished, success, values = false, false, nil
    task.spawn(function()
        success, values = pcall(function()
            return table.pack(target:InvokeServer(table.unpack(args, 1, args.n)))
        end)
        finished = true
        if env.AutoHivePendingRequest == request then env.AutoHivePendingRequest = nil end
    end)
    local timeout = target.Name == "ConstructHiveCellFromEgg" and 180 or 60
    while not finished and os.clock() - request.Started < timeout do task.wait(0.1) end
    assert(finished, "Server response timed out: " .. target.Name .. "; stopped without retrying. Wait for pending request before rerunning.")
    assert(success, "Server request failed: " .. tostring(values) .. "; stopped without retrying")
    return table.unpack(values, 1, values.n)
end

-- Uses standard Roblox APIs; optional executor APIs are feature-detected.
local function loadModule(module)
    local ok, value = pcall(require, module)
    if ok then return value end
    local setIdentity = setthreadidentity or setidentity
    local getIdentity = getthreadidentity or getidentity
    if type(setIdentity) == "function" and type(getIdentity) == "function" then
        local gotIdentity, original = pcall(getIdentity)
        if gotIdentity then
            local changed = pcall(setIdentity, 2)
            if changed then
                ok, value = pcall(require, module)
                local restored = pcall(setIdentity, original)
                assert(restored, "Could not restore execution identity; stopping")
                if ok then return value end
            end
        end
    end
    error("Cannot load game module " .. module.Name .. ": " .. tostring(value), 0)
end
local function fencePartsUnder(root)
    if not root then return {} end
    local ok, result = pcall(function() return root:QueryDescendants("BasePart") end)
    if ok then return result end
    -- Compatibility fallback for runtimes without QueryDescendants. The root
    -- is only Map.Fences, never the whole game or workspace.
    local parts, queue = {}, {root}
    local index = 1
    while index <= #queue do
        local node = queue[index]
        index = index + 1
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("BasePart") then parts[#parts + 1] = child end
            queue[#queue + 1] = child
        end
    end
    return parts
end

local function autoClaimHive()
-- Walk to an empty hive, then claim. No teleport, tween, or firetouch.
local Players = game:GetService("Players")
local Pathfinding = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local hives = workspace:WaitForChild("Honeycombs", 15)
assert(hives, "Honeycombs not found")

local function ownedHive()
    for id = 1, 6 do
        local hive = hives:FindFirstChild("Hive" .. id)
        local owner = hive and hive:FindFirstChild("Owner")
        if owner and owner.Value == player then return hive end
    end
end

local existing = ownedHive()
if existing then
    print("[Auto Hive] Already own " .. existing.Name)
    return
end

local claimRemote = game.ReplicatedStorage:WaitForChild("Events", 15):WaitForChild("ClaimHive", 15)
assert(claimRemote, "ClaimHive remote not found")
local deadline = os.clock() + 240
local function near(root, part)
    local d = root.Position - part.Position
    return Vector2.new(d.X, d.Z).Magnitude <= 0.9 and d.Y >= 0 and d.Y <= 8
end

local function walk(hive, part)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end
    if near(root, part) then return true end
    local path = Pathfinding:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4})
    local ok = pcall(function()
        path:ComputeAsync(root.Position, part.Position + Vector3.new(0, part.Size.Y / 2, 0))
    end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return false end
    local points = path:GetWaypoints()
    -- Finish at the actual pad center, even if the navigation mesh ends short.
    points[#points + 1] = {Position = part.Position, Action = Enum.PathWaypointAction.Walk}
    local index = 1
    local jumpIndex = 0
    local direction = Vector3.zero
    local binding = "AutoHiveWalk_" .. game:GetService("HttpService"):GenerateGUID(false)
    -- Apply movement after the default controls so they cannot reset it each frame.
    RunService:BindToRenderStep(binding, Enum.RenderPriority.Last.Value + 1, function()
        if hum.Parent then hum:Move(direction, false) end
    end)
    local success, result = pcall(function()
        local progressPosition = root.Position
        local progressTime = os.clock()
        local previousFrame = os.clock()
        while os.clock() < deadline and player.Character == char and hum.Health > 0
            and hive.Owner.Value == nil and not ownedHive() do
            local now = os.clock()
            local gap = now - previousFrame
            previousFrame = now
            if gap > 0.4 then progressTime = progressTime + gap deadline = deadline + math.min(gap, 30) end
            if near(root, part) then return true end
            local point = points[index]
            local delta = point.Position - root.Position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            -- Advance before stopping at intermediate points; keep moving between them.
            while index < #points and flat.Magnitude <= 2.5
                and math.abs(delta.Y) <= 6 do
                if point.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                index = index + 1
                point = points[index]
                delta = point.Position - root.Position
                flat = Vector3.new(delta.X, 0, delta.Z)
            end
            if point.Action == Enum.PathWaypointAction.Jump and jumpIndex ~= index then
                hum.Jump = true
                jumpIndex = index
            end
            direction = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
            if (root.Position - progressPosition).Magnitude >= 0.75 then
                progressPosition = root.Position
                progressTime = os.clock()
            elseif os.clock() - progressTime > 8 then
                return false -- Recompute a route on the next attempt if stuck.
            end
            RunService.Heartbeat:Wait()
        end
        return false
    end)
    RunService:UnbindFromRenderStep(binding)
    hum:Move(Vector3.zero, false)
    if not success then warn("[Auto Hive] Walk error: " .. tostring(result)) end
    return success and result
end

repeat
    if ownedHive() then break end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local candidates = {}
    for id = 1, 6 do
        local hive = hives:FindFirstChild("Hive" .. id)
        local owner = hive and hive:FindFirstChild("Owner")
        local ref = hive and hive:FindFirstChild("Platform")
        local model = ref and ref.Value
        local part = model and model:FindFirstChild("Platform")
        if owner and owner.Value == nil and part and hive:FindFirstChild("HiveID") then
            print("[Auto Hive] " .. hive.Name .. " is unowned")
            candidates[#candidates + 1] = {hive = hive, part = part}
        elseif owner and owner.Value then
            print("[Auto Hive] Skipping Hive" .. id .. ": owned by " .. owner.Value.Name)
        end
    end
    if root then
        for _, target in ipairs(candidates) do
            if ownedHive() or (os.clock() >= deadline or env.AutoGiftedStarStop) then break end
            print("[Auto Hive] Walking to " .. target.hive.Name)
            if walk(target.hive, target.part) then
                local currentRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if currentRoot and near(currentRoot, target.part)
                    and target.hive.Owner.Value == nil and not ownedHive() then
                    local ok, err = pcall(function()
                        claimRemote:FireServer(target.hive.HiveID.Value)
                    end)
                    if not ok then warn("[Auto Hive] " .. tostring(err)) end
                    local waitUntil = os.clock() + 2
                    repeat task.wait(0.1) until ownedHive() or os.clock() >= waitUntil
                end
            else
                warn("[Auto Hive] Could not reach " .. target.hive.Name .. "; checking next hive")
            end
        end
    end
    task.wait(0.5)
until (os.clock() >= deadline or env.AutoGiftedStarStop)

local owned = ownedHive()
if owned then
    print("[Auto Hive] Claimed " .. owned.Name)
else
    warn("[Auto Hive] Could not walk to and claim an empty hive within 90 seconds.")
end

end
if not Config.DryRun then
    autoClaimHive()
    if env.AutoGiftedStarStop then return end
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cache = loadModule(ReplicatedStorage.ClientStatCache)
local Types = loadModule(ReplicatedStorage.BeeTypes):GetTypes()
local player = game.Players.LocalPlayer
local remote = ReplicatedStorage.Events:WaitForChild("ConstructHiveCellFromEgg", 15)
assert(remote and remote:IsA("RemoteFunction"), "Egg remote unavailable")
local StarProgress = (function()
local Progress = {}
local function integer(value)
    return type(value)=="number" and value>=0 and value<math.huge and value%1==0
end
function Progress.usage(stats)
    local uses=stats.Totals and stats.Totals.EggUses
    if type(uses)~="table" then return {known=false,recordedKnown=false,used=0} end
    -- Live server counters omit Star before the first hatch. An absent key is
    -- a zero budget baseline, never evidence that two eggs have been hatched.
    if uses.Star==nil then return {known=true,recordedKnown=false,sparseZero=true,used=0} end
    if not integer(uses.Star) then return {known=false,recordedKnown=false,used=0} end
    return {known=true,recordedKnown=true,used=uses.Star}
end
function Progress.coverage(cells,types)
    assert(type(types)=="table", "Bee metadata unavailable")
    local required,mythics,counts={},{},{}
    local eligible={Common=true,Basic=true,Rare=true,Epic=true,Legendary=true}
    for name,info in pairs(types) do
        if type(info)=="table" then
            if eligible[info.Rarity] then required[#required+1]=name end
            if info.Rarity=="Mythic" then mythics[#mythics+1]=name end
        end
    end
    assert(table.find(required,"Basic") and #required>=29 and #mythics>=6,
        "Incomplete Star Egg prerequisite metadata")
    for _,cell in ipairs(cells) do
        if cell.bee and table.find(cell.bee.Traits or {},"Gifted") then counts[cell.bee.Type]=true end
    end
    table.sort(required);table.sort(mythics)
    local missing,missingMythics={},{}
    for _,name in ipairs(required) do if not counts[name] then missing[#missing+1]=name end end
    for _,name in ipairs(mythics) do if not counts[name] then missingMythics[#missingMythics+1]=name end end
    return {required=required,missing=missing,missingMythics=missingMythics}
end
function Progress.budget(stats,limit)
    local usage=Progress.usage(stats)
    local inventory=stats.Eggs and stats.Eggs.Star
    if not usage.known then return 0,"unknown-star-use-counter" end
    if not integer(inventory) then return 0,"unknown-star-inventory" end
    if limit~=nil and limit~=math.huge and not integer(limit) then return 0,"invalid-star-budget" end
    local remaining=math.max(0,2-usage.used)
    if remaining==0 then return 0,"two-recorded-uses" end
    return math.min(remaining,inventory,math.max(0,limit or 2))
end
function Progress.read(stats)
    local completed = stats.Quests and stats.Quests.Completed
    if type(completed) ~= "table" then return {known=false, ready=false} end
    local function done(name)
        if completed[name] == true then return true end
        for _, value in pairs(completed) do if value == name then return true end end
        return false
    end
    local mother, panda = done("Seven To Seven"), done("Royal Rumble")
    local earned = (mother and 1 or 0) + (panda and 1 or 0)
    local inventory = stats.Eggs and stats.Eggs.Star
    local usage=Progress.usage(stats)
    return {known=true, mother=mother, panda=panda, earned=earned, inventory=inventory,
        used=usage.used, recordedKnown=usage.recordedKnown,usageKnown=usage.known,
        sparseZero=usage.sparseZero,inventoryKnown=integer(inventory),
        ready=mother and panda and integer(inventory) and inventory==0
            and usage.recordedKnown and usage.used>=2}
end
return Progress
end)()
local Policy = (function()
-- Pure selection rules; embedded into the standalone combined script.
local Policy = {}
Policy.optionalMythics = {Spicy=true, Vector=true}
Policy.giftedDiscovered = {}
Policy.postEgg = false
-- Early-game fail-safe targets. Bubble/Frosty are quantity-flexible and are
-- handled as permanent species below; Baby/Music are four-slot fallbacks.
local giftedSingles = {"Bomber", "Bumble", "Cool", "Looker", "Bucko",
    "Commander", "Carpenter", "Diamond", "Lion", "Shy", "Demon", "Ninja"}
Policy.giftedSingles = giftedSingles
Policy.stageGifted = false
Policy.stageLegendary = false
Policy.convertFlexible = false
local function isGifted(bee)
    return table.find(bee.Traits or {}, "Gifted") ~= nil
end
local function key(cell) return cell.x .. "," .. cell.y end
function Policy.permanent(cell, types)
    if not cell.bee then return false end
    local info = assert(types[cell.bee.Type], "Unknown bee type")
    return info.Rarity == "Event" or (info.Rarity == "Mythic" and not (Policy.postEgg and Policy.optionalMythics[cell.bee.Type]))
end
function Policy.flexible(cell)
    return cell.bee and (cell.bee.Type == "Bubble" or cell.bee.Type == "Frosty")
end
function Policy.countGifted(cells)
    local counts = {}
    for _, cell in ipairs(cells) do
        if cell.bee and isGifted(cell.bee) then
            local name = cell.bee.Type
            counts[name] = (counts[name] or 0) + 1
        end
    end
    return counts
end
function Policy.missing(cells, required)
    local counts = Policy.countGifted(cells)
    local missing = {}
    for _, name in ipairs(required) do
        if not counts[name] then missing[#missing + 1] = name end
    end
    return missing, counts
end
function Policy.starRequirements(types)
    return StarProgress.coverage({},types).required
end
function Policy.starPreflight(cells, types, settings)
    local coverage=StarProgress.coverage(cells,types)
    assert(#coverage.missing == 0, "Every gifted non-Event/non-Mythic type must be in the current hive before each Star Egg")
    if #coverage.missingMythics==0 then return false,"all-gifted-mythics-present" end
    assert(type(settings) == "table", "Roll settings unavailable before Star Egg")
    for _, flag in ipairs({"RollToGifted", "RollToLegendary", "RollToMythic", "RollToMutation"}) do
        assert(not settings[flag], "Roll settings must be OFF before Star Egg")
    end
    return true
end
function Policy.stageMissing(cells, types, includeLegendary)
    local missing = {}
    local counts = Policy.countGifted(cells)
    for _, name in ipairs(giftedSingles) do
        local info = types[name]
        if info and (includeLegendary or info.Rarity ~= "Legendary") and not counts[name] then
            missing[#missing + 1] = name
        end
    end
    return missing
end
function Policy.starSafe(cell, cells, types, required)
    if Policy.permanent(cell, types) or Policy.flexible(cell) then return false end
    local missing, counts = Policy.missing(cells, required)
    -- Preserve the four-slot Baby/Music fallback even while gifted targets are
    -- still missing. These slots are only eligible when there is a spare copy.
    if cell.bee and (cell.bee.Type == "Baby" or cell.bee.Type == "Music") then
        local plan = Policy.honeyPlan(cells, types)
        if plan.keep[key(cell)] then return false end
    end
    if not cell.bee then return true end
    if isGifted(cell.bee) then
        return (counts[cell.bee.Type] or 0) > 1
    end
    return true
end
function Policy.prepSafe(cell, cells, types)
    if not cell.bee or Policy.permanent(cell, types) or Policy.flexible(cell) then return false end
    if cell.bee.Type == "Baby" or cell.bee.Type == "Music" then
        if Policy.honeyPlan(cells, types).keep[key(cell)] then return false end
    end
    if not isGifted(cell.bee) then return true end
    return (Policy.countGifted(cells)[cell.bee.Type] or 0) > 1
end
function Policy.honeyPlan(cells, types)
    local keep, needs, candidates = {}, {}, {}
    for _, cell in ipairs(cells) do
        if cell.bee and (Policy.permanent(cell, types) or (Policy.flexible(cell) and
            (isGifted(cell.bee) or not Policy.convertFlexible))) then
            keep[key(cell)] = true
        end
    end
    if Policy.postEgg then
        for _, name in ipairs({"Spicy", "Vector"}) do
            if not Policy.giftedDiscovered[name] then
                local found = false
                for _, cell in ipairs(cells) do
                    if cell.bee and cell.bee.Type == name and not isGifted(cell.bee) then
                        keep[key(cell)] = true
                        found = true
                        break
                    end
                end
                if not found then needs[#needs+1] = {type=name, gifted=false, amount=1, forceMythic=true} end
            end
        end
    end
    for _, name in ipairs(giftedSingles) do
        local info = types[name]
        local enabled = Policy.stageGifted and info and
            (Policy.stageLegendary or info.Rarity ~= "Legendary")
        if enabled then
            local found = false
            for _, cell in ipairs(cells) do
                if cell.bee and cell.bee.Type == name and isGifted(cell.bee) and not keep[key(cell)] then
                    keep[key(cell)] = true
                    found = true
                    break
                end
            end
            if not found then needs[#needs + 1] = {type = name, gifted = true, amount = 1} end
        end
    end
    for _, name in ipairs({"Baby", "Music"}) do
        -- Keep four total copies, preferring gifted copies when available.
        local kept = 0
        for _, cell in ipairs(cells) do
            if cell.bee and cell.bee.Type == name and keep[key(cell)] then
                kept = kept + 1
            end
        end
        for _, giftedPass in ipairs({true, false}) do
            for _, cell in ipairs(cells) do
                if kept < 4 and cell.bee and cell.bee.Type == name
                    and isGifted(cell.bee) == giftedPass and not keep[key(cell)] then
                    keep[key(cell)] = true
                    kept = kept + 1
                end
            end
        end
        if kept < 4 then needs[#needs + 1] = {type = name, gifted = false, amount = 4 - kept} end
    end
    for _, cell in ipairs(cells) do
        -- Do not spend Basic Eggs or hatch unused cells during the rebuild.
        if cell.bee and not keep[key(cell)] then candidates[#candidates + 1] = cell end
    end
    local fixedDemand = 0
    for _, need in ipairs(needs) do fixedDemand = fixedDemand + need.amount end
    if #candidates > fixedDemand then
        needs[#needs + 1] = {type = "Bubble/Frosty", gifted = Policy.convertFlexible,
            amount = #candidates - fixedDemand, filler = true}
    end
    return {keep = keep, needs = needs, candidates = candidates}
end
function Policy.honeySafe(cell, cells, types)
    return cell.bee ~= nil and not Policy.honeyPlan(cells, types).keep[key(cell)]
end
function Policy.choose(cells, predicate)
    -- Prefer empty unlocked cells, then normal extras, then gifted duplicates.
    for _, mode in ipairs({"empty", "normal", "gifted"}) do
        for _, cell in ipairs(cells) do
            local kind = not cell.bee and "empty" or (isGifted(cell.bee) and "gifted" or "normal")
            if kind == mode and predicate(cell) then return cell end
        end
    end
end
return Policy

end)()
local required = Policy.starRequirements(Types)
local function gifted(bee)
    return table.find(bee.Traits or {}, "Gifted") ~= nil
end

local function scan()
    local stats = Cache:Get()
    assert(type(stats.Honeycomb) == "table", "Hive data unavailable")
    local cells, counts = {}, {}
    for xKey, column in pairs(stats.Honeycomb) do
        local x = tonumber(tostring(xKey):match("^x(%d+)$"))
        if x and type(column) == "table" then
            for yKey, bee in pairs(column) do
                local y = tonumber(tostring(yKey):match("^y(%d+)$"))
                if y and type(bee) == "table" and bee.Type then
                    assert(Types[bee.Type], "Unknown bee type; stopping")
                    cells[#cells + 1] = {x = x, y = y, bee = bee}
                    if gifted(bee) then counts[bee.Type] = (counts[bee.Type] or 0) + 1 end
                end
            end
        end
    end
    assert(#cells > 0, "No occupied cells found")
    -- Empty unlocked cells are eligible for Star Eggs only, never Royal Jelly.
    local hiveRef = player:FindFirstChild("Honeycomb")
    local hive = hiveRef and hiveRef.Value
    if not hive then
        for _, candidate in ipairs(workspace.Honeycombs:GetChildren()) do
            if candidate.Owner.Value == player then hive = candidate break end
        end
    end
    if hive and hive:FindFirstChild("Cells") then
        for _, cell in ipairs(hive.Cells:GetChildren()) do
            local cellType, locked = cell:FindFirstChild("CellType"), cell:FindFirstChild("CellLocked")
            if cellType and cellType.Value == "Empty" and locked and not locked.Value then
                cells[#cells + 1] = {x = cell.CellX.Value, y = cell.CellY.Value}
            end
        end
    end
    table.sort(cells, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    local missing = {}
    for _, name in ipairs(required) do
        if not counts[name] then missing[#missing + 1] = name end
    end
    return stats, cells, counts, missing
end

local function ownsHive()
    for _, hive in ipairs(workspace.Honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner.Value == player then return true end
    end
    return false
end

local usedJelly, usedEggs = 0, 0
local function refreshStats()
    local fresh = invokeServer(ReplicatedStorage.Events.RetrievePlayerStats)
    assert(type(fresh) == "table", "Unable to refresh inventory")
    for _, key in ipairs({"Honey", "Eggs", "Totals", "Honeycomb", "Settings", "Quests", "DiscGiftTypes"}) do
        if fresh[key] ~= nil then Cache:Set(key, fresh[key]) end
    end
    return fresh
end
local function jellyCost(stats, amount)
    local purchases = assert(stats.Totals.Purchases.Eggs, "Purchase history unavailable")
    local bought = purchases.RoyalJelly or 0
    local cost = 0
    for i = 0, amount - 1 do
        local unit = math.min(250000 + 10000 * (bought + i), 1000000)
        if unit == 1000000 then return cost + (amount - i) * unit end
        cost = cost + unit
    end
    return cost
end

local function purchasePlan(stats)
    local budget = math.max(0, (stats.Honey or 0) - Config.HoneyReserve)
    for amount = 20000, 10000, -10000 do
        local cost = jellyCost(stats, amount)
        if amount <= Config.MaxRefill and amount >= Config.MinRefill and cost <= budget then
            return amount, cost
        end
    end
    return nil
end

local function walkToPart(part, directJump, allowBridge)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    assert(root and humanoid and humanoid.Health > 0, "Character unavailable")
    local runService = game:GetService("RunService")
    local binding = "GiftedStarShopWalk_" .. game:GetService("HttpService"):GenerateGUID(false)
    local direction = Vector3.zero
    local jumpRequested = false
    local bypassed = {}
    local fences = workspace.Map:FindFirstChild("Fences")
    local fenceParts = fencePartsUnder(fences)
    local function bypassNearbyFence()
        for _, obstacle in ipairs(fenceParts) do
            if obstacle.CanCollide then
                local p = obstacle.CFrame:PointToObjectSpace(root.Position)
                local half = obstacle.Size / 2
                local closest = Vector3.new(
                    math.clamp(p.X, -half.X, half.X),
                    math.clamp(p.Y, -half.Y, half.Y),
                    math.clamp(p.Z, -half.Z, half.Z))
                if (p - closest).Magnitude <= 6 then
                    bypassed[obstacle] = true
                    obstacle.CanCollide = false
                end
            end
        end
    end
    runService:BindToRenderStep(binding, Enum.RenderPriority.Last.Value + 1, function()
        if humanoid.Parent then
            humanoid:Move(direction, false)
            if jumpRequested then humanoid.Jump = true jumpRequested = false end
        end
    end)
    local ok, err = pcall(function()
        local destination = typeof(part) == "Vector3" and part
            or part.Position + Vector3.new(0, part.Size.Y / 2, 0)
        for attempt = 1, 4 do
            assert(not env.AutoGiftedStarStop, "Stopped by user")
            local path = game:GetService("PathfindingService"):CreatePath({
                AgentRadius = 3, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4,
            })
            path:ComputeAsync(root.Position, destination)
            if path.Status ~= Enum.PathStatus.Success and allowBridge == false then
                directJump = true -- Approach across the low field fence by walking/jumping.
            end
            if path.Status ~= Enum.PathStatus.Success and not directJump then
                -- Shortcut: walk to the yellow wall beside Sunflower Field,
                -- then jump onto the west platform instead of using the ramp.
                -- These are movement targets only; position is never assigned.
                direction = Vector3.zero
                runService:UnbindFromRenderStep(binding)
                local east = Vector3.new(-245, 2, 190)
                local west = Vector3.new(-261, 20, 190)
                if destination.X < -260 then
                    if root.Position.Z > 230 and root.Position.X > -235 then
                        if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Returning to hive' end
            walkToPart(Vector3.new(-113, 3, 271), true, false)
                        walkToPart(Vector3.new(-240, 3, 275), true, false)
                    end
                    walkToPart(east, true, false)
                    walkToPart(west, true, false)
                elseif root.Position.X < -255 then
                    walkToPart(west, false, false)
                    walkToPart(east, true, false)
                else
                    walkToPart(east, true, false)
                end
                walkToPart(part, false, false)
                return
            end
            local points = directJump and {
                {Position = destination, Action = Enum.PathWaypointAction.Jump},
            } or path:GetWaypoints()
            points[#points + 1] = {Position = destination, Action = Enum.PathWaypointAction.Walk}
            local index, jumpIndex = 1, 0
            local lastPosition, lastProgress = root.Position, os.clock()
            local lastRecoveryJump = 0
            local previousFrame = os.clock()
            local deadline = os.clock() + 240
            while os.clock() < deadline do
                assert(not env.AutoGiftedStarStop, "Stopped by user")
                assert(player.Character == character and humanoid.Health > 0, "Character changed")
                local now = os.clock()
                local gap = now - previousFrame
                previousFrame = now
                if gap > 0.4 then lastProgress = lastProgress + gap deadline = deadline + math.min(gap, 30) end
                local goal = root.Position - destination
                if Vector2.new(goal.X, goal.Z).Magnitude <= 0.9 and math.abs(goal.Y) <= 8 then return end
                local point = points[index]
                local delta = point.Position - root.Position
                local flat = Vector3.new(delta.X, 0, delta.Z)
                while index < #points and flat.Magnitude <= 2 and math.abs(delta.Y) <= 8 do
                    if point.Action == Enum.PathWaypointAction.Jump then jumpRequested = true end
                    index = index + 1
                    point = points[index]
                    delta = point.Position - root.Position
                    flat = Vector3.new(delta.X, 0, delta.Z)
                end
                if point.Action == Enum.PathWaypointAction.Jump and jumpIndex ~= index then
                    jumpRequested = true
                    jumpIndex = index
                end
                direction = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
                local progressDelta = root.Position - lastPosition
                if Vector2.new(progressDelta.X, progressDelta.Z).Magnitude >= 0.75 then
                    lastPosition, lastProgress = root.Position, os.clock()
                elseif os.clock() - lastProgress > 8 then break end
                if os.clock() - lastProgress > 0.5 and os.clock() - lastRecoveryJump > 0.7
                    and humanoid.FloorMaterial ~= Enum.Material.Air then
                    jumpRequested = true
                    lastRecoveryJump = os.clock()
                end
                if os.clock() - lastProgress > 0.35 then bypassNearbyFence() end
                -- Some mesh points sit inside the field fences. Once close,
                -- continue to the next point instead of pushing against that point.
                if os.clock() - lastProgress > 1 and index < #points
                    and flat.Magnitude <= 5 then
                    index = index + 1
                    lastProgress = os.clock()
                end
                runService.Heartbeat:Wait()
            end
            direction = Vector3.zero
        end
        error("Could not reach shop/hive after four routes")
    end)
    runService:UnbindFromRenderStep(binding)
    humanoid:Move(Vector3.zero, false)
    for obstacle in pairs(bypassed) do
        if obstacle.Parent then obstacle.CanCollide = true end
    end
    assert(ok, err)
end

local function refill()
    local stats = refreshStats()
    local amount, expectedCost = purchasePlan(stats)
    if not amount then
        warn("[Gifted Star] Cannot afford 10,000 jelly with the honey reserve; stopping")
        return false
    end
    local shop = workspace.Shops.JellyDispenser
    local floor = assert(shop.Floor.Value, "Jelly shop floor unavailable")
    print("[Gifted Star] Walking to honey Jelly Dispenser")
    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Walking to jelly dispenser' end
    walkToPart(floor)
    stats = refreshStats()
    amount, expectedCost = purchasePlan(stats)
    if not amount then return false end
    assert(not env.AutoGiftedStarStop, "Stopped by user")
    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Buying 10,000-jelly packs' end
    local packsBought = 0
    for pack = 1, amount / 10000 do
        assert(not env.AutoGiftedStarStop, "Stopped by user")
        stats = refreshStats()
        local packCost = jellyCost(stats, 10000)
        if (stats.Honey or 0) - Config.HoneyReserve < packCost then break end
        local beforeJelly, beforeHoney = stats.Eggs.RoyalJelly or 0, stats.Honey
        print(string.format("[Gifted Star] Buying 10,000 jelly pack %d/%d for %.0f honey",
            pack, amount / 10000, packCost))
        local accepted = invokeServer(ReplicatedStorage.Events.ItemPackageEvent, "Purchase", {
            Category = "Eggs", Type = "RoyalJelly", Amount = 10000,
        })
        assert(accepted, "Jelly purchase rejected; stopping without retry")
        local updated = refreshStats()
        assert((updated.Eggs.RoyalJelly or 0) - beforeJelly == 10000,
            "10,000-pack inventory could not be verified; stopping")
        assert(beforeHoney - updated.Honey <= packCost, "Unexpected purchase cost; stopping")
        packsBought = packsBought + 1
        task.wait(0.35)
    end
    if packsBought == 0 then return false end
    for _, hive in ipairs(workspace.Honeycombs:GetChildren()) do
        if hive.Owner.Value == player then
            if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Returning to hive' end
            walkToPart(Vector3.new(-113, 3, 271), true, false)
            walkToPart(hive.Platform.Value.Platform)
            return true
        end
    end
    error("Claimed hive lost after purchase")
end

local Report = {
    Phase = "inspect", DryRun = Config.DryRun, JelliesUsed = 0, StarEggsUsed = 0,
    Purchases = 0, RequiredTypes = #required,
}
env.AutoGiftedStarReport = Report
local function deferStars(reason)
    Report.Phase="star-eggs-deferred"
    Report.DeferredReason=reason
    Report.Activity="Star Eggs saved: "..reason
    return false
end
local function updateReport()
    local stats, cells, counts, missing = scan()
    Report.Missing = missing
    Report.RoyalJelly = stats.Eggs.RoyalJelly or 0
    Report.StarEggs = stats.Eggs.Star or 0
    Report.StarProgress = StarProgress.read(stats)
    Report.MissingGiftedMythics=StarProgress.coverage(cells,Types).missingMythics
    for _, name in ipairs({"Spicy", "Vector"}) do
        local info = Types[name]
        local discovered = stats.DiscGiftTypes
        assert(type(discovered)=="table" and info and info.ID, "Gifted discovery data unavailable")
        for k,v in pairs(discovered) do
            if v == info.ID or v == name or ((k==info.ID or k==name) and v==true) then
                Policy.giftedDiscovered[name] = true
            end
        end
    end
    Report.Honey = stats.Honey or 0
    local plan = Policy.honeyPlan(cells, Types)
    Report.HoneyNeeds = plan.needs
    Report.HoneyExtraSlots = #plan.candidates
    return stats, cells, counts, missing, plan
end
local function configureMode(mode)
    assert(mode == "gifted" or mode == "legendary" or mode == "off", "Unknown roll mode")
    local desired = {
        RollToGifted = mode == "gifted", RollToLegendary = mode == "legendary",
        RollToMythic = false, RollToMutation = false,
    }
    local current = Cache:Get().Settings or {}
    for setting, value in pairs(desired) do
        if (current[setting] == true) ~= value then
            ReplicatedStorage.Events.PlayerSettingsEvent:FireServer(setting, value)
        end
    end
    local deadline = os.clock() + 15
    local matched = false
    repeat
        task.wait(0.35)
        local fresh = refreshStats()
        matched = true
        for setting, value in pairs(desired) do
            if (fresh.Settings[setting] == true) ~= value then matched = false end
        end
    until matched or os.clock() >= deadline or env.AutoGiftedStarStop
    assert(matched, "Roll settings did not synchronize; stopping before spending")
    Report.RollMode = mode
end
local function stopped()
    assert(not env.AutoGiftedStarStop, "Stopped by user")
end
local function fingerprint(bee)
    return bee.Type .. ":" .. tostring(table.find(bee.Traits or {}, "Gifted") ~= nil)
end
local permanentBaseline = {}
local optionalBaselineKeys = {}
local rebuilding = false
local function capturePermanents(cells)
    for _, cell in ipairs(cells) do
        if Policy.permanent(cell, Types) then
            local key = cell.x .. "," .. cell.y
            local optional = Policy.optionalMythics[cell.bee.Type]
            if not rebuilding or not optional then
                permanentBaseline[key] = fingerprint(cell.bee)
                if optional then optionalBaselineKeys[key] = true end
            end
        end
    end
end
local function verifyPermanents(cells)
    local byKey = {}
    for _, cell in ipairs(cells) do byKey[cell.x .. "," .. cell.y] = cell end
    for key, expected in pairs(permanentBaseline) do
        local cell = byKey[key]
        assert(cell and cell.bee and fingerprint(cell.bee) == expected,
            "Protected Event/Mythic changed; stopping")
    end
    capturePermanents(cells)
end
local function isSafe(cell, cells, phase)
    if phase == "prepare" then return Policy.prepSafe(cell, cells, Types) end
    if phase == "eggs" then return Policy.starSafe(cell, cells, Types, required) end
    if phase == "rebuild" then return Policy.honeySafe(cell, cells, Types) end
    return false
end
local function useItem(target, item, phase)
    stopped()
    Report.Activity = item == "Star" and "Using Star Egg on a verified extra slot" or "Rolling Royal Jelly"
    assert(ownsHive(), "No claimed hive")
    refreshStats()
    local stats, cells = scan()
    if item == "RoyalJelly" then
        local settings = stats.Settings or {}
        assert((settings.RollToGifted == true) == (Report.RollMode == "gifted")
            and (settings.RollToLegendary == true) == (Report.RollMode == "legendary")
            and not settings.RollToMythic and not settings.RollToMutation,
            "Roll settings changed; stopping before spending")
    end
    verifyPermanents(cells)
    local current
    for _, cell in ipairs(cells) do
        if cell.x == target.x and cell.y == target.y then current = cell break end
    end
    assert(current and isSafe(current, cells, phase), "Target became protected; stopping")
    assert((item == "Star" and phase == "eggs") or (item == "RoyalJelly" and phase ~= "eggs"),
        "Item/phase mismatch")
    local before = stats.Eggs[item] or 0
    assert(before > 0, "Item inventory empty")
    if item == "Star" then
        local ready,reason=Policy.starPreflight(cells, Types, stats.Settings)
        if not ready then return deferStars(reason) end
        local budget=StarProgress.budget(stats,Config.MaxStarEggs-usedEggs)
        assert(budget>0,"Star Egg budget changed before spending")
    end
    local remaining, accepted, honeycomb, discovered, eggUses =
        invokeServer(remote, current.x, current.y, item, 1, false)
    assert(accepted and type(honeycomb) == "table" and type(remaining) == "number",
        "Server rejected request or returned an unknown result; no automatic retry")
    Cache:Set({"Eggs", item}, remaining)
    Cache:Set("Honeycomb", honeycomb)
    if discovered then Cache:Set("DiscoveredBees", discovered) end
    refreshStats()
    if eggUses then Cache:Set({"Totals", "EggUses"}, eggUses) end
    local consumed = before - remaining
    assert(consumed >= 1 and consumed <= before, "Invalid item consumption")
    if item == "Star" then
        assert(consumed == 1, "Unexpected Star Egg consumption")
        usedEggs = usedEggs + consumed
    else
        usedJelly = usedJelly + consumed
    end
    local bee = honeycomb["x" .. current.x] and honeycomb["x" .. current.x]["y" .. current.y]
    assert(bee and Types[bee.Type], "Updated bee unavailable")
    local _, afterCells = scan()
    verifyPermanents(afterCells)
    if phase == "eggs" then
        local afterMissing = Policy.missing(afterCells, required)
        assert(#afterMissing == 0, "Star Egg requirements were lost; stopping")
        assert(gifted(bee) and Types[bee.Type].Rarity == "Mythic", "Unexpected Star Egg result; stopping")
    end
    Report.JelliesUsed, Report.StarEggsUsed = usedJelly, usedEggs
    Report.LastResult = {X = current.x, Y = current.y, Type = bee.Type,
        Gifted = gifted(bee), Item = item, Consumed = consumed}
    print(string.format("[Hive] %s: %s%s (%d,%d), %d %s used", phase,
        gifted(bee) and "Gifted " or "", bee.Type, current.x, current.y, consumed, item))
    updateReport()
    task.wait(Config.RollDelay)
end
local function ensureJelly()
    stopped()
    assert(usedJelly < Config.MaxRoyalJellies, "Per-run Royal Jelly limit reached")
    local stats = Cache:Get()
    if (stats.Eggs.RoyalJelly or 0) > Config.JellyReserve then return true end
    if not Config.AutoRefill then return false end
    local success = refill()
    if success then Report.Purchases = Report.Purchases + 1 end
    Report.Activity = nil
    return success
end
refreshStats()
local stats, cells, counts, missing, plan = updateReport()
capturePermanents(cells)
local questProgress = StarProgress.read(stats)
assert(questProgress.known, "Quest completion data unavailable; stopping")
local eggBudget,budgetReason = StarProgress.budget(stats,Config.MaxStarEggs)
Report.QuestEggsEarned = questProgress.earned
Report.QuestEggsUsed = questProgress.used -- Compatibility alias: total recorded uses, not egg provenance.
Report.StarEggUsesRecorded = questProgress.used
Report.StarEggUsesKnown = questProgress.recordedKnown
Report.EggBudget = eggBudget
Report.EggBudgetReason=budgetReason
Report.NextStarTarget = Policy.choose(cells, function(cell)
    return Policy.starSafe(cell, cells, Types, required)
end)
-- Avoid putting an entire bee record into the status report.
if Report.NextStarTarget then
    local cell = Report.NextStarTarget
    Report.NextStarTarget = {X = cell.x, Y = cell.y, Type = cell.bee and cell.bee.Type or "Empty"}
end
if Config.DryRun then
    Report.Phase = "dry-run"
    print("[Hive] Dry run only: no settings, movement, items or purchases changed")
    return
end

if eggBudget > 0 then
    if #StarProgress.coverage(cells,Types).missingMythics==0 then
        return deferStars("all-gifted-mythics-present")
    end
    Report.Phase = "prepare"
    while true do
        stopped()
        stats, cells, counts, missing = updateReport()
        if #StarProgress.coverage(cells,Types).missingMythics==0 then
            return deferStars("all-gifted-mythics-present")
        end
        if #missing == 0 then break end -- Do not clean up duplicate bees here.
        assert(counts.Basic, "Gifted Basic is missing; Royal Jelly cannot supply it")
        local target = Policy.choose(cells, function(cell) return Policy.prepSafe(cell, cells, Types) end)
        assert(target, "No safe Royal Jelly slot remains")
        configureMode("gifted")
        assert(ensureJelly(), "Cannot refill jelly; Star Eggs preserved")
        useItem(target, "RoyalJelly", "prepare")
    end
    Report.Phase = "eggs"
    configureMode("off")
    while usedEggs < eggBudget do
        stopped()
        refreshStats()
        stats, cells, counts, missing = updateReport()
        if #StarProgress.coverage(cells,Types).missingMythics==0 then
            return deferStars("all-gifted-mythics-present")
        end
        assert(#missing == 0, "All gifted prerequisite types must be in the current hive before each egg")
        local target = Policy.choose(cells, function(cell)
            return Policy.starSafe(cell, cells, Types, required)
        end)
        assert(target, "No safe extra slot for Star Egg")
        if useItem(target, "Star", "eggs")==false then return end
    end
end

refreshStats()
local progress = StarProgress.read(Cache:Get())
Report.StarProgress = progress
if not progress.ready then
    Report.Phase = "waiting-for-star-quests"
    Report.Activity = "Post-egg rebuild deferred: complete both Star Egg quests, use the available eggs, and verify two recorded hatches"
    return
end
Policy.postEgg = true
-- Only the post-egg phase may release non-target gifted Legendaries.
Report.Phase = "rebuild"
rebuilding = true
-- Release only the optional species from the per-slot baseline; the policy
-- still protects one copy, while all other Event/Mythic slots stay immutable.
for key in pairs(optionalBaselineKeys) do permanentBaseline[key] = nil end
while Config.RebuildHoney do
    stopped()
    stats, cells, counts, missing, plan = updateReport()
    local jelly = stats.Eggs.RoyalJelly or 0
    Policy.stageGifted = jelly >= 5000
    Policy.stageLegendary = jelly >= 20000
    Policy.convertFlexible = Policy.stageGifted
    stats, cells, counts, missing, plan = updateReport()
    if #plan.needs == 0 then
        Report.Phase = "complete"
        print("[Hive] Honey targets reached; every remaining replaceable slot is gifted Bubble/Frosty")
        return
    end
    for _, need in ipairs(plan.needs) do
        assert(not (need.type == "Basic" and need.gifted), "Gifted Basic missing; cannot recover it with jelly")
    end
    local remainingDemand = 0
    for _, need in ipairs(plan.needs) do remainingDemand = remainingDemand + need.amount end
    assert(#plan.candidates >= remainingDemand,
        "Not enough unprotected slots for honey targets; protected bees kept")
    local needGifted, needNormal = false, false
    for _, need in ipairs(plan.needs) do
        if need.gifted and not need.filler then needGifted = true end
        if not need.gifted then needNormal = true end
    end
    -- Fixed gifted types first, then three normal Baby/Music each, then filler.
    if not needNormal then needGifted = true end
    local target = Policy.choose(cells, function(cell) return Policy.honeySafe(cell, cells, Types) end)
    assert(target, "No safe honey rebuild slot")
    if needGifted then
        assert((stats.Eggs.RoyalJelly or 0) >= Config.GiftedJellyThreshold,
            "Royal Jelly below 5,000; gifted-target phase is deferred")
        configureMode("gifted")
    else
        -- Baby/Music fallback rolls must run with both stop settings off.
        configureMode("off")
    end
    assert(ensureJelly(), "Cannot refill Royal Jelly; stopping rebuild")
    useItem(target, "RoyalJelly", "rebuild")
end
Report.Phase = "complete"

end
local ok, err = xpcall(run, function(message) return tostring(message) end)
env.AutoGiftedStarRunning = false
if not ok then
    env.AutoGiftedStarError = err
    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Error = err end
    warn("[Hive] " .. err)
end

