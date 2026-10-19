-- Auto-claim by walking and prepare gifted types. Star Egg use is disabled.
-- Running with DryRun=false SPENDS items, up to the limits below.
-- Stop: getgenv().AutoGiftedStarStop = true
local Config = {
    DryRun = false,
    MaxRoyalJellies = math.huge, -- Stop manually or set a per-run jelly limit.
    JellyReserve = 0,
    AutoRefill = true,
    MinRefill = 10000,
    MaxRefill = 20000,
    HoneyReserve = 0, -- Honey kept untouched when planning purchases.
    MaxStarEggs = 0, -- Preparation only: do not use Star Eggs.
    RollDelay = 0.25,
}
local env = getgenv()
if env.AutoGiftedStarRunning then
    warn("[Gifted Star] Already running")
    return
end
env.AutoGiftedStarRunning = true
env.AutoGiftedStarStop = false
env.AutoGiftedStarError = nil
local function run()
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
            if ownedHive() or (os.clock() >= deadline or getgenv().AutoGiftedStarStop) then break end
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
until (os.clock() >= deadline or getgenv().AutoGiftedStarStop)

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
local Cache = require(ReplicatedStorage.ClientStatCache)
local Types = require(ReplicatedStorage.BeeTypes):GetTypes()
local player = game.Players.LocalPlayer
local remote = ReplicatedStorage.Events:WaitForChild("ConstructHiveCellFromEgg", 15)
assert(remote and remote:IsA("RemoteFunction"), "Egg remote unavailable")
local required = {}
for name, info in pairs(Types) do
    if info.Rarity == "Common" or info.Rarity == "Rare"
        or info.Rarity == "Epic" or info.Rarity == "Legendary" then
        required[#required + 1] = name
    end
end
table.sort(required)
assert(#required >= 29, "Unexpected bee metadata; stopping")

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
    table.sort(cells, function(a, b)
        if gifted(a.bee) ~= gifted(b.bee) then return not gifted(a.bee) end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    local missing = {}
    for _, name in ipairs(required) do
        if not counts[name] then missing[#missing + 1] = name end
    end
    return stats, cells, counts, missing
end

local function safe(cell, counts)
    local bee = cell.bee
    local rarity = Types[bee.Type].Rarity
    if rarity == "Event" or rarity == "Mythic" then return false end
    if gifted(bee) then
        if rarity == "Legendary" then return false end
        if (counts[bee.Type] or 0) <= 1 then return false end
    end
    return true
end

local function choose(cells, counts)
    for _, cell in ipairs(cells) do
        if safe(cell, counts) then return cell end
    end
end

local function ownsHive()
    for _, hive in ipairs(workspace.Honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner.Value == player then return true end
    end
    return false
end

local usedJelly, usedEggs = 0, 0
if not Config.DryRun then
    for _, setting in ipairs({"RollToGifted", "RollToLegendary", "RollToMythic", "RollToMutation"}) do
        ReplicatedStorage.Events.PlayerSettingsEvent:FireServer(setting, setting == "RollToGifted")
    end
    task.wait(0.5)
    local fresh = ReplicatedStorage.Events.RetrievePlayerStats:InvokeServer()
    assert(fresh and fresh.Settings, "Could not verify jelly settings")
    for _, setting in ipairs({"RollToGifted", "RollToLegendary", "RollToMythic", "RollToMutation"}) do
        assert((fresh.Settings[setting] == true) == (setting == "RollToGifted"), "Unexpected jelly setting: " .. setting)
    end
    Cache:Set("Settings", fresh.Settings)
end
local function refreshStats()
    local fresh = ReplicatedStorage.Events.RetrievePlayerStats:InvokeServer()
    assert(type(fresh) == "table", "Unable to refresh inventory")
    for _, key in ipairs({"Honey", "Eggs", "Totals", "Honeycomb", "Settings"}) do
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
    local fenceParts = fences and fences:QueryDescendants("BasePart") or {}
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
            assert(not getgenv().AutoGiftedStarStop, "Stopped by user")
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
            local deadline = os.clock() + 120
            while os.clock() < deadline do
                assert(not getgenv().AutoGiftedStarStop, "Stopped by user")
                assert(player.Character == character and humanoid.Health > 0, "Character changed")
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
                elseif os.clock() - lastProgress > 3 then break end
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
    walkToPart(floor)
    stats = refreshStats()
    amount, expectedCost = purchasePlan(stats)
    if not amount then return false end
    assert(not getgenv().AutoGiftedStarStop, "Stopped by user")
    local packsBought = 0
    for pack = 1, amount / 10000 do
        assert(not getgenv().AutoGiftedStarStop, "Stopped by user")
        stats = refreshStats()
        local packCost = jellyCost(stats, 10000)
        if (stats.Honey or 0) - Config.HoneyReserve < packCost then break end
        local beforeJelly, beforeHoney = stats.Eggs.RoyalJelly or 0, stats.Honey
        print(string.format("[Gifted Star] Buying 10,000 jelly pack %d/%d for %.0f honey",
            pack, amount / 10000, packCost))
        local accepted = ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Purchase", {
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
            walkToPart(Vector3.new(-113, 3, 271), true, false)
            walkToPart(hive.Platform.Value.Platform)
            return true
        end
    end
    error("Claimed hive lost after purchase")
end

local function useItem(cell, item)
    assert(item == "RoyalJelly", "Preparation mode: Star Egg use is disabled")
    if getgenv().AutoGiftedStarStop then error("Stopped by user", 0) end
    assert(ownsHive(), "No claimed hive; stopping")
    -- Re-read immediately before every request. Never enable bulk/auto-jelly.
    local stats, cells, counts, missing = scan()
    local current
    for _, candidate in ipairs(cells) do
        if candidate.x == cell.x and candidate.y == cell.y then current = candidate break end
    end
    assert(current and safe(current, counts), "Target became protected; stopping")
    if item == "Star" then assert(#missing == 0, "Star Egg requirements not met") end
    local before = stats.Eggs[item] or 0
    assert(before > 0, "No " .. item .. " remaining")
    local remaining, accepted, honeycomb, discovered, eggUses =
        remote:InvokeServer(cell.x, cell.y, item, 1, false)
    -- A failed/ambiguous request stops the run. Never retry it blindly.
    assert(accepted and type(honeycomb) == "table" and type(remaining) == "number",
        "Server rejected item or returned an unknown result; stopping")
    Cache:Set({"Eggs", item}, remaining)
    Cache:Set("Honeycomb", honeycomb)
    if discovered then Cache:Set("DiscoveredBees", discovered) end
    if eggUses then Cache:Set({"Totals", "EggUses"}, eggUses) end
    local consumed = before - remaining
    assert(consumed >= 1 and consumed <= before, "Unexpected item consumption; stopping")
    local bee = honeycomb["x" .. cell.x] and honeycomb["x" .. cell.x]["y" .. cell.y]
    assert(bee and bee.Type, "Updated bee unavailable; stopping")
    print(string.format("[Gifted Star] %s (%d,%d) -> %s%s", item, cell.x, cell.y,
        gifted(bee) and "Gifted " or "", bee.Type))
    task.wait(Config.RollDelay)
    return consumed
end

local stats, cells, counts, missing = scan()
getgenv().AutoGiftedStarReport = {
    Missing = missing, RequiredTypes = #required,
    RoyalJelly = stats.Eggs.RoyalJelly or 0, StarEggs = stats.Eggs.Star or 0,
    DryRun = Config.DryRun,
}
local refillAmount, refillCost = purchasePlan(stats)
getgenv().AutoGiftedStarReport.RefillAmount = refillAmount
getgenv().AutoGiftedStarReport.RefillCost = refillCost
print("[Gifted Star] Missing gifted types: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
local target = choose(cells, counts)
if Config.DryRun then
    getgenv().AutoGiftedStarReport.Target = target and {
        X = target.x, Y = target.y, Type = target.bee.Type, Gifted = gifted(target.bee),
    } or nil
    print("[Gifted Star] Dry run complete; no movement or items used")
    return
end

while not getgenv().AutoGiftedStarStop do
    stats, cells, counts, missing = scan()
    getgenv().AutoGiftedStarReport.Missing = missing
    getgenv().AutoGiftedStarReport.JelliesUsed = usedJelly
    getgenv().AutoGiftedStarReport.RoyalJelly = stats.Eggs.RoyalJelly or 0
    target = choose(cells, counts)
    if #missing > 0 then
        if not counts.Basic then
            warn("[Gifted Star] Gifted Basic is missing. Royal Jelly cannot supply it; stopping.")
            break
        end
        if usedJelly >= Config.MaxRoyalJellies then
            warn("[Gifted Star] Jelly execution limit reached. Star Eggs kept.")
            break
        end
        if not target then warn("[Gifted Star] No unprotected roll slot remains") break end
        if (stats.Eggs.RoyalJelly or 0) <= Config.JellyReserve then
            if not Config.AutoRefill or not refill() then break end
        else
            usedJelly = usedJelly + useItem(target, "RoyalJelly")
        end
    else
        print("[Gifted Star] All required gifted types are currently in the hive")
        if usedEggs >= Config.MaxStarEggs or (stats.Eggs.Star or 0) < 1 then break end
        local missingMythic = false
        for name, info in pairs(Types) do
            if info.Rarity == "Mythic" and not counts[name] then missingMythic = true break end
        end
        if not missingMythic then
            warn("[Gifted Star] All gifted Mythic types already present; keeping Star Eggs")
            break
        end
        if not target then warn("[Gifted Star] No safe slot for the Star Egg") break end
        useItem(target, "Star")
        usedEggs = usedEggs + 1
    end
end
getgenv().AutoGiftedStarReport.JelliesUsed = usedJelly
getgenv().AutoGiftedStarReport.StarEggsUsed = usedEggs
local _, _, _, finalMissing = scan()
getgenv().AutoGiftedStarReport.Missing = finalMissing
print(string.format("[Gifted Star] Finished: %d jellies, %d Star Eggs; missing: %s",
    usedJelly, usedEggs, table.concat(finalMissing, ", ")))


end
local ok, err = xpcall(run, function(message) return tostring(message) end)
env.AutoGiftedStarRunning = false
if not ok then env.AutoGiftedStarError = err warn("[Gifted Star] " .. err) end

