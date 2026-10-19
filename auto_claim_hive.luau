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
local deadline = os.clock() + 90
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
        while os.clock() < deadline and player.Character == char and hum.Health > 0
            and hive.Owner.Value == nil and not ownedHive() do
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
            elseif os.clock() - progressTime > 3 then
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
            if ownedHive() or os.clock() >= deadline then break end
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
until os.clock() >= deadline

local owned = ownedHive()
if owned then
    print("[Auto Hive] Claimed " .. owned.Name)
else
    warn("[Auto Hive] Could not walk to and claim an empty hive within 90 seconds.")
end
