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
    for amount = Config.MaxRefill, Config.MinRefill, -1000 do
        local cost = jellyCost(stats, amount)
        if cost <= budget then return amount, cost end
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
    assert(ok, err)
end

local function refill()
    local stats = Cache:Update()
    local amount, expectedCost = purchasePlan(stats)
    if not amount then
        warn("[Gifted Star] Cannot afford 10,000 jelly with the honey reserve; stopping")
        return false
    end
    local shop = workspace.Shops.JellyDispenser
    local floor = assert(shop.Floor.Value, "Jelly shop floor unavailable")
    print("[Gifted Star] Walking to honey Jelly Dispenser")
    walkToPart(floor)
    stats = Cache:Update()
    amount, expectedCost = purchasePlan(stats)
    if not amount then return false end
    assert(not getgenv().AutoGiftedStarStop, "Stopped by user")
    local beforeJelly, beforeHoney = stats.Eggs.RoyalJelly or 0, stats.Honey
    print(string.format("[Gifted Star] Buying %d jelly for %.0f honey", amount, expectedCost))
    local accepted = ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Purchase", {
        Category = "Eggs", Type = "RoyalJelly", Amount = amount,
    })
    assert(accepted, "Jelly purchase rejected; stopping")
    local updated = Cache:Update()
    assert((updated.Eggs.RoyalJelly or 0) - beforeJelly == amount,
        "Purchase inventory could not be verified; stopping")
    assert(beforeHoney - updated.Honey <= expectedCost,
        "Unexpected purchase cost; stopping")
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
    assert(before - remaining == 1, "Unexpected item consumption; stopping")
    local bee = honeycomb["x" .. cell.x] and honeycomb["x" .. cell.x]["y" .. cell.y]
    assert(bee and bee.Type, "Updated bee unavailable; stopping")
    print(string.format("[Gifted Star] %s (%d,%d) -> %s%s", item, cell.x, cell.y,
        gifted(bee) and "Gifted " or "", bee.Type))
    task.wait(Config.RollDelay)
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
            useItem(target, "RoyalJelly")
            usedJelly = usedJelly + 1
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
